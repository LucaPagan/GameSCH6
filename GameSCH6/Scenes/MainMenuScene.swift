import SpriteKit

// MARK: - Main Menu Scene

/// Animated main menu with parallax mountain background, floating title, and navigation buttons.
class MainMenuScene: SKScene {
    
    // MARK: Nodes
    
    private var titleLabel: SKLabelNode!
    private var subtitleLabel: SKLabelNode!
    private var playButton: SKLabelNode!
    private var profileButton: SKLabelNode!
    private var settingsButton: SKLabelNode!
    private var streakBadge: SKLabelNode!
    private var healthPreview: SKShapeNode! // Rinominato da staminaPreview
    
    private var backgroundLayers: [SKSpriteNode] = []
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
            backgroundColor = GameConstants.Colors.infernoDark
            
            setupBackground()
            setupTitle()
            setupButtons()
            setupStreakBadge()
            setupHealthPreview()
            startAmbientAnimations()
            
            // FIX: Ascolta la notifica dal setup completato per avviare il gioco senza dover ri-premere il tasto
            NotificationCenter.default.addObserver(self, selector: #selector(forceStartGame), name: Notification.Name("startGameAutomatically"), object: nil)
    }
    
    // MARK: Setup
    
    private func setupBackground() {
        // Gradient sky
        let skyGradient = SKSpriteNode(color: GameConstants.Colors.infernoDark, size: size)
        skyGradient.position = CGPoint(x: size.width / 2, y: size.height / 2)
        skyGradient.zPosition = -10
        addChild(skyGradient)
        
        // Floating particles (ash/embers)
        if let emitter = createAshEmitter() {
            emitter.position = CGPoint(x: size.width / 2, y: size.height)
            emitter.zPosition = -5
            emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
            addChild(emitter)
        }
    }
    
    private func setupTitle() {
        // Main title
        titleLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        titleLabel.text = "AD ASTRA"
        titleLabel.fontSize = 48
        titleLabel.fontColor = GameConstants.Colors.paradisoGold
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.75)
        titleLabel.zPosition = 10
        addChild(titleLabel)
        
        // Subtitle
        subtitleLabel = SKLabelNode(fontNamed: "Avenir-Light")
        subtitleLabel.text = "The Ascent from Ash"
        subtitleLabel.fontSize = 18
        subtitleLabel.fontColor = GameConstants.Colors.uiText.withAlphaComponent(0.7)
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.75 - 36)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)
        
        // Floating animation on title
        let floatUp = SKAction.moveBy(x: 0, y: 8, duration: 2.0)
        floatUp.timingMode = .easeInEaseOut
        let floatDown = floatUp.reversed()
        titleLabel.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatDown])))
    }
    
    private func setupButtons() {
        let buttonFontSize: CGFloat = 24
        let centerX = size.width / 2
        let startY = size.height * 0.45
        let spacing: CGFloat = 60
        
        // Play button
        playButton = createMenuButton(text: "▲ BEGIN ASCENT", fontSize: buttonFontSize + 4)
        playButton.position = CGPoint(x: centerX, y: startY)
        playButton.name = "playButton"
        addChild(playButton)
        
        // Profile button
        profileButton = createMenuButton(text: "☉ PROFILE", fontSize: buttonFontSize)
        profileButton.position = CGPoint(x: centerX, y: startY - spacing)
        profileButton.name = "profileButton"
        addChild(profileButton)
        
        // Settings button
        settingsButton = createMenuButton(text: "⚙ SETTINGS", fontSize: buttonFontSize)
        settingsButton.position = CGPoint(x: centerX, y: startY - spacing * 2)
        settingsButton.name = "settingsButton"
        addChild(settingsButton)
        
        // Pulsing animation on play button
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        playButton.run(SKAction.repeatForever(pulse))
    }
    
    private func setupStreakBadge() {
        let streak = HabitTracker.shared.currentStreak
        streakBadge = SKLabelNode(fontNamed: "Avenir-Medium")
        streakBadge.fontSize = 16
        streakBadge.fontColor = streak > 0
            ? GameConstants.Colors.paradisoGold
            : GameConstants.Colors.uiText.withAlphaComponent(0.5)
        streakBadge.text = streak > 0 ? "🔥 \(streak) day streak" : "Start your streak today"
        streakBadge.position = CGPoint(x: size.width / 2, y: size.height * 0.15)
        streakBadge.zPosition = 10
        addChild(streakBadge)
    }
    
    private func setupHealthPreview() {
        let tracker = HabitTracker.shared
        let cigarettes = tracker.cigarettesLoggedToday
        let maxCigs = CGFloat(GameConstants.Mirror.maxCigarettesThreshold)
        
        // Calcola la salute polmonare stimata (100% = 0 sigarette, 0% = 20 sigarette)
        let healthRatio = max(0.0, 1.0 - (CGFloat(cigarettes) / maxCigs))
        
        let barWidth: CGFloat = 200
        let barHeight: CGFloat = 12
        
        // Background bar
        let bgBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 6)
        bgBar.fillColor = SKColor.white.withAlphaComponent(0.1)
        bgBar.strokeColor = .clear
        bgBar.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        bgBar.zPosition = 10
        addChild(bgBar)
        
        // Fill bar
        let fillWidth = max(0.01, barWidth * healthRatio)
        healthPreview = SKShapeNode(rectOf: CGSize(width: fillWidth, height: barHeight), cornerRadius: 6)
        
        // Colori basati sulle sigarette
        healthPreview.fillColor = cigarettes < 5
            ? GameConstants.Colors.paradisoGreen
            : cigarettes < 15 ? GameConstants.Colors.purgatorioWarm : GameConstants.Colors.infernoAccent
            
        healthPreview.strokeColor = .clear
        healthPreview.position = CGPoint(
            x: size.width / 2 - (barWidth - fillWidth) / 2,
            y: size.height * 0.20
        )
        healthPreview.zPosition = 11
        addChild(healthPreview)
        
        // Label
        let label = SKLabelNode(fontNamed: "Avenir-Medium")
        label.text = "Salute Polmonare: \(Int(healthRatio * 100))%"
        label.fontSize = 12
        label.fontColor = GameConstants.Colors.uiText.withAlphaComponent(0.6)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.20 - 18)
        label.zPosition = 10
        addChild(label)
    }
    
    private func startAmbientAnimations() {
        // Subtle background color pulsing
        let darken = SKAction.colorize(with: GameConstants.Colors.infernoSmoke, colorBlendFactor: 0.3, duration: 4.0)
        let lighten = SKAction.colorize(with: GameConstants.Colors.infernoDark, colorBlendFactor: 0.3, duration: 4.0)
        run(SKAction.repeatForever(SKAction.sequence([darken, lighten])))
    }
    
    // MARK: Touch Handling
        @objc private func forceStartGame() {
            let gameScene = GameScene(size: CGSize(width: 393, height: 852))
            gameScene.scaleMode = .aspectFill
            let transition = SKTransition.fade(withDuration: 1.0)
            view?.presentScene(gameScene, transition: transition)
        }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)
        
        for node in tappedNodes {
            switch node.name {
            case "playButton":
                animateButtonPress(node as! SKLabelNode) { [weak self] in
                    self?.transitionToGame()
                }
            case "profileButton":
                animateButtonPress(node as! SKLabelNode) {
                    // TODO: Present ProfileViewController
                }
            case "settingsButton":
                animateButtonPress(node as! SKLabelNode) {
                    // TODO: Present SettingsViewController
                }
            default:
                break
            }
        }
    }
    
    // MARK: Transitions
    
    private func transitionToGame() {
        let tracker = HabitTracker.shared
        
        if tracker.needsDailySetup {
            // Present HabitSetup first — handled by SwiftUI container
            NotificationCenter.default.post(name: .showHabitSetup, object: nil)
        } else {
            let gameScene = GameScene(size: CGSize(width: 393, height: 852))
            gameScene.scaleMode = .aspectFill
            let transition = SKTransition.fade(withDuration: 1.0)
            view?.presentScene(gameScene, transition: transition)
        }
    }
    
    // MARK: Helpers
    
    private func createMenuButton(text: String, fontSize: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Avenir-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = GameConstants.Colors.uiText
        label.zPosition = 10
        return label
    }
    
    private func animateButtonPress(_ node: SKLabelNode, completion: @escaping () -> Void) {
        let shrink = SKAction.scale(to: 0.9, duration: 0.1)
        let grow = SKAction.scale(to: 1.0, duration: 0.1)
        let haptic = SKAction.run {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        node.run(SKAction.sequence([haptic, shrink, grow, SKAction.run(completion)]))
    }
    
    private func createAshEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 8
        emitter.particleLifetime = 6
        emitter.particleSpeed = 20
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = .pi * 1.5  // Downward
        emitter.emissionAngleRange = 0.5
        emitter.particleAlpha = 0.3
        emitter.particleAlphaSpeed = -0.05
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.05
        emitter.particleColor = GameConstants.Colors.infernoAccent
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
}

// MARK: - Notification

extension Notification.Name {
    static let showHabitSetup = Notification.Name("showHabitSetup")
}
