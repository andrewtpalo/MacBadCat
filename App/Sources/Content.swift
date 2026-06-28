import UIKit

struct Breakable {
    let id: String
    let name: String
    let kind: String        // visual style: vase, plant, cup, books, tp, lamp, glass, fruit, clock, perfume, duck, keyboard, mug, plate, pen ...
    let chaos: Int          // mischief points
    let energyCost: Int
    let coins: Int
    /// horizontal position 0..1 across the room, and height above floor 0..1
    let x: CGFloat
    let top: CGFloat
}

struct RoomDef {
    let id: String
    let name: String
    let emoji: String
    let unlockCost: Int
    let wall: UIColor
    let days: Int
    let breakables: [Breakable]
}

enum ShopKind { case skin, upgrade }

struct ShopItem {
    let id: String
    let name: String
    let blurb: String
    let cost: Int           // base cost; for upgrades multiplied per level
    let kind: ShopKind
    let maxLevel: Int       // 1 for skins
}

enum Content {

    static let rooms: [RoomDef] = [
        RoomDef(id: "living", name: "Living Room", emoji: "🛋️", unlockCost: 0,
                wall: UIColor(hex: 0xB6BFA6), days: 5, breakables: [
            Breakable(id: "vase",  name: "the good vase",  kind: "vase",  chaos: 16, energyCost: 22, coins: 14, x: 0.10, top: 0.42),
            Breakable(id: "plant", name: "the fern",       kind: "plant", chaos: 12, energyCost: 18, coins: 10, x: 0.30, top: 0.02),
            Breakable(id: "cup",   name: "their coffee",   kind: "cup",   chaos: 9,  energyCost: 14, coins: 8,  x: 0.46, top: 0.18),
            Breakable(id: "books", name: "the books",      kind: "books", chaos: 7,  energyCost: 12, coins: 6,  x: 0.58, top: 0.40),
            Breakable(id: "tp",    name: "the toilet roll",kind: "tp",    chaos: 20, energyCost: 20, coins: 18, x: 0.70, top: 0.06),
            Breakable(id: "lamp",  name: "the lamp",       kind: "lamp",  chaos: 14, energyCost: 18, coins: 12, x: 0.74, top: 0.22),
        ]),
        RoomDef(id: "kitchen", name: "Kitchen", emoji: "🍽️", unlockCost: 150,
                wall: UIColor(hex: 0xC9B79A), days: 5, breakables: [
            Breakable(id: "glass", name: "a wine glass",   kind: "glass", chaos: 18, energyCost: 20, coins: 16, x: 0.12, top: 0.30),
            Breakable(id: "fruit", name: "the fruit bowl", kind: "fruit", chaos: 11, energyCost: 16, coins: 9,  x: 0.30, top: 0.20),
            Breakable(id: "plate", name: "a plate stack",  kind: "plate", chaos: 15, energyCost: 18, coins: 13, x: 0.46, top: 0.22),
            Breakable(id: "magnet",name: "fridge magnets", kind: "books", chaos: 6,  energyCost: 10, coins: 5,  x: 0.60, top: 0.34),
            Breakable(id: "spice", name: "the spice jar",  kind: "perfume",chaos: 13, energyCost: 16, coins: 11, x: 0.72, top: 0.24),
            Breakable(id: "mug",   name: "the morning mug",kind: "mug",   chaos: 10, energyCost: 14, coins: 9,  x: 0.84, top: 0.18),
        ]),
        RoomDef(id: "bedroom", name: "Bedroom", emoji: "🛏️", unlockCost: 350,
                wall: UIColor(hex: 0xA7AEC2), days: 6, breakables: [
            Breakable(id: "clock", name: "the alarm clock",kind: "clock", chaos: 17, energyCost: 18, coins: 15, x: 0.12, top: 0.22),
            Breakable(id: "jewel", name: "the jewelry",    kind: "glass", chaos: 22, energyCost: 22, coins: 22, x: 0.28, top: 0.26),
            Breakable(id: "tissue",name: "the tissues",    kind: "tp",    chaos: 14, energyCost: 16, coins: 11, x: 0.44, top: 0.20),
            Breakable(id: "perf",  name: "the perfume",    kind: "perfume",chaos: 16, energyCost: 18, coins: 14, x: 0.60, top: 0.24),
            Breakable(id: "lamp2", name: "the night lamp", kind: "lamp",  chaos: 12, energyCost: 16, coins: 10, x: 0.74, top: 0.22),
            Breakable(id: "book2", name: "the diary",      kind: "books", chaos: 9,  energyCost: 12, coins: 8,  x: 0.86, top: 0.36),
        ]),
        RoomDef(id: "bathroom", name: "Bathroom", emoji: "🛁", unlockCost: 600,
                wall: UIColor(hex: 0x9EC2C6), days: 6, breakables: [
            Breakable(id: "tp2",   name: "the toilet roll",kind: "tp",    chaos: 20, energyCost: 18, coins: 18, x: 0.12, top: 0.10),
            Breakable(id: "duck",  name: "the rubber duck",kind: "duck",  chaos: 8,  energyCost: 10, coins: 7,  x: 0.30, top: 0.04),
            Breakable(id: "shamp", name: "the shampoo",    kind: "perfume",chaos: 13, energyCost: 14, coins: 11, x: 0.46, top: 0.22),
            Breakable(id: "tooth", name: "the toothbrushes",kind:"cup",   chaos: 10, energyCost: 12, coins: 8,  x: 0.60, top: 0.24),
            Breakable(id: "mirror",name: "the mirror",     kind: "glass", chaos: 24, energyCost: 24, coins: 24, x: 0.74, top: 0.30),
            Breakable(id: "towel", name: "the towels",     kind: "books", chaos: 9,  energyCost: 12, coins: 8,  x: 0.86, top: 0.20),
        ]),
        RoomDef(id: "office", name: "Home Office", emoji: "💻", unlockCost: 900,
                wall: UIColor(hex: 0xB0A8C2), days: 7, breakables: [
            Breakable(id: "kbd",   name: "the keyboard",   kind: "keyboard",chaos: 15, energyCost: 16, coins: 13, x: 0.14, top: 0.18),
            Breakable(id: "omug",  name: "the work mug",   kind: "mug",   chaos: 11, energyCost: 14, coins: 9,  x: 0.30, top: 0.20),
            Breakable(id: "sticky",name: "the sticky notes",kind:"books", chaos: 7,  energyCost: 10, coins: 6,  x: 0.44, top: 0.34),
            Breakable(id: "pen",   name: "the pen cup",    kind: "cup",   chaos: 9,  energyCost: 12, coins: 8,  x: 0.58, top: 0.22),
            Breakable(id: "head",  name: "the headphones", kind: "duck",  chaos: 14, energyCost: 16, coins: 12, x: 0.72, top: 0.10),
            Breakable(id: "mon",   name: "the monitor",    kind: "lamp",  chaos: 26, energyCost: 26, coins: 26, x: 0.84, top: 0.28),
        ]),
    ]

    static func room(_ id: String) -> RoomDef { rooms.first { $0.id == id } ?? rooms[0] }
    static func roomIndex(_ id: String) -> Int { rooms.firstIndex { $0.id == id } ?? 0 }

    // MARK: shop
    static let skins: [ShopItem] = [
        ShopItem(id: "skin_default", name: "Just Mac",     blurb: "The classic flame point.",       cost: 0,   kind: .skin, maxLevel: 1),
        ShopItem(id: "skin_mask",    name: "Bandit Mask",  blurb: "Looks guilty. Is guilty.",        cost: 120, kind: .skin, maxLevel: 1),
        ShopItem(id: "skin_bow",     name: "Tiny Bowtie",  blurb: "A gentleman of crime.",           cost: 180, kind: .skin, maxLevel: 1),
        ShopItem(id: "skin_glasses", name: "Cool Shades",  blurb: "Deal with it.",                   cost: 250, kind: .skin, maxLevel: 1),
        ShopItem(id: "skin_crown",   name: "Tiny Crown",   blurb: "King of the household.",          cost: 500, kind: .skin, maxLevel: 1),
    ]

    static let upgrades: [ShopItem] = [
        ShopItem(id: "up_paws",   name: "Soft Paws",   blurb: "Crashes are quieter when overheard.", cost: 120, kind: .upgrade, maxLevel: 3),
        ShopItem(id: "up_belly",  name: "Big Belly",   blurb: "+20 max energy per level.",           cost: 150, kind: .upgrade, maxLevel: 3),
        ShopItem(id: "up_nap",    name: "Power Nap",   blurb: "Sunbeam naps refuel faster.",         cost: 130, kind: .upgrade, maxLevel: 3),
        ShopItem(id: "up_charm",  name: "Pure Charm",  blurb: "Looking innocent drops suspicion faster.", cost: 160, kind: .upgrade, maxLevel: 3),
        ShopItem(id: "up_value",  name: "Show Off",    blurb: "+15% mischief & coins per break.",    cost: 220, kind: .upgrade, maxLevel: 2),
    ]

    // MARK: per-day difficulty
    /// Returns (targetChaos, dayLength seconds, vigilance 0..1)
    static func dayConfig(room: String, day: Int) -> (target: Int, length: Double, vigilance: Double) {
        let r = Double(roomIndex(room))
        let d = Double(day)
        let target = Int(28 + r * 10 + d * 14)
        let length = max(70, 120 - d * 4)
        let vigilance = min(0.82, 0.46 + r * 0.05 + d * 0.04)
        return (target, length, vigilance)
    }
}
