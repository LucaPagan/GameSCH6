import SpriteKit

// MARK: - Dev Mode Flag
// Set to false before release to hide the Dev panel in the pause menu.
let kDevModeEnabled: Bool = true

// MARK: - Game Scene

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nodes
    var playerNode:    PlayerNode!
    let worldNode      = SKNode()
    let platformsNode  = SKNode()
    let cameraNode     = SKCameraNode()
    private let px: CGFloat = 6.0

    // MARK: - HUD
    var altitudeLabel: SKLabelNode!

    // MARK: - Managers
    var platformGenerator: DeterministicPlatformGenerator!
    var stamina:  PlayerStamina!
    var progress: PlayerProgress!

    // MARK: - Background
    private var worldBackground: WorldBackground!

    // MARK: - Health HUD (single bar, centered)
    private var lungHealthHUD: HealthHUD!
    private var blurOverlay:   BlurOverlay!

    // MARK: - State
    var lastUpdateTime: TimeInterval = 0
    var sceneStartTime: TimeInterval = 0
    var lastGrabTime:   TimeInterval = 0
    let grabCooldown:   TimeInterval = 0.2

    var safeFloorY: CGFloat = -300
    let autoGrabRadius: CGFloat = 100.0
    var grabLockoutTimer: TimeInterval = 0

    var groundContactCount = 0 {
        didSet { isPlayerGrounded = groundContactCount > 0 }
    }
    var isPlayerGrounded = false
    var isRespawning     = false
    private var isSceneReady = false
    var hasGrabbedFirstHold  = false

    // MARK: - Pause
    private var isPaused_game: Bool = false
    private var pauseMenuNode: SKNode?

    // MARK: - Dev Mode
    var isGodMode     = false { didSet { updateDevStatus() } }
    var isFreeFlyMode = false { didSet { updateDevStatus() } }
    private var devStatusLabel: SKLabelNode!

    // MARK: - Smoke Mirror
    private var smokeHazeOverlay: SmokeHazeOverlay!
    private var currentKingdom: Kingdom = .inferno
    private var gripSlipTimer:  TimeInterval = 0
    private var baseGravity:    CGFloat = GameConstants.World.gravity

    // MARK: - Init

    init(size: CGSize, player: PlayerNode? = nil, stamina: PlayerStamina? = nil) {
        self.playerNode = player
        self.stamina    = stamina
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        if stamina  == nil { stamina  = PlayerStamina(cigarettesLoggedToday: HabitTracker.shared.cigarettesLoggedToday) }
        if progress == nil { progress = PlayerProgress.shared }

        // ── Restore saved session if it exists ──
        if progress.hasSavedSession {
            stamina.debugSetCigarettes(count: progress.savedCigarettes)
            stamina.currentStamina = progress.savedStamina
        } else {
            progress.fullReset()
        }

        setupPhysics()
        setupNodes()

        PlayerNode.preloadTextures { [weak self] in
            guard let self = self else { return }

            self.setupPlayer()
            self.setupBackground()
            self.setupCamera()
            self.setupHUD()
            self.setupSmokeMirror()

            self.platformGenerator = DeterministicPlatformGenerator(
                scene: self, containerNode: self.platformsNode)
            self.platformGenerator.update(cameraAltitude: 300)

            self.isSceneReady = true

            self.stamina.lungHealth.onCough = { [weak self] in
                guard let self = self, !self.isGodMode else { return }
                _ = self.playerNode.releaseHold(stamina: self.stamina)
                self.playerNode.triggerCoughInterrupt()
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }

            self.stamina.lungHealth.onBreathShake = { [weak self] intensity in
                guard let self = self else { return }
                let dx = CGFloat.random(in: -intensity...intensity)
                let dy = CGFloat.random(in: -intensity * 0.5...intensity * 0.5)
                self.cameraNode.run(SKAction.sequence([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.08),
                    SKAction.moveBy(x: -dx, y: -dy, duration: 0.08)
                ]), withKey: "breath_shake")
            }

            // ── If there is a saved session, reposition the player at the checkpoint ──
            if self.progress.hasSavedSession {
                let cpAlt = self.progress.highestCheckpointAltitude
                self.platformGenerator.update(cameraAltitude: cpAlt + 300)
                self.playerNode.position = CGPoint(x: self.size.width / 2, y: cpAlt + 150)
                self.cameraNode.position.y = self.playerNode.position.y + 120
                self.hasGrabbedFirstHold = true
                self.safeFloorY = cpAlt - 200
                self.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.15),
                    SKAction.run { [weak self] in self?.attachToFirstHold(radius: 600) }
                ]))
            } else {
                self.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.15),
                    SKAction.run { [weak self] in self?.attachToFirstHold() }
                ]))
            }
        }

        // React to cigarette logs from MainMenu or the pause menu
        NotificationCenter.default.addObserver(
            self, selector: #selector(onCigaretteLogged),
            name: .cigaretteLogged, object: nil)

        // React to daily midnight reset
        NotificationCenter.default.addObserver(
            self, selector: #selector(onDailyReset),
            name: .dailyReset, object: nil)

        // Save the session when the app goes into background
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func appWillResignActive() {
        saveCurrentSession()
    }

    /// Syncs in-game stamina whenever a cigarette is logged from any screen.
    @objc private func onCigaretteLogged() {
        let count = HabitTracker.shared.cigarettesLoggedToday
        stamina.debugSetCigarettes(count: count)
        // If the pause menu is open, refresh its counter widget
        if isPaused_game { refreshPauseCigCount() }
    }

    /// Resets in-game stamina at midnight rollover.
    @objc private func onDailyReset() {
        stamina.debugSetCigarettes(count: 0)
        if isPaused_game { refreshPauseCigCount() }
    }

    private func saveCurrentSession() {
        progress.saveSession(
            stamina: stamina.currentStamina,
            cigarettes: stamina.cigarettesLoggedToday)
    }

    // MARK: - Setup

    private func setupNodes() {
        addChild(worldNode)
        worldNode.addChild(platformsNode)
    }

    private func setupPhysics() {
        physicsWorld.gravity         = CGVector(dx: 0, dy: GameConstants.World.gravity)
        physicsWorld.contactDelegate = self
        worldNode.addChild(makeWall(x: 0))
        worldNode.addChild(makeWall(x: size.width))
    }

    private func makeWall(x: CGFloat) -> SKNode {
        let n = SKNode()
        n.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: x, y: -2000),
            to:       CGPoint(x: x, y: 60000))
        n.physicsBody?.categoryBitMask  = GameConstants.Physics.boundary
        n.physicsBody?.collisionBitMask = GameConstants.Physics.player
        return n
    }

    private func setupBackground() {
        worldBackground = WorldBackground(screenSize: size)
        worldNode.addChild(worldBackground)
    }

    private func setupPlayer() {
        if playerNode == nil {
            playerNode = PlayerNode()
            playerNode.position = CGPoint(x: size.width / 2, y: 200)
        } else {
            playerNode.removeFromParent()
        }
        safeFloorY = playerNode.position.y - 300
        worldNode.addChild(playerNode)
        worldNode.addChild(playerNode.armLineNode)
        worldNode.addChild(playerNode.orbitCircleNode)
    }

    private func setupCamera() {
        cameraNode.position = CGPoint(x: size.width / 2, y: playerNode.position.y + 120)
        camera = cameraNode
        addChild(cameraNode)
    }

    private func setupHUD() {
        // ── ALTITUDE → left ──
        altitudeLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        altitudeLabel.fontSize = 16
        altitudeLabel.fontColor = .white
        altitudeLabel.horizontalAlignmentMode = .left
        altitudeLabel.position = CGPoint(x: -size.width / 2 + 18, y: size.height / 2 - 68)
        cameraNode.addChild(altitudeLabel)

        // ── PAUSE BUTTON (Gear) → right, pixel art ──
        let gear = buildGearIcon()
        gear.position = CGPoint(x: size.width / 2 - 30, y: size.height / 2 - 68)
        gear.name     = "pause_button"
        cameraNode.addChild(gear)

        // ── DEV STATUS ──
        devStatusLabel = SKLabelNode(fontNamed: "Avenir-Black")
        devStatusLabel.fontSize = 10
        devStatusLabel.fontColor = .cyan
        devStatusLabel.horizontalAlignmentMode = .right
        devStatusLabel.position = CGPoint(x: size.width / 2 - 20, y: size.height / 2 - 78)
        devStatusLabel.alpha = 0
        cameraNode.addChild(devStatusLabel)

        // ── HEALTH HUD → centered top (SINGLE bar) ──
        lungHealthHUD = HealthHUD(screenSize: size)
        cameraNode.addChild(lungHealthHUD)

        // ── BLUR OVERLAY ──
        blurOverlay = BlurOverlay(screenSize: size)
        cameraNode.addChild(blurOverlay)
    }

    private func updateDevStatus() {
        var status = [String]()
        if isGodMode     { status.append("GOD") }
        if isFreeFlyMode { status.append("FLY") }
        if status.isEmpty {
            devStatusLabel.run(SKAction.fadeOut(withDuration: 0.2))
        } else {
            devStatusLabel.text  = status.joined(separator: " | ")
            devStatusLabel.alpha = 1
        }
    }

    // MARK: - First attachment

    func attachToFirstHold(radius: CGFloat = 400) {
        guard let hold = findNearestHold(to: playerNode.position, radius: radius) else { return }
        playerNode.grab(hold: hold, preserveVelocity: false)
        hold.playGrabEffect()
        lastGrabTime = 0
        hasGrabbedFirstHold = true
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        guard isSceneReady else { return }
        guard !isPaused_game else { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            sceneStartTime = currentTime
        }
        let dt = min(1.0/60.0, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        platformGenerator.update(cameraAltitude: cameraNode.position.y)
        stamina.updateLungHealth(deltaTime: dt)

        if let hold = playerNode.currentHold {
            playerNode.angularVelocity = GameConstants.Swing.baseAngularVelocity
                * stamina.swingModulator
            let holdPosInWorld = hold.parent?.convert(hold.position, to: worldNode) ?? hold.position
            playerNode.updateRotation(deltaTime: dt, stamina: stamina,
                                       holdPositionInParent: holdPosInWorld)

            if !isGodMode && stamina.gripSlipChance > 0 {
                gripSlipTimer += dt
                if gripSlipTimer > 1.0 {
                    gripSlipTimer = 0
                    if Float.random(in: 0...1) < Float(stamina.gripSlipChance) {
                        playerNode.run(SKAction.sequence([
                            SKAction.moveBy(x: CGFloat.random(in: -6...6), y: -4, duration: 0.1),
                            SKAction.moveBy(x: 0, y: 4, duration: 0.15)
                        ]), withKey: "grip_slip")
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
            }
        } else {
            gripSlipTimer = 0
        }

        lungHealthHUD.update(
            cigarettes: stamina.cigarettesLoggedToday,
            level: LungHealthLevel.from(cigarettes: stamina.cigarettesLoggedToday))
        blurOverlay.update(intensity: stamina.blurIntensity)

        if grabLockoutTimer > 0 { grabLockoutTimer = max(0, grabLockoutTimer - dt) }

        updateSmokeMirror(deltaTime: dt)
        updateCamera()
        updateHUD()

        if playerNode.position.y < -400 && playerNode.currentHold == nil {
            respawnAtLowestHold()
        }
        checkCheckpointFall()
    }

    // MARK: - Camera / HUD

    private func updateCamera() {
        let targetY = max(size.height / 2, playerNode.position.y + 130)
        if targetY > cameraNode.position.y {
            cameraNode.position = CGPoint(x: size.width / 2, y: targetY)
        } else {
            let diff = targetY - cameraNode.position.y
            cameraNode.position = CGPoint(x: size.width / 2,
                                          y: cameraNode.position.y + diff * 0.06)
        }
    }

    private func updateHUD() {
        altitudeLabel.text = "\(Int(max(0, playerNode.position.y))) m"

        lungHealthHUD.update(
            cigarettes: stamina.cigarettesLoggedToday,
            level: LungHealthLevel.from(cigarettes: stamina.cigarettesLoggedToday))
        blurOverlay.update(intensity: stamina.blurIntensity)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc        = touch.location(in: cameraNode)
        let locInWorld = touch.location(in: worldNode)

        // ── Pause open: handle menu buttons ──
        if isPaused_game {
            handlePauseMenuTouch(at: loc)
            return
        }

        // ── Pause button ──
        if cameraNode.nodes(at: loc).first(where: { $0.name == "pause_button" }) != nil {
            showPauseMenu()
            return
        }

        // ── Normal gameplay ──
        guard lastUpdateTime - lastGrabTime >= grabCooldown else { return }
        guard grabLockoutTimer <= 0 else { return }

        if playerNode.currentHold != nil {
            _ = playerNode.releaseHold(stamina: stamina)
            lastGrabTime = lastUpdateTime
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if isPlayerGrounded || isGodMode {
            if let hold = findNearestHold(to: playerNode.position, radius: 2000.0) {
                let hp = hold.parent?.convert(hold.position, to: worldNode) ?? hold.position
                let dx = hp.x - playerNode.position.x
                let dy = hp.y - playerNode.position.y
                let length = hypot(dx, dy)
                if length > 0 {
                    let jumpForce    = GameConstants.Jump.baseForce * stamina.jumpForceMultiplier
                    let jumpVelocity = CGVector(
                        dx: (dx/length) * jumpForce,
                        dy: (dy/length) * jumpForce)
                    playerNode.physicsBody?.velocity = jumpVelocity
                    playerNode.physicsBody?.affectedByGravity = true
                    playerNode.zRotation = atan2(dy, dx) - .pi / 2
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        } else {
            if let hold = findNearestHold(to: playerNode.position, radius: 60.0) {
                if hold.onPlayerGrab(stamina: stamina) {
                    playerNode.grab(hold: hold, preserveVelocity: true)
                    hold.playGrabEffect()
                    lastGrabTime = lastUpdateTime
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }

        // Free fly
        if isFreeFlyMode {
            playerNode.physicsBody?.velocity = .zero
            playerNode.position = locInWorld
            attachToFirstHold(radius: 200)
        }
    }

    // MARK: - Pause Menu

    private func showPauseMenu() {
        guard !isPaused_game else { return }
        isPaused_game = true
        saveCurrentSession()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let menu = SKNode()
        menu.zPosition = 2000
        menu.name      = "pause_menu_root"
        cameraNode.addChild(menu)
        pauseMenuNode = menu

        // ── Background dimming ──
        let dim = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.72), size: size)
        dim.zPosition = 0
        dim.name      = "pause_dim"
        menu.addChild(dim)

        // ── Central panel ──
        let panelW: CGFloat = 280
        let panelH: CGFloat = kDevModeEnabled ? 430 : 400 // increased from 340 to 400
        let panel = SKSpriteNode(
            color: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.97),
            size:  CGSize(width: panelW, height: panelH))
        panel.zPosition = 1
        menu.addChild(panel)

        // Golden pixel border
        let brdColor = GameConstants.Colors.paradisoGold.withAlphaComponent(0.60)
        let bW: CGFloat = 3
        for (bx, by, bww, bhh): (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (-panelW/2,        panelH/2 - bW, panelW, bW),
            (-panelW/2,       -panelH/2,       panelW, bW),
            (-panelW/2,       -panelH/2,       bW, panelH),
            (panelW/2 - bW,   -panelH/2,       bW, panelH)
        ] {
            let b = SKSpriteNode(color: brdColor, size: CGSize(width: bww, height: bhh))
            b.anchorPoint = .zero
            b.position    = CGPoint(x: bx, y: by)
            b.zPosition   = 2
            menu.addChild(b)
        }

        // ── Title ──
        let title = makePauseLabel("— PAUSE —", font: "Minecraft", size: 22,
                                   color: GameConstants.Colors.paradisoGold)
        title.position  = CGPoint(x: 0, y: panelH/2 - 38)
        title.zPosition = 3
        menu.addChild(title)

        // ── Separator under title ──
        let sep = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.12),
            size:  CGSize(width: panelW - 40, height: 1))
        sep.position  = CGPoint(x: 0, y: panelH/2 - 60)
        sep.zPosition = 3
        menu.addChild(sep)

        // ── SMOKING COUNTER ──
        buildPauseSmokingCounter(in: menu, panelH: panelH)

        // ── Separator ──
        let sep2 = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.10),
            size:  CGSize(width: panelW - 40, height: 1))
        sep2.position  = CGPoint(x: 0, y: panelH/2 - 134)
        sep2.zPosition = 3
        menu.addChild(sep2)

        // ── Main buttons ──
        let buttons: [(String, String, SKColor)] = [
            ("▶  RESUME",     "pm_resume",  GameConstants.Colors.paradisoGold),
            ("↺  RESTART",    "pm_restart", SKColor.white.withAlphaComponent(0.85)),
            ("⌂  HOME",       "pm_home",    SKColor.white.withAlphaComponent(0.85))
        ]

        let btnStartY: CGFloat = panelH/2 - 170
        let btnSpacing: CGFloat = 54

        for (i, (label, name, color)) in buttons.enumerated() {
            let btn = makePauseButton(
                label: label, name: name, color: color,
                width: panelW - 40, height: 42)
            btn.position  = CGPoint(x: 0, y: btnStartY - CGFloat(i) * btnSpacing)
            btn.zPosition = 3
            menu.addChild(btn)
        }

        // ── Options separator ──
        let sep3 = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.10),
            size:  CGSize(width: panelW - 40, height: 1))
        sep3.position  = CGPoint(x: 0, y: btnStartY - CGFloat(buttons.count) * btnSpacing + 4)
        sep3.zPosition = 3
        menu.addChild(sep3)

        // ── Options toggles ──
        let optY = btnStartY - CGFloat(buttons.count) * btnSpacing - 18
        buildPauseToggle(in: menu, label: "HAPTICS", name: "pm_haptic",
                         isOn: UserDefaults.standard.bool(forKey: "hapticEnabled"),
                         y: optY, zPos: 3)

        // ── Dev Section (only if kDevModeEnabled) ──
        if kDevModeEnabled {
            let devSep = SKSpriteNode(
                color: SKColor.cyan.withAlphaComponent(0.20),
                size:  CGSize(width: panelW - 40, height: 1))
            devSep.position  = CGPoint(x: 0, y: optY - 38)
            devSep.zPosition = 3
            menu.addChild(devSep)

            buildDevSection(in: menu, startY: optY - 55, panelW: panelW)
        }

        // Animazione entrata
        menu.setScale(0.85)
        menu.alpha = 0
        menu.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.18),
            SKAction.scale(to: 1.0, duration: 0.18)
        ]))
    }

    // ── Smoking counter in the pause menu — matches MainMenu layout ──
    private func buildPauseSmokingCounter(in menu: SKNode, panelH: CGFloat) {
        let cigs = stamina.cigarettesLoggedToday
        let goal = HabitTracker.shared.dailyCigaretteGoal
        let topY = panelH / 2 - 78

        // ── Title ──
        let titleLbl = makePauseLabel("SMOKING COUNT", font: "Pixeboy-z8XGD",
                                      size: 12, color: SKColor.white.withAlphaComponent(0.32))
        titleLbl.position  = CGPoint(x: 0, y: topY)
        titleLbl.zPosition = 3
        menu.addChild(titleLbl)

        // ── Count  /  Goal  [+] ── (centered, same style as MainMenu)
        let rowY = topY - 26

        // Cigarette count (right-aligned before slash)
        let countLbl = makePauseLabel("\(cigs)", font: "Minecraft", size: 26,
                                      color: pauseCigColor(cigs, goal: goal))
        countLbl.horizontalAlignmentMode = .right
        countLbl.position  = CGPoint(x: -22, y: rowY)
        countLbl.zPosition = 3
        countLbl.name      = "pm_cig_count"
        menu.addChild(countLbl)

        // Slash separator
        let slash = makePauseLabel("/", font: "Pixeboy-z8XGD", size: 18,
                                   color: SKColor.white.withAlphaComponent(0.25))
        slash.position  = CGPoint(x: -4, y: rowY)
        slash.zPosition = 3
        menu.addChild(slash)

        // Goal (left-aligned after slash)
        let goalLbl = makePauseLabel("\(goal)", font: "Minecraft", size: 26,
                                     color: SKColor.white.withAlphaComponent(0.28))
        goalLbl.horizontalAlignmentMode = .left
        goalLbl.position  = CGPoint(x: 10, y: rowY)
        goalLbl.zPosition = 3
        goalLbl.name      = "pm_cig_goal"
        menu.addChild(goalLbl)

        // [+] button (only add — the real tracking must not go below 0 accidentally)
        let plusNode = makePauseTextButton("+", name: "pm_cig_plus")
        plusNode.position  = CGPoint(x: 62, y: rowY)
        plusNode.zPosition = 3
        menu.addChild(plusNode)
    }

    // ── Toggle in the pause menu ──
    private func buildPauseToggle(in menu: SKNode, label: String, name: String,
                                   isOn: Bool, y: CGFloat, zPos: CGFloat) {
        let lbl = makePauseLabel(label, font: "Pixeboy-z8XGD", size: 14,
                                 color: SKColor.white.withAlphaComponent(0.75))
        lbl.horizontalAlignmentMode = .left
        lbl.position  = CGPoint(x: -120, y: y)
        lbl.zPosition = zPos
        menu.addChild(lbl)

        // Toggle pill
        let pill = SKNode()
        pill.position  = CGPoint(x: 90, y: y + 3)
        pill.zPosition = zPos
        pill.name      = name

        let pillBg = SKSpriteNode(
            color: isOn ? GameConstants.Colors.paradisoGold : SKColor.white.withAlphaComponent(0.12),
            size:  CGSize(width: 44, height: 22))
        pillBg.name = name
        pill.addChild(pillBg)

        let knob = SKSpriteNode(color: .white, size: CGSize(width: 16, height: 16))
        knob.position = CGPoint(x: isOn ? 10 : -10, y: 0)
        knob.name     = name
        pill.addChild(knob)

        menu.addChild(pill)
    }

    // ── Dev Section in the pause menu ──
    private func buildDevSection(in menu: SKNode, startY: CGFloat, panelW: CGFloat) {
        let devTitle = makePauseLabel("— DEV MODE —", font: "Minecraft", size: 11,
                                      color: SKColor.cyan.withAlphaComponent(0.70))
        devTitle.position  = CGPoint(x: 0, y: startY)
        devTitle.zPosition = 3
        menu.addChild(devTitle)

        // Toggles
        let toggles: [(String, String, Bool)] = [
            ("GOD MODE", "pm_dev_god", isGodMode),
            ("FREE FLY", "pm_dev_fly", isFreeFlyMode)
        ]
        for (i, (lbl, nm, on)) in toggles.enumerated() {
            buildPauseToggle(in: menu, label: lbl, name: nm,
                             isOn: on, y: startY - 30 - CGFloat(i) * 34, zPos: 3)
        }

        // Dev cigarettes
        let cigDevLbl = makePauseLabel(
            "CIG (DEV): \(HabitTracker.shared.cigarettesLoggedToday)",
            font: "Pixeboy-z8XGD", size: 12, color: SKColor.cyan.withAlphaComponent(0.60))
        cigDevLbl.position  = CGPoint(x: -30, y: startY - 100)
        cigDevLbl.zPosition = 3
        cigDevLbl.name      = "pm_dev_cig_label"
        menu.addChild(cigDevLbl)

        let addBtn = makePauseTextButton("[+]", name: "pm_dev_cig_add")
        addBtn.position  = CGPoint(x: 80, y: startY - 100)
        addBtn.zPosition = 3
        menu.addChild(addBtn)

        let remBtn = makePauseTextButton("[-]", name: "pm_dev_cig_rem")
        remBtn.position  = CGPoint(x: 110, y: startY - 100)
        remBtn.zPosition = 3
        menu.addChild(remBtn)

        // Teleport checkpoints
        let cpTitle = makePauseLabel("TELEPORT:", font: "Pixeboy-z8XGD", size: 11,
                                     color: SKColor.cyan.withAlphaComponent(0.50))
        cpTitle.position  = CGPoint(x: -80, y: startY - 122)
        cpTitle.zPosition = 3
        menu.addChild(cpTitle)

        let cpAltitudes = GameConstants.Kingdoms.checkpointAltitudes
        for (i, cp) in cpAltitudes.enumerated() {
            let altInt = Int(cp * GameConstants.World.totalWorldHeight)
            let btn = makePauseLabel("➤\(altInt)m", font: "Pixeboy-z8XGD", size: 11,
                                     color: .cyan)
            let col = CGFloat(i % 4)
            let row = CGFloat(i / 4)
            btn.position  = CGPoint(x: -100 + col * 68, y: startY - 140 - row * 20)
            btn.zPosition = 3
            btn.name      = "pm_jump_\(i)"
            menu.addChild(btn)
        }
    }

    // ── Handling touches in the pause menu ──
    private func handlePauseMenuTouch(at loc: CGPoint) {
        guard let menu = pauseMenuNode else { return }
        let nodes = menu.nodes(at: loc) + cameraNode.nodes(at: loc)

        for node in nodes {
            switch node.name {

            case "pm_resume":
                hidePauseMenu()
                return

            case "pm_restart":
                hidePauseMenu()
                progress.fullReset()          // clear session + reset progress
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                let scene = GameScene(size: CGSize(width: 393, height: 852))
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.6))
                return

            case "pm_home":
                hidePauseMenu()
                saveCurrentSession()          // save before exit
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let menu = MainMenuScene(size: CGSize(width: 393, height: 852))
                menu.scaleMode = .aspectFill
                view?.presentScene(menu, transition: SKTransition.fade(withDuration: 0.8))
                return

            case "pm_haptic":
                let cur = UserDefaults.standard.bool(forKey: "hapticEnabled")
                UserDefaults.standard.set(!cur, forKey: "hapticEnabled")
                refreshPauseMenu()
                return

            // ── Smoking counter: + only (no − in the pause menu) ──
            case "pm_cig_plus":
                HabitTracker.shared.logCigarette()
                // onCigaretteLogged() fires automatically via NotificationCenter
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return

            // ── Dev toggles ──
            case "pm_dev_god":
                isGodMode.toggle()
                refreshPauseMenu()
                return

            case "pm_dev_fly":
                isFreeFlyMode.toggle()
                refreshPauseMenu()
                return

            case "pm_dev_cig_add":
                let newCount = HabitTracker.shared.cigarettesLoggedToday + 1
                HabitTracker.shared.debugSetCigarettes(count: newCount)
                stamina.debugSetCigarettes(count: newCount)
                refreshPauseMenu()
                return

            case "pm_dev_cig_rem":
                let newCount = max(0, HabitTracker.shared.cigarettesLoggedToday - 1)
                HabitTracker.shared.debugSetCigarettes(count: newCount)
                stamina.debugSetCigarettes(count: newCount)
                refreshPauseMenu()
                return

            default:
                // Teleport checkpoints
                if let name = node.name, name.hasPrefix("pm_jump_"),
                   let idxStr = name.split(separator: "_").last,
                   let idx = Int(idxStr) {
                    jumpToPhase(index: idx)
                    hidePauseMenu()
                    return
                }
            }
        }
    }

    private func hidePauseMenu() {
        isPaused_game = false
        pauseMenuNode?.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.scale(to: 0.9, duration: 0.15)
            ]),
            SKAction.removeFromParent()
        ]))
        pauseMenuNode = nil
    }

    /// Rebuilds the pause menu (used after dev/haptic toggle)
    private func refreshPauseMenu() {
        pauseMenuNode?.removeFromParent()
        pauseMenuNode = nil
        isPaused_game = false
        showPauseMenu()
    }

    /// Updates only the cigarette counter widgets without rebuilding the entire menu.
    private func refreshPauseCigCount() {
        guard let menu = pauseMenuNode else { return }
        let cigs = HabitTracker.shared.cigarettesLoggedToday  // source of truth
        let goal = HabitTracker.shared.dailyCigaretteGoal

        // The count label may be a direct child of menu
        if let countLbl = menu.childNode(withName: "pm_cig_count") as? SKLabelNode {
            countLbl.text      = "\(cigs)"
            countLbl.fontColor = pauseCigColor(cigs, goal: goal)
            countLbl.run(SKAction.sequence([
                SKAction.scale(to: 1.18, duration: 0.06),
                SKAction.scale(to: 1.00, duration: 0.06)
            ]))
        }
        if let devLbl = menu.childNode(withName: "pm_dev_cig_label") as? SKLabelNode {
            devLbl.text = "CIG (DEV): \(cigs)"
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func pauseCigColor(_ cigs: Int, goal: Int) -> SKColor {
        if goal == 0 { return GameConstants.Colors.infernoAccent }
        let ratio = CGFloat(cigs) / CGFloat(goal)
        if ratio <= 0.5  { return GameConstants.Colors.paradisoGreen }
        if ratio <= 0.85 { return GameConstants.Colors.purgatorioWarm }
        return GameConstants.Colors.infernoAccent
    }

    // ── Label / Button Factory ──
    private func makePauseLabel(_ text: String, font: String, size: CGFloat,
                                 color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text      = text
        l.fontSize  = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode   = .center
        return l
    }

    private func makePauseButton(label: String, name: String, color: SKColor,
                                  width: CGFloat, height: CGFloat) -> SKNode {
        let node = SKNode()
        node.name = name

        let bg = SKSpriteNode(
            color: name == "pm_resume"
                ? GameConstants.Colors.paradisoGold.withAlphaComponent(0.15)
                : SKColor.white.withAlphaComponent(0.06),
            size: CGSize(width: width, height: height))
        bg.name = name
        node.addChild(bg)

        // Border
        let brdColor = name == "pm_resume"
            ? GameConstants.Colors.paradisoGold.withAlphaComponent(0.50)
            : SKColor.white.withAlphaComponent(0.15)
        let bW: CGFloat = 2
        for (bx, by, bww, bhh): (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (-width/2, height/2-bW, width, bW),
            (-width/2, -height/2,   width, bW),
            (-width/2, -height/2,   bW, height),
            (width/2-bW, -height/2, bW, height)
        ] {
            let b = SKSpriteNode(color: brdColor, size: CGSize(width: bww, height: bhh))
            b.anchorPoint = .zero
            b.position    = CGPoint(x: bx, y: by)
            b.name        = name
            node.addChild(b)
        }

        let lbl = SKLabelNode(fontNamed: "Minecraft")
        lbl.text      = label
        lbl.fontSize  = 18
        lbl.fontColor = color
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode   = .center
        lbl.name = name
        node.addChild(lbl)

        return node
    }

    private func makePauseTextButton(_ text: String, name: String) -> SKNode {
        let node = SKNode()
        node.name = name

        let hit = SKSpriteNode(color: .clear, size: CGSize(width: 36, height: 36))
        hit.name = name
        node.addChild(hit)

        let lbl = SKLabelNode(fontNamed: "Minecraft")
        lbl.text      = text
        lbl.fontSize  = 20
        lbl.fontColor = SKColor.white.withAlphaComponent(0.55)
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode   = .center
        lbl.name = name
        node.addChild(lbl)

        return node
    }

    // MARK: - Respawn

    private func respawnAtLowestHold() {
        var lowestHold: HoldNode?
        var minY: CGFloat = CGFloat.infinity
        platformsNode.enumerateChildNodes(withName: "//*") { node, _ in
            if let hold = node as? HoldNode {
                let hp = hold.parent?.convert(hold.position, to: self.worldNode) ?? hold.position
                if hp.y < minY { minY = hp.y; lowestHold = hold }
            }
        }
        if let target = lowestHold {
            playerNode.physicsBody?.velocity = .zero
            playerNode.grab(hold: target, preserveVelocity: false)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func checkCheckpointFall() {
        guard !isRespawning else { return }
        guard hasGrabbedFirstHold else { return }
        guard playerNode.currentHold == nil else { return }
        let cpAlt = progress.highestCheckpointAltitude
        if cpAlt > 0 && playerNode.position.y < cpAlt - 800 {
            respawnAtLastCheckpoint()
        }
    }

    private func respawnAtLastCheckpoint() {
        isRespawning = true
        let cpAlt = progress.highestCheckpointAltitude
        var bestHold: HoldNode?
        var minDiff: CGFloat = 100.0

        platformsNode.enumerateChildNodes(withName: "//*") { node, _ in
            if let hold = node as? HoldNode, hold.platformType == .checkpoint {
                let hp = hold.parent?.convert(hold.position, to: self.worldNode) ?? hold.position
                let diff = abs(hp.y - (cpAlt + 20))
                if diff < minDiff { minDiff = diff; bestHold = hold }
            }
        }

        if let target = bestHold {
            playerNode.physicsBody?.velocity = .zero
            playerNode.grab(hold: target, preserveVelocity: false)
            cameraNode.position.y = target.parent?.convert(
                target.position, to: worldNode).y ?? target.position.y
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                SKAction.run { [weak self] in self?.isRespawning = false }
            ]))
        } else {
            cameraNode.position.y = cpAlt
            platformGenerator.update(cameraAltitude: cpAlt)
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                SKAction.run { [weak self] in self?.respawnAtLastCheckpoint() }
            ]))
        }
    }

    // MARK: - Hold search

    private func findNearestHold(to point: CGPoint, radius: CGFloat) -> HoldNode? {
        var best: HoldNode? = nil
        var bestDist = radius
        platformsNode.enumerateChildNodes(withName: "//*") { node, _ in
            guard let hold = node as? HoldNode,
                  hold.platformType != .spike else { return }
            let hp   = hold.parent?.convert(hold.position, to: self.worldNode) ?? hold.position
            let dist = hypot(point.x - hp.x, point.y - hp.y)
            if dist < bestDist { bestDist = dist; best = hold }
        }
        return best
    }

    // MARK: - Physics Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let col = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        guard col & GameConstants.Physics.player != 0 else { return }

        if col & GameConstants.Physics.platform != 0 || col & GameConstants.Physics.checkpoint != 0 {
            groundContactCount += 1
            if col & GameConstants.Physics.checkpoint != 0 {
                progress.reachCheckpoint(at: playerNode.position.y)
                safeFloorY = playerNode.position.y - 200
                playerNode.land()
            }
        }

        if col & GameConstants.Physics.enemy  != 0
        || col & GameConstants.Physics.spike  != 0
        || col & GameConstants.Physics.pigeon != 0 {
            if isGodMode { return }
            _ = playerNode.releaseHold(stamina: stamina)
            playerNode.triggerCoughInterrupt()
            grabLockoutTimer = 0.5
            let knockX: CGFloat = playerNode.position.x < contact.contactPoint.x ? -200 : 200
            playerNode.physicsBody?.velocity = .zero
            playerNode.physicsBody?.applyImpulse(CGVector(dx: knockX, dy: -60))
            _ = stamina.consume(amount: 15)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            cameraNode.run(SKAction.sequence([
                SKAction.moveBy(x: -4, y: -4, duration: 0.04),
                SKAction.moveBy(x:  8,  y:  8, duration: 0.08),
                SKAction.moveBy(x: -4, y: -4, duration: 0.04)
            ]))
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        let col = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if col & GameConstants.Physics.player != 0,
           col & GameConstants.Physics.platform != 0
           || col & GameConstants.Physics.checkpoint != 0 {
            groundContactCount = max(0, groundContactCount - 1)
        }
    }

    override func didSimulatePhysics() {
        guard let body = playerNode?.physicsBody else { return }
        if playerNode.currentHold != nil {
            body.velocity = .zero
            body.angularVelocity = 0
        }
    }

    // MARK: - Smoke Mirror

    private func setupSmokeMirror() {
        smokeHazeOverlay = SmokeHazeOverlay(screenSize: size)
        cameraNode.addChild(smokeHazeOverlay)
        baseGravity = GameConstants.World.gravity
    }

    private func updateSmokeMirror(deltaTime: TimeInterval) {
        let cigs           = stamina.cigarettesLoggedToday
        let smokeIntensity = stamina.smokeIntensity

        let norm = playerNode.position.y / GameConstants.World.totalWorldHeight
        if norm < GameConstants.Kingdoms.infernoEnd           { currentKingdom = .inferno }
        else if norm < GameConstants.Kingdoms.purgatorioEnd   { currentKingdom = .purgatorio }
        else                                                   { currentKingdom = .paradiso }

        smokeHazeOverlay.update(deltaTime: deltaTime,
                                smokeIntensity: smokeIntensity,
                                kingdom: currentKingdom)

        if !isGodMode {
            physicsWorld.gravity = CGVector(dx: 0, dy: baseGravity * stamina.gravityMultiplier)
        }

        playerNode.updateSmokeMirrorVisuals(cigarettes: cigs)

        platformsNode.enumerateChildNodes(withName: "//*") { [weak self] node, _ in
            guard let self = self, let hound = node as? TarHoundNode else { return }
            if cigs >= GameConstants.SmokeMirror.tarHoundActivationThreshold {
                if hound.state == .dormant { hound.awaken() }
                hound.update(deltaTime: deltaTime,
                             playerPosition: self.playerNode.position,
                             smokeIntensity: smokeIntensity)
            } else {
                if hound.state != .dormant { hound.goBackToDormant() }
            }
        }

        if !isGodMode {
            platformsNode.enumerateChildNodes(withName: "//*") { [weak self] node, _ in
                guard let self = self, let cloud = node as? ToxicCloudNode else { return }
                cloud.updateOrganic(deltaTime: deltaTime)
                if cloud.isPlayerInside(playerPosition: self.playerNode.position) {
                    cloud.applyEffects(stamina: self.stamina,
                                       deltaTime: deltaTime,
                                       cameraNode: self.cameraNode)
                } else if cloud.screenOverlay?.parent != nil {
                    cloud.playerExited(cameraNode: self.cameraNode)
                }
            }
        } else {
            platformsNode.enumerateChildNodes(withName: "//*") { node, _ in
                (node as? ToxicCloudNode)?.updateOrganic(deltaTime: deltaTime)
            }
        }
    }

    // MARK: - Dev Jump

    private func jumpToPhase(index: Int) {
        guard index < GameConstants.Kingdoms.checkpointAltitudes.count else { return }
        progress.debugSetCheckpoint(index: index)
        let normAlt   = GameConstants.Kingdoms.checkpointAltitudes[index]
        let targetAbs = normAlt * GameConstants.World.totalWorldHeight

        _ = playerNode.releaseHold(stamina: stamina)
        playerNode.physicsBody?.velocity = .zero
        playerNode.position  = CGPoint(x: size.width / 2, y: targetAbs + 150)
        playerNode.zRotation = 0
        grabLockoutTimer     = 0
        hasGrabbedFirstHold  = true
        safeFloorY           = targetAbs - 200

        cameraNode.position.y = playerNode.position.y + 120
        platformGenerator.update(cameraAltitude: cameraNode.position.y)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in self?.attachToFirstHold(radius: 600) }
        ]))
        updateHUD()
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
                b.name = "pause_button" // Important for touch detection
                c.addChild(b)
            }
        }
        c.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 8.0)))
        return c
    }
}
