import SpriteKit

// MARK: - Midnight Reset Cutscene

/// Dramatic cutscene that plays when the user exceeds their daily cigarette goal.
/// Shows the character being pulled down through smoke to the last checkpoint.
class MidnightResetCutscene: SKScene {
    
    var onComplete: (() -> Void)?
    
    private var messageLabel: SKLabelNode!
    private var player: PlayerNode?
    private var stamina: PlayerStamina?
    
    init(size: CGSize, player: PlayerNode, stamina: PlayerStamina) {
        self.player = player
        self.stamina = stamina
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        // Phase 1: Darkness + message
        let overlay = SKSpriteNode(color: .black, size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 0
        overlay.alpha = 0
        addChild(overlay)
        
        // Heavy smoke particles
        let smoke = createHeavySmokeEmitter()
        smoke.position = CGPoint(x: size.width / 2, y: size.height / 2)
        smoke.zPosition = 5
        smoke.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        addChild(smoke)
        
        // Warning message
        messageLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        messageLabel.text = "The smoke pulls you back..."
        messageLabel.fontSize = 22
        messageLabel.fontColor = GameConstants.Colors.infernoAccent
        messageLabel.alpha = 0
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        messageLabel.zPosition = 10
        addChild(messageLabel)
        
        // Subtitle
        let subtitle = SKLabelNode(fontNamed: "Avenir-Light")
        subtitle.text = "You exceeded your goal.\nTry again tomorrow."
        subtitle.fontSize = 16
        subtitle.fontColor = GameConstants.Colors.uiText.withAlphaComponent(0.6)
        subtitle.numberOfLines = 2
        subtitle.alpha = 0
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.6 - 40)
        subtitle.zPosition = 10
        addChild(subtitle)
        
        // Ghostly hands (simplified as dark shapes pulling down)
        let hands = createGhostlyHands()
        hands.position = CGPoint(x: size.width / 2, y: size.height * 0.3)
        hands.zPosition = 8
        hands.alpha = 0
        addChild(hands)
        
        // Animation sequence
        let sequence = SKAction.sequence([
            // Fade in overlay
            SKAction.run { overlay.run(SKAction.fadeAlpha(to: 0.8, duration: 1.0)) },
            SKAction.wait(forDuration: 1.0),
            
            // Show smoke message
            SKAction.run {
                self.messageLabel.run(SKAction.fadeIn(withDuration: 0.8))
                subtitle.run(SKAction.fadeIn(withDuration: 0.8))
            },
            SKAction.wait(forDuration: 2.0),
            
            // Show ghostly hands pulling down
            SKAction.run {
                hands.run(SKAction.fadeIn(withDuration: 0.5))
                hands.run(SKAction.moveBy(x: 0, y: -100, duration: 2.0))
            },
            SKAction.wait(forDuration: 2.0),
            
            // Haptic rumble
            SKAction.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            },
            SKAction.wait(forDuration: 1.0),
            
            // Fade out everything
            SKAction.run {
                self.enumerateChildNodes(withName: "//*") { node, _ in
                    node.run(SKAction.fadeOut(withDuration: 1.0))
                }
            },
            SKAction.wait(forDuration: 1.5),
            
            // Complete
            SKAction.run { [weak self] in
                self?.onComplete?()
                
                // Return to GameScene
                guard let playerNode = self?.player, let stamina = self?.stamina else { return }
                let gameScene = GameScene(size: CGSize(width: 393, height: 852), player: playerNode, stamina: stamina)
                gameScene.scaleMode = .aspectFill
                self?.view?.presentScene(gameScene, transition: SKTransition.fade(withDuration: 1.0))
            }
        ])
        
        run(sequence)
    }
    
    // MARK: Emitter
    
    private func createHeavySmokeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 30
        emitter.particleLifetime = 4
        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = .pi * 1.5
        emitter.emissionAngleRange = .pi
        emitter.particleAlpha = 0.4
        emitter.particleAlphaSpeed = -0.1
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3
        emitter.particleColor = GameConstants.Colors.infernoSmoke
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    private func createGhostlyHands() -> SKNode {
        let container = SKNode()
        
        for i in 0..<3 {
            let hand = SKShapeNode(rectOf: CGSize(width: 20, height: 80), cornerRadius: 10)
            hand.fillColor = GameConstants.Colors.infernoSmoke.withAlphaComponent(0.5)
            hand.strokeColor = .clear
            hand.position = CGPoint(x: CGFloat(i - 1) * 50, y: 0)
            
            // Creepy reaching animation
            let reach = SKAction.sequence([
                SKAction.moveBy(x: 0, y: -15, duration: 0.5),
                SKAction.moveBy(x: 0, y: 15, duration: 0.5)
            ])
            hand.run(SKAction.repeatForever(reach))
            
            container.addChild(hand)
        }
        
        return container
    }
}
