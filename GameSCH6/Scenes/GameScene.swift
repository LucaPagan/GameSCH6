import SpriteKit

// MARK: - Game Scene (Rocky Climb)
//
// ORDINE EVENTI PER FRAME (critico per capire il lancio):
//
//   1. update()           → se agganciato: updateRotation() muove il player manualmente
//                           se in volo: checkAutoGrab() controlla aggancio
//   2. SpriteKit simula   → applica gravity + velocity al physicsBody
//   3. didSimulatePhysics → se agganciato: azzera velocity (neutralizza step 2)
//                           se in volo: NON tocca nulla → il lancio balistico funziona
//
// Il toggle isDynamic è stato eliminato da PlayerNode.
// Il body è SEMPRE dinamico. Agganciato = gravity off + velocity azzerata ogni frame.
// In volo = gravity on + velocity tangenziale applicata in releaseHold().

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nodes
    var playerNode:    PlayerNode!
    let worldNode      = SKNode()
    let platformsNode  = SKNode()
    let cameraNode     = SKCameraNode()

    // MARK: - HUD
    var altitudeLabel: SKLabelNode!
    var staminaFill:   SKShapeNode!

    // MARK: - Managers
    var platformGenerator: DeterministicPlatformGenerator!
    var stamina:  PlayerStamina!
    var progress: PlayerProgress!

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
    var isRespawning = false
    var hasGrabbedFirstHold = false
    
    // --- DEV MODE STATE ---
    var isGodMode = false {
        didSet { updateDevStatus() }
    }
    var isFreeFlyMode = false {
        didSet { updateDevStatus() }
    }
    private var devStatusLabel: SKLabelNode!

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

        // Reset del progresso all'avvio per partire sempre da 0
        progress.fullReset()

        setupPhysics()
        setupNodes()
        setupPlayer()
        setupCamera()
        setupHUD()

        platformGenerator = DeterministicPlatformGenerator(scene: self, containerNode: platformsNode)
        platformGenerator.update(cameraAltitude: 300)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in self?.attachToFirstHold() }
        ]))
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
        n.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: x, y: -2000),
                                       to:       CGPoint(x: x, y: 60000))
        n.physicsBody?.categoryBitMask  = GameConstants.Physics.boundary
        n.physicsBody?.collisionBitMask = GameConstants.Physics.player
        return n
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
        altitudeLabel = SKLabelNode(fontNamed: "Avenir-Heavy")
        altitudeLabel.fontSize  = 20
        altitudeLabel.fontColor = .white
        altitudeLabel.position  = CGPoint(x: 0, y: size.height / 2 - 65)
        cameraNode.addChild(altitudeLabel)

        let barW: CGFloat = 110; let barH: CGFloat = 7
        let barX = -size.width / 2 + 18
        let barY =  size.height / 2 - 78

        let bg = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 3)
        bg.fillColor = SKColor.white.withAlphaComponent(0.12)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: barX + barW / 2, y: barY)
        cameraNode.addChild(bg)

        staminaFill = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 3)
        staminaFill.fillColor   = GameConstants.Colors.paradisoGreen
        staminaFill.strokeColor = .clear
        staminaFill.position = CGPoint(x: barX + barW / 2, y: barY)
        cameraNode.addChild(staminaFill)

        // ── DEV MENU BUTTON ──
        let devButton = SKLabelNode(fontNamed: "Avenir-Heavy")
        devButton.text = "DEV"
        devButton.fontSize = 16
        devButton.fontColor = .cyan
        devButton.position = CGPoint(x: size.width / 2 - 40, y: size.height / 2 - 65)
        devButton.name = "dev_button"
        cameraNode.addChild(devButton)
        
        // ── DEV STATUS HUD ──
        devStatusLabel = SKLabelNode(fontNamed: "Avenir-Black")
        devStatusLabel.fontSize = 10
        devStatusLabel.fontColor = .cyan
        devStatusLabel.horizontalAlignmentMode = .right
        devStatusLabel.position = CGPoint(x: size.width / 2 - 20, y: size.height / 2 - 85)
        devStatusLabel.alpha = 0
        cameraNode.addChild(devStatusLabel)
    }

    private func updateDevStatus() {
        var status = [String]()
        if isGodMode { status.append("GOD") }
        if isFreeFlyMode { status.append("FLY") }
        
        if status.isEmpty {
            devStatusLabel.run(SKAction.fadeOut(withDuration: 0.2))
        } else {
            devStatusLabel.text = status.joined(separator: " | ")
            devStatusLabel.alpha = 1
        }
    }

    // MARK: - Primo aggancio

    func attachToFirstHold(radius: CGFloat = 400) {
        guard let hold = findNearestHold(to: playerNode.position, radius: radius) else {
            // Se non c'è una hold vicina, riproviamo o restiamo fermi
            print("DEV: Nessun appiglio nel raggio di \(radius)m")
            return
        }
        playerNode.grab(hold: hold, preserveVelocity: false)
        lastGrabTime = 0
        hasGrabbedFirstHold = true
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            sceneStartTime = currentTime
        }
        let dt = min(1.0/60.0, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        platformGenerator.update(cameraAltitude: cameraNode.position.y)
        
        if isGodMode {
            stamina.currentStamina = stamina.maxStamina
        } else {
            stamina.regenerate(deltaTime: dt)
        }

        if let hold = playerNode.currentHold {
            let holdPosInWorld = hold.parent?.convert(hold.position, to: worldNode) ?? hold.position
            playerNode.updateRotation(deltaTime: dt, stamina: stamina,
                                       holdPositionInParent: holdPosInWorld)

            // Tosse: distacco forzato (Soli se non siamo in God Mode)
            if !isGodMode {
                let coughRoll = Float.random(in: 0...1)
                if coughRoll < Float(stamina.coughChancePerSecond * CGFloat(dt)) {
                    _ = playerNode.releaseHold(stamina: stamina)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }

        // Decremento lockout
        if grabLockoutTimer > 0 {
            grabLockoutTimer = max(0, grabLockoutTimer - dt)
        }

        updateCamera()
        updateHUD()

        if playerNode.position.y < -400 && playerNode.currentHold == nil {
            respawnAtLowestHold()
        }
        
        checkCheckpointFall()
    }

    // MARK: - Camera / HUD

    private func updateCamera() {
        let targetY  = max(size.height / 2, playerNode.position.y + 130)
        let currentY = cameraNode.position.y
        let speed: CGFloat = playerNode.position.y > currentY ? 0.1 : 0.08
        cameraNode.position = CGPoint(x: size.width / 2,
                                      y: currentY + (targetY - currentY) * speed)
    }

    private func updateHUD() {
        altitudeLabel.text = "\(Int(max(0, playerNode.position.y))) m"
        let ratio = max(0.01, min(1, stamina.currentStamina / stamina.maxStamina))
        staminaFill.xScale = ratio
        staminaFill.fillColor = ratio > 0.5 ? GameConstants.Colors.paradisoGreen
            : ratio > 0.25 ? GameConstants.Colors.purgatorioWarm
            : GameConstants.Colors.infernoAccent
    }

    // MARK: - Touch: tap ovunque = lancia

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isRespawning else { return }
        
        // --- DEV MENU HANDLING ---
        if let touch = touches.first {
            let loc = touch.location(in: cameraNode)
            let locInWorld = touch.location(in: worldNode)
            
            if let node = cameraNode.nodes(at: loc).first(where: { $0.name == "dev_button" }) {
                showDevMenu()
                return
            }
            
            // Check for other dev menu buttons
            let subNode = cameraNode.nodes(at: loc).first
            if subNode?.name == "dev_close" { hideDevMenu(); return }
            if subNode?.name == "dev_god" { isGodMode.toggle(); showDevMenu(); return }
            if subNode?.name == "dev_fly" { isFreeFlyMode.toggle(); showDevMenu(); return }
            
            if subNode?.name == "dev_cig_add" { 
                let newCount = HabitTracker.shared.cigarettesLoggedToday + 1
                HabitTracker.shared.debugSetCigarettes(count: newCount)
                stamina.debugSetCigarettes(count: newCount)
                showDevMenu()
                return 
            }
            if subNode?.name == "dev_cig_rem" { 
                let newCount = max(0, HabitTracker.shared.cigarettesLoggedToday - 1)
                HabitTracker.shared.debugSetCigarettes(count: newCount)
                stamina.debugSetCigarettes(count: newCount)
                showDevMenu()
                return 
            }

            if let node = cameraNode.nodes(at: loc).first(where: { $0.name?.starts(with: "dev_jump_") == true }) {
                if let idxStr = node.name?.split(separator: "_").last, let idx = Int(idxStr) {
                    jumpToPhase(index: idx)
                }
                hideDevMenu()
                return
            }
            
            // FREE FLY MODE: Teleport to tap
            if isFreeFlyMode && devMenuNode == nil {
                playerNode.physicsBody?.velocity = .zero
                playerNode.position = locInWorld
                attachToFirstHold(radius: 200)
                return
            }

            // Close menu if it's open and user taps outside
            if devMenuNode != nil {
                hideDevMenu()
                return
            }
        }
        // -------------------------

        guard lastUpdateTime - lastGrabTime >= grabCooldown else { return }
        guard grabLockoutTimer <= 0 else { return } // BLOCCO GRAB SE STORDITO

        if playerNode.currentHold != nil {
            // TAP quando attaccato: Lancio nel vuoto radiale
            _ = playerNode.releaseHold(stamina: stamina)
            lastGrabTime = lastUpdateTime
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else if isPlayerGrounded || isGodMode {
            // TAP sul terreno/checkpoint (o ovunque se GodMode): salto drittissimo verso il nodo più vicino
            if let hold = findNearestHold(to: playerNode.position, radius: 2000.0) {
                let hp = hold.parent?.convert(hold.position, to: worldNode) ?? hold.position
                let dx = hp.x - playerNode.position.x
                let dy = hp.y - playerNode.position.y
                let length = hypot(dx, dy)
                if length > 0 {
                    let jumpForce = GameConstants.Jump.baseForce * stamina.jumpForceMultiplier
                    let jumpVelocity = CGVector(dx: (dx/length) * jumpForce, dy: (dy/length) * jumpForce)
                    
                    playerNode.physicsBody?.velocity = jumpVelocity
                    playerNode.physicsBody?.affectedByGravity = true // Durante il salto da terra applichiamo la gravità normale
                    playerNode.zRotation = atan2(dy, dx) - .pi / 2
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        } else {
            // TAP quando in volo: Tentativo di aggancio manuale (Tempismo stretto)
            // L'aiuto deve essere minimo, la tolleranza è molto piccola (40 pt)
            if let hold = findNearestHold(to: playerNode.position, radius: 60.0) {
                if hold.onPlayerGrab(stamina: stamina) {
                    playerNode.grab(hold: hold, preserveVelocity: true)
                    lastGrabTime = lastUpdateTime
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else {
                // Opzionale: un feedback acustico o visivo di "tap fallito"
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }

    // MARK: - Respawn
    
    private func respawnAtLowestHold() {
        var lowestHold: HoldNode?
        var minY: CGFloat = CGFloat.infinity

        // Cerchiamo la hold con la coordinata Y più bassa tra quelle caricate
        platformsNode.enumerateChildNodes(withName: "//*") { node, _ in
            if let hold = node as? HoldNode {
                let hp = hold.parent?.convert(hold.position, to: self.worldNode) ?? hold.position
                if hp.y < minY {
                    minY = hp.y
                    lowestHold = hold
                }
            }
        }

        if let target = lowestHold {
            playerNode.physicsBody?.velocity = .zero
            playerNode.grab(hold: target, preserveVelocity: false)
            
            // Feedback
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    private func checkCheckpointFall() {
        guard !isRespawning else { return }
        guard hasGrabbedFirstHold else { return }
        guard playerNode.currentHold == nil else { return }
        let cpAlt = progress.highestCheckpointAltitude
        // Se abbiamo superato il primo checkpoint (0m) e cadiamo sensibilmente sotto l'ultimo raggiunto
        if cpAlt > 0 && playerNode.position.y < cpAlt - 800 {
            respawnAtLastCheckpoint()
        }
    }
    
    private func respawnAtLastCheckpoint() {
        isRespawning = true
        let cpAlt = progress.highestCheckpointAltitude
        var bestHold: HoldNode?
        var minDiff: CGFloat = 100.0

        // Cerchiamo il nodo checkpoint all'altitudine corretta
        platformsNode.enumerateChildNodes(withName: "//*") { node, _ in
            if let hold = node as? HoldNode, hold.platformType == .checkpoint {
                let hp = hold.parent?.convert(hold.position, to: self.worldNode) ?? hold.position
                let diff = abs(hp.y - (cpAlt + 20))
                if diff < minDiff {
                    minDiff = diff
                    bestHold = hold
                }
            }
        }

        if let target = bestHold {
            playerNode.physicsBody?.velocity = .zero
            playerNode.grab(hold: target, preserveVelocity: false)
            
            // Reset camera per evitare scrolling infinito verso l'alto
            cameraNode.position.y = target.parent?.convert(target.position, to: worldNode).y ?? target.position.y
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                SKAction.run { [weak self] in self?.isRespawning = false }
            ]))
        } else {
            // Se il chunk è stato scaricato, forziamo il caricamento muovendo prima la camera
            cameraNode.position.y = cpAlt
            platformGenerator.update(cameraAltitude: cpAlt)
            
            // Ritentiamo tra un attimo
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
                // Se il contatto è con un checkpoint, aggiorna l'altitudine salvata
                // Usiamo la posizione del player o quella del nodo? Usiamo quella del player per semplicità
                progress.reachCheckpoint(at: playerNode.position.y)
                safeFloorY = playerNode.position.y - 200
                playerNode.land()
            }
        }

        if col & GameConstants.Physics.enemy  != 0
        || col & GameConstants.Physics.spike  != 0
        || col & GameConstants.Physics.pigeon != 0 {
            
            if isGodMode { return } // INVULNERABILE!
            
            _ = playerNode.releaseHold(stamina: stamina)
            playerNode.triggerCoughInterrupt()
            
            // STUN: non può agganciarsi per 0.5s
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
           col & GameConstants.Physics.platform != 0 || col & GameConstants.Physics.checkpoint != 0 {
            groundContactCount = max(0, groundContactCount - 1)
        }
    }

    // MARK: - didSimulatePhysics
    //
    // Agganciato → azzera velocity ogni frame per neutralizzare la simulazione SpriteKit.
    // In volo    → non tocchiamo nulla: velocity tangenziale + gravità agiscono liberamente.

    override func didSimulatePhysics() {
        guard let body = playerNode?.physicsBody else { return }

        if playerNode.currentHold != nil {
            body.velocity = .zero
            body.angularVelocity = 0
        }
    }

    // MARK: - Dev Menu
    private var devMenuNode: SKNode?

    private func showDevMenu() {
        hideDevMenu() // Refresh menu if it's already there
        
        let menu = SKNode()
        menu.zPosition = 1000
        
        // Pannello più largo e alto per i nuovi controlli
        let bg = SKShapeNode(rectOf: CGSize(width: 320, height: 350), cornerRadius: 10)
        bg.fillColor = SKColor.black.withAlphaComponent(0.9)
        bg.strokeColor = .cyan
        bg.lineWidth = 2
        menu.addChild(bg)
        
        let title = SKLabelNode(fontNamed: "Avenir-Black")
        title.text = "DEV MENU - AD ASTRA"
        title.fontSize = 18
        title.fontColor = .cyan
        title.position = CGPoint(x: 0, y: 150)
        menu.addChild(title)
        
        // --- TOGGLES ---
        let godBtn = SKLabelNode(fontNamed: "Avenir-Heavy")
        godBtn.text = "GOD MODE: \(isGodMode ? "ON" : "OFF")"
        godBtn.fontSize = 14
        godBtn.fontColor = isGodMode ? .green : .white
        godBtn.name = "dev_god"
        godBtn.position = CGPoint(x: -80, y: 110)
        menu.addChild(godBtn)
        
        let flyBtn = SKLabelNode(fontNamed: "Avenir-Heavy")
        flyBtn.text = "FREE FLY: \(isFreeFlyMode ? "ON" : "OFF")"
        flyBtn.fontSize = 14
        flyBtn.fontColor = isFreeFlyMode ? .green : .white
        flyBtn.name = "dev_fly"
        flyBtn.position = CGPoint(x: 80, y: 110)
        menu.addChild(flyBtn)
        
        // --- SIGARETTE ---
        let cigLabel = SKLabelNode(fontNamed: "Avenir-Medium")
        cigLabel.text = "Sigarette: \(HabitTracker.shared.cigarettesLoggedToday)"
        cigLabel.fontSize = 13
        cigLabel.position = CGPoint(x: 0, y: 80)
        menu.addChild(cigLabel)
        
        let addCig = SKLabelNode(fontNamed: "Avenir-Black")
        addCig.text = "[ + ]"
        addCig.name = "dev_cig_add"
        addCig.fontSize = 16
        addCig.position = CGPoint(x: 100, y: 80)
        menu.addChild(addCig)
        
        let remCig = SKLabelNode(fontNamed: "Avenir-Black")
        remCig.text = "[ - ]"
        remCig.name = "dev_cig_rem"
        remCig.fontSize = 16
        remCig.position = CGPoint(x: -100, y: 80)
        menu.addChild(remCig)

        let line = SKShapeNode(rectOf: CGSize(width: 280, height: 1))
        line.fillColor = .white.withAlphaComponent(0.3)
        line.strokeColor = .clear
        line.position = CGPoint(x: 0, y: 65)
        menu.addChild(line)
        
        // --- CHECKPOINTS JUMP ---
        let jumpTitle = SKLabelNode(fontNamed: "Avenir-Heavy")
        jumpTitle.text = "TELEPORT CHECKPOINTS"
        jumpTitle.fontSize = 12
        jumpTitle.alpha = 0.5
        jumpTitle.position = CGPoint(x: 0, y: 45)
        menu.addChild(jumpTitle)

        let cpAltitudes = GameConstants.Kingdoms.checkpointAltitudes
        for (i, cp) in cpAltitudes.enumerated() {
            let altInt = Int(cp * GameConstants.World.totalWorldHeight)
            let btn = SKLabelNode(fontNamed: "Avenir-Heavy")
            btn.text = "➤ \(altInt)m"
            btn.fontSize = 13
            btn.name = "dev_jump_\(i)"
            
            let col = CGFloat(i % 3) // 3 colonne orali
            let row = CGFloat(i / 3)
            
            btn.position = CGPoint(x: -100 + col * 100, y: 20 - row * 24)
            menu.addChild(btn)
        }
        
        let closeBtn = SKLabelNode(fontNamed: "Avenir-Heavy")
        closeBtn.text = "[ CHIUDI MENU ]"
        closeBtn.fontSize = 14
        closeBtn.fontColor = .red
        closeBtn.position = CGPoint(x: 0, y: -155)
        closeBtn.name = "dev_close"
        menu.addChild(closeBtn)
        
        cameraNode.addChild(menu)
        devMenuNode = menu
    }
    
    private func hideDevMenu() {
        devMenuNode?.removeFromParent()
        devMenuNode = nil
    }
    
    private func jumpToPhase(index: Int) {
        guard index < GameConstants.Kingdoms.checkpointAltitudes.count else { return }
        
        // 1. Reset Progress state
        progress.debugSetCheckpoint(index: index)
        
        let normAlt = GameConstants.Kingdoms.checkpointAltitudes[index]
        let targetAbs = normAlt * GameConstants.World.totalWorldHeight
        
        // 2. Reset Player State
        _ = playerNode.releaseHold(stamina: stamina)
        playerNode.physicsBody?.velocity = .zero
        playerNode.position = CGPoint(x: size.width / 2, y: targetAbs + 150)
        playerNode.zRotation = 0
        grabLockoutTimer = 0
        hasGrabbedFirstHold = true // Forziamo True per permettere subito l'attacco
        safeFloorY = targetAbs - 200
        
        // 3. Instant Camera Snap
        cameraNode.position.y = playerNode.position.y + 120
        
        // 4. Force World Update
        platformGenerator.update(cameraAltitude: cameraNode.position.y)
        
        // 5. AUTO ATTACHMENT (Migliorare con delay minimo per caricamento nodi)
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in 
                self?.attachToFirstHold(radius: 600) 
            }
        ]))
        
        updateHUD()
        print("DEV: Teleport to \(Int(targetAbs))m successful.")
    }
}
