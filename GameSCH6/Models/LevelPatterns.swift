import CoreGraphics

// MARK: - Platform Type

enum PlatformType: CaseIterable {
    case solid       // Pietra stabile: sempre sicura
    case crumbling   // Si sbriciola dopo 1.5s: devi muoverti in fretta
    case sticky      // Rallenta la rotazione: ti intrappola
    case bouncy      // Ti respinge leggermente: timing diverso
    case moving      // Si muove lateralmente: richiede adattamento
    case cloud       // Scompare e riappare: finestra temporale
    case spike       // DANNO: non aggrappabile, stordisce per 0.5s
    case checkpoint  // Piattaforma dorata: punto di respawn
}

enum EnemyType {
    case gloomBug    // Nemico volante: stordisce al contatto
}
