import SpriteKit

// MARK: - Midnight Reset Cutscene (Enhanced)
//
// Dramatic cutscene triggered when the user exceeds their daily goal.
// Shows:
// 1. Smoke hands grabbing the character
// 2. Earned cosmetics from the streak flying away one by one
// 3. Stronger narrative messages linking smoking to loss
// 4. The player being dragged downwards
//
// THIS ACTUALLY REMOVES COSMETICS — they are not temporarily hidden.

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
        
        // ── Background overlay ──
        let overlay = SKSpriteNode(color: .black, size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 0
        overlay.alpha = 0
        addChild(overlay)
        
        // ── Heavy smoke particles ──
        let smoke = createHeavySmokeEmitter()
        smoke.position = CGPoint(x: size.width / 2, y: size.height / 2)
        smoke.zPosition = 5
        smoke.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        addChild(smoke)
        
        // ── Ghostly hands ──
        let hands = createGhostlyHands()
        hands.position = CGPoint(x: size.width / 2, y: size.height * 0.3)
        hands.zPosition = 8
        hands.alpha = 0
        addChild(hands)
        
        // ── Narrative messages ──
        let messages = [
            "THE SMOKE REACHES YOU...",
            "EVERY CIGARETTE HAS A COST.",
            "YOUR PROGRESS DISSOLVES.",
            "PARADISE DRIFTS AWAY."
        ]
        
        // ── Cosmetics to remove ──
        let progress = PlayerProgress.shared
        var cosmeticsToLose: [String] = []
        if progress.equippedHat != nil { cosmeticsToLose.append("👑") }
        if progress.equippedTrail != nil { cosmeticsToLose.append("✨") }
        // Add placeholder if no cosmetics
        if cosmeticsToLose.isEmpty { cosmeticsToLose.append("⭐") }
        
        // ── Main animation sequence ──
        var actions: [SKAction] = []
        
        // Phase 1: Darkness
        actions.append(SKAction.run { overlay.run(SKAction.fadeAlpha(to: 0.85, duration: 1.5)) })
        actions.append(SKAction.wait(forDuration: 1.5))
        
        // Phase 2: Messages one at a time
        for (i, msg) in messages.enumerated() {
            actions.append(SKAction.run { [weak self] in
                guard let self = self else { return }
                let label = SKLabelNode(fontNamed: i == 0 ? "Minecraft" : "Pixeboy-z8XGD")
                label.text = msg
                label.fontSize = i == 0 ? 28 : 24
                label.fontColor = i == 0 ? GameConstants.Colors.infernoAccent : .white
                label.alpha = 0
                label.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.65 - CGFloat(i) * 35)
                label.zPosition = 10
                self.addChild(label)
                
                label.run(SKAction.sequence([
                    SKAction.fadeIn(withDuration: 0.5),
                    SKAction.wait(forDuration: 1.5),
                    SKAction.fadeOut(withDuration: 0.3)
                ]))
            })
            actions.append(SKAction.wait(forDuration: 2.3))
        }
        
        // Phase 3: Smoke hands grab the character
        actions.append(SKAction.run {
            hands.run(SKAction.fadeIn(withDuration: 0.5))
            hands.run(SKAction.sequence([
                SKAction.moveBy(x: 0, y: -60, duration: 1.5),
                SKAction.moveBy(x: 0, y: 20, duration: 0.5),
                SKAction.moveBy(x: 0, y: -80, duration: 2.0)
            ]))
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        })
        actions.append(SKAction.wait(forDuration: 1.0))
        
        // Phase 4: Cosmetics fly away
        for (_, emoji) in cosmeticsToLose.enumerated() {
            actions.append(SKAction.run { [weak self] in
                guard let self = self else { return }
                let cosmeticLabel = SKLabelNode(text: emoji)
                cosmeticLabel.fontSize = 48
                cosmeticLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.45)
                cosmeticLabel.zPosition = 15
                self.addChild(cosmeticLabel)
                
                // Animation: cosmetic dissolves upwards
                cosmeticLabel.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: CGFloat.random(in: -80...80), y: 200, duration: 1.5),
                        SKAction.fadeOut(withDuration: 1.5),
                        SKAction.scale(to: 0.2, duration: 1.5),
                        SKAction.rotate(byAngle: .pi * 3, duration: 1.5)
                    ]),
                    SKAction.removeFromParent()
                ]))
                
                // Message for each lost cosmetic
                let lostMsg = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
                lostMsg.text = "LOST."
                lostMsg.fontSize = 24
                lostMsg.fontColor = GameConstants.Colors.infernoAccent
                lostMsg.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.40)
                lostMsg.zPosition = 15
                lostMsg.alpha = 0
                self.addChild(lostMsg)
                lostMsg.run(SKAction.sequence([
                    SKAction.fadeIn(withDuration: 0.3),
                    SKAction.wait(forDuration: 0.8),
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
                
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            })
            actions.append(SKAction.wait(forDuration: 1.8))
        }
        
        // Phase 5: Actually remove cosmetics
        actions.append(SKAction.run {
            PlayerProgress.shared.equippedHat = nil
            PlayerProgress.shared.equippedTrail = nil
            // Streak reset if goal is exceeded
            // (Streak is already reset in HabitTracker.rollOverToNewDay)
        })
        
        // Phase 6: Final message
        actions.append(SKAction.run { [weak self] in
            guard let self = self else { return }
            let finalMsg = SKLabelNode(fontNamed: "Minecraft")
            finalMsg.text = "TOMORROW IS A NEW DAY."
            finalMsg.fontSize = 22
            finalMsg.fontColor = GameConstants.Colors.paradisoGold
            finalMsg.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.5)
            finalMsg.zPosition = 20
            finalMsg.alpha = 0
            self.addChild(finalMsg)
            
            finalMsg.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 1.0),
                SKAction.wait(forDuration: 2.0),
                SKAction.fadeOut(withDuration: 1.0)
            ]))
        })
        actions.append(SKAction.wait(forDuration: 4.0))
        
        // Phase 7: Final haptic and transition
        actions.append(SKAction.run {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        })
        actions.append(SKAction.wait(forDuration: 0.5))
        
        // Phase 8: Fade out and return to game
        actions.append(SKAction.run { [weak self] in
            self?.enumerateChildNodes(withName: "//*") { node, _ in
                node.run(SKAction.fadeOut(withDuration: 1.0))
            }
        })
        actions.append(SKAction.wait(forDuration: 1.5))
        
        actions.append(SKAction.run { [weak self] in
            self?.onComplete?()
            
            guard let playerNode = self?.player, let stamina = self?.stamina else { return }
            let gameScene = GameScene(size: CGSize(width: 393, height: 852), player: playerNode, stamina: stamina)
            gameScene.scaleMode = .aspectFill
            self?.view?.presentScene(gameScene, transition: SKTransition.fade(withDuration: 1.0))
        })
        
        run(SKAction.sequence(actions))
    }
    
    // MARK: - Emitters
    
    private func createHeavySmokeEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 40
        emitter.particleLifetime = 5
        emitter.particleLifetimeRange = 2
        emitter.particleSpeed = 12
        emitter.particleSpeedRange = 8
        emitter.emissionAngle = .pi * 1.5
        emitter.emissionAngleRange = .pi
        emitter.particleAlpha = 0.5
        emitter.particleAlphaSpeed = -0.1
        emitter.particleScale = 0.4
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = 0.05
        emitter.particleColor = GameConstants.Colors.infernoSmoke
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    private func createGhostlyHands() -> SKNode {
        let container = SKNode()
        
        for i in 0..<5 {
            let hand = SKShapeNode()
            let path = CGMutablePath()
            // More organic hand shape
            let baseX = CGFloat(i - 2) * 45
            path.move(to: CGPoint(x: baseX - 8, y: 0))
            path.addQuadCurve(to: CGPoint(x: baseX, y: -60), control: CGPoint(x: baseX - 15, y: -30))
            path.addQuadCurve(to: CGPoint(x: baseX + 8, y: 0), control: CGPoint(x: baseX + 15, y: -30))
            path.closeSubpath()
            hand.path = path
            hand.fillColor = GameConstants.Colors.infernoSmoke.withAlphaComponent(0.6)
            hand.strokeColor = GameConstants.Colors.infernoAccent.withAlphaComponent(0.2)
            hand.lineWidth = 1
            hand.glowWidth = 5
            
            // Eerie animation — each hand moves with different timing
            let delay = TimeInterval(i) * 0.15
            let reach = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.moveBy(x: CGFloat.random(in: -5...5), y: -20, duration: 0.6),
                SKAction.moveBy(x: CGFloat.random(in: -5...5), y: 20, duration: 0.8)
            ])
            hand.run(SKAction.repeatForever(reach))
            
            container.addChild(hand)
        }
        
        return container
    }
}
