import SpriteKit

// MARK: - Audio Manager

/// Manages background music and sound effects.
/// Uses SpriteKit's built-in audio for simplicity.
class AudioManager {
    
    static let shared = AudioManager()
    private init() {}
    
    private var isMuted = false
    private weak var currentScene: SKScene?
    
    // MARK: - Background Music
    
    /// Play kingdom-specific ambient music
    func playAmbientMusic(for kingdom: Kingdom, in scene: SKScene) {
        currentScene = scene
        guard !isMuted else { return }
        
        // Stop current music
        scene.removeAction(forKey: "bgm")
        
        let filename: String
        switch kingdom {
        case .inferno:    filename = "bgm_inferno"    // Dark, industrial drone
        case .purgatorio: filename = "bgm_purgatorio" // Ambient, hopeful
        case .paradiso:   filename = "bgm_paradiso"   // Uplifting, airy
        }
        
        // Note: Actual audio files need to be added to the project
        // let bgm = SKAction.playSoundFileNamed("\(filename).m4a", waitForCompletion: true)
        // scene.run(SKAction.repeatForever(bgm), withKey: "bgm")
    }
    
    // MARK: - Sound Effects
    
    func playJump(in scene: SKScene, intensity: CGFloat) {
        guard !isMuted else { return }
        // scene.run(SKAction.playSoundFileNamed("sfx_jump.wav", waitForCompletion: false))
    }
    
    func playLand(in scene: SKScene) {
        guard !isMuted else { return }
        // scene.run(SKAction.playSoundFileNamed("sfx_land.wav", waitForCompletion: false))
    }
    
    func playCough(in scene: SKScene) {
        guard !isMuted else { return }
        // scene.run(SKAction.playSoundFileNamed("sfx_cough.wav", waitForCompletion: false))
    }
    
    func playPigeonCaw(in scene: SKScene) {
        guard !isMuted else { return }
        // scene.run(SKAction.playSoundFileNamed("sfx_pigeon_caw.wav", waitForCompletion: false))
    }
    
    func playCheckpoint(in scene: SKScene) {
        guard !isMuted else { return }
        // scene.run(SKAction.playSoundFileNamed("sfx_checkpoint.wav", waitForCompletion: false))
    }
    
    // MARK: - Mute Toggle
    
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            currentScene?.removeAction(forKey: "bgm")
        }
    }
    
    var isSoundEnabled: Bool { !isMuted }
}
