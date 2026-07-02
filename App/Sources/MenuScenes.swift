import SpriteKit
import UIKit

// MARK: - Main Menu
final class MenuScene: BaseScene {
    private var coinChipLabel: SKLabelNode?

    override func build() {
        let W = size.width, H = size.height
        addRoomBackground(Palette.wall)

        // Floor + rug for depth.
        let floorH = H * 0.30
        let floor = SKSpriteNode(color: Palette.wood, size: CGSize(width: W, height: floorH))
        floor.anchorPoint = .zero; floor.position = .zero; floor.zPosition = -90; addChild(floor)
        let rug = SKShapeNode(ellipseOf: CGSize(width: W * 0.7, height: floorH * 0.5))
        rug.fillColor = UIColor(hex: 0xC98A2E, alpha: 0.30); rug.strokeColor = .clear
        rug.position = CGPoint(x: W/2, y: floorH * 0.5); rug.zPosition = -88; addChild(rug)

        // Title block, anchored from the top inset.
        let titleY = H - topInset - H * 0.10
        let title = makeLabel("Bad Cat", size: min(64, W * 0.17), color: Palette.ink, weight: .black)
        title.position = CGPoint(x: W/2, y: titleY); addChild(title)
        let sub = makeLabel("STARRING MAC", size: 14, color: Palette.inkSoft, weight: .heavy)
        sub.position = CGPoint(x: W/2, y: titleY - title.frame.height/2 - 16); addChild(sub)

        // Mac preview, sat on the floor, scaled to the screen.
        let mac = CatNode()
        mac.baseScale = max(1.8, min(3.0, W / 150))
        mac.position = CGPoint(x: W/2, y: floorH + H * 0.10)
        addChild(mac)
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 90, height: 22))
        shadow.fillColor = UIColor(hex: 0x000000, alpha: 0.12); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: W/2, y: floorH + 6); shadow.zPosition = -10; addChild(shadow)

        // Buttons, stacked with even spacing in the lower third.
        let btnW = min(300, W - 64)
        let play = ButtonNode("Play", size: CGSize(width: btnW, height: 56), fill: Palette.ink, fontSize: 22)
        play.position = CGPoint(x: W/2, y: floorH * 0.80)
        play.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: RoomSelectScene(size: s.size)) }
        addChild(play)

        let half = (btnW - 12) / 2
        let room = ButtonNode("Mac's Room", size: CGSize(width: half, height: 48), fill: Palette.couch, fontSize: 15)
        room.position = CGPoint(x: W/2 - half/2 - 6, y: floorH * 0.48)
        room.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: CatRoomScene(size: s.size)) }
        addChild(room)

        let shop = ButtonNode("Shop", size: CGSize(width: half, height: 48), fill: Palette.flame, fontSize: 15)
        shop.position = CGPoint(x: W/2 + half/2 + 6, y: floorH * 0.48)
        shop.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: ShopScene(size: s.size)) }
        addChild(shop)

        let awards = ButtonNode("Awards", size: CGSize(width: btnW, height: 40),
                                fill: UIColor(hex: 0x4A3526, alpha: 0.12), textColor: Palette.ink, fontSize: 14)
        awards.position = CGPoint(x: W/2, y: floorH * 0.16)
        awards.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: AchievementsScene(size: s.size)) }
        addChild(awards)

        coinChipLabel = addCoinChip()
        addSoundToggle()
        maybeShowDailyReward()
    }

    private func maybeShowDailyReward() {
        let status = GameData.shared.dailyRewardStatus()
        guard status.claimable else { return }
        // Full-screen button acts as the dimmer AND swallows taps meant for the menu behind it.
        let blocker = ButtonNode("", size: CGSize(width: size.width, height: size.height),
                                 fill: UIColor(hex: 0x4A3526, alpha: 0.55), fontSize: 1, shadow: false)
        blocker.position = CGPoint(x: size.width / 2, y: size.height / 2); blocker.zPosition = 200
        addChild(blocker)
        let cardW = min(300, size.width - 56)
        let card = roundedPanel(CGSize(width: cardW, height: 236), fill: Palette.panel, corner: 24)
        card.position = CGPoint(x: size.width / 2, y: size.height / 2); card.zPosition = 201; addChild(card)
        let t = makeLabel("Daily Treat!", size: 24, color: Palette.ink, weight: .black); t.position = CGPoint(x: 0, y: 78); card.addChild(t)
        let gift = IconFactory.loot(); gift.setScale(1.8); gift.position = CGPoint(x: 0, y: 18); card.addChild(gift)
        let info = makeLabel("+\(status.reward) coins", size: 22, color: Palette.flameDeep, weight: .black); info.position = CGPoint(x: 0, y: -36); card.addChild(info)
        let streak = makeLabel("\(status.streak)-day streak · tap to claim", size: 13, color: Palette.inkSoft, weight: .bold); streak.position = CGPoint(x: 0, y: -66); card.addChild(streak)
        blocker.onTap = { [weak self, weak blocker, weak card] in
            let r = GameData.shared.claimDailyReward()
            if r > 0 { SFX.coin(); Haptics.loot() }
            self?.coinChipLabel?.text = "\(GameData.shared.coins)"
            blocker?.removeFromParent()
            card?.run(.sequence([.group([.scale(to: 0.8, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
            if let s = self { s.showAchievements(Achievements.set("streak", to: GameData.shared.rewardStreak)) }
        }
        card.setScale(0.8); card.alpha = 0
        card.run(.group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.25)]))
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
        title.position = CGPoint(x: size.width/2, y: size.height - topInset - 100)
        addChild(title)
        layoutRooms()
    }

    private func layoutRooms() {
        children.filter { $0.name == "roomcard" }.forEach { $0.removeFromParent() }
        let cardW = size.width - 44
        let cardH: CGFloat = 92
        var y = size.height - topInset - 172
        for room in Content.rooms {
            let card = SKNode(); card.name = "roomcard"
            let panel = roundedPanel(CGSize(width: cardW, height: cardH), fill: Palette.panel, corner: 20)
            card.addChild(panel)
            let unlocked = GameData.shared.roomUnlocked(room.id)

            let icon = IconFactory.room(room.id); icon.position = CGPoint(x: -cardW/2 + 38, y: 4); card.addChild(icon)
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
                let unlock = ButtonNode("Unlock \(room.unlockCost)", size: CGSize(width: 108, height: 44),
                                        fill: canAfford ? Palette.flame : Palette.inkSoft, fontSize: 13)
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
        let icon = IconFactory.room(room.id)
        icon.position = CGPoint(x: size.width/2 - 90, y: size.height - topInset - 100)
        addChild(icon)
        let title = makeLabel(room.name, size: 24, color: Palette.ink, weight: .heavy)
        title.position = CGPoint(x: size.width/2 + 22, y: size.height - topInset - 100)
        addChild(title)
        let hint = makeLabel("Cause mayhem before bedtime", size: 13, color: Palette.inkSoft, weight: .bold)
        hint.position = CGPoint(x: size.width/2, y: size.height - topInset - 128)
        addChild(hint)

        let cols = 3
        let gap: CGFloat = 14
        let cell = (size.width - 44 - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let startY = size.height - topInset - 200
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
                let lock = IconFactory.padlock(); card.addChild(lock)
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
    private enum Tab { case looks, breeds, boosts, coins }
    private var tab: Tab = .looks
    private var coinLabel: SKLabelNode?
    private var listRoot = SKNode()
    private var tabButtons: [Tab: ButtonNode] = [:]

    override func build() {
        addRoomBackground(Palette.wall)
        addBackButton { [weak self] in guard let s = self else { return }
            s.navigate(to: MenuScene(size: s.size), .push(with: .right, duration: 0.32)) }
        coinLabel = addCoinChip()
        let title = makeLabel("Shop", size: 26, color: Palette.ink, weight: .heavy)
        title.position = CGPoint(x: size.width/2, y: size.height - topInset - 100)
        addChild(title)

        // category tabs
        let toggleY = size.height - topInset - 140
        let names: [(Tab, String)] = [(.looks, "Looks"), (.breeds, "Breeds"), (.boosts, "Boosts"), (.coins, "Coins")]
        let bw = (size.width - 44 - 24) / 4
        for (i, (t, name)) in names.enumerated() {
            let b = ButtonNode(name, size: CGSize(width: bw, height: 38), fill: Palette.inkSoft, fontSize: 13)
            b.position = CGPoint(x: 22 + bw/2 + CGFloat(i) * (bw + 8), y: toggleY)
            b.onTap = { [weak self] in self?.tab = t; self?.rebuild() }
            tabButtons[t] = b
            addChild(b)
        }

        addChild(listRoot)
        // Kick off product loading so the Coins tab has prices when opened.
        Task { [weak self] in
            await Store.shared.loadIfNeeded()
            DispatchQueue.main.async { self?.rebuild() }
        }
        rebuild()
    }

    private func rebuild() {
        listRoot.removeAllChildren()
        coinLabel?.text = "\(GameData.shared.coins)"
        for (t, b) in tabButtons { b.setTitleColorState(active: t == tab) }
        let cardW = size.width - 44
        var y = size.height - topInset - 196
        switch tab {
        case .looks:
            for item in Content.skins { listRoot.addChild(cosmeticRow(item, isBreed: false, width: cardW, y: y)); y -= 74 }
        case .breeds:
            for item in Content.breeds { listRoot.addChild(cosmeticRow(item, isBreed: true, width: cardW, y: y)); y -= 74 }
        case .boosts:
            for item in Content.upgrades { listRoot.addChild(upgradeRow(item, width: cardW, y: y)); y -= 90 }
        case .coins:
            y = buildIAPRows(width: cardW, startY: y)
        }
    }

    // MARK: cosmetic rows (accessories + breeds share equip/buy logic)
    private func cosmeticRow(_ item: ShopItem, isBreed: Bool, width: CGFloat, y: CGFloat) -> SKNode {
        let card = SKNode()
        card.addChild(roundedPanel(CGSize(width: width, height: 64), fill: Palette.panel, corner: 16))
        let data = GameData.shared

        let nm = makeLabel(item.name, size: 16, color: Palette.ink, weight: .heavy, h: .left)
        nm.position = CGPoint(x: -width/2 + 18, y: 11); card.addChild(nm)
        let blurb = makeLabel(item.blurb, size: 11, color: Palette.inkSoft, weight: .regular, h: .left)
        blurb.position = CGPoint(x: -width/2 + 18, y: -12); card.addChild(blurb)
        if isBreed {
            let sw = Breeds.style(item.id)
            let chip = SKShapeNode(circleOfRadius: 9)
            chip.fillColor = sw.coat; chip.strokeColor = sw.accent; chip.lineWidth = 3
            chip.position = CGPoint(x: -width/2 + 18 + nm.frame.width + 16, y: 11)
            card.addChild(chip)
        }

        let owned = data.owns(item.id) || item.cost == 0
        let equipped = isBreed ? (data.equippedBreed == item.id) : (data.equippedSkin == item.id)
        if equipped {
            let tag = makeLabel("Equipped", size: 13, color: Palette.good, weight: .heavy)
            tag.position = CGPoint(x: width/2 - 54, y: 0); card.addChild(tag)
        } else if owned {
            let b = ButtonNode("Equip", size: CGSize(width: 80, height: 38), fill: Palette.ink, fontSize: 14)
            b.position = CGPoint(x: width/2 - 58, y: 0)
            b.onTap = { [weak self] in
                if isBreed { data.equippedBreed = item.id } else { data.equippedSkin = item.id }
                data.save(); SFX.tap(); self?.rebuild()
            }
            card.addChild(b)
        } else {
            let afford = data.coins >= item.cost
            let b = ButtonNode("Buy \(item.cost)", size: CGSize(width: 92, height: 38),
                               fill: afford ? Palette.flame : Palette.inkSoft, fontSize: 13)
            b.position = CGPoint(x: width/2 - 62, y: 0)
            b.onTap = { [weak self] in
                if data.spend(item.cost) {
                    data.ownedItems.insert(item.id)
                    if isBreed { data.equippedBreed = item.id } else { data.equippedSkin = item.id }
                    data.save(); SFX.coin(); Haptics.loot(); self?.rebuild()
                }
            }
            card.addChild(b)
        }
        card.position = CGPoint(x: size.width/2, y: y)
        return card
    }

    private func upgradeRow(_ item: ShopItem, width: CGFloat, y: CGFloat) -> SKNode {
        let card = SKNode()
        card.addChild(roundedPanel(CGSize(width: width, height: 78), fill: Palette.panel, corner: 16))
        let data = GameData.shared
        let nm = makeLabel(item.name, size: 16, color: Palette.ink, weight: .heavy, h: .left)
        nm.position = CGPoint(x: -width/2 + 18, y: 16); card.addChild(nm)
        let blurb = makeLabel(item.blurb, size: 11, color: Palette.inkSoft, weight: .regular, h: .left)
        blurb.position = CGPoint(x: -width/2 + 18, y: -6); card.addChild(blurb)
        let lvl = data.upgradeLevel(item.id)
        let lvlTag = makeLabel("Lv \(lvl)/\(item.maxLevel)", size: 11, color: Palette.flameDeep, weight: .heavy, h: .left)
        lvlTag.position = CGPoint(x: -width/2 + 18, y: -26); card.addChild(lvlTag)
        if lvl >= item.maxLevel {
            let tag = makeLabel("MAX", size: 13, color: Palette.good, weight: .heavy)
            tag.position = CGPoint(x: width/2 - 48, y: 0); card.addChild(tag)
        } else {
            let cost = item.cost * (lvl + 1)
            let afford = data.coins >= cost
            let b = ButtonNode("Buy \(cost)", size: CGSize(width: 92, height: 38),
                               fill: afford ? Palette.flame : Palette.inkSoft, fontSize: 13)
            b.position = CGPoint(x: width/2 - 62, y: 0)
            b.onTap = { [weak self] in
                if data.spend(cost) { data.upgradeLevels[item.id] = lvl + 1; data.save(); SFX.coin(); self?.rebuild() }
            }
            card.addChild(b)
        }
        card.position = CGPoint(x: size.width/2, y: y)
        return card
    }

    // MARK: real-money rows (StoreKit)
    private func buildIAPRows(width: CGFloat, startY: CGFloat) -> CGFloat {
        var y = startY
        let packs: [(String, String, String)] = [
            (Store.ID.coinsSmall,  "Pocket Money",  "500 coins"),
            (Store.ID.coinsMedium, "Heist Haul",    "1,500 coins — best value"),
            (Store.ID.coinsLarge,  "Dragon Hoard",  "4,000 coins"),
            (Store.ID.removeAds,   "Remove Ads",    "No more ad breaks, ever"),
        ]
        if Store.shared.products.isEmpty {
            let note = makeLabel("Store unavailable — purchases will appear\nonce the app is live on the App Store.",
                                 size: 13, color: Palette.inkSoft, weight: .bold)
            note.numberOfLines = 0
            note.position = CGPoint(x: size.width/2, y: y - 20)
            listRoot.addChild(note)
            y -= 90
        }
        for (id, name, blurb) in packs {
            let card = SKNode()
            card.addChild(roundedPanel(CGSize(width: width, height: 64), fill: Palette.panel, corner: 16))
            let nm = makeLabel(name, size: 16, color: Palette.ink, weight: .heavy, h: .left)
            nm.position = CGPoint(x: -width/2 + 18, y: 11); card.addChild(nm)
            let bl = makeLabel(blurb, size: 11, color: Palette.inkSoft, weight: .regular, h: .left)
            bl.position = CGPoint(x: -width/2 + 18, y: -12); card.addChild(bl)
            if id == Store.ID.removeAds && GameData.shared.adsRemoved {
                let tag = makeLabel("Owned", size: 13, color: Palette.good, weight: .heavy)
                tag.position = CGPoint(x: width/2 - 50, y: 0); card.addChild(tag)
            } else if let product = Store.shared.product(id) {
                let b = ButtonNode(product.displayPrice, size: CGSize(width: 92, height: 38), fill: Palette.good, fontSize: 14)
                b.position = CGPoint(x: width/2 - 62, y: 0)
                b.onTap = { [weak self, weak b] in
                    b?.isEnabledButton = false
                    Task {
                        let ok = await Store.shared.purchase(id)
                        DispatchQueue.main.async {
                            if ok { SFX.coin(); Haptics.loot() }
                            self?.rebuild()
                        }
                    }
                }
                card.addChild(b)
            } else {
                let tag = makeLabel("—", size: 15, color: Palette.inkSoft, weight: .heavy)
                tag.position = CGPoint(x: width/2 - 50, y: 0); card.addChild(tag)
            }
            card.position = CGPoint(x: size.width/2, y: y)
            listRoot.addChild(card)
            y -= 74
        }
        // Restore purchases (required by App Review when you sell non-consumables)
        let restore = ButtonNode("Restore Purchases", size: CGSize(width: 200, height: 40),
                                 fill: UIColor(hex: 0x4A3526, alpha: 0.12), textColor: Palette.ink, fontSize: 13)
        restore.position = CGPoint(x: size.width/2, y: y - 6)
        restore.onTap = { [weak self] in
            Task {
                await Store.shared.restore()
                DispatchQueue.main.async { self?.rebuild() }
            }
        }
        listRoot.addChild(restore)
        return y - 60
    }
}

private extension ButtonNode {
    /// Cheap active/inactive visual for the shop tabs.
    func setTitleColorState(active: Bool) { alpha = active ? 1.0 : 0.55 }
}
