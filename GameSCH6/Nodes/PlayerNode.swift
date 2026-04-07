import SpriteKit

// MARK: - Player Node
//
// SPRITESHEET ANIMATION:
//   Expected asset names in Assets.xcassets:
//     player_00, player_01, player_02, player_03, player_04,
//     player_05, player_07, player_08, player_09
//   (9 frames, with non-continuous numbering — skips player_06)
//
// ROTATION:
//   zRotation = currentAngle + .pi/2 → head towards the rock while rotating.
//   In flight zRotation = 0 → character upright.
//
// RED X FIX:
//   PlayerNode.preloadTextures { } must be called in GameScene.didMove(to:)
//   BEFORE setupPlayer(). setupPlayer() should be moved inside the completion.

class PlayerNode: SKSpriteNode {

    // MARK: - Rotation State

    private(set) var currentHold: HoldNode?
    private(set) var currentAngle: CGFloat = 0
    var angularVelocity: CGFloat = GameConstants.Swing.baseAngularVelocity
    let armLength: CGFloat = GameConstants.Swing.armLength

    // MARK: - Animation Textures
    private let grabTextures: [SKTexture]
    private let releaseTextures: [SKTexture]
    private let idleHoldTexture: SKTexture   // player_08: hands up, used as idle while grabbed

    // true = the grab animation has already played for this hold,
    //        should not be restarted until released and re-grabbed
    private var grabAnimDidPlay = false

    // MARK: - Frame Names
    // Explicit list of real names in Assets.xcassets.
    // Change here if you rename the files.
    private static let frameNames = [
        "player_00", "player_01", "player_02", "player_03",
        "player_04", "player_05", "player_06", "player_07", "player_08"
    ]

    // MARK: - Preload (call from GameScene BEFORE init)
    static func preloadTextures(completion: @escaping () -> Void) {
        let textures = frameNames.map { SKTexture(imageNamed: $0) }
        SKTexture.preload(textures) {
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - Visuals
    private var armLine: SKShapeNode!
    private var orbitCircle: SKShapeNode!
    private var ashBackpack: SKShapeNode!
    private var breathingEmitter: SKEmitterNode!
    private var coughEmitter: SKEmitterNode?

    // MARK: - Smoke Trail
    private let smokeTrail = SmokeTrailEffect()

    // MARK: - Init

    init() {
        let frames = PlayerNode.frameNames.map { SKTexture(imageNamed: $0) }

        grabTextures     = frames
        releaseTextures  = frames.reversed()
        idleHoldTexture = frames.isEmpty ? SKTexture() : frames[min(frames.count - 2, frames.count - 1)]

        // Starts on frame 8 (hands up)
        super.init(texture: grabTextures.first ?? idleHoldTexture, color: .clear, size: CGSize(width: 105, height: 120))

        setupPhysics()
        setupVisuals()
        zPosition = 50
        name = "player"
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 14)
        body.mass = GameConstants.World.playerMass
        body.friction = 0.1
        body.restitution = 0.0
        body.linearDamping = 0.3
        body.allowsRotation = false
        body.isDynamic = true
        body.affectedByGravity = false

        body.categoryBitMask    = GameConstants.Physics.player
        body.contactTestBitMask = GameConstants.Physics.checkpoint
                                | GameConstants.Physics.enemy
                                | GameConstants.Physics.spike
                                | GameConstants.Physics.pigeon
        body.collisionBitMask   = GameConstants.Physics.boundary

        physicsBody = body
    }

    private func setupVisuals() {
        armLine = SKShapeNode()
        armLine.strokeColor = SKColor.white.withAlphaComponent(0.35)
        armLine.lineWidth = 2
        armLine.lineCap = .round
        armLine.zPosition = 45
        armLine.isHidden = true

        orbitCircle = SKShapeNode(circleOfRadius: armLength)
        orbitCircle.strokeColor = SKColor.white.withAlphaComponent(0.08)
        orbitCircle.lineWidth = 1
        orbitCircle.fillColor = .clear
        orbitCircle.zPosition = 44
        orbitCircle.isHidden = true

        ashBackpack = SKShapeNode(rectOf: CGSize(width: 14, height: 18), cornerRadius: 3)
        ashBackpack.fillColor = SKColor(white: 0.35, alpha: 0.7)
        ashBackpack.strokeColor = SKColor(white: 0.25, alpha: 0.5)
        ashBackpack.lineWidth = 1
        ashBackpack.position = CGPoint(x: 0, y: -8)
        ashBackpack.zPosition = -1
        ashBackpack.setScale(0)
        addChild(ashBackpack)

        breathingEmitter = SKEmitterNode()
        breathingEmitter.particleBirthRate = 0
        breathingEmitter.particleLifetime = 0.6
        breathingEmitter.particleSpeed = 15
        breathingEmitter.emissionAngle = .pi / 2
        breathingEmitter.emissionAngleRange = 0.4
        breathingEmitter.particleAlpha = 0.3
        breathingEmitter.particleAlphaSpeed = -0.5
        breathingEmitter.particleScale = 0.04
        breathingEmitter.particleScaleSpeed = 0.02
        breathingEmitter.particleColor = SKColor(white: 0.7, alpha: 1.0)
        breathingEmitter.particleColorBlendFactor = 1.0
        breathingEmitter.position = CGPoint(x: 0, y: 16)
        breathingEmitter.zPosition = 65
        addChild(breathingEmitter)

        // Smoke trail — behind the player sprite
        smokeTrail.zPosition = -2
        addChild(smokeTrail)
    }

    // MARK: - Animation

    func playGrabAnimation() {
        removeAction(forKey: "playerAnim")
        guard !grabTextures.isEmpty else { return }
        run(SKAction.animate(with: grabTextures,
                             timePerFrame: 0.030,
                             resize: false,
                             restore: false),
            withKey: "playerAnim")
    }

    func playReleaseAnimation() {
        removeAction(forKey: "playerAnim")
        guard !releaseTextures.isEmpty else { return }
        run(SKAction.animate(with: releaseTextures,
                             timePerFrame: 0.055,
                             resize: false,
                             restore: false),
            withKey: "playerAnim")
    }

    // MARK: - Grab

    func grab(hold: HoldNode, preserveVelocity: Bool = false) {
        guard hold !== currentHold else { return }

        let prevHold = currentHold
        currentHold = hold

        let holdPosInParent = hold.parent?.convert(hold.position, to: parent!) ?? hold.position

        let dx = position.x - holdPosInParent.x
        let dy = position.y - holdPosInParent.y
        currentAngle = atan2(dy, dx)

        position = CGPoint(
            x: holdPosInParent.x + cos(currentAngle) * armLength,
            y: holdPosInParent.y + sin(currentAngle) * armLength
        )

        if !preserveVelocity || prevHold == nil {
            angularVelocity = GameConstants.Swing.baseAngularVelocity
        }

        if let prev = prevHold {
            let prevPos = prev.parent?.convert(prev.position, to: parent!) ?? prev.position
            let toNew = CGPoint(x: holdPosInParent.x - prevPos.x,
                                y: holdPosInParent.y - prevPos.y)
            let cross = toNew.x * sin(currentAngle) - toNew.y * cos(currentAngle)
            angularVelocity = cross < 0 ? -abs(angularVelocity) : abs(angularVelocity)
        }

        removeAction(forKey: "restore_gravity")
        physicsBody?.affectedByGravity = false
        physicsBody?.velocity = .zero
        zRotation = currentAngle + .pi / 2

        // Plays the animation only on the FIRST grab on this hold.
        // If grab() is recalled on the same hold (e.g. from attachToFirstHold),
        // the flag prevents restarting the animation and frame 08 remains still.
        if !grabAnimDidPlay {
            grabAnimDidPlay = true
            playGrabAnimation()
            hold.playGrabEffect()
        } else {
            // Already grabbed: ensure the texture is fixed on frame 08
            removeAction(forKey: "playerAnim")
            texture = idleHoldTexture
        }
    }

    // MARK: - Release

    func releaseHold(stamina: PlayerStamina) -> CGVector {
        guard currentHold != nil else { return .zero }

        let nx = cos(currentAngle)
        let ny = sin(currentAngle)
        let jumpForce = GameConstants.Jump.baseForce * stamina.jumpForceMultiplier
        let jumpVelocity = CGVector(dx: nx * jumpForce, dy: ny * jumpForce)

        currentHold = nil
        grabAnimDidPlay = false   // next grab will play the animation again

        physicsBody?.affectedByGravity = false
        physicsBody?.velocity = jumpVelocity

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.physicsBody?.affectedByGravity = true
            }
        ]), withKey: "restore_gravity")

        zRotation = 0
        playReleaseAnimation()

        return jumpVelocity
    }

    // MARK: - Update (every frame, when grabbed)

    func updateRotation(deltaTime: TimeInterval, stamina: PlayerStamina,
                        holdPositionInParent: CGPoint) {
        guard currentHold != nil else { return }

        currentAngle += CGFloat(deltaTime) * angularVelocity

        position = CGPoint(
            x: holdPositionInParent.x + cos(currentAngle) * armLength,
            y: holdPositionInParent.y + sin(currentAngle) * armLength
        )

        zRotation = currentAngle + .pi / 2
    }

    // MARK: - Smoke Mirror Visuals

    func updateSmokeMirrorVisuals(cigarettes: Int) {
        let maxCig = CGFloat(GameConstants.SmokeMirror.maxVisualCigarettes)
        let fillRatio = min(1.0, CGFloat(cigarettes) / maxCig)

        // Ash backpack
        ashBackpack.setScale(fillRatio)
        let darkness = 0.35 - fillRatio * 0.2
        ashBackpack.fillColor = SKColor(white: darkness, alpha: 0.5 + fillRatio * 0.3)

        // Breathing puff
        breathingEmitter.particleBirthRate = cigarettes > 5
            ? CGFloat(cigarettes - 5) * 3.0
            : 0

        // Smoke trail — velocity from physics body, fallback zero
        let velocity = physicsBody?.velocity ?? .zero
        smokeTrail.update(cigarettes: cigarettes, velocity: velocity)
    }

    private func updateArmLine(holdPos: CGPoint) {
        let path = CGMutablePath()
        path.move(to: holdPos)
        path.addLine(to: position)
        armLine.path = path
    }

    // MARK: - Animations

    func land() {
        let sq = SKAction.group([SKAction.scaleY(to: 0.88, duration: 0.05),
                                  SKAction.scaleX(to: 1.12, duration: 0.05)])
        let rs = SKAction.group([SKAction.scaleY(to: 1.0,  duration: 0.1),
                                  SKAction.scaleX(to: 1.0,  duration: 0.1)])
        run(SKAction.sequence([sq, rs]), withKey: "land")
    }

    func triggerCoughInterrupt() {
        let flashRed = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.3),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ])
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -4, y: 0, duration: 0.04),
            SKAction.moveBy(x:  8, y: 0, duration: 0.08),
            SKAction.moveBy(x: -4, y: 0, duration: 0.04)
        ])
        run(SKAction.group([flashRed, shake]))
        spawnCoughBurst()
    }

    private func spawnCoughBurst() {
        if coughEmitter == nil {
            let e = SKEmitterNode()
            e.particleBirthRate  = 60; e.particleLifetime    = 0.35
            e.particleSpeed      = 45; e.emissionAngle       = .pi / 2
            e.emissionAngleRange = 1.2; e.particleAlpha      = 0.65
            e.particleAlphaSpeed = -1.8; e.particleScale     = 0.09
            e.particleColor = SKColor(white: 0.7, alpha: 1)
            coughEmitter = e
        }
        guard let burst = coughEmitter?.copy() as? SKEmitterNode else { return }
        burst.position = CGPoint(x: 0, y: 16)
        burst.numParticlesToEmit = 12
        burst.zPosition = 65
        addChild(burst)
        burst.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    var armLineNode: SKShapeNode { armLine }
    var orbitCircleNode: SKShapeNode { orbitCircle }
}
