import SpriteKit

// MARK: - Gloom Bug Node

/// Static enemy that sits on platforms. Contact deals stamina damage + knockback.
class GloomBugNode: SKSpriteNode {
    
    init() {
        let size = CGSize(width: 18, height: 14)
        super.init(texture: nil, color: SKColor(red: 0.2, green: 0.3, blue: 0.15, alpha: 1.0), size: size)
        
        setupPhysics()
        setupVisuals()
        
        name = "gloomBug"
        zPosition = 40
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 8)
        body.isDynamic = false
        body.categoryBitMask = GameConstants.Physics.enemy
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask = 0
        
        physicsBody = body
    }
    
    private func setupVisuals() {
        // Bug eyes
        for xOffset: CGFloat in [-4, 4] {
            let eye = SKShapeNode(circleOfRadius: 2)
            eye.fillColor = SKColor(red: 0.6, green: 0.8, blue: 0.3, alpha: 1.0)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: xOffset, y: 3)
            eye.zPosition = 1
            addChild(eye)
        }
        
        // Idle wiggle
        let wiggle = SKAction.sequence([
            SKAction.rotate(byAngle: 0.1, duration: 0.3),
            SKAction.rotate(byAngle: -0.2, duration: 0.6),
            SKAction.rotate(byAngle: 0.1, duration: 0.3)
        ])
        run(SKAction.repeatForever(wiggle))
    }
}

// MARK: - Trajectory Dots Node

/// Displays the aiming trajectory as a parabolic arc of fading dots.
class TrajectoryDotsNode: SKNode {
    
    private let dotCount = 6
    private var dots: [SKShapeNode] = []
    
    // MARK: Initialization
    
    override init() {
        super.init()
        
        for _ in 0..<dotCount {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = 0
            dot.zPosition = 60
            dots.append(dot)
            addChild(dot)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Update dot positions based on current charge and aim direction.
    func updateTrajectory(charge: CGFloat, direction: CGVector, staminaColor: SKColor) {
        let force = GameConstants.Jump.baseForce * max(charge, 0.05)
        let gravity = GameConstants.World.gravity
        let mass = GameConstants.World.playerMass
        let timeStep: CGFloat = 0.08 // Smaller time step for shorter line
        
        let initialVelocity = force / mass
        
        for (i, dot) in dots.enumerated() {
            let t = CGFloat(i + 1) * timeStep
            let x = direction.dx * initialVelocity * t
            let y = direction.dy * initialVelocity * t + 0.5 * gravity * t * t
            
            // Apply a visual dampening to keep the line near the player
            let visualScale: CGFloat = 0.25
            dot.position = CGPoint(x: x * visualScale, y: y * visualScale)
            
            dot.fillColor = staminaColor
            // Fade out dots based on distance
            dot.alpha = CGFloat(1.0 - Double(i) / Double(dotCount)) * (charge > 0.05 ? 1.0 : 0.0)
            // Smaller dots as they go further
            dot.setScale(CGFloat(1.0 - Double(i) / Double(dotCount * 2)))
        }
    }
}

// MARK: - Smoking Log Overlay

/// Brief overlay shown when the player logs a cigarette.
/// Auto-dismisses after 3 seconds without pausing the game.
class SmokingLogOverlay: SKNode {
    
    init(size: CGSize, cigaretteCount: Int, newMaxStamina: CGFloat, message: String) {
        super.init()
        
        zPosition = 200
        
        // Semi-transparent background
        let bg = SKShapeNode(rectOf: size, cornerRadius: 12)
        bg.fillColor = GameConstants.Colors.uiBG.withAlphaComponent(0.85)
        bg.strokeColor = GameConstants.Colors.infernoAccent.withAlphaComponent(0.3)
        bg.lineWidth = 1
        addChild(bg)
        
        // Cigarette icon (text emoji as placeholder)
        let icon = SKLabelNode(text: "🚬")
        icon.fontSize = 28
        icon.position = CGPoint(x: 0, y: 20)
        icon.zPosition = 201
        addChild(icon)
        
        // Ash disintegration animation on the icon
        let ashAnim = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.scaleX(to: 1.5, duration: 0.5),
                SKAction.moveBy(x: 0, y: -5, duration: 0.5)
            ])
        ])
        icon.run(ashAnim)
        
        // Status text (Updated per la nuova logica: conta sigarette invece di maxStamina)
        let staminaLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        staminaLabel.text = "Sigarette oggi: \(cigaretteCount)"
        staminaLabel.fontSize = 18
        
        // Usa i colori dei Regni che abbiamo in GameConstants al posto dei vecchi colori stamina
        staminaLabel.fontColor = cigaretteCount < 5
            ? GameConstants.Colors.paradisoGreen
            : cigaretteCount < 15 ? GameConstants.Colors.purgatorioWarm : GameConstants.Colors.infernoAccent
            
        staminaLabel.position = CGPoint(x: 0, y: -5)
        staminaLabel.zPosition = 201
        addChild(staminaLabel)
        
        // Message
        let msgLabel = SKLabelNode(fontNamed: "Avenir-Light")
        msgLabel.text = message
        msgLabel.fontSize = 12
        msgLabel.fontColor = GameConstants.Colors.uiText.withAlphaComponent(0.7)
        msgLabel.position = CGPoint(x: 0, y: -28)
        msgLabel.zPosition = 201
        addChild(msgLabel)
        
        // Entrance animation
        alpha = 0
        setScale(0.8)
        let entrance = SKAction.group([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        run(entrance)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
