import UIKit

/// Tiny haptics wrapper. Generators are prepared lazily and reused so taps feel instant.
/// All calls respect the sound/feedback toggle in GameData.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()

    private static var on: Bool { GameData.shared.hapticsOn }

    static func tap()    { guard on else { return }; light.impactOccurred() }
    static func knock()  { guard on else { return }; medium.impactOccurred() }
    static func bigHit() { guard on else { return }; heavy.impactOccurred() }
    static func climb()  { guard on else { return }; rigid.impactOccurred(intensity: 0.6) }
    static func loot()   { guard on else { return }; notify.notificationOccurred(.success) }
    static func win()    { guard on else { return }; notify.notificationOccurred(.success) }
    static func caught() { guard on else { return }; notify.notificationOccurred(.error) }

    /// Call before a burst of feedback so the Taptic Engine is warm.
    static func prepare() {
        guard on else { return }
        light.prepare(); medium.prepare(); heavy.prepare()
    }
}
