import SpriteKit
import GameplayKit

// MARK: - Deterministic Platform Generator
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                    LOGICA PROCEDURALE "SEAMLESS"                    │
// │                                                                     │
// │  Questa classe ricrea l'intero mondo da y=0 fino alla quota target  │
// │  in modo puramente matematico e deterministico.                     │
// │  Vantaggi:                                                          │
// │  - NESSUN "GAP" AI CONFINI DEI CHUNK! I salti sono matematicamente  │
// │    perfetti attraversando i chunk.                                  │
// │  - Checkpoint calcolati organicamente. Il generatore si accorge se  │
// │    ne sta per incontrare uno e piazza automaticamente un "ponte"    │
// │    a distanza raggiungibile, prima di piazzare il checkpoint d'oro. │
// └─────────────────────────────────────────────────────────────────────┘

class DeterministicPlatformGenerator {

    private weak var scene: GameScene?
    private var loadedChunks: Set<Int> = []
    private let containerNode: SKNode

    private var lanes: [CGFloat] = []
    private let laneCount = 5

    init(scene: GameScene, containerNode: SKNode) {
        self.scene         = scene
        self.containerNode = containerNode
        computeLanes()
    }

    private func computeLanes() {
        let screenWidth = scene?.size.width ?? 393
        let margin: CGFloat = 55 // armLength(30) + physicsRadius(14) + 11 buffer
        let playableW = screenWidth - margin * 2
        let spacing = playableW / CGFloat(laneCount - 1)
        lanes = (0..<laneCount).map { margin + CGFloat($0) * spacing }
    }

    // MARK: - Update

    func update(cameraAltitude: CGFloat) {
        let chunkSize = GameConstants.World.chunkSize
        let current   = Int(cameraAltitude / chunkSize)
        let range     = (current - GameConstants.World.renderDistance)...(current + GameConstants.World.renderDistance)

        for i in range where i >= 0 && !loadedChunks.contains(i) { loadChunk(index: i) }
        for i in loadedChunks.filter({ !range.contains($0) }) { unloadChunk(index: i) }
    }

    // MARK: - Load

    private func loadChunk(index: Int) {
        loadedChunks.insert(index)

        let chunkSize = GameConstants.World.chunkSize
        let chunkStart = CGFloat(index) * chunkSize
        let chunkEnd   = chunkStart + chunkSize

        // Seed globale fisso: il mondo è SEMPRE identico in ogni sessione.
        // Questo garantisce che simulandolo da 0 a Y, le decisioni del RNG siano in sincrono perfetto.
        let globalRng = GKLinearCongruentialRandomSource(seed: 42)

        var currentY: CGFloat = 0.0
        var lastSafeLane: Int = 2

        // Tutti i checkpoint, ordinati dal più basso
        var upcomingCheckpoints = GameConstants.Kingdoms.checkpointAltitudes.enumerated().map {
            ($0.offset, $0.element * GameConstants.World.totalWorldHeight)
        }.sorted { $0.1 < $1.1 }

        // Simulazione dal suolo (y=0) fino alla fine matematica del chunk che stiamo per caricare
        while currentY < chunkEnd {
            var isBridge = false
            var targetCheckpoint: (Int, CGFloat)? = nil

            let progression = min(1.0, currentY / GameConstants.World.totalWorldHeight)
            let baseGap: CGFloat = 85.0
            let difficultyGap: CGFloat = 30.0 * progression
            
            // Consuma 2 tick RNG per calcolare il gap
            let rngRoll1 = CGFloat(globalRng.nextUniform())
            let rngRoll2 = CGFloat(globalRng.nextUniform())
            
            let randomGap = rngRoll1 * 10.0
            let verticalGap = baseGap + difficultyGap * rngRoll2 + randomGap

            var nextY = currentY + verticalGap

            // Verifichiamo se ci stiamo imbattendo in un checkpoint
            if let nextCp = upcomingCheckpoints.first {
                let cpAlt = nextCp.1
                let proceduralLimit = cpAlt - 85 // Posizione in cui SI DEVE piazzare l'ultimo nodo utile

                if nextY >= proceduralLimit - 15 {
                    // Forziamo il piazzamento del ponte al livello perfetto per raggiungere il checkpoint
                    nextY = proceduralLimit
                    isBridge = true
                    targetCheckpoint = nextCp
                    upcomingCheckpoints.removeFirst()
                }
            }

            // Distanza fisica minima garantita (altrimenti i nodi si compenetrano)
            if nextY - currentY < 75 {
                nextY = currentY + 75
            }

            currentY = nextY
            
            // Definisce se i nodi generati in questo step appartengono REALMENTE al chunk che stiamo caricando
            let isInsideChunk = (currentY >= chunkStart && currentY < chunkEnd)

            if isBridge, let cp = targetCheckpoint {
                // PONTE: Il nodo centrale sicuro che funge da slancio per la piattaforma
                if isInsideChunk {
                    let bridgeNode = HoldNode(type: .solid)
                    bridgeNode.position = CGPoint(x: lanes[2], y: currentY)
                    bridgeNode.name = "hold_bridge"
                    tag(bridgeNode, chunk: index)
                    containerNode.addChild(bridgeNode)
                }

                // CHECKPOINT: La piattaforma d'oro di salvataggio
                // Lo controlliamo e lo piazziamo separatamente per posizionarlo esattamente nella sua altitudine fissa
                if cp.1 >= chunkStart && cp.1 < chunkEnd {
                    spawnCheckpoint(at: cp.1, gironeIndex: cp.0, chunkIndex: index)
                }

                // Avanziamo la currentY appena oltre il checkpoint per ripartire puliti
                currentY = cp.1 + 85
                lastSafeLane = 2
                continue
            }

            // SE NON E' PONTE: Generiamo la logica dei nodi procedurale
            
            // Consuma tick RNG per stabilire nodi e corsie
            let safeRoll = globalRng.nextInt(upperBound: 3) // per shift di -1, 0, +1
            let countRoll = globalRng.nextUniform()
            
            let minSafe = max(0, lastSafeLane - 1)
            let maxSafe = min(laneCount - 1, lastSafeLane + 1)
            let safeLane = minSafe + (safeRoll % (maxSafe - minSafe + 1))

            let nodeCount: Int
            if progression < 0.15 {
                // Tutorial: quasi sempre 1nodo (percorso obbligato), a volte 2
                nodeCount = countRoll < 0.8 ? 1 : 2
            } else if progression < 0.33 {
                // Inferno: mix di 1 e 2 nodi
                nodeCount = countRoll < 0.5 ? 1 : 2
            } else if progression < 0.66 {
                // Purgatorio: maggioranza 2 nodi (bivio), raramente 1 o 3
                if countRoll < 0.2 { nodeCount = 1 }
                else if countRoll < 0.85 { nodeCount = 2 }
                else { nodeCount = 3 }
            } else {
                // Paradiso: percorsi doppi, a volte tripli (caos massimo)
                nodeCount = countRoll < 0.65 ? 2 : 3
            }

            var activeLanes = Set<Int>()
            activeLanes.insert(safeLane)
            
            var attempts = 0
            while activeLanes.count < nodeCount && attempts < 15 {
                let candidate = globalRng.nextInt(upperBound: laneCount)
                if candidate != safeLane { activeLanes.insert(candidate) }
                attempts += 1
            }

            lastSafeLane = safeLane

            for lane in activeLanes.sorted() {
                // IMPORTANTISSIMO: Dobbiamo consumare l'RNG esatto a prescindere che siamo dentro il chunk visibile 
                // o no. Altrimenti si spacca la simulazione.
                let rollY      = CGFloat(globalRng.nextUniform())
                let rollX      = CGFloat(globalRng.nextUniform())
                let rollType   = CGFloat(globalRng.nextUniform())
                let rollEnemy  = CGFloat(globalRng.nextUniform())

                // Bypass visuale rapido se fuori dal chunk corrente
                if !isInsideChunk { continue } 
                
                let yJitter = (rollY - 0.5) * 16.0
                let xJitter = (rollX - 0.5) * 20.0
                
                let holdY = currentY + yJitter
                let xPos  = lanes[lane]
                let finalX = max(55, min(338, xPos + xJitter))

                var nodeType: PlatformType = .solid
                var spawnEnemy = false

                if lane == safeLane {
                    // CORSIA SICURA: Niente trappole istantanee o nemici, massimo movimento o rimbalzo
                    if progression > 0.5 {
                        if rollType < 0.2 { nodeType = .moving }
                        else if rollType < 0.3 { nodeType = .bouncy }
                    }
                } else {
                    // CORSIE ALTERNATIVE: Gradualmente più diaboliche
                    if progression < 0.15 { nodeType = .solid }
                    else if progression < 0.33 {
                        if rollType < 0.15 { nodeType = .sticky }
                    } else if progression < 0.50 {
                        if rollType < 0.25 { nodeType = .crumbling }
                        else if rollType < 0.45 { nodeType = .moving }
                    } else if progression < 0.66 {
                        if rollType < 0.15 { nodeType = .spike }
                        else if rollType < 0.35 { nodeType = .crumbling }
                        else if rollType < 0.50 { nodeType = .moving }
                    } else if progression < 0.85 {
                        if rollType < 0.25 { nodeType = .spike }
                        else if rollType < 0.45 { nodeType = .cloud }
                        else if rollType < 0.55 { nodeType = .crumbling }
                    } else {
                        if rollType < 0.35 { nodeType = .spike }
                        else if rollType < 0.55 { nodeType = .cloud }
                        else if rollType < 0.65 { nodeType = .crumbling }
                    }

                    if nodeType != .spike && nodeType != .cloud {
                        let enemyChance: CGFloat = progression < 0.33 ? 0.05 : (progression < 0.66 ? 0.15 : 0.25)
                        if rollEnemy < enemyChance { spawnEnemy = true }
                    }
                }

                let holdNode = HoldNode(type: nodeType)
                holdNode.position = CGPoint(x: finalX, y: holdY)
                holdNode.name = "hold_\(nodeType)"
                tag(holdNode, chunk: index)
                containerNode.addChild(holdNode)

                if spawnEnemy {
                    let bug = GloomBugNode()
                    // Dispone i nemici lateralmente per non ostacolare il tap del nodo!
                    let enemyOffsetX: CGFloat = lane < 2 ? 35 : -35
                    bug.position = CGPoint(x: finalX + enemyOffsetX, y: holdY + 30)
                    bug.name = "enemy"
                    tag(bug, chunk: index)
                    containerNode.addChild(bug)
                }
            }
        }
    }

    // MARK: - Unload

    private func unloadChunk(index: Int) {
        loadedChunks.remove(index)
        containerNode.enumerateChildNodes(withName: "//*") { node, _ in
            if (node.userData?["chunk"] as? Int) == index {
                node.removeFromParent()
            }
        }
    }

    // MARK: - Checkpoint (Visuale & Fisico)

    private func spawnCheckpoint(at altitude: CGFloat, gironeIndex: Int, chunkIndex: Int) {
        guard let scene = scene else { return }
        let w = scene.size.width

        let marker = PlatformNode(type: .solid, width: w)
        marker.position = CGPoint(x: w / 2, y: altitude)
        marker.color    = GameConstants.Colors.paradisoGold.withAlphaComponent(0.4)
        marker.name     = "platform_checkpoint"
        marker.physicsBody?.categoryBitMask = GameConstants.Physics.checkpoint | GameConstants.Physics.platform
        tag(marker, chunk: chunkIndex)
        containerNode.addChild(marker)

        let hold = HoldNode(type: .checkpoint)
        hold.position = CGPoint(x: w / 2, y: altitude + 20)
        hold.name = "hold_checkpoint"
        tag(hold, chunk: chunkIndex)
        containerNode.addChild(hold)

        let label = SKLabelNode(fontNamed: "Avenir-Heavy")
        let altInt = Int(altitude)
        if altInt == 0 {
            label.text = "— L'ABISSO DI CENERE —"
        } else if altInt == Int(GameConstants.Kingdoms.infernoEnd * GameConstants.World.totalWorldHeight) {
            label.text = "— LA NEBBIA DEL PURGATORIO —"
        } else if altInt == Int(GameConstants.Kingdoms.purgatorioEnd * GameConstants.World.totalWorldHeight) {
            label.text = "— LA VETTA PURA —"
        } else {
            label.text = "— CHECKPOINT \(altInt)m —"
        }

        label.fontSize  = 20
        label.fontColor = GameConstants.Colors.paradisoGold
        label.position  = CGPoint(x: w / 2, y: altitude + 50)
        label.zPosition = -10
        label.name      = "label_checkpoint"
        tag(label, chunk: chunkIndex)
        containerNode.addChild(label)
    }

    // MARK: - Utility

    private func tag(_ node: SKNode, chunk: Int) {
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["chunk"] = chunk
    }
}
