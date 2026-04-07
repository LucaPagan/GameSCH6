import CoreGraphics

// MARK: - Platform Type

enum PlatformType: CaseIterable {
    case solid       // Stable stone: always safe
    case crumbling   // Crumbles after 1.5s: you must move quickly
    case sticky      // Slows down rotation: traps you
    case bouncy      // Repels you slightly: different timing
    case moving      // Moves laterally: requires adaptation
    case cloud       // Disappears and reappears: time window
    case spike       // DAMAGE: cannot be grabbed, stuns for 0.5s
    case checkpoint  // Golden platform: respawn point
}

enum EnemyType {
    case gloomBug    // Flying enemy: stuns on contact
    case tarHound    // Tar Hound: chases the player's smoke trail
    case toxicCloud  // Toxic Cloud: slows down and drains stamina for smokers
}
