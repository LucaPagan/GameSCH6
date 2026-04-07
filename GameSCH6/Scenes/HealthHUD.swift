import SpriteKit

// MARK: - Health HUD
//
// Lung health bar centered at the top, below the Dynamic Island.
// Structure from top to bottom:
//   🫁  [icon]
//   ❤️  Healthy Lungs   [status label]
//   ████████░░░░       [pixel art bar]
//   Maximum Strength    [detail label]
//
// Leave a 62pt margin from the top for the Dynamic Island.

class HealthHUD: SKNode {

    // ── Configuration ──────────────────────────────────────────
    private let blockCount:  Int     = 16
    private let blockSize:   CGFloat = 7
    private let blockGap:    CGFloat = 2
    private let topMargin:   CGFloat = 62   // below Dynamic Island

    // ── Nodes ────────────────────────────────────────────────────
    private var iconLabel:    SKLabelNode!
    private var healthLabel:  SKLabelNode!
    private var detailLabel:  SKLabelNode!
    private var blocksBG:     [SKSpriteNode] = []
    private var blocksFill:   [SKSpriteNode] = []

    // ── State ───────────────────────────────────────────────────
    private var displayedLevel: LungHealthLevel = .healthy
    private var displayedCigs:  Int = -1   // -1 = never updated → force first update

    // MARK: - Init

    init(screenSize: CGSize) {
        super.init()
        zPosition = 600
        buildHUD(screenSize: screenSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildHUD(screenSize: CGSize) {
        // Y Origin: starts from the top of the screen (in camera coordinates = screenSize.height/2)
        // Drops by topMargin to sit below the Dynamic Island
        let topY      = screenSize.height / 2 - topMargin
        let barTotalW = CGFloat(blockCount) * blockSize
                      + CGFloat(blockCount - 1) * blockGap
        // ── Status label (e.g. "❤️  Healthy Lungs") ──
        healthLabel          = SKLabelNode(fontNamed: "Minecraft")
        healthLabel.fontSize = 12
        healthLabel.fontColor = LungHealthLevel.healthy.color
        healthLabel.text      = LungHealthLevel.healthy.label
        healthLabel.horizontalAlignmentMode = .center
        healthLabel.verticalAlignmentMode   = .center
        healthLabel.position = CGPoint(x: 0, y: topY - 18)
        addChild(healthLabel)

        // ── Pixel art bar (blocks) ──
        let barY = topY - 32

        for i in 0..<blockCount {
            let xPos = -barTotalW / 2 + CGFloat(i) * (blockSize + blockGap) + blockSize / 2

            // Block background
            let bg = SKSpriteNode(
                color: SKColor.white.withAlphaComponent(0.10),
                size:  CGSize(width: blockSize, height: blockSize))
            bg.position  = CGPoint(x: xPos, y: barY)
            bg.zPosition = 0
            addChild(bg)
            blocksBG.append(bg)

            // Block fill
            let fill = SKSpriteNode(
                color: LungHealthLevel.healthy.color,
                size:  CGSize(width: blockSize, height: blockSize))
            fill.position  = CGPoint(x: xPos, y: barY)
            fill.zPosition = 1
            fill.name      = "healthBlock_\(i)"
            addChild(fill)
            blocksFill.append(fill)
        }

        // ── Detail label (e.g. "Maximum Strength") ──
        detailLabel          = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
        detailLabel.fontSize = 14
        detailLabel.fontColor = SKColor.white.withAlphaComponent(0.45)
        detailLabel.text      = LungHealthLevel.healthy.statusDetail
        detailLabel.horizontalAlignmentMode = .center
        detailLabel.verticalAlignmentMode   = .center
        detailLabel.position = CGPoint(x: 0, y: topY - 44)
        addChild(detailLabel)
    }

    // MARK: - Update

    func update(cigarettes: Int, level: LungHealthLevel) {
        guard cigarettes != displayedCigs || level != displayedLevel else { return }
        displayedCigs  = cigarettes
        displayedLevel = level

        let maxCigs: CGFloat = CGFloat(GameConstants.SmokeMirror.maxVisualCigarettes)
        let ratio    = max(0.0, 1.0 - CGFloat(cigarettes) / maxCigs)
        let filled   = Int((ratio * CGFloat(blockCount)).rounded())

        // ── Update blocks ──
        for (i, block) in blocksFill.enumerated() {
            if i < filled {
                block.color = level.color
                block.alpha = 1.0

                // Last filled block pulses if we are low
                if i == filled - 1 && ratio < 0.30 {
                    if block.action(forKey: "hpulse") == nil {
                        block.run(SKAction.repeatForever(SKAction.sequence([
                            SKAction.fadeAlpha(to: 0.35, duration: 0.25),
                            SKAction.fadeAlpha(to: 1.00, duration: 0.25)
                        ])), withKey: "hpulse")
                    }
                } else {
                    block.removeAction(forKey: "hpulse")
                    block.alpha = 1.0
                }
            } else {
                block.removeAction(forKey: "hpulse")
                block.alpha = 0.0
            }
        }

        // ── Update text with fade ──
        let fadeOut = SKAction.fadeOut(withDuration: 0.12)
        let fadeIn  = SKAction.fadeIn(withDuration:  0.12)

        healthLabel.run(SKAction.sequence([
            fadeOut,
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.healthLabel.text      = level.label
                self.healthLabel.fontColor = level.color
            },
            fadeIn
        ]))

        detailLabel.run(SKAction.sequence([
            fadeOut,
            SKAction.run { [weak self] in
                self?.detailLabel.text = level.statusDetail
            },
            fadeIn
        ]))

        // ── Subtle flash on level change ──
        let flash = SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.07),
            SKAction.scale(to: 1.00, duration: 0.07)
        ])
        healthLabel.run(flash)
    }
}
