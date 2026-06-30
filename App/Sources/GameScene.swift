import SpriteKit
import UIKit

// MARK: - Breakable sprite
final class BreakableSprite: SKNode {
    let def: Breakable
    let platformId: Int
    let standX: CGFloat
    let mult: CGFloat
    private(set) var messed = false
    private let icon: SKLabelNode

    init(placement: Placement, worldY: CGFloat) {
        self.def = placement.def
        self.platformId = placement.platform
        self.standX = placement.x
        self.mult = placement.mult
        self.icon = makeLabel(BreakableSprite.emoji(placement.def.kind), size: 28)
        super.init()
        position = CGPoint(x: placement.x, y: worldY)
        icon.position = CGPoint(x: 0, y: 18)
        addChild(icon)
        let v = Int(CGFloat(placement.def.chaos) * placement.mult)
        let tag = makeLabel("+\(v)", size: 11, color: placement.mult > 1.5 ? Palette.gold : Palette.inkSoft, weight: .heavy)
        tag.position = CGPoint(x: 0, y: 40); tag.alpha = 0.9
        addChild(tag)
    }
    required init?(coder: NSCoder) { fatalError() }

    var chaosValue: Int { Int(CGFloat(def.chaos) * mult) }
    var coinValue: Int { Int(CGFloat(def.coins) * mult) }

    func makeMessed() {
        guard !messed else { return }
        messed = true
        icon.run(.group([
            .move(to: CGPoint(x: CGFloat.random(in: -14...14), y: 6), duration: 0.25),
            .rotate(toAngle: .pi / 2, duration: 0.25),
            .fadeAlpha(to: 0.4, duration: 0.25)
        ]))
    }
    func restore() {
        messed = false
        icon.removeAllActions()
        icon.run(.group([.move(to: CGPoint(x: 0, y: 18), duration: 0.2),
                         .rotate(toAngle: 0, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)]))
    }

    static func emoji(_ kind: String) -> String {
        switch kind {
        case "vase": return "🏺"; case "plant": return "🪴"; case "cup": return "🥤"
        case "books": return "📚"; case "tp": return "🧻"; case "lamp": return "💡"
        case "glass": return "🍷"; case "fruit": return "🍎"; case "plate": return "🍽️"
        case "perfume": return "🧴"; case "mug": return "☕️"; case "clock": return "⏰"
        case "duck": return "🦆"; case "keyboard": return "⌨️"
        default: return "🧸"
        }
    }
}

// MARK: - Collectible
final class Collectible: SKNode {
    let value: Int
    let isGem: Bool
    let platformId: Int
    init(value: Int, isGem: Bool, platformId: Int) {
        self.value = value; self.isGem = isGem; self.platformId = platformId
        super.init()
        let l = makeLabel(isGem ? "💎" : "🪙", size: isGem ? 24 : 20)
        addChild(l)
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.6), .moveBy(x: 0, y: -5, duration: 0.6)])))
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Loot box
final class LootBox: SKNode {
    let platformId: Int
    let tier: CGFloat            // 0..1 height — richer higher up
    private(set) var opened = false
    private let icon = makeLabel("🎁", size: 30)

    init(platformId: Int, tier: CGFloat) {
        self.platformId = platformId; self.tier = tier
        super.init()
        icon.position = CGPoint(x: 0, y: 18); addChild(icon)
        let glow = makeLabel("✨", size: 14); glow.position = CGPoint(x: 0, y: 40); glow.alpha = 0.85
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.7), .fadeAlpha(to: 0.9, duration: 0.7)])))
        addChild(glow)
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.7), .moveBy(x: 0, y: -4, duration: 0.7)])))
    }
    required init?(coder: NSCoder) { fatalError() }

    func open() {
        guard !opened else { return }
        opened = true
        icon.text = "✨"
        icon.run(.sequence([.scale(to: 1.5, duration: 0.15), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
}

// MARK: - Watcher (a person who might see the cat)
final class Watcher {
    let node = HumanNode()
    let platform: Int
    var timer: Double = 3
    var next: HumanNode.Gaze = .watch
    init(platform: Int) { self.platform = platform }
}

// MARK: - Game
final class GameScene: BaseScene {
    let roomId: String
    let day: Int
    private let room: RoomDef
    private let cfg: (target: Int, length: Double, vigilance: Double)

    // actors
    private let cat = CatNode()
    private var watchers: [Watcher] = []
    private var sunbeam: SKShapeNode!
    private var breakables: [BreakableSprite] = []
    private var collectibles: [Collectible] = []
    private var lootBoxes: [LootBox] = []
    private var foodBowl: SKNode!
    private var waterBowl: SKNode!

    // world / layout
    private var world: SKNode!
    private var layout: LevelLayout!
    private var platforms: [PlatformDef] = []
    private var worldWidth: CGFloat = 0
    private var worldHeight: CGFloat = 0
    private var floorY: CGFloat = 0

    // state
    private var energy: CGFloat = 75
    private var maxEnergy: CGFloat = 100
    private var susp: CGFloat = 10
    private var chaos = 0
    private var runCoins = 0
    private var dayT: Double = 0
    private var sunX: CGFloat = 0
    private var ended = false
    private var lastTime: TimeInterval = 0
    private var spawnTimer: Double = 4

    // combo
    private var combo = 0
    private var comboTimer: Double = 0
    private let comboWindow: Double = 3.4
    private let comboCap = 6

    // cat control
    private enum Action { case none, knock, eat, drink, nap }
    private var action: Action = .none
    private var actT: Double = 0
    private var catPlatform = 0
    private var moveDir: CGFloat = 0
    private var climbHeld = false
    private var climbLink: LinkDef?
    private var climbTarget = 0
    private var swatTarget: BreakableSprite?

    // input
    private enum Role { case left, right, climb }
    private var touchRoles: [UITouch: Role] = [:]
    private var climbBtnCenter: CGPoint = .zero
    private var swatBtnCenter: CGPoint = .zero
    private var climbBtnR: CGFloat = 34
    private var swatBtnR: CGFloat = 36
    private var quitRect: CGRect = .zero
    private var hudHeight: CGFloat = 140

    // tuning
    private let walkSpeed: CGFloat = 188
    private let climbSpeed: CGFloat = 150
    private let swatRange: CGFloat = 64
    private let climbReach: CGFloat = 46
    private var hopCost: CGFloat { max(8, 16 - CGFloat(upBelly)) }

    // HUD
    private var energyBar: BarNode!
    private var suspBar: BarNode!
    private var chaosLabel: SKLabelNode!
    private var coinLabel: SKLabelNode!
    private var dayBar: BarNode!
    private var comboLabel: SKLabelNode!
    private var bannerLabel: SKLabelNode!
    private var bannerPanel: SKShapeNode!
    private var climbBtn: SKShapeNode!
    private var thoughtNode: SKNode?
    private var thoughtCooldown: Double = 0

    // upgrades
    private var upPaws = 0, upBelly = 0, upNap = 0, upCharm = 0, upValue = 0

    init(size: CGSize, roomId: String, day: Int) {
        self.roomId = roomId; self.day = day
        self.room = Content.room(roomId)
        self.cfg = Content.dayConfig(room: roomId, day: day)
        super.init(size: size)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func build() {
        if size.width <= 0 || size.height <= 0 { size = CGSize(width: 390, height: 844) }
        backgroundColor = room.wall
        let d = GameData.shared
        upPaws = d.upgradeLevel("up_paws"); upBelly = d.upgradeLevel("up_belly")
        upNap = d.upgradeLevel("up_nap"); upCharm = d.upgradeLevel("up_charm"); upValue = d.upgradeLevel("up_value")
        maxEnergy = 100 + CGFloat(upBelly) * 20
        energy = min(78, maxEnergy)

        hudHeight = 150 + bottomInset
        floorY = hudHeight + 28      // keep the floor (cat, bowls) clear of the HUD panel
        layout = Content.layout(roomId: roomId, day: day, screen: size, floorY: floorY)
        platforms = layout.platforms
        worldWidth = layout.worldWidth
        worldHeight = layout.worldHeight

        world = SKNode(); addChild(world)
        buildRoom()
        buildPlatforms()
        buildBowls()
        buildBreakables()
        buildLoot()

        cat.position = CGPoint(x: worldWidth * 0.4, y: floorY)
        cat.baseScale = min(1.12, size.width / 360)
        catPlatform = 0
        world.addChild(cat)

        buildWatchers()
        buildHUD()
        updateCamera()
    }

    // MARK: geometry helpers
    private func platformWorldY(_ id: Int) -> CGFloat {
        guard id >= 0 && id < platforms.count else { return floorY }
        return floorY + platforms[id].topY
    }
    private func platform(_ id: Int) -> PlatformDef { (id >= 0 && id < platforms.count) ? platforms[id] : platforms[0] }

    // MARK: build world
    private func buildRoom() {
        let wall = SKSpriteNode(color: room.wall, size: CGSize(width: worldWidth, height: worldHeight))
        wall.anchorPoint = .zero; wall.zPosition = -100; world.addChild(wall)
        let floor = SKSpriteNode(color: Palette.wood, size: CGSize(width: worldWidth, height: floorY))
        floor.anchorPoint = .zero; floor.zPosition = -90; world.addChild(floor)
        let base = SKSpriteNode(color: Palette.woodDeep, size: CGSize(width: worldWidth, height: 6))
        base.anchorPoint = .zero; base.position = CGPoint(x: 0, y: floorY); base.zPosition = -89; world.addChild(base)
        for wx in stride(from: size.width * 0.16, to: worldWidth, by: size.width * 0.66) {
            let win = SKShapeNode(rect: CGRect(x: wx, y: floorY + 130, width: 100, height: 130), cornerRadius: 6)
            win.fillColor = UIColor(hex: 0xBFE3F2); win.strokeColor = Palette.woodDeep; win.lineWidth = 5; win.zPosition = -80
            world.addChild(win)
        }
        sunbeam = SKShapeNode()
        sunbeam.fillColor = Palette.sun; sunbeam.strokeColor = .clear; sunbeam.alpha = 0.34; sunbeam.zPosition = -70
        world.addChild(sunbeam)
    }

    private func buildPlatforms() {
        for l in layout.links {
            let yLo = platformWorldY(l.lower), yHi = platformWorldY(l.upper)
            let post = SKShapeNode(rect: CGRect(x: l.x - 6, y: yLo, width: 12, height: yHi - yLo), cornerRadius: 5)
            post.fillColor = UIColor(hex: 0x8B6A45, alpha: 0.55); post.strokeColor = .clear; post.zPosition = -78
            world.addChild(post)
            var rungY = yLo + 18
            while rungY < yHi {
                let rung = SKShapeNode(rect: CGRect(x: l.x - 11, y: rungY, width: 22, height: 4), cornerRadius: 2)
                rung.fillColor = UIColor(hex: 0x8B6A45, alpha: 0.75); rung.strokeColor = .clear; rung.zPosition = -77
                world.addChild(rung); rungY += 24
            }
        }
        for p in platforms where p.id != 0 {
            let y = floorY + p.topY
            let surf = SKShapeNode(rect: CGRect(x: p.cx - p.width / 2, y: y - 14, width: p.width, height: 16), cornerRadius: 4)
            surf.fillColor = Palette.wood; surf.strokeColor = Palette.woodDeep; surf.lineWidth = 2; surf.zPosition = -60
            world.addChild(surf)
            let lip = SKShapeNode(rect: CGRect(x: p.cx - p.width / 2, y: y - 2, width: p.width, height: 3), cornerRadius: 1)
            lip.fillColor = UIColor(hex: 0xD9B98C); lip.strokeColor = .clear; lip.zPosition = -59
            world.addChild(lip)
        }
    }

    private func buildBowls() {
        func bowl(_ x: CGFloat, _ color: UIColor, _ glyph: String, _ gsize: CGFloat) -> SKNode {
            let n = SKNode(); n.position = CGPoint(x: x, y: floorY)
            let dish = SKShapeNode(ellipseIn: CGRect(x: -20, y: -8, width: 40, height: 16))
            dish.fillColor = color; dish.strokeColor = .clear; n.addChild(dish)
            let g = makeLabel(glyph, size: gsize); n.addChild(g)
            return n
        }
        foodBowl = bowl(worldWidth * 0.07, Palette.flameDeep, "🐟", 16); world.addChild(foodBowl)
        waterBowl = bowl(worldWidth * 0.13, Palette.water, "💧", 14); world.addChild(waterBowl)
    }

    private func buildBreakables() {
        for pl in layout.placements {
            let s = BreakableSprite(placement: pl, worldY: platformWorldY(pl.platform))
            world.addChild(s); breakables.append(s)
        }
    }

    private func buildLoot() {
        let topTierY = platforms.map { $0.topY }.max() ?? 1
        for spot in layout.lootSpots {
            let tier = platformWorldY(spot.platform) > floorY ? platforms[spot.platform].topY / max(1, topTierY) : 0
            let lb = LootBox(platformId: spot.platform, tier: tier)
            lb.position = CGPoint(x: spot.x, y: platformWorldY(spot.platform))
            world.addChild(lb); lootBoxes.append(lb)
        }
    }

    private func buildWatchers() {
        for spot in layout.humanSpots {
            let w = Watcher(platform: spot.platform)
            w.node.position = CGPoint(x: spot.x, y: platformWorldY(spot.platform))
            w.node.setScale(min(1.05, size.width / 400))
            world.addChild(w.node)
            watchers.append(w)
            setGaze(w, .distract)
        }
    }

    // MARK: HUD + controls
    private func buildHUD() {
        let quit = ButtonNode("✕", size: CGSize(width: 38, height: 38), fill: Palette.panel, textColor: Palette.ink, fontSize: 18)
        quit.position = CGPoint(x: 32, y: size.height - topInset - 24)
        quit.zPosition = 60; addChild(quit)
        quit.onTap = { [weak self] in guard let s = self else { return }
            s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        quitRect = CGRect(x: 8, y: size.height - topInset - 48, width: 48, height: 48)

        let coinChip = roundedPanel(CGSize(width: 104, height: 34), fill: Palette.panel, corner: 17)
        coinChip.position = CGPoint(x: size.width - 66, y: size.height - topInset - 24); coinChip.zPosition = 60
        addChild(coinChip)
        let ci = SKShapeNode(circleOfRadius: 8); ci.fillColor = Palette.gold; ci.strokeColor = .clear; ci.position = CGPoint(x: -36, y: 0); coinChip.addChild(ci)
        coinLabel = makeLabel("\(GameData.shared.coins)", size: 16, color: Palette.ink, weight: .heavy, h: .left)
        coinLabel.position = CGPoint(x: -20, y: 0); coinChip.addChild(coinLabel)

        bannerPanel = roundedPanel(CGSize(width: min(260, size.width - 40), height: 30), fill: UIColor(hex: 0xFBF6EE, alpha: 0.92), corner: 15)
        bannerPanel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 64); bannerPanel.zPosition = 60
        addChild(bannerPanel)
        bannerLabel = makeLabel("", size: 14, color: Palette.inkSoft, weight: .heavy)
        bannerPanel.addChild(bannerLabel)

        comboLabel = makeLabel("", size: 22, color: Palette.flameDeep, weight: .black)
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 104); comboLabel.zPosition = 60
        addChild(comboLabel)

        // Bottom HUD panel
        let hud = roundedPanel(CGSize(width: size.width, height: hudHeight), fill: UIColor(hex: 0xA6B095, alpha: 0.96), corner: 0, shadow: false)
        hud.position = CGPoint(x: size.width / 2, y: hudHeight / 2); hud.zPosition = 55; addChild(hud)

        let leftX = -size.width / 2 + 18
        let barW = min(size.width * 0.36, 132)
        energyBar = BarNode(width: barW, color: Palette.energy)
        energyBar.position = CGPoint(x: leftX, y: 18); hud.addChild(energyBar)
        let eLab = makeLabel("STAMINA", size: 10, color: Palette.ink, weight: .heavy, h: .left); eLab.position = CGPoint(x: leftX, y: 34); hud.addChild(eLab)
        suspBar = BarNode(width: barW, color: Palette.susp)
        suspBar.position = CGPoint(x: leftX, y: -16); hud.addChild(suspBar)
        let sLab = makeLabel("SUSPICION", size: 10, color: Palette.ink, weight: .heavy, h: .left); sLab.position = CGPoint(x: leftX, y: 0); hud.addChild(sLab)

        let chaosX = leftX + barW + 30
        chaosLabel = makeLabel("0", size: 24, color: Palette.ink, weight: .black, h: .center)
        chaosLabel.position = CGPoint(x: chaosX, y: 6); hud.addChild(chaosLabel)
        let cLab = makeLabel("MISCHIEF", size: 9, color: Palette.ink, weight: .heavy, h: .center); cLab.position = CGPoint(x: chaosX, y: 30); hud.addChild(cLab)

        dayBar = BarNode(width: size.width - 40, height: 5, color: Palette.gold)
        dayBar.position = CGPoint(x: -size.width / 2 + 20, y: hudHeight / 2 - 12); hud.addChild(dayBar)
        let goal = makeLabel("Day \(day + 1) · goal \(cfg.target)", size: 10, color: Palette.ink, weight: .bold, h: .left)
        goal.position = CGPoint(x: -size.width / 2 + 20, y: hudHeight / 2 - 28); hud.addChild(goal)

        // Control buttons (hold to move via screen sides; these two are tap/hold buttons)
        swatBtnCenter = CGPoint(x: size.width - 128, y: hudHeight * 0.46)
        climbBtnCenter = CGPoint(x: size.width - 48, y: hudHeight * 0.46)
        let swat = controlButton(at: swatBtnCenter, r: swatBtnR, fill: Palette.flame, glyph: "🐾", label: "SWAT")
        addChild(swat)
        climbBtn = controlButton(at: climbBtnCenter, r: climbBtnR, fill: Palette.eyeDeep, glyph: "▲", label: "CLIMB")
        addChild(climbBtn)

        // hint
        let hint = makeLabel("hold left / right to move", size: 11, color: UIColor(hex: 0xFBF6EE, alpha: 0.9), weight: .heavy)
        hint.position = CGPoint(x: size.width / 2 - 30, y: hudHeight + 16); hint.zPosition = 56; addChild(hint)
        hint.run(.sequence([.wait(forDuration: 4), .fadeOut(withDuration: 0.6), .removeFromParent()]))

        syncHUD()
    }

    private func controlButton(at c: CGPoint, r: CGFloat, fill: UIColor, glyph: String, label: String) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: r)
        node.fillColor = fill; node.strokeColor = UIColor(hex: 0xFBF6EE, alpha: 0.8); node.lineWidth = 2
        node.position = c; node.zPosition = 58
        let g = makeLabel(glyph, size: r * 0.8, color: .white, weight: .black); g.position = CGPoint(x: 0, y: 2); node.addChild(g)
        let l = makeLabel(label, size: 9, color: UIColor(hex: 0xFBF6EE), weight: .heavy); l.position = CGPoint(x: 0, y: -r - 8); node.addChild(l)
        return node
    }

    private func syncHUD() {
        energyBar.setValue(energy / maxEnergy)
        energyBar.setColor(energy < hopCost ? Palette.flame : Palette.energy)
        suspBar.setValue(susp / 100)
        suspBar.setColor(susp > 70 ? Palette.susp : susp > 40 ? Palette.flame : Palette.good)
        chaosLabel.text = "\(chaos)"
        coinLabel.text = "\(GameData.shared.coins)"
        dayBar.setValue(CGFloat(dayT / cfg.length))
        comboLabel.text = combo >= 2 ? "COMBO ×\(combo)" : ""
        climbBtn?.alpha = canClimbNow ? 1 : 0.45
    }
    private var comboFactor: CGFloat { combo >= 2 ? 1 + 0.4 * CGFloat(combo - 1) : 1 }

    private func setBanner() {
        var txt = "📱  make your move"; var col = Palette.good
        if anyWatching { txt = "👀  EYES ON YOU — freeze or act cute"; col = UIColor(hex: 0xB23A2E) }
        else if watchers.allSatisfy({ $0.node.gaze == .away }) { txt = "🚪  all clear — free reign!"; col = Palette.good }
        else if watchers.contains(where: { $0.next == .watch && $0.node.gaze == .distract && $0.timer < 0.9 }) {
            txt = "⚠  someone's about to look…"; col = UIColor(hex: 0xC98A2E)
        }
        bannerLabel.text = txt; bannerLabel.fontColor = col
    }

    // MARK: watcher AI
    private func planNext(_ g: HumanNode.Gaze) -> HumanNode.Gaze {
        let v = cfg.vigilance
        switch g {
        case .watch: return Double.random(in: 0...1) < 0.2 ? .watch : .distract
        case .distract:
            let r = Double.random(in: 0...1)
            return r < v ? .watch : (r < v + 0.15 ? .away : .distract)
        case .away: return .distract
        }
    }
    private func setGaze(_ w: Watcher, _ g: HumanNode.Gaze) {
        w.node.setGaze(g, lookDir: lookDir(w))
        switch g {
        case .watch: w.timer = Double.random(in: 2.2...4.0) - Double(Content.roomIndex(roomId)) * 0.1
        case .distract: w.timer = Double.random(in: 2.8...5.6)
        case .away: w.timer = Double.random(in: 3.6...6.6)
        }
        w.next = planNext(g)
        if g == .away { tidyOne() }
    }
    private func lookDir(_ w: Watcher) -> CGFloat { max(-1, min(1, (cat.position.x - w.node.position.x) / 140)) }
    private func tidyOne() {
        if let one = breakables.filter({ $0.messed }).randomElement(), Double.random(in: 0...1) < 0.7 { one.restore() }
    }
    private var anyWatching: Bool { watchers.contains { $0.node.gaze == .watch } }
    /// Seen = a watching person whose vision covers the cat's position (height band matters).
    private var isSeen: Bool {
        for w in watchers where w.node.gaze == .watch {
            if abs(cat.position.x - w.node.position.x) < size.width * 0.72 &&
               abs(cat.position.y - w.node.position.y) < 250 { return true }
        }
        return false
    }
    private var onHigh: Bool { catPlatform != 0 }
    private var idle: Bool { moveDir == 0 && climbLink == nil && action == .none && !climbHeld }

    // MARK: input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { assign(t, at: t.location(in: self)) }
        refreshControls()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let r = touchRoles[t], r == .left || r == .right {
                touchRoles[t] = t.location(in: self).x < size.width / 2 ? .left : .right
            }
        }
        refreshControls()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchRoles[t] = nil }
        refreshControls()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchRoles[t] = nil }
        refreshControls()
    }

    private func assign(_ t: UITouch, at loc: CGPoint) {
        if ended {
            // let result-screen buttons work
            for n in nodes(at: loc) {
                var node: SKNode? = n
                while let cur = node { if let b = cur as? ButtonNode { SFX.tap(); b.trigger(); return }; node = cur.parent }
            }
            return
        }
        if loc.y <= hudHeight {
            if hypot(loc.x - swatBtnCenter.x, loc.y - swatBtnCenter.y) < swatBtnR + 6 { SFX.tap(); doSwat(); return }
            if hypot(loc.x - climbBtnCenter.x, loc.y - climbBtnCenter.y) < climbBtnR + 6 { touchRoles[t] = .climb; return }
            return
        }
        if quitRect.contains(loc) {
            SFX.tap()
            navigate(to: LevelSelectScene(size: size, roomId: roomId), .push(with: .right, duration: 0.3)); return
        }
        touchRoles[t] = loc.x < size.width / 2 ? .left : .right
    }

    private func refreshControls() {
        var l = false, r = false, c = false
        for role in touchRoles.values {
            switch role { case .left: l = true; case .right: r = true; case .climb: c = true }
        }
        moveDir = (r ? 1 : 0) - (l ? 1 : 0)
        climbHeld = c
    }

    // MARK: climbing helper
    private var nearestLink: LinkDef? {
        var best: LinkDef?; var bestD = climbReach
        for l in layout.links where l.lower == catPlatform || l.upper == catPlatform {
            let d = abs(cat.position.x - l.x)
            if d < bestD { bestD = d; best = l }
        }
        return best
    }
    private var canClimbNow: Bool { climbLink != nil || nearestLink != nil }

    // MARK: loop
    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime; lastTime = currentTime
        dt = min(dt, 0.05)
        if ended { return }
        let dtf = CGFloat(dt)

        dayT += dt
        sunX = worldWidth * (0.05 + 0.14 * CGFloat(dayT / cfg.length))
        updateSun()
        if dayT >= cfg.length { return finish(caught: false) }

        // watcher gaze
        for w in watchers {
            w.timer -= dt
            if w.timer <= 0 { setGaze(w, w.next) }
            else if w.node.gaze == .watch { w.node.lookAt(lookDir(w)) }
        }
        setBanner()

        // movement & climbing
        stepCat(dtf)
        updateCamera()

        // passive drain
        energy = max(0, min(maxEnergy, energy - dtf * 0.2))
        if comboTimer > 0 { comboTimer -= dt; if comboTimer <= 0 { combo = 0 } }

        // refuel: stand still on a bowl to eat/drink, or in the sunbeam to nap
        if action != .knock {
            let stationary = moveDir == 0 && climbLink == nil && !climbHeld
            let inSun = !onHigh && abs(cat.position.x - sunX) < size.width * 0.08
            let nearFood = catPlatform == 0 && abs(cat.position.x - foodBowl.position.x) < 30
            let nearWater = catPlatform == 0 && abs(cat.position.x - waterBowl.position.x) < 30
            if stationary && nearFood {
                if action != .eat { action = .eat; cat.setNapping(false); cat.face(1) }
                energy = min(maxEnergy, energy + dtf * 16)
            } else if stationary && nearWater {
                if action != .drink { action = .drink; cat.setNapping(false); cat.face(1) }
                energy = min(maxEnergy, energy + dtf * 11)
            } else if stationary && inSun {
                if action != .nap { action = .nap; cat.setNapping(true) }
                energy = min(maxEnergy, energy + dtf * (7 + CGFloat(upNap) * 2))
            } else if action == .eat || action == .drink || action == .nap {
                action = .none; cat.setNapping(false)
            }
        }

        // suspicion — the risk/reward
        let climbing = climbLink != nil
        if isSeen {
            if climbing { susp = min(100, susp + dtf * 46) }
            else if onHigh && moveDir != 0 { susp = min(100, susp + dtf * 24) }
            else if onHigh { susp = min(100, susp + dtf * 12) }
            else if action == .nap || action == .eat || action == .drink || idle {
                susp = max(0, susp - dtf * (5 + CGFloat(upCharm)))
            } else { susp = max(0, susp - dtf * 1.5) }
            for b in breakables where b.messed {
                if hypot(cat.position.x - b.position.x, cat.position.y - b.position.y) < 56 { susp = min(100, susp + dtf * 9) }
            }
        } else {
            susp = max(0, susp - dtf * (idle || action == .nap ? 4 : 2))
        }

        tickAction(dt)
        spawnCollectibles(dt)
        autoCollect()
        if thoughtCooldown > 0 { thoughtCooldown -= dt }

        if susp >= 100 { return finish(caught: true) }
        syncHUD()
    }

    private func stepCat(_ dt: CGFloat) {
        // any movement intent cancels passive states (this is the nap-while-moving fix)
        if (moveDir != 0 || climbHeld) && (action == .eat || action == .drink || action == .nap) {
            action = .none; cat.setNapping(false)
        }
        guard action == .none || action == .nap else { return }

        // start a climb if requested and a link is in reach
        if climbHeld && climbLink == nil {
            if let l = nearestLink {
                let target = (l.lower == catPlatform) ? l.upper : l.lower
                let goingUp = platformWorldY(target) > cat.position.y
                if goingUp && energy < hopCost { showThought("too tired to climb — refuel first") }
                else {
                    climbLink = l; climbTarget = target
                    if goingUp { energy = max(0, energy - hopCost) }
                    if action == .nap { action = .none; cat.setNapping(false) }
                }
            }
        }

        // execute an in-progress climb
        if let l = climbLink {
            if action == .nap { action = .none; cat.setNapping(false) }
            let ty = platformWorldY(climbTarget)
            let dx = l.x - cat.position.x, dy = ty - cat.position.y
            let dist = max(0.001, hypot(dx, dy))
            if dist <= 2.5 {
                cat.position = CGPoint(x: l.x, y: ty); catPlatform = climbTarget; climbLink = nil
                cat.setWalking(false)
            } else {
                let step = min(dist, climbSpeed * dt)
                cat.position = CGPoint(x: cat.position.x + dx / dist * step, y: cat.position.y + dy / dist * step)
                cat.setWalking(true)
            }
            return
        }

        // horizontal walk along current platform
        if moveDir != 0 {
            if action == .nap { action = .none; cat.setNapping(false) }
            cat.face(moveDir > 0 ? 1 : -1)
            let p = platform(catPlatform)
            let lo = p.cx - p.width / 2 + 16, hi = p.cx + p.width / 2 - 16
            let nx = min(max(cat.position.x + moveDir * walkSpeed * dt, lo), hi)
            cat.position.x = nx
            cat.position.y = platformWorldY(catPlatform)
            cat.setWalking(true)
            energy = max(0, energy - dt * 0.35)
        } else {
            cat.setWalking(false)
        }
    }

    private func doSwat() {
        guard !ended, action == .none, climbLink == nil else { return }
        // nearest breakable on this platform within reach
        var target: BreakableSprite?; var bestD = swatRange
        for b in breakables where !b.messed && b.platformId == catPlatform {
            let d = abs(b.standX - cat.position.x)
            if d < bestD { bestD = d; target = b }
        }
        if let b = target {
            if energy < CGFloat(b.def.energyCost) { showThought("too tired to wreck that — refuel"); return }
            cat.face(b.standX >= cat.position.x ? 1 : -1)
            action = .knock; actT = 0; swatTarget = b; cat.knock(); return
        }
        // nearest loot box
        var loot: LootBox?; var bestL = swatRange
        for lb in lootBoxes where !lb.opened && lb.platformId == catPlatform {
            let d = abs(lb.position.x - cat.position.x)
            if d < bestL { bestL = d; loot = lb }
        }
        if let lb = loot { openLoot(lb); return }
        showThought("nothing to swat here")
    }

    private func tickAction(_ dt: Double) {
        guard action != .none else { return }
        actT += dt
        switch action {
        case .knock:
            if actT > 0.42, let b = swatTarget, !b.messed { commitCrime(b); swatTarget = nil; action = .none }
            else if actT > 0.8 { swatTarget = nil; action = .none }
        default: break
        }
    }

    private func commitCrime(_ b: BreakableSprite) {
        b.makeMessed()
        if !isSeen { combo = min(comboCap, combo + 1); comboTimer = comboWindow } else { combo = 0 }
        let valueMult = 1 + 0.15 * CGFloat(upValue)
        let gainChaos = Int(CGFloat(b.chaosValue) * valueMult * comboFactor)
        let gainCoins = Int(CGFloat(b.coinValue) * valueMult)
        chaos += gainChaos; runCoins += gainCoins; GameData.shared.addCoins(gainCoins)
        energy = max(0, energy - CGFloat(b.def.energyCost))
        SFX.crash(); shake()
        let label = combo >= 2 ? "+\(gainChaos)  ×\(combo)" : "+\(gainChaos)"
        popText(label, at: CGPoint(x: b.position.x, y: b.position.y + 44), color: combo >= 2 ? Palette.gold : Palette.flameDeep)

        if isSeen {
            susp = min(100, susp + 38)
            for w in watchers where w.node.gaze == .watch { w.node.mad = 1.2; w.node.setGaze(.watch, lookDir: lookDir(w)) }
            redFlash(); showThought("seen! that one stings")
        } else if !watchers.allSatisfy({ $0.node.gaze == .away }) {
            let heard = max(2, 8 - 2 * CGFloat(upPaws))
            susp = min(100, susp + heard)
            // a nearby distracted watcher might glance over
            for w in watchers where w.node.gaze == .distract {
                if abs(cat.position.x - w.node.position.x) < size.width * 0.5, Double.random(in: 0...1) < 0.5 {
                    w.next = .watch; w.timer = min(w.timer, 0.8)
                }
            }
        }
        syncHUD()
    }

    private func openLoot(_ lb: LootBox) {
        lb.open()
        let coins = Int(20 + lb.tier * 45) + Int.random(in: 0...12)
        let bonusChaos = Int(8 + lb.tier * 20)
        let gem = Double.random(in: 0...1) < (0.3 + Double(lb.tier) * 0.4)
        chaos += bonusChaos; runCoins += coins; GameData.shared.addCoins(coins)
        if gem { runCoins += 25; GameData.shared.addCoins(25) }
        SFX.coin(); shake()
        popText("+\(coins)🪙", at: CGPoint(x: lb.position.x, y: lb.position.y + 46), color: Palette.gold)
        popText("+\(bonusChaos)", at: CGPoint(x: lb.position.x, y: lb.position.y + 70), color: Palette.flameDeep)
        if gem { popText("💎+25", at: CGPoint(x: lb.position.x + 28, y: lb.position.y + 54), color: Palette.eye) }
        // loot is noisy
        if isSeen { susp = min(100, susp + 26) } else { susp = min(100, susp + max(2, 6 - CGFloat(upPaws))) }
        syncHUD()
    }

    // MARK: collectibles
    private func spawnCollectibles(_ dt: Double) {
        spawnTimer -= dt
        if spawnTimer <= 0 && collectibles.count < 3 {
            spawnTimer = Double.random(in: 4.5...7.5)
            let gem = Double.random(in: 0...1) < 0.2
            let pool = gem ? platforms.filter { $0.id != 0 } : platforms
            let plat = pool.randomElement() ?? platforms[0]
            let c = Collectible(value: gem ? 25 : 6, isGem: gem, platformId: plat.id)
            let x = min(max(CGFloat.random(in: (plat.cx - plat.width / 2 + 16)...(plat.cx + plat.width / 2 - 16)), 30), worldWidth - 30)
            c.position = CGPoint(x: x, y: platformWorldY(plat.id) + 16)
            c.alpha = 0; c.run(.fadeIn(withDuration: 0.3))
            world.addChild(c); collectibles.append(c)
        }
    }
    private func autoCollect() {
        for c in collectibles where hypot(cat.position.x - c.position.x, cat.position.y - c.position.y) < 32 {
            collect(c)
        }
    }
    private func collect(_ c: Collectible) {
        guard collectibles.contains(where: { $0 === c }) else { return }
        collectibles.removeAll { $0 === c }
        runCoins += c.value; GameData.shared.addCoins(c.value)
        SFX.coin(); popText("+\(c.value)🪙", at: c.position, color: Palette.gold)
        c.run(.sequence([.group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        syncHUD()
    }

    private func updateSun() {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: sunX - 44, y: floorY))
        p.addLine(to: CGPoint(x: sunX + 44, y: floorY))
        p.addLine(to: CGPoint(x: sunX + 70, y: 0))
        p.addLine(to: CGPoint(x: sunX - 70, y: 0))
        p.close()
        sunbeam.path = p.cgPath
    }

    private func updateCamera() {
        let camX = min(max(cat.position.x - size.width / 2, 0), max(0, worldWidth - size.width))
        let camY = min(max(cat.position.y - size.height * 0.42, 0), max(0, worldHeight - size.height))
        world.position = CGPoint(x: -camX, y: -camY)
    }

    // MARK: feedback
    private func shake() {
        run(.sequence([.moveBy(x: 5, y: 0, duration: 0.03), .moveBy(x: -10, y: 0, duration: 0.05), .moveBy(x: 5, y: 0, duration: 0.03)]))
    }
    private func redFlash() {
        let f = SKSpriteNode(color: UIColor(hex: 0xE2554B, alpha: 0.35), size: size)
        f.anchorPoint = .zero; f.zPosition = 80
        addChild(f); f.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
    private func popText(_ t: String, at p: CGPoint, color: UIColor) {
        let l = makeLabel(t, size: 18, color: color, weight: .black)
        l.position = p; l.zPosition = 70; world.addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 34, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }
    private func showThought(_ text: String) {
        guard size.width > 0, thoughtCooldown <= 0 else { return }
        thoughtCooldown = 1.8
        thoughtNode?.removeFromParent()
        let node = SKNode()
        let label = makeLabel(text, size: 12, color: Palette.ink, weight: .semibold)
        label.preferredMaxLayoutWidth = min(210, size.width - 70)
        label.numberOfLines = 0; label.verticalAlignmentMode = .center
        let w = max(60, min(label.frame.width + 22, size.width - 40))
        let h = max(28, label.frame.height + 16)
        let bubble = roundedPanel(CGSize(width: w, height: h), fill: Palette.panel, corner: 12, shadow: false)
        node.addChild(bubble); node.addChild(label)
        node.position = CGPoint(x: min(max(cat.position.x, w / 2 + 8), worldWidth - w / 2 - 8), y: cat.position.y + 86)
        node.zPosition = 65
        world.addChild(node); thoughtNode = node
        node.run(.sequence([.wait(forDuration: 2.2), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: end
    private func finish(caught: Bool) {
        guard !ended else { return }
        ended = true
        cat.setWalking(false)
        var stars = 0
        if !caught {
            stars = chaos >= Int(Double(cfg.target) * 1.6) ? 3 : (chaos >= cfg.target ? 2 : 1)
            GameData.shared.setStars(room: roomId, day: day, value: stars)
            let bonus = cfg.target / 2
            runCoins += bonus; GameData.shared.addCoins(bonus)
            SFX.win()
        } else { SFX.caught() }
        showResults(caught: caught, stars: stars)
    }

    private func showResults(caught: Bool, stars: Int) {
        let dim = SKSpriteNode(color: UIColor(hex: 0x4A3526, alpha: 0.5), size: size)
        dim.anchorPoint = .zero; dim.zPosition = 100; addChild(dim)
        let cardW = min(330, size.width - 44), cardH: CGFloat = 320
        let card = roundedPanel(CGSize(width: cardW, height: cardH), fill: Palette.panel, corner: 24)
        card.position = CGPoint(x: size.width / 2, y: size.height / 2); card.zPosition = 101; addChild(card)

        let title = makeLabel(caught ? "BUSTED!" : "Day \(day + 1) survived", size: 24, color: Palette.ink, weight: .black)
        title.position = CGPoint(x: 0, y: cardH / 2 - 40); card.addChild(title)
        if !caught {
            let st = makeLabel(String(repeating: "★", count: stars) + String(repeating: "·", count: 3 - stars), size: 36, color: Palette.gold, weight: .heavy)
            st.position = CGPoint(x: 0, y: cardH / 2 - 86); card.addChild(st)
        }
        let chaosL = makeLabel("Mischief: \(chaos)   ·   goal \(cfg.target)", size: 15, color: Palette.inkSoft, weight: .bold)
        chaosL.position = CGPoint(x: 0, y: cardH / 2 - 132); card.addChild(chaosL)
        let coinsL = makeLabel("Coins earned: \(runCoins) 🪙", size: 16, color: Palette.flameDeep, weight: .heavy)
        coinsL.position = CGPoint(x: 0, y: cardH / 2 - 160); card.addChild(coinsL)

        let bw = cardW - 48
        let hasNext = !caught && day + 1 < room.days
        let primary = ButtonNode(caught ? "Try again" : (hasNext ? "Next day" : "Back to rooms"),
                                 size: CGSize(width: bw, height: 50), fill: Palette.ink, fontSize: 18)
        primary.position = CGPoint(x: 0, y: -cardH / 2 + 92); primary.zPosition = 102
        primary.onTap = { [weak self] in
            guard let s = self else { return }
            if caught { s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: s.day), .fade(withDuration: 0.3)) }
            else if hasNext { s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: s.day + 1), .fade(withDuration: 0.3)) }
            else { s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        }
        card.addChild(primary)

        let row = SKNode(); row.position = CGPoint(x: 0, y: -cardH / 2 + 38); card.addChild(row)
        let half = (bw - 12) / 2
        let shopB = ButtonNode("Shop", size: CGSize(width: half, height: 44), fill: Palette.flame, fontSize: 16)
        shopB.position = CGPoint(x: -half / 2 - 6, y: 0)
        shopB.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: ShopScene(size: s.size), .fade(withDuration: 0.3)) }
        row.addChild(shopB)
        let roomsB = ButtonNode("Levels", size: CGSize(width: half, height: 44), fill: UIColor(hex: 0x4A3526, alpha: 0.1), textColor: Palette.ink, fontSize: 16)
        roomsB.position = CGPoint(x: half / 2 + 6, y: 0)
        roomsB.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        row.addChild(roomsB)

        card.setScale(0.8); card.alpha = 0
        card.run(.group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.25)]))
    }
}
