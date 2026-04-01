import SpriteKit

// MARK: - Haze Pigeon Node

/// Smoker-only enemy that dive-bombs players with a Smoky Aura.
/// Cannot be killed — only avoided. Attracted by cigarette smoke.
class HazePigeonNode: SKSpriteNode {
    
    enum PigeonState {
        case circling    // Flying around off-screen or at a distance
        case diving      // Diving toward the player
        case retreating  // Flying away after an attack
    }
    
    private(set) var state: PigeonState = .circling
    private var targetPosition: CGPoint = .zero
    private let divingSpeed: CGFloat = 300
    private let circleRadius: CGFloat = 150
    
    // MARK: Initialization
    
    init() {
        let size = CGSize(width: 28, height: 24)
        super.init(texture: nil, color: GameConstants.Colors.hazePigeon, size: size)
        
        setupPhysics()
        setupVisuals()
        
        name = "hazePigeon"
        zPosition = 45
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Setup
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 12)
        body.isDynamic = true
        body.affectedByGravity = false
        body.mass = 0.5
        body.categoryBitMask = GameConstants.Physics.pigeon
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask = 0 // Passes through everything except player contact
        
        physicsBody = body
    }
    
    private func setupVisuals() {
        // Wing shapes
        let leftWing = createWing(xScale: -1)
        leftWing.position = CGPoint(x: -12, y: 4)
        addChild(leftWing)
        
        let rightWing = createWing(xScale: 1)
        rightWing.position = CGPoint(x: 12, y: 4)
        addChild(rightWing)
        
        // Glowing red eye
        let eye = SKShapeNode(circleOfRadius: 2.5)
        eye.fillColor = GameConstants.Colors.infernoAccent
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 6, y: 4)
        eye.zPosition = 1
        addChild(eye)
        
        // Eye glow
        let glowPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        ])
        eye.run(SKAction.repeatForever(glowPulse))
        
        // Trailing smoke
        let trail = createTrailEmitter()
        trail.position = CGPoint(x: -10, y: 0)
        trail.zPosition = -1
        addChild(trail)
        
        // Flapping animation
        startFlapping()
    }
    
    private func createWing(xScale: CGFloat) -> SKShapeNode {
        let wing = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10 * xScale, y: 8))
        path.addLine(to: CGPoint(x: 8 * xScale, y: 0))
        path.closeSubpath()
        wing.path = path
        wing.fillColor = GameConstants.Colors.hazePigeon.withAlphaComponent(0.8)
        wing.strokeColor = .clear
        wing.name = "wing"
        return wing
    }
    
    private func createTrailEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 10
        emitter.particleLifetime = 0.8
        emitter.particleSpeed = 5
        emitter.emissionAngle = .pi
        emitter.particleAlpha = 0.3
        emitter.particleAlphaSpeed = -0.4
        emitter.particleScale = 0.08
        emitter.particleScaleSpeed = 0.02
        emitter.particleColor = GameConstants.Colors.infernoSmoke
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    private func startFlapping() {
        enumerateChildNodes(withName: "wing") { wing, _ in
            let flapUp = SKAction.scaleY(to: 1.3, duration: 0.15)
            let flapDown = SKAction.scaleY(to: 0.7, duration: 0.15)
            wing.run(SKAction.repeatForever(SKAction.sequence([flapUp, flapDown])))
        }
    }
    
    // MARK: AI Behavior
    
    /// Update the pigeon's behavior each frame.
    func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        targetPosition = playerPosition
        
        switch state {
        case .circling:
            circleAround(playerPosition: playerPosition, deltaTime: deltaTime)
        case .diving:
            diveToward(playerPosition: playerPosition, deltaTime: deltaTime)
        case .retreating:
            retreat(deltaTime: deltaTime)
        }
    }
    
    /// Initiate a dive attack toward the player
    func startDive() {
        state = .diving
        
        // Visual cue — flash eyes
        let flash = SKAction.sequence([
            SKAction.colorize(with: GameConstants.Colors.infernoAccent, colorBlendFactor: 0.5, duration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ])
        run(SKAction.repeat(flash, count: 2))
    }
    
    // MARK: Movement
    
    private func circleAround(playerPosition: CGPoint, deltaTime: TimeInterval) {
        // Orbit around the player at a distance
        let time = CACurrentMediaTime()
        let angle = CGFloat(time) * 1.5 // Orbit speed
        let x = playerPosition.x + cos(angle) * circleRadius
        let y = playerPosition.y + sin(angle) * circleRadius + 100 // Above player
        
        let targetPos = CGPoint(x: x, y: y)
        let dx = targetPos.x - position.x
        let dy = targetPos.y - position.y
        let speed: CGFloat = 100
        
        position.x += dx * CGFloat(deltaTime) * speed / max(1, sqrt(dx*dx + dy*dy))
        position.y += dy * CGFloat(deltaTime) * speed / max(1, sqrt(dx*dx + dy*dy))
        
        // Face direction of movement
        xScale = dx > 0 ? abs(xScale) : -abs(xScale)
    }
    
    private func diveToward(playerPosition: CGPoint, deltaTime: TimeInterval) {
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 5 else {
            // Hit! Start retreating
            state = .retreating
            return
        }
        
        let speed = divingSpeed * CGFloat(deltaTime)
        position.x += (dx / distance) * speed
        position.y += (dy / distance) * speed
        
        // Face direction
        xScale = dx > 0 ? abs(xScale) : -abs(xScale)
    }
    
    private func retreat(deltaTime: TimeInterval) {
        // Fly upward and off-screen
        position.y += 200 * CGFloat(deltaTime)
        
        // After flying high enough, remove
        if let scene = scene, position.y > scene.size.height + 200 {
            removeFromParent()
        }
    }
}
