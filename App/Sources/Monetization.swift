import UIKit
import SpriteKit

/// Rewarded-ad seam. Real ad SDKs (e.g. Google AdMob) plug in behind `showRewarded`.
/// Until an SDK + ad-unit IDs are configured in the project, this grants the reward directly
/// so the whole flow is playable and testable end-to-end.
///
/// TO GO LIVE:
///   1. Add the AdMob SDK (Swift Package) and your App ID to Info.plist (GADApplicationIdentifier).
///   2. Load a GADRewardedAd; in showRewarded present it and call completion(true) only in the
///      userDidEarnReward callback, completion(false) on failure/dismiss-without-reward.
///   3. Add ATT (AppTrackingTransparency) prompt before requesting personalized ads.
enum Ads {
    static let usingRealAds = false

    static func showRewarded(from scene: SKScene?, reward: String, _ completion: @escaping (Bool) -> Void) {
        // Placeholder implementation — no network, always "grants".
        completion(true)
    }
}

/// Share sheet for a run result. Renders the current view to an image and presents the system
/// share sheet so players can post their chaos (free user acquisition).
enum ShareCard {
    static func present(from view: SKView?, caption: String) {
        guard let view = view, let root = view.window?.rootViewController else { return }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { _ in view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
        let items: [Any] = [caption, image]
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        root.present(vc, animated: true)
    }
}
