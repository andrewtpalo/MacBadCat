import SpriteKit
import UIKit

// MARK: - Main Menu
final class MenuScene: BaseScene {
    override func build() {
        addRoomBackground(Palette.wall)
        // ambient floor strip
        let floor = SKSpriteNode(color: Palette.wood, size: CGSize(width: size.width, height: size.height * 0.22))
        floor.anchorPoint = .zero; floor.position = .zero; floor.zPosition = -90; addChild(floor)

        let title = makeLabel("Bad Cat", size: 56, color: Palette.ink, weight: .black)
        title.position = CGPoint(x: size.width/2, y: size.height - topInset - 90)
        addChild(title)
        let sub = makeLabel("STARRING MAC", size: 15, color: Palette.inkSoft, weight: .bold)
        sub.position = CGPoint(x: size.width/2, y: size.height - topInset - 120)
        addChild(sub)

        // Mac preview
        let mac = CatNode()
        mac.baseScale = 2.0
        mac.position = CGPoint(x: size.width/2, y: size.height * 0.40)
        addChild(mac)

        let playW = min(260, size.width - 80)
        let play = ButtonNode("Play", size: CGSize(width: playW, height: 60), fill: Palette.ink, fontSize: 22)
        play.position = CGPoint(x: size.width/2, y: size.height * 0.26)
        play.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: RoomSelectScene(size: s.size)) }
        addChild(play)

        let shop = ButtonNode("Shop", size: CGSize(width: playW, height: 52), fill: Palette.flame, fontSize: 20)
        shop.position = CGPoint(x: size.width/2, y: size.height * 0.26 - 72)
        shop.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: ShopScene(size: s.size)) }
        addChild(shop)

        _ = addCoinChip()
        addSoundToggle()
    }

    private func addSoundToggle() {
        let b = ButtonNode(GameData.shared.soundOn ? "♪" : "♪̸", size: CGSize(width: 40, height: 40),
                           fill: Palette.panel, textColor: Palette.ink, fontSize: 20)
        b.position = CGPoint(x: 34, y: size.height - topInset - 26)
        b.onTap = {
            GameData.shared.soundOn.toggle(); GameData.shared.save()
            b.setTitle(GameData.shared.soundOn ? "♪" : "♪̸")
        }
        addChild(b)
    }
}

// MARK: - Room Select
final class RoomSelectScene: BaseScene {
    private var coinLabel: SKLabelNode?

    override func build() {
        addRoomBackground(Palette.wall)
        addBackButton { [weak self] in guard let s = self else { return }
            s.navigate(to: MenuScene(size: s.size), .push(with: .right, duration: 0.32)) }
        coinLabel = addCoinChip()
        let title = makeLabel("Pick a room", size: 26, color: Palette.ink, weight: .heavy)
        title.position = CGPoint(x: size.width/2, y: size.height - topInset - 64)
        addChild(title)
        layoutRooms()
    }

    private func layoutRooms() {
        children.filter { $0.name == "roomcard" }.forEach { $0.removeFromParent() }
        let cardW = size.width - 44
        let cardH: CGFloat = 92
        var y = size.height - topInset - 120
        for room in Content.rooms {
            let card = SKNode(); card.name = "roomcard"
            let panel = roundedPanel(CGSize(width: cardW, height: cardH), fill: Palette.panel, corner: 20)
            card.addChild(panel)
            let unlocked = GameData.shared.roomUnlocked(room.id)

            let emoji = makeLabel(room.emoji, size: 34); emoji.position = CGPoint(x: -cardW/2 + 38, y: 4); card.addChild(emoji)
            let nm = makeLabel(room.name, size: 19, color: Palette.ink, weight: .heavy, h: .left)
            nm.position = CGPoint(x: -cardW/2 + 70, y: 14); card.addChild(nm)
            let starsTotal = GameData.shared.totalStars(room: room.id, days: room.days)
            let prog = makeLabel(unlocked ? "★ \(starsTotal)/\(room.days * 3)   ·   \(room.days) days"
                                          : "Locked", size: 13, color: Palette.inkSoft, weight: .bold, h: .left)
            prog.position = CGPoint(x: -cardW/2 + 70, y: -12); card.addChild(prog)

            if unlocked {
                let enter = ButtonNode("Enter", size: CGSize(width: 86, height: 44), fill: Palette.ink, fontSize: 16)
                enter.position = CGPoint(x: cardW/2 - 60, y: 0)
                enter.onTap = { [weak self] in guard let s = self else { return }
                    s.navigate(to: LevelSelectScene(size: s.size, roomId: room.id)) }
                card.addChild(enter)
            } else {
                let canAfford = GameData.shared.coins >= room.unlockCost
                let unlock = ButtonNode("🔒 \(room.unlockCost)", size: CGSize(width: 100, height: 44),
                                        fill: canAfford ? Palette.flame : Palette.inkSoft, fontSize: 15)
                unlock.position = CGPoint(x: cardW/2 - 64, y: 0)
                unlock.onTap = { [weak self] in
                    guard let s = self else { return }
                    if GameData.shared.spend(room.unlockCost) {
                        GameData.shared.unlockedRooms.insert(room.id); GameData.shared.save()
                        SFX.coin(); s.coinLabel?.text = "\(GameData.shared.coins)"; s.layoutRooms()
                    }
                }
                card.addChild(unlock)
            }
            card.position = CGPoint(x: size.width/2, y: y)
            addChild(card)
            y -= cardH + 12
        }
    }
}

// MARK: - Level (Day) Select
final class LevelSelectScene: BaseScene {
    let roomId: String
    init(size: CGSize, roomId: String) { self.roomId = roomId; super.init(size: size) }
    required init?(coder: NSCoder) { fatalError() }

    override func build() {
        let room = Content.room(roomId)
        addRoomBackground(room.wall)
        addBackButton { [weak self] in guard let s = self else { return }
            s.navigate(to: RoomSelectScene(size: s.size), .push(with: .right, duration: 0.32)) }
        _ = addCoinChip()
        let title = makeLabel("\(room.emoji) \(room.name)", size: 24, color: Palette.ink, weight: .heavy)
        title.position = CGPoint(x: size.width/2, y: size.height - topInset - 64)
        addChild(title)
        let hint = makeLabel("Cause mayhem before bedtime", size: 13, color: Palette.inkSoft, weight: .bold)
        hint.position = CGPoint(x: size.width/2, y: size.height - topInset - 90)
        addChild(hint)

        let cols = 3
        let gap: CGFloat = 14
        let cell = (size.width - 44 - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let startY = size.height - topInset - 140
        for day in 0..<room.days {
            let r = day / cols, c = day % cols
            let x = 22 + cell/2 + CGFloat(c) * (cell + gap)
            let y = startY - CGFloat(r) * (cell + gap)
            let unlocked = GameData.shared.dayUnlocked(room: roomId, day: day)
            let stars = GameData.shared.stars(room: roomId, day: day)
            let card = SKNode()
            let panel = roundedPanel(CGSize(width: cell, height: cell),
                                     fill: unlocked ? Palette.panel : UIColor(hex: 0xFBF6EE, alpha: 0.5), corner: 18)
            card.addChild(panel)
            if unlocked {
                let num = makeLabel("\(day + 1)", size: 30, color: Palette.ink, weight: .black)
                num.position = CGPoint(x: 0, y: 8); card.addChild(num)
                let st = makeLabel(String(repeating: "★", count: stars) + String(repeating: "·", count: 3 - stars),
                                   size: 14, color: Palette.gold, weight: .bold)
                st.position = CGPoint(x: 0, y: -22); card.addChild(st)
            } else {
                let lock = makeLabel("🔒", size: 24, color: Palette.inkSoft); card.addChild(lock)
            }
            card.position = CGPoint(x: x, y: y)
            addChild(card)
            if unlocked {
                let btn = ButtonNode("", size: CGSize(width: cell, height: cell), fill: .clear, fontSize: 1, shadow: false)
                btn.position = CGPoint(x: x, y: y)
                btn.onTap = { [weak self] in guard let s = self else { return }
                    s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: day), .fade(withDuration: 0.35)) }
                addChild(btn)
            }
        }
    }
}

// MARK: - Shop
final class ShopScene: BaseScene {
    private var category: ShopKind = .skin
    private var coinLabel: SKLabelNode?
    private var listRoot = SKNode()

    override func build() {
        addRoomBackground(Palette.wall)
        addBackButton { [weak self] in guard let s = self else { return }
            s.navigate(to: MenuScene(size: s.size), .push(with: .right, duration: 0.32)) }
        coinLabel = addCoinChip()
        let title = makeLabel("Shop", size: 26, color: Palette.ink, weight: .heavy)
        title.position = CGPoint(x: size.width/2, y: size.height - topInset - 64)
        addChild(title)

        // category toggle
        let toggleY = size.height - topInset - 104
        let skinsBtn = ButtonNode("Looks", size: CGSize(width: 120, height: 40), fill: Palette.ink, fontSize: 16)
        skinsBtn.position = CGPoint(x: size.width/2 - 66, y: toggleY)
        skinsBtn.onTap = { [weak self] in self?.category = .skin; self?.rebuild() }
        addChild(skinsBtn)
        let upBtn = ButtonNode("Upgrades", size: CGSize(width: 120, height: 40), fill: Palette.flame, fontSize: 16)
        upBtn.position = CGPoint(x: size.width/2 + 66, y: toggleY)
        upBtn.onTap = { [weak self] in self?.category = .upgrade; self?.rebuild() }
        addChild(upBtn)

        addChild(listRoot)
        rebuild()
    }

    private func rebuild() {
        listRoot.removeAllChildren()
        coinLabel?.text = "\(GameData.shared.coins)"
        let items = category == .skin ? Content.skins : Content.upgrades
        let cardW = size.width - 44
        let cardH: CGFloat = 78
        var y = size.height - topInset - 156
        for item in items {
            listRoot.addChild(makeRow(item, width: cardW, height: cardH, y: y))
            y -= cardH + 12
        }
    }

    private func makeRow(_ item: ShopItem, width: CGFloat, height: CGFloat, y: CGFloat) -> SKNode {
        let card = SKNode()
        card.addChild(roundedPanel(CGSize(width: width, height: height), fill: Palette.panel, corner: 18))
        let data = GameData.shared

        let nm = makeLabel(item.name, size: 17, color: Palette.ink, weight: .heavy, h: .left)
        nm.position = CGPoint(x: -width/2 + 18, y: 14); card.addChild(nm)
        let blurb = makeLabel(item.blurb, size: 12, color: Palette.inkSoft, weight: .regular, h: .left)
        blurb.position = CGPoint(x: -width/2 + 18, y: -10); card.addChild(blurb)

        if item.kind == .skin {
            let owned = data.owns(item.id)
            let equipped = data.equippedSkin == item.id
            if equipped {
                let tag = makeLabel("Equipped", size: 14, color: Palette.good, weight: .heavy)
                tag.position = CGPoint(x: width/2 - 56, y: 0); card.addChild(tag)
            } else if owned {
                let b = ButtonNode("Equip", size: CGSize(width: 86, height: 42), fill: Palette.ink, fontSize: 15)
                b.position = CGPoint(x: width/2 - 60, y: 0)
                b.onTap = { [weak self] in data.equippedSkin = item.id; data.save(); self?.rebuild() }
                card.addChild(b)
            } else {
                let afford = data.coins >= item.cost
                let b = ButtonNode("🪙 \(item.cost)", size: CGSize(width: 96, height: 42),
                                   fill: afford ? Palette.flame : Palette.inkSoft, fontSize: 15)
                b.position = CGPoint(x: width/2 - 64, y: 0)
                b.onTap = { [weak self] in
                    if data.spend(item.cost) { data.ownedItems.insert(item.id); data.equippedSkin = item.id; data.save(); SFX.coin(); self?.rebuild() }
                }
                card.addChild(b)
            }
        } else {
            let lvl = data.upgradeLevel(item.id)
            let maxed = lvl >= item.maxLevel
            let lvlTag = makeLabel("Lv \(lvl)/\(item.maxLevel)", size: 12, color: Palette.flameDeep, weight: .heavy, h: .left)
            lvlTag.position = CGPoint(x: -width/2 + 18, y: -28); card.addChild(lvlTag)
            if maxed {
                let tag = makeLabel("MAX", size: 14, color: Palette.good, weight: .heavy)
                tag.position = CGPoint(x: width/2 - 50, y: 0); card.addChild(tag)
            } else {
                let cost = item.cost * (lvl + 1)
                let afford = data.coins >= cost
                let b = ButtonNode("🪙 \(cost)", size: CGSize(width: 96, height: 42),
                                   fill: afford ? Palette.flame : Palette.inkSoft, fontSize: 15)
                b.position = CGPoint(x: width/2 - 64, y: 0)
                b.onTap = { [weak self] in
                    if data.spend(cost) { data.upgradeLevels[item.id] = lvl + 1; data.save(); SFX.coin(); self?.rebuild() }
                }
                card.addChild(b)
            }
        }
        card.position = CGPoint(x: size.width/2, y: y)
        return card
    }
}
