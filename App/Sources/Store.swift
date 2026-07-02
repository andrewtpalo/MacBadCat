import Foundation
import StoreKit

/// In-app purchases via StoreKit 2.
///
/// IMPORTANT — to go live these product IDs must be created in App Store Connect
/// (Monetization → In-App Purchases) with matching identifiers, and the app's bundle ID
/// must be your real one. Until then `products` stays empty and the shop shows the
/// "store unavailable" row — everything else in the app works normally.
final class Store {
    static let shared = Store()

    enum ID {
        static let coinsSmall  = "com.example.macbadcat.coins.small"   // 500 coins
        static let coinsMedium = "com.example.macbadcat.coins.medium"  // 1500 coins
        static let coinsLarge  = "com.example.macbadcat.coins.large"   // 4000 coins
        static let removeAds   = "com.example.macbadcat.removeads"     // non-consumable
        static let all = [coinsSmall, coinsMedium, coinsLarge, removeAds]
    }

    static func coins(for id: String) -> Int {
        switch id {
        case ID.coinsSmall: return 500
        case ID.coinsMedium: return 1500
        case ID.coinsLarge: return 4000
        default: return 0
        }
    }

    private(set) var products: [Product] = []
    private(set) var loaded = false
    private var updatesTask: Task<Void, Never>?

    private init() {
        // Handle transactions that arrive outside a purchase flow (renewals, family sharing,
        // purchases finished after an app kill).
        updatesTask = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let t) = result {
                    self?.grant(t.productID)
                    await t.finish()
                }
            }
        }
    }

    func loadIfNeeded() async {
        guard !loaded else { return }
        loaded = true
        products = (try? await Product.products(for: ID.all)) ?? []
        // Re-apply non-consumable entitlements (e.g. Remove Ads after reinstall).
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == ID.removeAds {
                grant(ID.removeAds)
            }
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Returns true when the purchase completed and was granted.
    func purchase(_ id: String) async -> Bool {
        guard let product = product(id) else { return false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let t) = verification else { return false }
                grant(t.productID)
                await t.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch { return false }
    }

    func restore() async {
        try? await AppStore.sync()
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == ID.removeAds {
                grant(ID.removeAds)
            }
        }
    }

    private func grant(_ id: String) {
        DispatchQueue.main.async {
            if id == ID.removeAds {
                GameData.shared.adsRemoved = true
                GameData.shared.save()
            } else {
                let amount = Store.coins(for: id)
                if amount > 0 { GameData.shared.addCoins(amount) }
            }
        }
    }
}
