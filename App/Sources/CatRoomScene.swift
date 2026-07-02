import SpriteKit
import UIKit

// MARK: - Mac's Room: pet him, feed him treats, dress him up, find easter eggs.
final class CatRoomScene: BaseScene {
    private let cat = CatNode()
    private var coinChipLabel: SKLabelNode?
    private var bondBar: BarNode!
    private var bondLabel: SKLabelNode!
    private var treatBtn: ButtonNode!
    private var floorY: CGFloat = 0
    private var catHome: CGPoint = .zero
    private var busy = false                 // during zoomies/treat animation
    private var recentTaps: [TimeInterval] = []
    private let bondGoal = 20

    override func build() {
        GameData.shared.refreshCareDay()
        addRoomBackground(UIColor(hex: 0xD9C6A8))
        floorY = size.height * 0.30
        let floor = SKSpriteNode(color: Palette.wood, size: CGSize(width: size.width, height: floorY))
        floor.anchorPoint = .zero; floor.zPosition = -90; addChild(floor)
        let rug = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.78, height: floorY * 0.5))
        rug.fillColor = UIColor(hex: 0xC98A2E, alpha: 0.35); rug.strokeColor = .clear
        rug.position = CGPoint(x: size.width / 2, y: floorY * 0.55); rug.zPosition = -88; addChild(rug)
        // window + sun for coziness
        let win = SKShapeNode(rect: CGRect(x: size.width * 0.62, y: size.height * 0.62, width: 110, height: 130), cornerRadius: 6)
        win.fillColor = UIColor(hex: 0xBFE3F2); win.strokeColor = Palette.woodDeep; win.lineWidth = 5; win.zPosition = -80
        addChild(win)

        addBackButton { [weak self] in guard let s = self else { return }
            s.navigate(to: MenuScene(size: s.size), .push(with: .right, duration: 0.32)) }
        coinChipLabel = addCoinChip()

        let title = makeLabel("Mac's Room", size: 26, color: Palette.ink, weight: .black)
        title.position = CGPoint(x: size.width / 2, y: size.height - topInset - 100)
        addChild(title)
        let sub = makeLabel("pet him · feed him · dress him", size: 13, color: Palette.inkSoft, weight: .bold)
        sub.position = CGPoint(x: size.width / 2, y: size.height - topInset - 126)
        addChild(sub)

        // bond meter
        let bw = min(280, size.width - 80)
        let panel = roundedPanel(CGSize(width: bw + 24, height: 46), fill: Palette.panel, corner: 14)
        panel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 172); addChild(panel)
        let bl = makeLabel("BOND", size: 10, color: Palette.ink, weight: .heavy, h: .left)
        bl.position = CGPoint(x: -bw / 2, y: 11); panel.addChild(bl)
        bondLabel = makeLabel("", size: 10, color: Palette.inkSoft, weight: .heavy, h: .right)
        bondLabel.position = CGPoint(x: bw / 2, y: 11); panel.addChild(bondLabel)
        bondBar = BarNode(width: bw, height: 12, color: UIColor(hex: 0xE2554B))
        bondBar.position = CGPoint(x: -bw / 2, y: -9); panel.addChild(bondBar)

        // the star of the show
        catHome = CGPoint(x: size.width / 2, y: floorY + 10)
        cat.position = catHome
        cat.baseScale = max(2.0, min(3.0, size.width / 145))
        addChild(cat)
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 110, height: 24))
        shadow.fillColor = UIColor(hex: 0x000000, alpha: 0.12); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: size.width / 2, y: floorY + 2); shadow.zPosition = -10; addChild(shadow)

        // treat button
        treatBtn = ButtonNode("Give a treat", size: CGSize(width: 170, height: 48), fill: Palette.flame, fontSize: 16)
        treatBtn.position = CGPoint(x: size.width / 2, y: floorY * 0.42)
        treatBtn.onTap = { [weak self] in self?.giveTreat() }
        addChild(treatBtn)

        // dress-up arrows
        let outfits = ownedOutfits()
        if outfits.count > 1 {
            let left = ButtonNode("‹", size: CGSize(width: 44, height: 44), fill: Palette.panel, textColor: Palette.ink, fontSize: 22)
            left.position = CGPoint(x: size.width * 0.16, y: catHome.y + 60)
            left.onTap = { [weak self] in self?.cycleOutfit(-1) }
            addChild(left)
            let right = ButtonNode("›", size: CGSize(width: 44, height: 44), fill: Palette.panel, textColor: Palette.ink, fontSize: 22)
            right.position = CGPoint(x: size.width * 0.84, y: catHome.y + 60)
            right.onTap = { [weak self] in self?.cycleOutfit(1) }
            addChild(right)
            let dl = makeLabel("dress up", size: 10, color: Palette.inkSoft, weight: .heavy)
            dl.position = CGPoint(x: size.width * 0.84, y: catHome.y + 30); addChild(dl)
        }
        syncCare()
    }

    private func ownedOutfits() -> [String] {
        var list = ["skin_default"]
        for s in Content.skins where s.id != "skin_default" && GameData.shared.owns(s.id) { list.append(s.id) }
        return list
    }
    private func cycleOutfit(_ dir: Int) {
        let outfits = ownedOutfits()
        guard let cur = outfits.firstIndex(of: GameData.shared.equippedSkin) else {
            GameData.shared.equippedSkin = "skin_default"; GameData.shared.save(); cat.applySkin("skin_default"); return
        }
        let next = outfits[(cur + dir + outfits.count) % outfits.count]
        GameData.shared.equippedSkin = next; GameData.shared.save()
        cat.applySkin(next)
        SFX.tap(); Haptics.tap()
    }

    private func syncCare() {
        let d = GameData.shared
        bondBar.setValue(CGFloat(d.bondToday) / CGFloat(bondGoal))
        bondLabel.text = d.bondToday >= bondGoal ? "MAX today" : "\(d.bondToday)/\(bondGoal)"
        let left = max(0, 3 - d.treatsToday)
        treatBtn.setTitle(left > 0 ? "Give a treat (\(left) left)" : "No treats left today")
        treatBtn.isEnabledButton = left > 0
        coinChipLabel?.text = "\(d.coins)"
    }

    private func addBond(_ n: Int) {
        let d = GameData.shared
        let before = d.bondToday
        d.bondToday = min(bondGoal, d.bondToday + n)
        if d.bondToday >= bondGoal && before < bondGoal && !d.bondRewardClaimed {
            d.bondRewardClaimed = true
            d.addCoins(60)
            popHeart(big: true)
            let msg = makeLabel("Mac loves you! +60", size: 18, color: Palette.flameDeep, weight: .black)
            msg.position = CGPoint(x: size.width / 2, y: catHome.y + 150); msg.zPosition = 70; addChild(msg)
            msg.run(.sequence([.group([.moveBy(x: 0, y: 30, duration: 0.9), .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
            SFX.win(); Haptics.win()
        }
        d.save()
        syncCare()
    }

    // MARK: interactions
    override func worldTouch(at point: CGPoint) {
        guard !busy else { return }
        let d = hypot(point.x - catHome.x, point.y - (catHome.y + 40))
        guard d < 110 else { return }
        let now = Date.timeIntervalSinceReferenceDate
        recentTaps = recentTaps.filter { now - $0 < 2.0 }
        recentTaps.append(now)
        if recentTaps.count >= 5 { recentTaps.removeAll(); zoomies(); return }

        // boop the nose (upper part of the cat) vs pet the body
        if point.y > catHome.y + 80 { boop() } else { pet() }
    }

    private func pet() {
        GameData.shared.petsTotal += 1
        Haptics.tap(); SFX.tap()
        cat.run(.sequence([.scaleY(to: cat.baseScale * 0.92, duration: 0.08), .scaleY(to: cat.baseScale, duration: 0.1)]))
        popHeart(big: false)
        addBond(1)
        showAchievements(Achievements.record("pet"))
        if GameData.shared.petsTotal % 12 == 0 { say(["prrrrr…", "mrrp!", "*happy tail*", "purrrrrr"].randomElement()!) }
    }

    private func boop() {
        Haptics.knock(); SFX.tap()
        cat.run(.sequence([.moveBy(x: 0, y: -6, duration: 0.06), .moveBy(x: 0, y: 6, duration: 0.1)]))
        say(["mlem", "boop accepted", "*squints happily*", "mrrp?"].randomElement()!)
        addBond(1)
        showAchievements(Achievements.record("pet"))
    }

    private func giveTreat() {
        let d = GameData.shared
        guard d.treatsToday < 3, !busy else { return }
        d.treatsToday += 1; d.save()
        busy = true
        let treat = IconFactory.fish()
        treat.position = CGPoint(x: catHome.x, y: catHome.y + 220)
        treat.zPosition = 20
        addChild(treat)
        let drop = SKAction.move(to: CGPoint(x: catHome.x, y: catHome.y + 40), duration: 0.5)
        drop.timingMode = .easeIn
        treat.run(.sequence([drop, .fadeOut(withDuration: 0.15), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in
            guard let s = self else { return }
            SFX.coin(); Haptics.loot()
            s.say(["nom nom nom", "CHOMP", "*inhales it*"].randomElement()!)
            s.cat.run(.sequence([.scale(to: s.cat.baseScale * 1.06, duration: 0.1), .scale(to: s.cat.baseScale, duration: 0.12)]))
            s.addBond(3)
            s.busy = false
        }]))
    }

    private func zoomies() {
        busy = true
        Haptics.bigHit(); SFX.win()
        say("ZOOMIES!!!")
        showAchievements(Achievements.record("zoomies"))
        let l = CGPoint(x: size.width * 0.14, y: catHome.y)
        let r = CGPoint(x: size.width * 0.86, y: catHome.y)
        cat.setWalking(true)
        let dashes = SKAction.sequence([
            .run { [weak self] in self?.cat.face(-1) }, .move(to: l, duration: 0.28),
            .run { [weak self] in self?.cat.face(1) },  .move(to: r, duration: 0.34),
            .run { [weak self] in self?.cat.face(-1) }, .move(to: l, duration: 0.3),
            .run { [weak self] in self?.cat.face(1) },  .move(to: self.catHome, duration: 0.3)
        ])
        cat.run(.sequence([dashes, .run { [weak self] in
            guard let s = self else { return }
            s.cat.setWalking(false); s.cat.face(1); s.busy = false
            s.addBond(2)
        }]))
    }

    private func popHeart(big: Bool) {
        let h = IconFactory.heart()
        h.position = CGPoint(x: catHome.x + CGFloat.random(in: -40...40), y: catHome.y + 110)
        h.setScale(big ? 1.6 : CGFloat.random(in: 0.7...1.1))
        h.zPosition = 30
        addChild(h)
        h.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -20...20), y: 70, duration: 0.9),
                                 .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.5)])]),
                         .removeFromParent()]))
    }

    private func say(_ text: String) {
        let node = SKNode()
        let label = makeLabel(text, size: 13, color: Palette.ink, weight: .bold)
        let w = max(56, label.frame.width + 22), h = label.frame.height + 16
        node.addChild(roundedPanel(CGSize(width: w, height: h), fill: Palette.panel, corner: 12, shadow: false))
        node.addChild(label)
        node.position = CGPoint(x: catHome.x, y: catHome.y + 190)
        node.zPosition = 40
        addChild(node)
        node.setScale(0.6); node.alpha = 0
        node.run(.sequence([.group([.scale(to: 1, duration: 0.12), .fadeIn(withDuration: 0.12)]),
                            .wait(forDuration: 1.4), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }
}

// MARK: - Awards (achievements list)
final class AchievementsScene: BaseScene {
    override func build() {
        addRoomBackground(Palette.wall)
        addBackButton { [weak self] in guard let s = self else { return }
            s.navigate(to: MenuScene(size: s.size), .push(with: .right, duration: 0.32)) }
        _ = addCoinChip()
        let title = makeLabel("Awards", size: 26, color: Palette.ink, weight: .heavy)
        title.position = CGPoint(x: size.width / 2, y: size.height - topInset - 100)
        addChild(title)

        let cardW = size.width - 40
        let rowH: CGFloat = 46
        var y = size.height - topInset - 148
        for a in Achievements.all {
            let unlocked = Achievements.isUnlocked(a)
            let row = SKNode()
            row.addChild(roundedPanel(CGSize(width: cardW, height: rowH),
                                      fill: unlocked ? Palette.panel : UIColor(hex: 0xFBF6EE, alpha: 0.55), corner: 12))
            let icon = IconFactory.trophy()
            icon.setScale(0.8); icon.alpha = unlocked ? 1 : 0.3
            icon.position = CGPoint(x: -cardW / 2 + 26, y: 0); row.addChild(icon)
            let nm = makeLabel(a.name, size: 14, color: unlocked ? Palette.ink : Palette.inkSoft, weight: .heavy, h: .left)
            nm.position = CGPoint(x: -cardW / 2 + 48, y: 8); row.addChild(nm)
            let bl = makeLabel(a.blurb, size: 10, color: Palette.inkSoft, weight: .regular, h: .left)
            bl.position = CGPoint(x: -cardW / 2 + 48, y: -11); row.addChild(bl)
            let progress = makeLabel(unlocked ? "✓" : "\(Achievements.progress(a))/\(a.target)",
                                     size: 13, color: unlocked ? Palette.good : Palette.inkSoft, weight: .heavy, h: .right)
            progress.position = CGPoint(x: cardW / 2 - 16, y: 0); row.addChild(progress)
            row.position = CGPoint(x: size.width / 2, y: y)
            addChild(row)
            y -= rowH + 8
        }
    }
}
