import SpriteKit

// MARK: - Main Menu Scene

class MainMenuScene: SKScene {

    // MARK: - Main Nodes
    private var titleLabel:    SKLabelNode!
    private var subtitleLabel: SKLabelNode!
    private var playButton:    SKNode!

    // Cigarette Counter
    private var counterWidget: SKNode!
    private var cigTodayLabel: SKLabelNode!
    private var cigGoalLabel:  SKLabelNode!

    // Streak
    private var streakLabel: SKLabelNode!

    private let px: CGFloat = 6.0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.03, blue: 0.08, alpha: 1)
        buildArtisticBackground()
        buildTitle()
        buildPlayButton()
        buildStreakBadge()
        buildCigaretteCounter()   // compact counter at bottom
        buildCornerButtons()

        NotificationCenter.default.addObserver(
            self, selector: #selector(forceStartGame),
            name: Notification.Name("startGameAutomatically"), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshCounter),
            name: .cigaretteLogged, object: nil)
        // Reset counter display at midnight rollover
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshCounter),
            name: .dailyReset, object: nil)
    }

    // MARK: - Artistic Background (graduated bands with soft gradient)

    private func buildArtisticBackground() {

        // ── Pixel gradient: many thin strips simulating a soft gradient ──
        // Divide the screen into N horizontal strips and interpolate color
        let stripeCount = 60
        let stripeH = size.height / CGFloat(stripeCount)

        // Key colors for each height (0 = bottom, 1 = top)
        // Bottom: dark red (Inferno) → middle: neutral green/gray (Purgatorio) → top: night blue (Paradiso)
        let colorStops: [(CGFloat, SKColor)] = [
            (0.00, SKColor(red: 0.09, green: 0.02, blue: 0.02, alpha: 1)),
            (0.18, SKColor(red: 0.07, green: 0.03, blue: 0.03, alpha: 1)),
            (0.30, SKColor(red: 0.05, green: 0.04, blue: 0.05, alpha: 1)),
            (0.45, SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)),
            (0.60, SKColor(red: 0.03, green: 0.04, blue: 0.10, alpha: 1)),
            (0.78, SKColor(red: 0.03, green: 0.03, blue: 0.12, alpha: 1)),
            (1.00, SKColor(red: 0.02, green: 0.02, blue: 0.10, alpha: 1))
        ]

        for i in 0..<stripeCount {
            let t = CGFloat(i) / CGFloat(stripeCount)
            let color = interpolateColor(stops: colorStops, t: t)
            let stripe = SKSpriteNode(color: color, size: CGSize(width: size.width, height: stripeH + 1))
            stripe.anchorPoint = CGPoint(x: 0, y: 0)
            stripe.position    = CGPoint(x: 0, y: CGFloat(i) * stripeH)
            stripe.zPosition   = -20
            addChild(stripe)
        }

        // ── Pixel stars (Paradiso) — less dense, softer ──
        let starColors: [SKColor] = [
            SKColor(red: 1.0, green: 0.95, blue: 0.80, alpha: 1),
            SKColor(red: 0.85, green: 0.90, blue: 1.00, alpha: 1),
            GameConstants.Colors.paradisoGold
        ]
        for _ in 0..<38 {
            let x    = CGFloat.random(in: 0...size.width)
            let y    = CGFloat.random(in: size.height * 0.48...size.height)
            let col  = starColors.randomElement()!
            let s    = px * CGFloat.random(in: 0.3...0.8)
            let star = SKSpriteNode(
                color: col.withAlphaComponent(CGFloat.random(in: 0.25...0.60)),
                size: CGSize(width: s, height: s))
            star.position  = CGPoint(x: x, y: y)
            star.zPosition = -18
            addChild(star)
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.08...0.25), duration: CGFloat.random(in: 1.0...2.8)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.35...0.65), duration: CGFloat.random(in: 1.0...2.8))
            ])
            star.run(SKAction.repeatForever(twinkle))
        }

        // ── Pixel clouds (Purgatorio) — lighter ──
        for i in 0..<5 {
            let yBase = size.height * CGFloat.random(in: 0.36...0.56)
            let xBase = size.width  * CGFloat(i) / 4 + CGFloat.random(in: -20...20)
            buildPixelCloud(at: CGPoint(x: xBase, y: yBase),
                            width: px * CGFloat.random(in: 5...11),
                            color: SKColor(white: 0.7, alpha: CGFloat.random(in: 0.07...0.14)))
        }

        // ── Pixel rocks (Inferno) — less intense ──
        buildInfernoRocks()

        // ── Rising embers — reduced ──
        buildEmberEmitter()

        // ── Climber silhouette ──
        buildClimberSilhouette()

        // ── Dotted vertical line ──
        buildDottedPath()
    }

    /// Interpolates between color stops based on t value (0–1)
    private func interpolateColor(stops: [(CGFloat, SKColor)], t: CGFloat) -> SKColor {
        guard stops.count >= 2 else { return stops.first?.1 ?? .black }
        for i in 0..<(stops.count - 1) {
            let (t0, c0) = stops[i]
            let (t1, c1) = stops[i + 1]
            if t >= t0 && t <= t1 {
                let local = (t - t0) / (t1 - t0)
                var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
                var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                c0.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
                c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                return SKColor(
                    red:   r0 + (r1 - r0) * local,
                    green: g0 + (g1 - g0) * local,
                    blue:  b0 + (b1 - b0) * local,
                    alpha: 1)
            }
        }
        return stops.last?.1 ?? .black
    }

    private func buildPixelCloud(at pt: CGPoint, width: CGFloat, color: SKColor) {
        let h = px * 2.0
        let b = SKSpriteNode(color: color, size: CGSize(width: width, height: h))
        b.position  = CGPoint(x: pt.x, y: pt.y)
        b.zPosition = -16
        addChild(b)
        let bump = SKSpriteNode(color: color, size: CGSize(width: width * 0.50, height: h))
        bump.position  = CGPoint(x: pt.x + width * 0.05, y: pt.y + h)
        bump.zPosition = -16
        addChild(bump)
        let drift = SKAction.sequence([
            SKAction.moveBy(x: 16, y: 0, duration: 5.5),
            SKAction.moveBy(x: -16, y: 0, duration: 5.5)
        ])
        b.run(SKAction.repeatForever(drift))
        bump.run(SKAction.repeatForever(drift))
    }

    private func buildInfernoRocks() {
        let rockColor = SKColor(red: 0.12, green: 0.05, blue: 0.04, alpha: 1)
        let lavaColor = GameConstants.Colors.infernoAccent

        let leftRocks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0, 0, px*3.5, px*7), (0, px*7, px*5, px*5),
            (0, px*12, px*2.5, px*9)
        ]
        for (x, y, w, h) in leftRocks { addRockBlock(x: x, y: y, w: w, h: h, color: rockColor) }

        let rightRocks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (size.width - px*4.5, 0, px*4.5, px*9),
            (size.width - px*7, px*9, px*7, px*4.5)
        ]
        for (x, y, w, h) in rightRocks { addRockBlock(x: x, y: y, w: w, h: h, color: rockColor) }

        // Lava pixels — softer
        for _ in 0..<5 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height * 0.25)
            let s = px * CGFloat.random(in: 0.4...1.2)
            let l = SKSpriteNode(
                color: lavaColor.withAlphaComponent(CGFloat.random(in: 0.25...0.50)),
                size: CGSize(width: s, height: s))
            l.position  = CGPoint(x: x, y: y)
            l.zPosition = -15
            addChild(l)
        }
    }

    private func addRockBlock(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: SKColor) {
        let b = SKSpriteNode(color: color, size: CGSize(width: w, height: h))
        b.anchorPoint = CGPoint(x: 0, y: 0)
        b.position    = CGPoint(x: x, y: y)
        b.zPosition   = -15
        addChild(b)
    }

    private func buildEmberEmitter() {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate      = 4          // fewer embers
        emitter.particleLifetime       = 5.0
        emitter.particleLifetimeRange  = 2.0
        emitter.particleSpeed          = 22
        emitter.particleSpeedRange     = 10
        emitter.emissionAngle          = .pi / 2
        emitter.emissionAngleRange     = 0.5
        emitter.particleAlpha          = 0.35       // softer
        emitter.particleAlphaSpeed     = -0.07
        emitter.particleScale          = 0.06
        emitter.particleScaleRange     = 0.03
        emitter.particleColor          = GameConstants.Colors.infernoAccent
        emitter.particleColorBlendFactor = 1.0
        emitter.position               = CGPoint(x: size.width / 2, y: 0)
        emitter.particlePositionRange  = CGVector(dx: size.width, dy: 0)
        emitter.zPosition              = -14
        addChild(emitter)
    }

    private func buildClimberSilhouette() {
        let base  = CGPoint(x: size.width * 0.78, y: size.height * 0.38)
        let color = SKColor(red: 0.06, green: 0.04, blue: 0.10, alpha: 0.70)
        let s     = px * 1.3

        let grid = [
            ".###.",
            ".###.",
            "..#..",
            ".###.",
            "#####",
            ".#.#.",
            ".#.#.",
            ".#.#."
        ]
        let cols = 5; let rows = grid.count
        let oX   = base.x - CGFloat(cols) * s / 2
        let oY   = base.y
        for (r, row) in grid.enumerated() {
            for (c, ch) in row.enumerated() {
                guard ch == "#" else { continue }
                let b = SKSpriteNode(color: color, size: CGSize(width: s, height: s))
                b.position  = CGPoint(x: oX + CGFloat(c)*s + s/2,
                                      y: oY + CGFloat(rows - r - 1)*s + s/2)
                b.zPosition = -13
                addChild(b)
            }
        }

        var ropeY = oY - s
        while ropeY > size.height * 0.05 {
            let dot = SKSpriteNode(
                color: color.withAlphaComponent(0.35),
                size: CGSize(width: s * 0.35, height: s * 0.35))
            dot.position  = CGPoint(x: base.x + s * 0.5, y: ropeY)
            dot.zPosition = -13
            addChild(dot)
            ropeY -= s * 1.6
        }
    }

    private func buildDottedPath() {
        let x = size.width / 2
        var y: CGFloat = size.height * 0.20
        while y < size.height * 0.90 {
            let dot = SKSpriteNode(
                color: SKColor.white.withAlphaComponent(0.04),
                size: CGSize(width: px * 0.4, height: px * 1.0))
            dot.position  = CGPoint(x: x, y: y)
            dot.zPosition = -12
            addChild(dot)
            y += px * 3.5
        }
    }

    // MARK: - Titolo

    private func buildTitle() {
        let shadow      = SKLabelNode(fontNamed: "Minecraft")
        shadow.text     = "AD ASTRA"
        shadow.fontSize = 52
        shadow.fontColor = .black
        shadow.position  = CGPoint(x: size.width / 2 + 3, y: size.height * 0.80 - 3)
        shadow.zPosition = 9
        addChild(shadow)

        titleLabel          = SKLabelNode(fontNamed: "Minecraft")
        titleLabel.text     = "AD ASTRA"
        titleLabel.fontSize = 52
        titleLabel.fontColor = GameConstants.Colors.paradisoGold
        titleLabel.position  = CGPoint(x: size.width / 2, y: size.height * 0.80)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        subtitleLabel          = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
        subtitleLabel.text     = "THE ASCENT FROM ASH"
        subtitleLabel.fontSize = 22
        subtitleLabel.fontColor = SKColor.white.withAlphaComponent(0.55)
        subtitleLabel.position  = CGPoint(x: size.width / 2, y: size.height * 0.80 - 44)
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)

        let floatUp = SKAction.moveBy(x: 0, y: 7, duration: 2.2)
        floatUp.timingMode = .easeInEaseOut
        titleLabel.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatUp.reversed()])))
        subtitleLabel.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatUp.reversed()])))
    }

    // MARK: - Play Button (CONTINUE if save exists, else PLAY)

    private func buildPlayButton() {
        let hasSave = PlayerProgress.shared.hasSavedSession
        let btnText = hasSave ? "▶  CONTINUE" : "▲  PLAY"

        playButton          = SKNode()
        playButton.position = CGPoint(x: size.width / 2,
                                      y: hasSave ? size.height * 0.51 : size.height * 0.48)
        playButton.zPosition = 10
        playButton.name     = "playButton"
        addChild(playButton)

        let bgW: CGFloat = 260; let bgH: CGFloat = 70

        let glow = SKSpriteNode(
            color: GameConstants.Colors.paradisoGold.withAlphaComponent(0.18),
            size: CGSize(width: bgW + 30, height: bgH + 20))
        glow.zPosition = -2; glow.name = "playButton"
        playButton.addChild(glow)
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.08, duration: 1.1),
            SKAction.fadeAlpha(to: 0.22, duration: 1.1)
        ])))

        let shadow = SKSpriteNode(
            color: SKColor(red: 0.10, green: 0.07, blue: 0.00, alpha: 1),
            size: CGSize(width: bgW, height: bgH))
        shadow.position = CGPoint(x: 5, y: -5); shadow.zPosition = -1
        shadow.name = "playButton"
        playButton.addChild(shadow)

        let bg = SKSpriteNode(color: GameConstants.Colors.paradisoGold,
                               size: CGSize(width: bgW, height: bgH))
        bg.name = "playButton"; bg.zPosition = 0
        playButton.addChild(bg)

        let brdColor = SKColor(red: 0.28, green: 0.18, blue: 0.00, alpha: 1)
        let bW: CGFloat = 3
        for (bx, by, bww, bhh): (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (-bgW/2, bgH/2-bW, bgW, bW), (-bgW/2, -bgH/2, bgW, bW),
            (-bgW/2, -bgH/2, bW, bgH),   (bgW/2-bW, -bgH/2, bW, bgH)
        ] {
            let b = SKSpriteNode(color: brdColor, size: CGSize(width: bww, height: bhh))
            b.anchorPoint = .zero; b.position = CGPoint(x: bx, y: by)
            b.name = "playButton"; playButton.addChild(b)
        }

        let highlight = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.12),
            size: CGSize(width: bgW - 6, height: bgH / 2 - 3))
        highlight.anchorPoint = CGPoint(x: 0.5, y: 0)
        highlight.position = CGPoint(x: 0, y: 3); highlight.name = "playButton"
        playButton.addChild(highlight)

        let lbl = SKLabelNode(fontNamed: "Minecraft")
        lbl.text = btnText; lbl.fontSize = 30
        lbl.fontColor = SKColor(red: 0.07, green: 0.04, blue: 0.00, alpha: 1)
        lbl.verticalAlignmentMode = .center; lbl.name = "playButton"
        playButton.addChild(lbl)

        let txtShadow = SKLabelNode(fontNamed: "Minecraft")
        txtShadow.text = btnText; txtShadow.fontSize = 30
        txtShadow.fontColor = SKColor(red: 0.15, green: 0.09, blue: 0.00, alpha: 0.35)
        txtShadow.verticalAlignmentMode = .center
        txtShadow.position = CGPoint(x: 2, y: -2); txtShadow.name = "playButton"
        playButton.addChild(txtShadow)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.045, duration: 1.0),
            SKAction.scale(to: 1.000, duration: 1.0)
        ])
        pulse.timingMode = .easeInEaseOut
        playButton.run(SKAction.repeatForever(pulse))

        // ── Secondary "NEW GAME" button (only if save exists) ──
        if hasSave { buildNewGameButton() }
    }

    private func buildNewGameButton() {
        let ngBtn = SKNode()
        ngBtn.position  = CGPoint(x: size.width / 2, y: size.height * 0.41)
        ngBtn.zPosition = 10
        ngBtn.name      = "newGameButton"
        addChild(ngBtn)

        let bgW: CGFloat = 210; let bgH: CGFloat = 44
        let bg = SKSpriteNode(color: SKColor.white.withAlphaComponent(0.06),
                               size: CGSize(width: bgW, height: bgH))
        bg.name = "newGameButton"; ngBtn.addChild(bg)

        let bW: CGFloat = 2
        for (bx, by, bww, bhh): (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (-bgW/2, bgH/2-bW, bgW, bW), (-bgW/2, -bgH/2, bgW, bW),
            (-bgW/2, -bgH/2, bW, bgH),   (bgW/2-bW, -bgH/2, bW, bgH)
        ] {
            let b = SKSpriteNode(color: SKColor.white.withAlphaComponent(0.18),
                                  size: CGSize(width: bww, height: bhh))
            b.anchorPoint = .zero; b.position = CGPoint(x: bx, y: by)
            b.name = "newGameButton"; ngBtn.addChild(b)
        }

        let lbl = SKLabelNode(fontNamed: "Minecraft")
        lbl.text = "↺  NEW GAME"; lbl.fontSize = 16
        lbl.fontColor = SKColor.white.withAlphaComponent(0.55)
        lbl.verticalAlignmentMode = .center; lbl.name = "newGameButton"
        ngBtn.addChild(lbl)
    }

    // MARK: - Cigarette counter (pure text, two lines, centered)
    //
    // Layout:
    //   SMOKING COUNT          ← small, subtle label
    //   [−]   3 / 10   [+]     ← main row with buttons
    //   (no bar, no cigarette icon)

    private func buildCigaretteCounter() {
        let tracker = HabitTracker.shared
        let cigs    = tracker.cigarettesLoggedToday
        let goal    = tracker.dailyCigaretteGoal
        let centerX = size.width / 2
        let centerY = size.height * 0.235   // sopra i corner buttons, sotto lo streak

        counterWidget           = SKNode()
        counterWidget.position  = CGPoint(x: centerX, y: centerY)
        counterWidget.zPosition = 10
        addChild(counterWidget)

        // ── Title label ──
        let titleLbl          = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
        titleLbl.text         = "SMOKING COUNT"
        titleLbl.fontSize     = 13
        titleLbl.fontColor    = SKColor.white.withAlphaComponent(0.32)
        titleLbl.horizontalAlignmentMode = .center
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position     = CGPoint(x: 0, y: 22)
        titleLbl.zPosition    = 2
        counterWidget.addChild(titleLbl)

        // ── Count / Goal (centered, without − button) ──
        cigTodayLabel                        = SKLabelNode(fontNamed: "Minecraft")
        cigTodayLabel.text                   = "\(cigs)"
        cigTodayLabel.fontSize               = 28
        cigTodayLabel.fontColor              = colorForCigs(cigs, goal: goal)
        cigTodayLabel.horizontalAlignmentMode = .right
        cigTodayLabel.verticalAlignmentMode   = .center
        cigTodayLabel.position               = CGPoint(x: -22, y: -2)
        cigTodayLabel.zPosition              = 2
        counterWidget.addChild(cigTodayLabel)

        // Separator " / "
        let slash          = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
        slash.text         = "/"
        slash.fontSize     = 20
        slash.fontColor    = SKColor.white.withAlphaComponent(0.25)
        slash.horizontalAlignmentMode = .center
        slash.verticalAlignmentMode   = .center
        slash.position     = CGPoint(x: -4, y: -2)
        slash.zPosition    = 2
        counterWidget.addChild(slash)

        cigGoalLabel                        = SKLabelNode(fontNamed: "Minecraft")
        cigGoalLabel.text                   = "\(goal)"
        cigGoalLabel.fontSize               = 28
        cigGoalLabel.fontColor              = SKColor.white.withAlphaComponent(0.28)
        cigGoalLabel.horizontalAlignmentMode = .left
        cigGoalLabel.verticalAlignmentMode   = .center
        cigGoalLabel.position               = CGPoint(x: 10, y: -2)
        cigGoalLabel.zPosition              = 2
        counterWidget.addChild(cigGoalLabel)

        // ── + Button (well spaced after goal) ──
        let plusBtn = buildCounterTextButton(text: "+", name: "btn_cig_plus")
        plusBtn.position  = CGPoint(x: 62, y: -2)
        counterWidget.addChild(plusBtn)
    }

    /// Pixel text button without background — character only, lightweight
    private func buildCounterTextButton(text: String, name: String) -> SKNode {
        let node          = SKNode()
        node.name         = name
        node.zPosition    = 3

        // Invisible hit area
        let hitArea       = SKSpriteNode(color: .clear, size: CGSize(width: 36, height: 36))
        hitArea.name      = name
        node.addChild(hitArea)

        let lbl           = SKLabelNode(fontNamed: "Minecraft")
        lbl.text          = text
        lbl.fontSize      = 26
        lbl.fontColor     = SKColor.white.withAlphaComponent(0.55)
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode   = .center
        lbl.name          = name
        node.addChild(lbl)

        return node
    }

    @objc private func refreshCounter() {
        let tracker = HabitTracker.shared
        let cigs    = tracker.cigarettesLoggedToday
        let goal    = tracker.dailyCigaretteGoal

        cigTodayLabel.text      = "\(cigs)"
        cigTodayLabel.fontColor = colorForCigs(cigs, goal: goal)
        cigGoalLabel.text       = "\(goal)"

        cigTodayLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.20, duration: 0.07),
            SKAction.scale(to: 1.00, duration: 0.07)
        ]))
    }

    private func colorForCigs(_ cigs: Int, goal: Int) -> SKColor {
        if goal == 0 { return GameConstants.Colors.infernoAccent }
        let ratio = CGFloat(cigs) / CGFloat(goal)
        if ratio <= 0.5  { return GameConstants.Colors.paradisoGreen }
        if ratio <= 0.85 { return GameConstants.Colors.purgatorioWarm }
        return GameConstants.Colors.infernoAccent
    }

    // MARK: - Corner buttons (profilo + opzioni)

    private func buildCornerButtons() {
        let profileBtn = buildPixelIconButton(
            icon: buildPersonIcon(),
            label: "PROFILE",
            name: "profileButton",
            position: CGPoint(x: 52, y: size.height * 0.08))
        addChild(profileBtn)

        let settingsBtn = buildPixelIconButton(
            icon: buildGearIcon(),
            label: "SETTINGS",
            name: "settingsButton",
            position: CGPoint(x: size.width - 52, y: size.height * 0.08))
        addChild(settingsBtn)
    }

    private func buildPixelIconButton(icon: SKNode, label: String,
                                      name: String, position: CGPoint) -> SKNode {
        let container       = SKNode()
        container.position  = position
        container.zPosition = 10
        container.name      = name

        icon.name      = name
        icon.zPosition = 1
        container.addChild(icon)

        // Label spaced further from the icon
        let lbl          = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
        lbl.text         = label
        lbl.fontSize     = 13
        lbl.fontColor    = SKColor.white.withAlphaComponent(0.50)
        lbl.position     = CGPoint(x: 0, y: -34)   // was -28, now further down
        lbl.name         = name
        container.addChild(lbl)

        return container
    }

    private func buildPersonIcon() -> SKNode {
        let c = SKNode()
        let s = px * 0.9
        let col = SKColor.white.withAlphaComponent(0.70)
        let grid = [
            ".###.",
            ".###.",
            "..#..",
            ".###.",
            "#.#.#",
            "#...#"
        ]
        let rows = grid.count; let cols = 5
        let oX = -CGFloat(cols) * s / 2
        let oY: CGFloat = -CGFloat(rows) * s / 2
        for (r, row) in grid.enumerated() {
            for (c2, ch) in row.enumerated() {
                guard ch == "#" else { continue }
                let b = SKSpriteNode(color: col, size: CGSize(width: s, height: s))
                b.position = CGPoint(x: oX + CGFloat(c2)*s + s/2,
                                     y: oY + CGFloat(rows-r-1)*s + s/2)
                c.addChild(b)
            }
        }
        return c
    }

    private func buildGearIcon() -> SKNode {
        let c   = SKNode()
        let s   = px * 0.9
        let col = SKColor.white.withAlphaComponent(0.70)
        let grid = [
            "..#.#..",
            ".#####.",
            "#.###.#",
            "#.###.#",
            "#.###.#",
            ".#####.",
            "..#.#.."
        ]
        let rows = grid.count; let cols = 7
        let oX = -CGFloat(cols) * s / 2
        let oY: CGFloat = -CGFloat(rows) * s / 2
        for (r, row) in grid.enumerated() {
            for (c2, ch) in row.enumerated() {
                guard ch == "#" else { continue }
                let b = SKSpriteNode(color: col, size: CGSize(width: s, height: s))
                b.position = CGPoint(x: oX + CGFloat(c2)*s + s/2,
                                     y: oY + CGFloat(rows-r-1)*s + s/2)
                c.addChild(b)
            }
        }
        c.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 8.0)))
        return c
    }

    // MARK: - Streak badge

    private func buildStreakBadge() {
        let streak = HabitTracker.shared.currentStreak
        streakLabel          = SKLabelNode(fontNamed: "Pixeboy-z8XGD")
        streakLabel.fontSize = 17
        // Positioned between play button and counter
        streakLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        streakLabel.zPosition = 10

        if streak > 0 {
            streakLabel.text      = "🔥  \(streak) DAY STREAK"
            streakLabel.fontColor = GameConstants.Colors.paradisoGold
        } else {
            streakLabel.text      = "START YOUR STREAK"
            streakLabel.fontColor = SKColor.white.withAlphaComponent(0.30)
        }
        addChild(streakLabel)
    }

    // MARK: - Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        
        for node in nodes(at: loc) {
            switch node.name {
            case "playButton":
                animatePress(playButton) { [weak self] in self?.transitionToGame() }
                return
            case "newGameButton":
                // Clear save and launch fresh game
                animatePress(node) { [weak self] in
                    PlayerProgress.shared.fullReset()
                    self?.forceStartGame()
                }
                return
            case "profileButton":
                animatePress(node) { [weak self] in self?.showProfile() }
                return
            case "settingsButton":
                animatePress(node) { [weak self] in self?.showSettings() }
                return
            case "btn_cig_plus":
                HabitTracker.shared.logCigarette()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                refreshCounter()
                return
            default: break
            }
        }
    }

    // MARK: - Navigation
    
    private func transitionToGame() {
        let tracker = HabitTracker.shared
        if tracker.needsDailySetup {
            NotificationCenter.default.post(name: .showHabitSetup, object: nil)
        } else {
            forceStartGame()
        }
    }

    @objc private func forceStartGame() {
        let scene = GameScene(size: CGSize(width: 393, height: 852))
        scene.scaleMode = .aspectFill
        view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.8))
    }

    private func showProfile() {
        NotificationCenter.default.post(name: Notification.Name("showProfile"), object: nil)
    }

    private func showSettings() {
        NotificationCenter.default.post(name: Notification.Name("showSettings"), object: nil)
    }

    // MARK: - Helpers

    private func animatePress(_ node: SKNode, completion: @escaping () -> Void) {
        node.run(SKAction.sequence([
            SKAction.scale(to: 0.92, duration: 0.08),
            SKAction.scale(to: 1.00, duration: 0.08),
            SKAction.run(completion)
        ]))
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

extension Notification.Name {
    static let showHabitSetup = Notification.Name("showHabitSetup")
}
