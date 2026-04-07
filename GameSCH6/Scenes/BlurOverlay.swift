//
//  BlurOverlay.swift
//  GameSCH6
//
//  Created by Luca Pagano on 04/04/26.
//


import SpriteKit

// MARK: - Blur Overlay
//
// Simulates visual blur for bronchitis and critical health levels.
// Uses two combined techniques:
//   1. White vignette at the edges (strained eyes)
//   2. Semi-transparent central overlay that pulses (foggy vision)
//
// It is a child of the camera, so it follows the screen.

class BlurOverlay: SKNode {

    private var vignetteRings: [SKShapeNode] = []
    private var centerFog:     SKSpriteNode!
    private var scanlines:     [SKSpriteNode] = [] // Thin horizontal lines

    private let screenSize: CGSize

    // MARK: - Init

    init(screenSize: CGSize) {
        self.screenSize = screenSize
        super.init()
        zPosition = 490  // Below SmokeHaze (500) but above the game
        alpha = 0
        buildOverlay()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildOverlay() {
        // ── White vignette at the edges (5 rings) ──
        // Different from SmokeHaze which is black — this is milk-white
        // to simulate glare/loss of focus
        let ringCount = 5
        for i in 0..<ringCount {
            let t      = CGFloat(i) / CGFloat(ringCount)
            let inset  = screenSize.width * 0.12 * t
            let size   = CGSize(width:  screenSize.width  - inset,
                                height: screenSize.height - inset)
            let ring   = SKShapeNode(rectOf: size, cornerRadius: size.width * 0.25)
            ring.fillColor   = .clear
            ring.strokeColor = SKColor(white: 0.95, alpha: 0.06 * (1.0 - t))
            ring.lineWidth   = screenSize.width * 0.10
            ring.zPosition   = CGFloat(i)
            addChild(ring)
            vignetteRings.append(ring)
        }

        // ── Light central fog ──
        centerFog = SKSpriteNode(
            color: SKColor(white: 0.85, alpha: 1.0),
            size: screenSize)
        centerFog.blendMode = .alpha
        centerFog.alpha     = 0
        centerFog.zPosition = 10
        addChild(centerFog)

        // ── Thin horizontal scanlines ("fatigued vision" effect) ──
        // 6 lines spread horizontally
        let lineCount = 6
        for i in 0..<lineCount {
            let y = -screenSize.height / 2 + screenSize.height
                    * CGFloat(i) / CGFloat(lineCount)
            let line = SKSpriteNode(
                color: SKColor(white: 1.0, alpha: 0.03),
                size: CGSize(width: screenSize.width, height: 1.5))
            line.position  = CGPoint(x: 0, y: y)
            line.zPosition = 11
            addChild(line)
            scanlines.append(line)
        }
    }

    // MARK: - Update

    /// intensity: 0.0 = no effect, 1.0 = maximum
    func update(intensity: CGFloat) {
        // Global alpha of the node
        let targetAlpha = min(1.0, intensity * 1.2)
        alpha += (targetAlpha - alpha) * 0.08

        // Central fog — much thinner than the vignette
        let targetFog = intensity * 0.06
        centerFog.alpha += (targetFog - centerFog.alpha) * 0.05

        // Scanlines more visible at high intensity
        for line in scanlines {
            line.color = SKColor(white: 1.0, alpha: intensity * 0.05)
        }

        // Micro-movement of the scanlines (trembling vision)
        if intensity > 0.3 {
            for (i, line) in scanlines.enumerated() {
                let phase = CGFloat(i) * 1.1
                let drift = sin(CGFloat(CACurrentMediaTime()) * 2.0 + phase) * intensity * 0.8
                line.position.y += drift * 0.1
            }
        }
    }
}