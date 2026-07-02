import Foundation

final class GameData: Codable {
    static let shared: GameData = GameData.load()

    var coins: Int = 0
    var ownedItems: Set<String> = ["skin_default"]
    var equippedSkin: String = "skin_default"
    var upgradeLevels: [String: Int] = [:]     // upgrade id -> level
    var unlockedRooms: Set<String> = ["living"]
    var dayStars: [String: Int] = [:]          // "roomId:dayIndex" -> stars (0...3)
    var soundOn: Bool = true
    var hapticsOn: Bool = true
    var lastRewardDay: Int = 0                  // days since 1970 of last claimed daily reward
    var rewardStreak: Int = 0
    var ratingPrompted: Bool = false            // asked for an App Store rating already?
    var bestRampage: Int = 0                    // high score for endless mode (future)
    var equippedBreed: String = "breed_flame"
    var adsRemoved: Bool = false                // "Remove Ads" IAP purchased
    var achProgress: [String: Int] = [:]        // achievement event -> count
    var achUnlocked: Set<String> = []           // unlocked achievement ids
    var petsTotal: Int = 0                      // lifetime pets in Mac's Room
    var lastCareDay: Int = 0                    // daily reset for bond/treats
    var bondToday: Int = 0
    var treatsToday: Int = 0
    var bondRewardClaimed: Bool = false

    enum CodingKeys: String, CodingKey {
        case coins, ownedItems, equippedSkin, upgradeLevels, unlockedRooms, dayStars, soundOn
        case hapticsOn, lastRewardDay, rewardStreak, ratingPrompted, bestRampage
        case equippedBreed, adsRemoved, achProgress, achUnlocked
        case petsTotal, lastCareDay, bondToday, treatsToday, bondRewardClaimed
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins        = (try? c.decode(Int.self, forKey: .coins)) ?? 0
        ownedItems   = (try? c.decode(Set<String>.self, forKey: .ownedItems)) ?? ["skin_default"]
        equippedSkin = (try? c.decode(String.self, forKey: .equippedSkin)) ?? "skin_default"
        upgradeLevels = (try? c.decode([String: Int].self, forKey: .upgradeLevels)) ?? [:]
        unlockedRooms = (try? c.decode(Set<String>.self, forKey: .unlockedRooms)) ?? ["living"]
        dayStars     = (try? c.decode([String: Int].self, forKey: .dayStars)) ?? [:]
        soundOn      = (try? c.decode(Bool.self, forKey: .soundOn)) ?? true
        hapticsOn    = (try? c.decode(Bool.self, forKey: .hapticsOn)) ?? true
        lastRewardDay = (try? c.decode(Int.self, forKey: .lastRewardDay)) ?? 0
        rewardStreak = (try? c.decode(Int.self, forKey: .rewardStreak)) ?? 0
        ratingPrompted = (try? c.decode(Bool.self, forKey: .ratingPrompted)) ?? false
        bestRampage  = (try? c.decode(Int.self, forKey: .bestRampage)) ?? 0
        equippedBreed = (try? c.decode(String.self, forKey: .equippedBreed)) ?? "breed_flame"
        adsRemoved   = (try? c.decode(Bool.self, forKey: .adsRemoved)) ?? false
        achProgress  = (try? c.decode([String: Int].self, forKey: .achProgress)) ?? [:]
        achUnlocked  = (try? c.decode(Set<String>.self, forKey: .achUnlocked)) ?? []
        petsTotal    = (try? c.decode(Int.self, forKey: .petsTotal)) ?? 0
        lastCareDay  = (try? c.decode(Int.self, forKey: .lastCareDay)) ?? 0
        bondToday    = (try? c.decode(Int.self, forKey: .bondToday)) ?? 0
        treatsToday  = (try? c.decode(Int.self, forKey: .treatsToday)) ?? 0
        bondRewardClaimed = (try? c.decode(Bool.self, forKey: .bondRewardClaimed)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coins, forKey: .coins)
        try c.encode(ownedItems, forKey: .ownedItems)
        try c.encode(equippedSkin, forKey: .equippedSkin)
        try c.encode(upgradeLevels, forKey: .upgradeLevels)
        try c.encode(unlockedRooms, forKey: .unlockedRooms)
        try c.encode(dayStars, forKey: .dayStars)
        try c.encode(soundOn, forKey: .soundOn)
        try c.encode(hapticsOn, forKey: .hapticsOn)
        try c.encode(lastRewardDay, forKey: .lastRewardDay)
        try c.encode(rewardStreak, forKey: .rewardStreak)
        try c.encode(ratingPrompted, forKey: .ratingPrompted)
        try c.encode(bestRampage, forKey: .bestRampage)
        try c.encode(equippedBreed, forKey: .equippedBreed)
        try c.encode(adsRemoved, forKey: .adsRemoved)
        try c.encode(achProgress, forKey: .achProgress)
        try c.encode(achUnlocked, forKey: .achUnlocked)
        try c.encode(petsTotal, forKey: .petsTotal)
        try c.encode(lastCareDay, forKey: .lastCareDay)
        try c.encode(bondToday, forKey: .bondToday)
        try c.encode(treatsToday, forKey: .treatsToday)
        try c.encode(bondRewardClaimed, forKey: .bondRewardClaimed)
    }

    /// Resets the Mac's-Room daily counters when the calendar day rolls over.
    func refreshCareDay() {
        let today = Int(Date().timeIntervalSince1970 / 86400)
        if today != lastCareDay {
            lastCareDay = today
            bondToday = 0; treatsToday = 0; bondRewardClaimed = false
            save()
        }
    }

    // MARK: daily reward
    /// Returns (claimable, streakIfClaimed, coinRewardIfClaimed).
    func dailyRewardStatus() -> (claimable: Bool, streak: Int, reward: Int) {
        let today = Int(Date().timeIntervalSince1970 / 86400)
        guard today > lastRewardDay else { return (false, rewardStreak, 0) }
        let continues = (today - lastRewardDay) == 1
        let streak = continues ? rewardStreak + 1 : 1
        let reward = 40 + min(streak, 7) * 20        // 60 → up to 180, caps at day 7
        return (true, streak, reward)
    }
    @discardableResult
    func claimDailyReward() -> Int {
        let (claimable, streak, reward) = dailyRewardStatus()
        guard claimable else { return 0 }
        let today = Int(Date().timeIntervalSince1970 / 86400)
        lastRewardDay = today
        rewardStreak = streak
        coins += reward
        save()
        return reward
    }

    // MARK: persistence
    private static let key = "macbadcat.save.v1"

    static func load() -> GameData {
        debugCheckpoint("GameData.load:start")
        if let data = UserDefaults.standard.data(forKey: key) {
            if let decoded = try? JSONDecoder().decode(GameData.self, from: data) {
                debugCheckpoint("GameData.load:decoded")
                return decoded
            } else {
                debugCheckpoint("GameData.load:decodeFailed")
            }
        } else {
            debugCheckpoint("GameData.load:noData")
        }
        debugCheckpoint("GameData.load:default")
        return GameData()
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: GameData.key)
        }
    }

    // MARK: helpers
    func upgradeLevel(_ id: String) -> Int { upgradeLevels[id] ?? 0 }
    func owns(_ id: String) -> Bool { ownedItems.contains(id) }
    func roomUnlocked(_ id: String) -> Bool { unlockedRooms.contains(id) }
    func stars(room: String, day: Int) -> Int { dayStars["\(room):\(day)"] ?? 0 }

    func setStars(room: String, day: Int, value: Int) {
        let k = "\(room):\(day)"
        if value > (dayStars[k] ?? 0) { dayStars[k] = value }
    }
    func dayUnlocked(room: String, day: Int) -> Bool {
        day == 0 || stars(room: room, day: day - 1) > 0
    }
    func totalStars(room: String, days: Int) -> Int {
        (0..<days).reduce(0) { $0 + stars(room: room, day: $1) }
    }

    func addCoins(_ n: Int) { coins += n; save() }
    func spend(_ n: Int) -> Bool {
        guard coins >= n else { return false }
        coins -= n; save(); return true
    }
}
