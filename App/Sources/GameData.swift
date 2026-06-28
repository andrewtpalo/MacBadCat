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

    enum CodingKeys: String, CodingKey {
        case coins, ownedItems, equippedSkin, upgradeLevels, unlockedRooms, dayStars, soundOn
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
