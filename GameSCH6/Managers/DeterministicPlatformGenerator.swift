import SpriteKit
import GameplayKit

// MARK: - Deterministic Platform Generator
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │                    "SEAMLESS" PROCEDURAL LOGIC                      │
// │                                                                     │
// │  This class recreates the entire world from y=0 up to the target    │
// │  altitude in a purely mathematical and deterministic way.           │
// │  Advantages:                                                        │
// │  - NO "GAPS" AT CHUNK BOUNDARIES! Jumps are mathematically perfect  │
// │    across chunks.                                                   │
// │  - Organically calculated checkpoints. The generator detects if one │
// │    is approaching and automatically places a reachabl "bridge"      │
// │    before placing the golden checkpoint platform.                   │
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
    
    /// Determines the kingdom based on normalized progression
    private func kingdomFor(progression: CGFloat) -> Kingdom {
        if progression < GameConstants.Kingdoms.infernoEnd { return .inferno }
        if progression < GameConstants.Kingdoms.purgatorioEnd { return .purgatorio }
        return .paradiso
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

        // Fixed global seed: the world is ALWAYS identical in every session.
        // This ensures that when simulating from 0 to Y, RNG decisions are in perfect sync.
        let globalRng = GKLinearCongruentialRandomSource(seed: 42)

        var currentY: CGFloat = 0.0
        var lastSafeLane: Int = 2

        // All checkpoints, sorted from lowest
        var upcomingCheckpoints = GameConstants.Kingdoms.checkpointAltitudes.enumerated().map {
            ($0.offset, $0.element * GameConstants.World.totalWorldHeight)
        }.sorted { $0.1 < $1.1 }

        // Simulation from ground (y=0) up to the mathematical end of the chunk we are about to load
        while currentY < chunkEnd {
            var isBridge = false
            var targetCheckpoint: (Int, CGFloat)? = nil

            let progression = min(1.0, currentY / GameConstants.World.totalWorldHeight)
            let baseGap: CGFloat = 85.0
            let difficultyGap: CGFloat = 30.0 * progression
            
            // Consumes 2 RNG ticks to calculate the gap
            let rngRoll1 = CGFloat(globalRng.nextUniform())
            let rngRoll2 = CGFloat(globalRng.nextUniform())
            
            let randomGap = rngRoll1 * 10.0
            let verticalGap = baseGap + difficultyGap * rngRoll2 + randomGap

            var nextY = currentY + verticalGap

            // Check if we are running into a checkpoint
            if let nextCp = upcomingCheckpoints.first {
                let cpAlt = nextCp.1
                let proceduralLimit = cpAlt - 85 // Position where the last useful node MUST be placed

                if nextY >= proceduralLimit - 15 {
                    // Force a bridge placement at the perfect level to reach the checkpoint
                    nextY = proceduralLimit
                    isBridge = true
                    targetCheckpoint = nextCp
                    upcomingCheckpoints.removeFirst()
                }
            }

            // Guaranteed minimum physical distance (otherwise nodes overlap)
            if nextY - currentY < 75 {
                nextY = currentY + 75
            }

            currentY = nextY
            
            // Defines if the nodes generated in this step REALLY belong to the chunk we are loading
            let isInsideChunk = (currentY >= chunkStart && currentY < chunkEnd)

            if isBridge, let cp = targetCheckpoint {
                // BRIDGE: The safe central node that serves as a launch for the platform
                if isInsideChunk {
                    let bridgeNode = HoldNode(type: .solid)
                    bridgeNode.position = CGPoint(x: lanes[2], y: currentY)
                    bridgeNode.name = "hold_bridge"
                    bridgeNode.buildVisuals()
                    tag(bridgeNode, chunk: index)
                    containerNode.addChild(bridgeNode)
                }

                // CHECKPOINT: The golden rescue platform
                // We handle and place it separately to position it exactly at its fixed altitude
                if cp.1 >= chunkStart && cp.1 < chunkEnd {
                    spawnCheckpoint(at: cp.1, kingdomIndex: cp.0, chunkIndex: index)
                }

                // Advance currentY just beyond the checkpoint to start clean
                currentY = cp.1 + 85
                lastSafeLane = 2
                continue
            }

            // IF NOT A BRIDGE: Generate procedural node logic
            
            // Consumes RNG ticks to establish nodes and lanes
            let safeRoll = globalRng.nextInt(upperBound: 3) // for shifts of -1, 0, +1
            let countRoll = globalRng.nextUniform()
            
            let minSafe = max(0, lastSafeLane - 1)
            let maxSafe = min(laneCount - 1, lastSafeLane + 1)
            let safeLane = minSafe + (safeRoll % (maxSafe - minSafe + 1))

            let nodeCount: Int
            if progression < 0.15 {
                // Tutorial: almost always 1 node (forced path), sometimes 2
                nodeCount = countRoll < 0.8 ? 1 : 2
            } else if progression < 0.33 {
                // Inferno: mix of 1 and 2 nodes
                nodeCount = countRoll < 0.5 ? 1 : 2
            } else if progression < 0.66 {
                // Purgatorio: mostly 2 nodes (fork), rarely 1 or 3
                if countRoll < 0.2 { nodeCount = 1 }
                else if countRoll < 0.85 { nodeCount = 2 }
                else { nodeCount = 3 }
            } else {
                // Paradiso: double paths, sometimes triple (maximum chaos)
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
                // VERY IMPORTANT: We must consume text RNG regardless of whether we are inside visible chunk
                // or not. Otherwise the simulation breaks.
                let rollY      = CGFloat(globalRng.nextUniform())
                let rollX      = CGFloat(globalRng.nextUniform())
                let rollType   = CGFloat(globalRng.nextUniform())
                let rollEnemy  = CGFloat(globalRng.nextUniform())

                // Quick visual bypass if outside the current chunk
                if !isInsideChunk { continue } 
                
                let yJitter = (rollY - 0.5) * 16.0
                let xJitter = (rollX - 0.5) * 20.0
                
                let holdY = currentY + yJitter
                let xPos  = lanes[lane]
                let finalX = max(55, min(338, xPos + xJitter))

                var nodeType: PlatformType = .solid
                var spawnEnemy = false

                if lane == safeLane {
                    // SAFE LANE: No instant traps or enemies, max movement or bouncy
                    if progression > 0.5 {
                        if rollType < 0.2 { nodeType = .moving }
                        else if rollType < 0.3 { nodeType = .bouncy }
                    }
                } else {
                    // ALTERNATIVE LANES: Gradually more diabolical
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
                holdNode.kingdom = kingdomFor(progression: progression)
                holdNode.buildVisuals()
                tag(holdNode, chunk: index)
                containerNode.addChild(holdNode)

                if spawnEnemy {
                    let bug = GloomBugNode()
                    let enemyOffsetX: CGFloat = lane < 2 ? 35 : -35
                    bug.position = CGPoint(x: finalX + enemyOffsetX, y: holdY + 30)
                    bug.name = "enemy"
                    tag(bug, chunk: index)
                    containerNode.addChild(bug)
                }
                
                // ── SMOKE MIRROR: Spawn TarHound (Late Inferno + Purgatorio) ──
                let currentKingdom = kingdomFor(progression: progression)
                if lane != safeLane && nodeType == .solid {
                    // TarHound: only in non-safe lanes, with increasing probability
                    if (currentKingdom == .inferno && progression > 0.2) || currentKingdom == .purgatorio {
                        // Consume an extra RNG roll for TarHound decision
                        let tarRoll = CGFloat(globalRng.nextUniform())
                        let tarChance: CGFloat = currentKingdom == .purgatorio ? 0.08 : 0.04
                        if tarRoll < tarChance {
                            let hound = TarHoundNode()
                            hound.position = CGPoint(x: finalX, y: holdY + 60)
                            tag(hound, chunk: index)
                            containerNode.addChild(hound)
                        }
                    }
                }
                
                // ── SMOKE MIRROR: Spawn ToxicCloud (Purgatorio + Paradiso) ──
                if lane == safeLane && (currentKingdom == .purgatorio || currentKingdom == .paradiso) {
                    let cloudRoll = CGFloat(globalRng.nextUniform())
                    let cloudChance: CGFloat = currentKingdom == .paradiso ? 0.12 : 0.06
                    if cloudRoll < cloudChance {
                        let cloud = ToxicCloudNode(radius: 55)
                        cloud.position = CGPoint(x: finalX + 40, y: holdY + 40)
                        cloud.configureForKingdom(currentKingdom)
                        tag(cloud, chunk: index)
                        containerNode.addChild(cloud)
                    }
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

    // MARK: - Checkpoint (Visual & Physical)

    private func spawnCheckpoint(at altitude: CGFloat, kingdomIndex: Int, chunkIndex: Int) {
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
        hold.buildVisuals()
        tag(hold, chunk: chunkIndex)
        containerNode.addChild(hold)

        let label = SKLabelNode(fontNamed: "Avenir-Heavy")
        let altInt = Int(altitude)
        if altInt == 0 {
            label.text = "— THE ASH ABYSS —"
        } else if altInt == Int(GameConstants.Kingdoms.infernoEnd * GameConstants.World.totalWorldHeight) {
            label.text = "— THE PURGATORY MIST —"
        } else if altInt == Int(GameConstants.Kingdoms.purgatorioEnd * GameConstants.World.totalWorldHeight) {
            label.text = "— THE PURE PEAK —"
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
