import SpriteKit

// MARK: - Enemy Spawner

/// Gestisce lo spawn dei Piccioni dell'Haze basato sullo stato del fumo.
/// I piccioni appaiono solo quando `cigarettesLoggedToday > 0`.
class EnemySpawner {
    
    private weak var scene: GameScene?
    
    /// Accumulatore di tempo per il timing di spawn
    private var spawnTimer: TimeInterval = 0
    
    /// Piccioni attivi nella scena
    private var activePigeons: [HazePigeonNode] = []
    
    /// Massimo numero di piccioni simultanei
    private let maxActivePigeons = 3
    
    /// Tempo tra un attacco in picchiata e l'altro per ogni piccione
    private let diveInterval: TimeInterval = 4.0
    private var diveTimer: TimeInterval = 0
    
    init(scene: GameScene) {
        self.scene = scene
    }
    
    // MARK: - Update
    
    /// Chiamato ad ogni frame da GameScene.update()
    func update(deltaTime: TimeInterval, playerPosition: CGPoint, spawnRate: CGFloat) {
        guard spawnRate > 0 else {
            // Niente fumo → Niente piccioni
            removeAllPigeons()
            return
        }
        
        // Pulisce i piccioni rimossi
        activePigeons.removeAll { $0.parent == nil }
        
        // Timer di spawn
        let spawnInterval: TimeInterval = spawnRate > 0 ? 60.0 / Double(spawnRate) : .infinity
        spawnTimer += deltaTime
        
        if spawnTimer >= spawnInterval && activePigeons.count < maxActivePigeons {
            spawnPigeon(nearPlayer: playerPosition)
            spawnTimer = 0
        }
        
        // Aggiorna i piccioni attivi
        for pigeon in activePigeons {
            pigeon.update(deltaTime: deltaTime, playerPosition: playerPosition)
        }
        
        // Timer per attacco in picchiata
        diveTimer += deltaTime
        if diveTimer >= diveInterval {
            triggerRandomDive()
            diveTimer = 0
        }
    }
    
    // MARK: - Spawning
    
    private func spawnPigeon(nearPlayer playerPos: CGPoint) {
        guard let scene = scene else { return }
        
        let pigeon = HazePigeonNode()
        
        // Genera da un lato casuale dello schermo, sopra al giocatore
        let side: CGFloat = Bool.random() ? -1 : 1
        let spawnX = playerPos.x + side * (scene.size.width / 2 + 50)
        let spawnY = playerPos.y + CGFloat.random(in: 100...250)
        
        pigeon.position = CGPoint(x: spawnX, y: spawnY)
        
        // FIX: Ora usa worldNode invece dell'obsoleto enemiesNode
        scene.worldNode.addChild(pigeon)
        activePigeons.append(pigeon)
        
        // Audio (placeholder)
        // scene.run(SKAction.playSoundFileNamed("pigeon_caw.wav", waitForCompletion: false))
    }
    
    private func triggerRandomDive() {
        let circling = activePigeons.filter { $0.state == .circling }
        guard let pigeon = circling.randomElement() else { return }
        pigeon.startDive()
    }
    
    private func removeAllPigeons() {
        for pigeon in activePigeons {
            pigeon.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
        activePigeons.removeAll()
    }
}
