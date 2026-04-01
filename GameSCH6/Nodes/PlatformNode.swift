import SpriteKit

// MARK: - Platform Node

/// Base platform node. Subclass behavior is determined by `platformType`.
class PlatformNode: SKSpriteNode {
    
    let platformType: PlatformType
    private var hasBeenLandedOn = false
    
    // Proprietà locali che sostituiscono il vecchio GameConstants.Platforms
    private var moveRange: CGFloat = 80
    private var moveSpeed: TimeInterval = 2.0
    private let crumbleDelay: TimeInterval = 1.5
    private let bouncyImpulse: CGFloat = 600.0 // Adattato per la nuova gravità pesante
    private let cloudMaxCigarettes: Int = 10 // Limite massimo di sigarette prima di sfondare le nuvole
    
    // MARK: Initialization
    
    init(type: PlatformType, width: CGFloat) {
        self.platformType = type
        
        let height: CGFloat = 12
        let color = PlatformNode.color(for: type)
        
        super.init(texture: nil, color: color, size: CGSize(width: width, height: height))
        
        setupPhysics(width: width, height: height)
        setupVisuals()
        setupBehavior()
        
        name = "platform_\(type)"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Setup
    
    private func setupPhysics(width: CGFloat, height: CGFloat) {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: width, height: height))
        body.isDynamic = false
        body.friction = platformType == .sticky ? 1.0 : 0.3
        body.restitution = platformType == .bouncy ? 0.8 : 0.1
        body.categoryBitMask = platformType == .spike
            ? GameConstants.Physics.spike
            : GameConstants.Physics.platform
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask = GameConstants.Physics.player
        
        physicsBody = body
    }
    
    private func setupVisuals() {
        switch platformType {
        case .crumbling:
            addCrackOverlay()
        case .sticky:
            addDripEffect()
        case .bouncy:
            let spring = SKShapeNode(rectOf: CGSize(width: size.width * 0.6, height: 4), cornerRadius: 2)
            spring.fillColor = GameConstants.Colors.paradisoGreen
            spring.strokeColor = .clear
            spring.position = CGPoint(x: 0, y: size.height / 2 + 2)
            addChild(spring)
        case .cloud:
            alpha = 0.7
            let glow = SKShapeNode(rectOf: CGSize(width: size.width + 10, height: size.height + 6), cornerRadius: 8)
            glow.fillColor = SKColor.white.withAlphaComponent(0.1)
            glow.strokeColor = .clear
            glow.zPosition = -1
            addChild(glow)
        case .spike:
            addSpikeVisuals()
        default:
            break
        }
    }
    
    private func setupBehavior() {
        switch platformType {
        case .moving:
            startMoving()
        case .bouncy:
            let bounce = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 2, duration: 0.5),
                SKAction.moveBy(x: 0, y: -2, duration: 0.5)
            ])
            run(SKAction.repeatForever(bounce))
        default:
            break
        }
    }
    
    // MARK: Landing Behavior
    
    /// Called when the player lands on this platform
    func onPlayerLand(player: PlayerNode, stamina: PlayerStamina) {
        guard !hasBeenLandedOn || platformType != .crumbling else { return }
        hasBeenLandedOn = true
        
        switch platformType {
        case .crumbling:
            triggerCrumble()
            
        case .bouncy:
            triggerBounce(player: player)
            
        case .cloud:
            // Nuova meccanica Specchio: se hai fumato troppo (peso dei polmoni alto) cadi attraverso le nuvole
            if stamina.cigarettesLoggedToday >= cloudMaxCigarettes {
                physicsBody?.collisionBitMask = 0
                let fadeAndRemove = SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.run { [weak self] in
                        self?.physicsBody?.collisionBitMask = GameConstants.Physics.player
                        self?.alpha = 0.7
                        self?.hasBeenLandedOn = false
                    }
                ])
                run(fadeAndRemove)
            }
            
        default:
            break
        }
    }
    
    // MARK: Platform Behaviors
    
    private func triggerCrumble() {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -2, y: 0, duration: 0.05),
            SKAction.moveBy(x: 4, y: 0, duration: 0.05),
            SKAction.moveBy(x: -2, y: 0, duration: 0.05)
        ])
        
        run(SKAction.sequence([
            SKAction.repeat(shake, count: 5),
            SKAction.wait(forDuration: crumbleDelay - 0.75),
            SKAction.run { [weak self] in
                self?.physicsBody?.collisionBitMask = 0
                self?.physicsBody?.categoryBitMask = 0
            },
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.moveBy(x: 0, y: -20, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))
    }
    
    private func triggerBounce(player: PlayerNode) {
        let springSquash = SKAction.sequence([
            SKAction.scaleY(to: 0.7, duration: 0.08),
            SKAction.scaleY(to: 1.2, duration: 0.08),
            SKAction.scaleY(to: 1.0, duration: 0.1)
        ])
        run(springSquash)
        
        player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: bouncyImpulse))
    }
    
    private func startMoving() {
        let moveRight = SKAction.moveBy(x: moveRange, y: 0, duration: moveSpeed)
        moveRight.timingMode = .easeInEaseOut
        let moveLeft = moveRight.reversed()
        run(SKAction.repeatForever(SKAction.sequence([moveRight, moveLeft])))
    }
    
    // MARK: Visuals Helpers
    
    private func addCrackOverlay() {
        let crack = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size.width * 0.3, y: 0))
        path.addLine(to: CGPoint(x: -size.width * 0.1, y: size.height * 0.3))
        path.addLine(to: CGPoint(x: size.width * 0.1, y: -size.height * 0.2))
        path.addLine(to: CGPoint(x: size.width * 0.3, y: 0))
        crack.path = path
        crack.strokeColor = SKColor.black.withAlphaComponent(0.3)
        crack.lineWidth = 1
        crack.zPosition = 1
        addChild(crack)
    }
    
    private func addDripEffect() {
        let drip = SKShapeNode(rectOf: CGSize(width: 3, height: 8), cornerRadius: 1.5)
        drip.fillColor = color.withAlphaComponent(0.6)
        drip.strokeColor = .clear
        drip.position = CGPoint(x: CGFloat.random(in: -size.width/3...size.width/3), y: -size.height/2 - 4)
        
        let dripAnim = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: -8, duration: 0.8),
            SKAction.moveBy(x: 0, y: 8, duration: 0),
            SKAction.wait(forDuration: CGFloat.random(in: 0.5...2.0))
        ]))
        drip.run(dripAnim)
        addChild(drip)
    }
    
    private func addSpikeVisuals() {
        let spikeCount = Int(size.width / 12)
        for i in 0..<spikeCount {
            let spike = SKShapeNode()
            let path = CGMutablePath()
            let x = -size.width / 2 + CGFloat(i) * 12 + 6
            path.move(to: CGPoint(x: x - 5, y: size.height / 2))
            path.addLine(to: CGPoint(x: x, y: size.height / 2 + 8))
            path.addLine(to: CGPoint(x: x + 5, y: size.height / 2))
            path.closeSubpath()
            spike.path = path
            spike.fillColor = GameConstants.Colors.infernoAccent
            spike.strokeColor = .clear
            spike.zPosition = 1
            addChild(spike)
        }
    }
    
    // MARK: Color Mapping
    
    private static func color(for type: PlatformType) -> SKColor {
        switch type { // Rimosso i due punti qui
        case .solid:     
            return SKColor(white: 0.4, alpha: 1.0)
        case .crumbling:
            return SKColor(white: 0.35, alpha: 0.8)
        case .sticky:
            return SKColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1.0)
        case .bouncy:
            return GameConstants.Colors.paradisoGreen.withAlphaComponent(0.8)
        case .moving:
            return GameConstants.Colors.purgatorioWarm
        case .cloud:
            return SKColor.white
        case .spike:
            return SKColor(red: 0.3, green: 0.15, blue: 0.15, alpha: 1.0)
        case .checkpoint:
            // Aggiunto per coerenza con il resto del gioco
            return GameConstants.Colors.paradisoGreen
        }
    }
}
