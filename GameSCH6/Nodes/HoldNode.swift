import SpriteKit

// MARK: - Hold Node (Appiglio)

/// Un appiglio sul muro per l'arrampicata stile bouldering.
class HoldNode: SKSpriteNode {
    
    let platformType: PlatformType
    
    // MARK: Initialization
    
    init(type: PlatformType = .solid) {
        self.platformType = type
        
        let radius: CGFloat = 16.0
        let color = HoldNode.color(for: type)
        
        super.init(texture: nil, color: .clear, size: CGSize(width: radius * 2, height: radius * 2))
        
        setupPhysics(radius: radius)
        setupVisuals(radius: radius, color: color)
        setupBehavior()
        
        name = "hold_\(type)"
        zPosition = 10
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Setup
    
    private func setupPhysics(radius: CGFloat) {
        // I nodi normali hanno un raggio di contatto 3x per aiutare il player (Helper),
        // ma gli SPIKE devono essere precisi e "onesti". Usiamo 0.8x del raggio visivo per gli spike.
        let physicsRadius = (platformType == .spike) ? radius * 0.8 : radius * 3.0
        
        let body = SKPhysicsBody(circleOfRadius: physicsRadius)
        body.isDynamic = false
        body.categoryBitMask = (platformType == .spike) ? GameConstants.Physics.spike : 
                               (platformType == .checkpoint) ? GameConstants.Physics.checkpoint : 
                               GameConstants.Physics.hold
        
        // I hold non collidono fisicamente, ma generano contatti
        body.collisionBitMask = 0
        body.contactTestBitMask = GameConstants.Physics.player
        
        physicsBody = body
    }
    
    private func setupVisuals(radius: CGFloat, color: SKColor) {
        let rockShape = SKShapeNode(circleOfRadius: radius)
        rockShape.fillColor = color
        rockShape.strokeColor = color.withAlphaComponent(0.6)
        rockShape.lineWidth = 2
        
        // Distorcere un po' la forma per farla sembrare una roccia irregolare
        rockShape.yScale = CGFloat.random(in: 0.8...1.2)
        rockShape.xScale = CGFloat.random(in: 0.8...1.2)
        rockShape.zRotation = CGFloat.random(in: 0...2 * .pi)
        
        addChild(rockShape)
        
        // Effetti speciali basati sul tipo (presi in prestito da PlatformNode)
        switch platformType {
        case .cloud:
            rockShape.alpha = 0.6
        case .spike:
            // Aggiungiamo delle "spine" visive
            for i in 0..<8 {
                let angle = CGFloat(i) * (.pi * 2 / 8)
                let thorn = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: cos(angle) * (radius + 8), y: sin(angle) * (radius + 8)))
                path.addLine(to: CGPoint(x: cos(angle + 0.2) * (radius + 2), y: sin(angle + 0.2) * (radius + 2)))
                path.closeSubpath()
                thorn.path = path
                thorn.fillColor = color
                thorn.strokeColor = .black
                thorn.lineWidth = 1
                addChild(thorn)
            }
        default:
            break
        }
    }
    
    private func setupBehavior() {
        switch platformType {
        case .moving:
            let moveRight = SKAction.moveBy(x: 50, y: 0, duration: 2.0)
            moveRight.timingMode = .easeInEaseOut
            let moveLeft = moveRight.reversed()
            run(SKAction.repeatForever(SKAction.sequence([moveRight, moveLeft])))
        case .checkpoint:
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.6),
                SKAction.scale(to: 0.85, duration: 0.6)
            ])
            run(SKAction.repeatForever(pulse))
        default:
            break
        }
    }
    
    // MARK: Interaction behavior
    
    func onPlayerGrab(stamina: PlayerStamina) -> Bool {
        // Se è una nuvola e hai fumato troppo, non puoi aggrapparti
        if platformType == .cloud && stamina.cigarettesLoggedToday >= 10 {
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.2, duration: 0.2),
                SKAction.fadeAlpha(to: 0.6, duration: 0.5)
            ])
            run(fade)
            return false // Grab failed
        }
        
        if platformType == .crumbling {
            // Cade poco dopo ma poi ritorna (respawn) per non bloccare il giocatore se cade
            run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.run { [weak self] in
                    self?.physicsBody?.categoryBitMask = 0 // Lascia cadere il giocatore
                },
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.wait(forDuration: 3.0), // Aspetta un po' prima di ricrearsi
                SKAction.run { [weak self] in
                    self?.physicsBody?.categoryBitMask = GameConstants.Physics.hold
                },
                SKAction.fadeIn(withDuration: 0.5)
            ]))
        }
        
        return true // Grab success
    }
    
    // MARK: Color Mapping
    
    private static func color(for type: PlatformType) -> SKColor {
        switch type {
        case .solid:     return SKColor(white: 0.5, alpha: 1.0)
        case .crumbling: return SKColor(white: 0.4, alpha: 0.8)
        case .sticky:    return SKColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1.0)
        case .bouncy:    return GameConstants.Colors.paradisoGreen
        case .moving:    return GameConstants.Colors.purgatorioWarm
        case .cloud:     return SKColor.white
        case .spike:      return GameConstants.Colors.infernoAccent
        case .checkpoint: return SKColor.cyan
        }
    }
}
