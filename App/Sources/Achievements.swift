import Foundation

struct Achievement {
    let id: String
    let name: String
    let blurb: String
    let event: String     // progress counter key in GameData.achProgress
    let target: Int
    let reward: Int       // coins granted on unlock
}

enum Achievements {
    static let all: [Achievement] = [
        Achievement(id: "breaks10",  name: "Warm-Up Wrecker",  blurb: "Break 10 things",             event: "break",    target: 10,  reward: 40),
        Achievement(id: "breaks100", name: "Certified Menace", blurb: "Break 100 things",            event: "break",    target: 100, reward: 200),
        Achievement(id: "combo3",    name: "Chain Reaction",   blurb: "Land a ×3 combo",             event: "combo3",   target: 1,   reward: 60),
        Achievement(id: "summit",    name: "Top of the World", blurb: "Reach the highest shelf",     event: "summit",   target: 1,   reward: 60),
        Achievement(id: "loot5",     name: "Treasure Hunter",  blurb: "Open 5 loot chests",          event: "loot",     target: 5,   reward: 80),
        Achievement(id: "ghost3",    name: "Now You See Me",   blurb: "Use Ghost Mode 3 times",      event: "ghost",    target: 3,   reward: 80),
        Achievement(id: "threestar5",name: "Overachiever",     blurb: "Earn ★★★ on 5 days",          event: "threestar",target: 5,   reward: 120),
        Achievement(id: "busted10",  name: "Repeat Offender",  blurb: "Get busted 10 times",         event: "busted",   target: 10,  reward: 50),
        Achievement(id: "pets50",    name: "Best Friends",     blurb: "Pet Mac 50 times",            event: "pet",      target: 50,  reward: 80),
        Achievement(id: "zoomies",   name: "ZOOMIES!",         blurb: "Find the zoomies easter egg", event: "zoomies",  target: 1,   reward: 40),
        Achievement(id: "streak7",   name: "Creature of Habit",blurb: "7-day login streak",          event: "streak",   target: 7,   reward: 150),
    ]

    static func progress(_ a: Achievement) -> Int {
        min(GameData.shared.achProgress[a.event] ?? 0, a.target)
    }
    static func isUnlocked(_ a: Achievement) -> Bool {
        GameData.shared.achUnlocked.contains(a.id)
    }

    /// Increment an event counter; returns any achievements newly unlocked by it.
    @discardableResult
    static func record(_ event: String, count: Int = 1) -> [Achievement] {
        let d = GameData.shared
        d.achProgress[event] = (d.achProgress[event] ?? 0) + count
        return settle(event: event)
    }

    /// Set an event counter to a high-water value (e.g. streak length).
    @discardableResult
    static func set(_ event: String, to value: Int) -> [Achievement] {
        let d = GameData.shared
        d.achProgress[event] = max(d.achProgress[event] ?? 0, value)
        return settle(event: event)
    }

    private static func settle(event: String) -> [Achievement] {
        let d = GameData.shared
        var unlocked: [Achievement] = []
        for a in all where a.event == event && !d.achUnlocked.contains(a.id) {
            if (d.achProgress[event] ?? 0) >= a.target {
                d.achUnlocked.insert(a.id)
                d.coins += a.reward
                unlocked.append(a)
            }
        }
        d.save()
        return unlocked
    }
}
