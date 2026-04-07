import SpriteKit

struct SessionData {
    let altitudeReached: CGFloat
    let sessionDuration: TimeInterval
    let cigarettesThisSession: Int
    let staminaRemaining: CGFloat
}

// MARK: - Result Scene

/// Shown when a game session ends (fall or quit).
/// Displays session stats and navigation options.
class ResultScene: SKScene {
    
    var sessionData: SessionData?
    
    override func didMove(to view: SKView) {
        backgroundColor = GameConstants.Colors.uiBG
        
        guard let data = sessionData else { return }
        
        setupTitle()
        setupStats(data: data)
        setupButtons()
    }
    
    // MARK: Setup
    
    private func setupTitle() {
        let title = SKLabelNode(fontNamed: "Minecraft")
        title.text = "SESSION COMPLETE"
        title.fontSize = 32
        title.fontColor = GameConstants.Colors.paradisoGold
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        title.zPosition = 10
        // Pixel Shadow
        let shadow = SKLabelNode(fontNamed: "Minecraft")
        shadow.text = title.text
        shadow.fontSize = title.fontSize
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        title.addChild(shadow)
        addChild(title)
    }
    
    private func setupStats(data: SessionData) {
        let stats: [(String, String)] = [
            ("ALTITUDE REACHED", "\(Int(data.altitudeReached / 10))M"),
            ("SESSION DURATION", formatDuration(data.sessionDuration)),
            ("CIGARETTES", "\(data.cigarettesThisSession)"),
            ("STAMINA REMAINING", "\(Int(data.staminaRemaining))%")
        ]
        
        let startY = size.height * 0.65
        let spacing: CGFloat = 60
        
        for (i, stat) in stats.enumerated() {
            let y = startY - CGFloat(i) * spacing
            
            // Label
            let label = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
            label.text = stat.0
            label.fontSize = 22
            label.fontColor = .white
            label.alpha = 0.8
            label.position = CGPoint(x: size.width / 2, y: y)
            label.zPosition = 10
            addChild(label)
            
            // Value
            let value = SKLabelNode(fontNamed: "Minecraft")
            value.text = stat.1
            value.fontSize = 28
            value.fontColor = GameConstants.Colors.paradisoGold
            value.position = CGPoint(x: size.width / 2, y: y - 30)
            value.zPosition = 10
            addChild(value)
        }
    }
    
    private func setupButtons() {
        let centerX = size.width / 2
        
        // Try Again
        let tryAgain = createButton(text: "▲ TRY AGAIN", fontSize: 28)
        tryAgain.position = CGPoint(x: centerX, y: size.height * 0.2)
        tryAgain.name = "tryAgainButton"
        addChild(tryAgain)
        
        // Menu
        let menu = createButton(text: "☰ MENU", fontSize: 24)
        menu.position = CGPoint(x: centerX, y: size.height * 0.12)
        menu.name = "menuButton"
        addChild(menu)
    }
    
    // MARK: Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)
        
        for node in tapped {
            switch node.name {
            case "tryAgainButton":
                let gameScene = GameScene(size: CGSize(width: 393, height: 852))
                gameScene.scaleMode = .aspectFill
                view?.presentScene(gameScene, transition: SKTransition.fade(withDuration: 0.8))
                
            case "menuButton":
                let menuScene = MainMenuScene(size: CGSize(width: 393, height: 852))
                menuScene.scaleMode = .aspectFill
                view?.presentScene(menuScene, transition: SKTransition.fade(withDuration: 0.8))
                
            default: break
            }
        }
    }
    
    // MARK: Helpers
    
    private func createButton(text: String, fontSize: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Minecraft")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.zPosition = 10
        // Pixel shadow
        let shadow = SKLabelNode(fontNamed: "Minecraft")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)
        return label
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
