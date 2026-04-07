import SpriteKit

// MARK: - Smoke Haze Overlay
//
// Nodo figlio della camera che gestisce TUTTI gli effetti visivi legati al fumo:
// - Vignettatura grigia ai bordi dello schermo
// - Desaturazione (overlay grigio semitrasparente sul mondo)
// - Pulsazione cardiaca (la vignettatura pulsa ritmicamente)
// - Particelle di respiro affannoso
//
// Aggiornato ogni frame da GameScene con il conteggio sigarette corrente.

class SmokeHazeOverlay: SKNode {
    
    private let screenSize: CGSize
    
    // ── Vignettatura ──
    private var vignetteNode: SKShapeNode!
    
    // ── Desaturazione ──
    private var desaturationNode: SKSpriteNode!
    
    // ── Respiro affannoso (particelle) ──
    private var breathEmitter: SKEmitterNode!
    
    // ── Heartbeat state ──
    private var heartbeatTimer: TimeInterval = 0
    private var currentHeartbeatInterval: TimeInterval = 0
    
    // ── Cached values ──
    private var currentSmokeIntensity: CGFloat = 0
    private var currentKingdom: Kingdom = .inferno
    
    init(screenSize: CGSize) {
        self.screenSize = screenSize
        super.init()
        
        zPosition = 500 // Davanti a tutto tranne il DEV menu
        setupVignette()
        setupDesaturation()
        setupBreathEmitter()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupVignette() {
        // Vignettatura radiale simulata con un rettangolo nero con bordi sfumati
        // Usiamo un gradiente concentrico approssimato con anelli concentrici
        vignetteNode = SKShapeNode(rectOf: screenSize, cornerRadius: 0)
        vignetteNode.fillColor = .clear
        vignetteNode.strokeColor = .clear
        vignetteNode.alpha = 0
        addChild(vignetteNode)
        
        // Anelli di vignettatura — dal bordo verso il centro
        let rings = 6
        for i in 0..<rings {
            let t = CGFloat(i) / CGFloat(rings)
            let inset = screenSize.width * 0.1 * t
            let ringSize = CGSize(
                width: screenSize.width - inset,
                height: screenSize.height - inset
            )
            let ring = SKShapeNode(rectOf: ringSize, cornerRadius: ringSize.width * 0.3)
            ring.fillColor = .clear
            ring.strokeColor = SKColor(white: 0.0, alpha: 0.12 * (1.0 - t))
            ring.lineWidth = screenSize.width * 0.08
            ring.zPosition = CGFloat(i)
            vignetteNode.addChild(ring)
        }
    }
    
    private func setupDesaturation() {
        // Overlay grigio semitrasparente che copre l'intero schermo
        desaturationNode = SKSpriteNode(color: SKColor(white: 0.3, alpha: 1.0), size: screenSize)
        desaturationNode.alpha = 0
        desaturationNode.zPosition = -1
        desaturationNode.blendMode = .alpha
        addChild(desaturationNode)
    }
    
    private func setupBreathEmitter() {
        breathEmitter = SKEmitterNode()
        breathEmitter.particleBirthRate = 0 // Viene impostato dinamicamente
        breathEmitter.particleLifetime = 1.2
        breathEmitter.particleLifetimeRange = 0.3
        breathEmitter.particleSpeed = 20
        breathEmitter.particleSpeedRange = 8
        breathEmitter.emissionAngle = .pi / 2 // Verso l'alto
        breathEmitter.emissionAngleRange = 0.5
        breathEmitter.particleAlpha = 0.25
        breathEmitter.particleAlphaSpeed = -0.2
        breathEmitter.particleScale = 0.06
        breathEmitter.particleScaleRange = 0.03
        breathEmitter.particleScaleSpeed = 0.04
        breathEmitter.particleColor = SKColor(white: 0.7, alpha: 1.0)
        breathEmitter.particleColorBlendFactor = 1.0
        breathEmitter.position = CGPoint(x: 0, y: -screenSize.height * 0.35) // Basso nello schermo
        breathEmitter.zPosition = 10
        addChild(breathEmitter)
    }
    
    // MARK: - Update (chiamato ogni frame)
    
    func update(deltaTime: TimeInterval, smokeIntensity: CGFloat, kingdom: Kingdom) {
        currentSmokeIntensity = smokeIntensity
        currentKingdom = kingdom
        
        // ── Calcola riduzione per regno ──
        let kingdomFactor: CGFloat
        switch kingdom {
        case .inferno:
            // Nell'Inferno "tutti soffrono" — l'haze è ridotto
            kingdomFactor = GameConstants.SmokeMirror.infernoHazeReduction
        case .purgatorio:
            kingdomFactor = 1.0
        case .paradiso:
            // Nel Paradiso l'haze è al massimo (il contrasto è fortissimo)
            kingdomFactor = 1.2
        }
        
        let effectiveIntensity = smokeIntensity * kingdomFactor
        
        // ── Vignettatura ──
        let targetVignetteAlpha = effectiveIntensity * GameConstants.SmokeMirror.maxHazeAlpha
        vignetteNode.alpha += (targetVignetteAlpha - vignetteNode.alpha) * 0.05
        
        // ── Desaturazione ──
        let targetDesatAlpha = effectiveIntensity * GameConstants.SmokeMirror.maxDesaturationAlpha
        desaturationNode.alpha += (targetDesatAlpha - desaturationNode.alpha) * 0.05
        
        // ── Respiro affannoso ──
        if smokeIntensity > 0.3 {
            breathEmitter.particleBirthRate = 8 + smokeIntensity * 25
        } else {
            breathEmitter.particleBirthRate = 0
        }
        
        // ── Heartbeat pulsazione ──
        updateHeartbeat(deltaTime: deltaTime, intensity: effectiveIntensity)
    }
    
    private func updateHeartbeat(deltaTime: TimeInterval, intensity: CGFloat) {
        guard intensity > 0.1 else {
            currentHeartbeatInterval = 0
            return
        }
        
        // Calcola intervallo
        let base = GameConstants.SmokeMirror.heartbeatBaseInterval
        let minInt = GameConstants.SmokeMirror.heartbeatMinInterval
        currentHeartbeatInterval = base - (base - minInt) * Double(intensity)
        
        heartbeatTimer += deltaTime
        
        if heartbeatTimer >= currentHeartbeatInterval {
            heartbeatTimer = 0
            triggerHeartbeatPulse(intensity: intensity)
        }
    }
    
    private func triggerHeartbeatPulse(intensity: CGFloat) {
        let pulseAmount = GameConstants.SmokeMirror.heartbeatPulseIntensity * intensity
        
        // La vignettatura pulsa — "systole"
        let currentAlpha = vignetteNode.alpha
        vignetteNode.run(SKAction.sequence([
            SKAction.fadeAlpha(to: currentAlpha + pulseAmount, duration: 0.08),
            SKAction.fadeAlpha(to: currentAlpha + pulseAmount * 0.6, duration: 0.06),
            SKAction.fadeAlpha(to: currentAlpha + pulseAmount * 0.8, duration: 0.06),
            SKAction.fadeAlpha(to: currentAlpha, duration: 0.15)
        ]), withKey: "heartbeat")
        
        // Haptic feedback — battito cardiaco
        if intensity > 0.3 {
            UIImpactFeedbackGenerator(style: intensity > 0.7 ? .heavy : .light).impactOccurred()
        }
    }
}
