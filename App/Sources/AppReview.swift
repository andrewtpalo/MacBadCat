import UIKit
import StoreKit

/// Fires the native "rate this app" prompt. Apple rate-limits this system-wide, so it's safe
/// to call — the OS decides whether to actually show it. We still gate to once/win in GameData.
enum AppReview {
    static func request() {
        if #available(iOS 14.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                return
            }
        }
        SKStoreReviewController.requestReview()
    }
}
