import SpriteKit
import UIKit

// MARK: - Breakable sprite
final class BreakableSprite: SKNode {
    let def: Breakable
    let platformId: Int
    let standX: CGFloat          // world x the cat stands at to knock it
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
        // value tag so the reward of climbing high is legible
        let v = Int(CGFloat(placement.def.chaos) * placement.mult)
        let tag = makeLabel("+\(v)", size: 11, color: placement.mult > 1.4 ? Palette.gold : Palette.inkSoft, weight: .heavy)
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
    func highlight(_ on: Bool) {
        removeAction(forKey: "sel")
        if on {
            run(.repeatForever(.sequence([.scale(to: 1.14, duration: 0.4), .scale(to: 1.0, duration: 0.4)])), withKey: "sel")
        } else { run(.scale(to: 1, duration: 0.15)) }
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

// MARK: - Waypoint for route following
private struct Waypoint {
    let x: CGFloat
    let y: CGFloat
    let climb: Bool      // a vertical hop between platforms
    let platform: Int    // platform the cat is on once this waypoint is reached
}

// MARK: - Game
final class GameScene: BaseScene {
    let roomId: String
    let day: Int
    private let room: RoomDef
    private let cfg: (target: Int, length: Double, vigilance: Double)

    // actors
    private let cat = CatNode()
    private let human = HumanNode()
    private var sunbeam: SKShapeNode!
    private var breakables: [BreakableSprite] = []
    private var collectibles: [Collectible] = []
    private var foodBowl: SKNode!
    private var waterBowl: SKNode!

    // world / layout
    private var world: SKNode!
    private var layout: LevelLayout!
    private var platforms: [PlatformDef] = []
    private var adjacency: [Int: [Int]] = [:]
    private var worldWidth: CGFloat = 0
    private var worldHeight: CGFloat = 0
    private var floorY: CGFloat = 0
    private var routePreview: SKShapeNode?

    // state
    private var energy: CGFloat = 70
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

    // cat control / movement
    private enum Action { case none, knock, eat, drink, nap }
    private var action: Action = .none
    private var actT: Double = 0
    private var path: [Waypoint] = []
    private var targetObj: AnyObject?
    private var catPlatform = 0
    private var isHopping = false
    private var hopCharged = false       // paid stamina for the current up-hop yet

    // tuning
    private let walkSpeed: CGFloat = 168
    private let climbSpeed: CGFloat = 132
    private var hopCost: CGFloat { max(8, 16 - CGFloat(upBelly)) }

    // human gaze
    private var gazeTimer: Double = 4
    private var nextGaze: HumanNode.Gaze = .watch

    // HUD
    private var energyBar: BarNode!
    private var suspBar: BarNode!
    private var chaosLabel: SKLabelNode!
    private var coinLabel: SKLabelNode!
    private var dayBar: BarNode!
    private var comboLabel: SKLabelNode!
    private var bannerLabel: SKLabelNode!
    private var bannerPanel: SKShapeNode!
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
        debugCheckpoint("Game.build:start \(roomId) d\(day)")
        if size.width <= 0 || size.height <= 0 { size = CGSize(width: 390, height: 844) }
        backgroundColor = room.wall
        let d = GameData.shared
        upPaws = d.upgradeLevel("up_paws"); upBelly = d.upgradeLevel("up_belly")
        upNap = d.upgradeLevel("up_nap"); upCharm = d.upgradeLevel("up_charm"); upValue = d.upgradeLevel("up_value")
        maxEnergy = 100 + CGFloat(upBelly) * 20
        energy = min(75, maxEnergy)

        floorY = bottomInset + 150 + 24
        layout = Content.layout(roomId: roomId, day: day, screen: size, floorY: floorY)
        platforms = layout.platforms
        worldWidth = layout.worldWidth
        worldHeight = layout.worldHeight
        buildAdjacency()
        debugCheckpoint("Game.build:layout")

        world = SKNode(); addChild(world)
        buildRoom();        debugCheckpoint("Game.build:room")
        buildPlatforms();   debugCheckpoint("Game.build:platforms")
        buildBowls();       debugCheckpoint("Game.build:bowls")
        buildBreakables();  debugCheckpoint("Game.build:breakables")

        human.position = CGPoint(x: min(worldWidth - 70, size.width * 0.86), y: floorY)
        human.setScale(min(1.1, size.width / 390))
        world.addChild(human)
        debugCheckpoint("Game.build:human")

        cat.position = CGPoint(x: worldWidth * 0.42, y: floorY)
        cat.baseScale = min(1.12, size.width / 360)
        catPlatform = 0
        world.addChild(cat)
        debugCheckpoint("Game.build:cat")

        buildHUD();         debugCheckpoint("Game.build:hud")
        setGaze(.distract)
        updateCamera()
        debugCheckpoint("Game.build:done")
    }

    private func buildAdjacency() {
        adjacency = [:]
        for l in layout.links {
            adjacency[l.lower, default: []].append(l.upper)
            adjacency[l.upper, default: []].append(l.lower)
        }
    }

    private func platformWorldY(_ id: Int) -> CGFloat {
        guard id >= 0 && id < platforms.count else { return floorY }
        return floorY + platforms[id].topY
    }
    private func platform(_ id: Int) -> PlatformDef {
        (id >= 0 && id < platforms.count) ? platforms[id] : platforms[0]
    }
    private func linkBetween(_ a: Int, _ b: Int) -> LinkDef? {
        layout.links.first { ($0.lower == a && $0.upper == b) || ($0.lower == b && $0.upper == a) }
    }

    // MARK: build world
    private func buildRoom() {
        let wall = SKSpriteNode(color: room.wall, size: CGSize(width: worldWidth, height: worldHeight))
        wall.anchorPoint = .zero; wall.zPosition = -100; world.addChild(wall)
        let floor = SKSpriteNode(color: Palette.wood, size: CGSize(width: worldWidth, height: floorY))
        floor.anchorPoint = .zero; floor.zPosition = -90; world.addChild(floor)
        // baseboard
        let base = SKSpriteNode(color: Palette.woodDeep, size: CGSize(width: worldWidth, height: 6))
        base.anchorPoint = .zero; base.position = CGPoint(x: 0, y: floorY); base.zPosition = -89; world.addChild(base)
        // windows scattered along the wall
        for wx in stride(from: size.width * 0.16, to: worldWidth, by: size.width * 0.7) {
            let win = SKShapeNode(rect: CGRect(x: wx, y: floorY + 120, width: 96, height: 120), cornerRadius: 6)
            win.fillColor = UIColor(hex: 0xBFE3F2); win.strokeColor = Palette.woodDeep; win.lineWidth = 5; win.zPosition = -80
            world.addChild(win)
        }
        // sunbeam pool on the floor
        sunbeam = SKShapeNode()
        sunbeam.fillColor = Palette.sun; sunbeam.strokeColor = .clear; sunbeam.alpha = 0.34; sunbeam.zPosition = -70
        world.addChild(sunbeam)
    }

    private func buildPlatforms() {
        // climb posts (hint where you can go vertical)
        for l in layout.links {
            let yLo = platformWorldY(l.lower), yHi = platformWorldY(l.upper)
            let post = SKShapeNode(rect: CGRect(x: l.x - 5, y: yLo, width: 10, height: yHi - yLo), cornerRadius: 4)
            post.fillColor = UIColor(hex: 0x8B6A45, alpha: 0.5); post.strokeColor = .clear; post.zPosition = -78
            world.addChild(post)
            var rungY = yLo + 16
            while rungY < yHi {
                let rung = SKShapeNode(rect: CGRect(x: l.x - 9, y: rungY, width: 18, height: 4), cornerRadius: 2)
                rung.fillColor = UIColor(hex: 0x8B6A45, alpha: 0.7); rung.strokeColor = .clear; rung.zPosition = -77
                world.addChild(rung); rungY += 22
            }
        }
        // platform surfaces
        for p in platforms where p.id != 0 {
            let y = floorY + p.topY
            let surf = SKShapeNode(rect: CGRect(x: p.cx - p.width / 2, y: y - 12, width: p.width, height: 14), cornerRadius: 4)
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
        foodBowl = bowl(worldWidth * 0.08, Palette.flameDeep, "🐟", 16); world.addChild(foodBowl)
        waterBowl = bowl(worldWidth * 0.15, Palette.water, "💧", 14); world.addChild(waterBowl)
    }

    private func buildBreakables() {
        for pl in layout.placements {
            let y = platformWorldY(pl.platform)
            let s = BreakableSprite(placement: pl, worldY: y)
            world.addChild(s); breakables.append(s)
        }
    }

    // MARK: HUD
    private func buildHUD() {
        let quit = ButtonNode("✕", size: CGSize(width: 38, height: 38), fill: Palette.panel, textColor: Palette.ink, fontSize: 18)
        quit.position = CGPoint(x: 32, y: size.height - topInset - 24)
        quit.onTap = { [weak self] in guard let s = self else { return }
            s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        quit.zPosition = 60; addChild(quit)

        let coinChip = roundedPanel(CGSize(width: 104, height: 34), fill: Palette.panel, corner: 17)
        coinChip.position = CGPoint(x: size.width - 66, y: size.height - topInset - 24); coinChip.zPosition = 60
        addChild(coinChip)
        let ci = SKShapeNode(circleOfRadius: 8); ci.fillColor = Palette.gold; ci.strokeColor = .clear; ci.position = CGPoint(x: -36, y: 0); coinChip.addChild(ci)
        coinLabel = makeLabel("\(GameData.shared.coins)", size: 16, color: Palette.ink, weight: .heavy, h: .left)
        coinLabel.position = CGPoint(x: -20, y: 0); coinChip.addChild(coinLabel)

        bannerPanel = roundedPanel(CGSize(width: 250, height: 30), fill: UIColor(hex: 0xFBF6EE, alpha: 0.92), corner: 15)
        bannerPanel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 64); bannerPanel.zPosition = 60
        addChild(bannerPanel)
        bannerLabel = makeLabel("", size: 14, color: Palette.inkSoft, weight: .heavy)
        bannerPanel.addChild(bannerLabel)

        comboLabel = makeLabel("", size: 22, color: Palette.flameDeep, weight: .black)
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 104); comboLabel.zPosition = 60
        addChild(comboLabel)

        let hud = roundedPanel(CGSize(width: size.width, height: 150 + bottomInset), fill: UIColor(hex: 0xA6B095, alpha: 0.96), corner: 0, shadow: false)
        hud.position = CGPoint(x: size.width / 2, y: (150 + bottomInset) / 2); hud.zPosition = 55; addChild(hud)

        let barW = (size.width - 60) * 0.42
        energyBar = BarNode(width: barW, color: Palette.energy)
        energyBar.position = CGPoint(x: -size.width / 2 + 24, y: 28); hud.addChild(energyBar)
        let eLab = makeLabel("STAMINA", size: 10, color: Palette.ink, weight: .heavy, h: .left); eLab.position = CGPoint(x: -size.width / 2 + 24, y: 44); hud.addChild(eLab)

        suspBar = BarNode(width: barW, color: Palette.susp)
        suspBar.position = CGPoint(x: 6, y: 28); hud.addChild(suspBar)
        let sLab = makeLabel("SUSPICION", size: 10, color: Palette.ink, weight: .heavy, h: .left); sLab.position = CGPoint(x: 6, y: 44); hud.addChild(sLab)

        chaosLabel = makeLabel("0", size: 26, color: Palette.ink, weight: .black, h: .right)
        chaosLabel.position = CGPoint(x: size.width / 2 - 24, y: 24); hud.addChild(chaosLabel)
        let cLab = makeLabel("MISCHIEF", size: 10, color: Palette.ink, weight: .heavy, h: .right); cLab.position = CGPoint(x: size.width / 2 - 24, y: 46); hud.addChild(cLab)

        dayBar = BarNode(width: size.width - 48, height: 6, color: Palette.gold)
        dayBar.position = CGPoint(x: -size.width / 2 + 24, y: -4); hud.addChild(dayBar)
        let goal = makeLabel("Day \(day + 1) · goal \(cfg.target) mischief", size: 11, color: Palette.ink, weight: .bold, h: .left)
        goal.position = CGPoint(x: -size.width / 2 + 24, y: -20); hud.addChild(goal)
        syncHUD()
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
    }
    private var comboFactor: CGFloat { combo >= 2 ? 1 + 0.4 * CGFloat(combo - 1) : 1 }

    private func setBanner() {
        let g = human.gaze
        var txt = ""; var col = Palette.inkSoft
        let telegraph = (nextGaze == .watch && g == .distract && gazeTimer < 0.9)
        if g == .watch { txt = "👀  WATCHING — freeze or act cute"; col = UIColor(hex: 0xB23A2E) }
        else if telegraph { txt = "⚠  about to look up…"; col = UIColor(hex: 0xC98A2E) }
        else if g == .distract { txt = "📱  distracted — make your move"; col = Palette.good }
        else { txt = "🚪  gone — free reign!"; col = Palette.good }
        bannerLabel.text = txt; bannerLabel.fontColor = col
    }

    // MARK: gaze AI
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
    private func setGaze(_ g: HumanNode.Gaze) {
        switch g {
        case .watch: gazeTimer = Double.random(in: 2.4...4.4) - Double(Content.roomIndex(roomId)) * 0.1
        case .distract: gazeTimer = Double.random(in: 3.0...6.0)
        case .away: gazeTimer = Double.random(in: 4.0...7.0)
        }
        nextGaze = planNext(g)
        human.setGaze(g, lookDir: lookDir)
        if g == .away { tidyOne() }
    }
    private var lookDir: CGFloat { max(-1, min(1, (cat.position.x - human.position.x) / 140)) }
    private func tidyOne() {
        if let one = breakables.filter({ $0.messed }).randomElement(), Double.random(in: 0...1) < 0.8 { one.restore() }
    }
    private var watching: Bool { human.gaze == .watch }
    private var inRoom: Bool { human.gaze != .away }
    private var idle: Bool { path.isEmpty && action == .none }
    private var onHigh: Bool { catPlatform != 0 }

    // MARK: input — pick a target and plot a climbing route to it
    override func worldTouch(at point: CGPoint) {
        guard !ended else { return }
        let p = convert(point, to: world)
        var pick: AnyObject?
        var best: CGFloat = 60
        for b in breakables where !b.messed {
            let d = hypot(p.x - b.position.x, p.y - (b.position.y + 18))
            if d < best { best = d; pick = b }
        }
        for c in collectibles {
            let d = hypot(p.x - c.position.x, p.y - c.position.y)
            if d < best { best = d; pick = c }
        }
        let bowls: [SKNode] = [foodBowl, waterBowl]
        for bw in bowls {
            let d = hypot(p.x - bw.position.x, p.y - bw.position.y)
            if d < best { best = d; pick = bw }
        }
        breakables.forEach { $0.highlight(false) }

        if let b = pick as? BreakableSprite {
            b.highlight(true)
            routeTo(platform: b.platformId, finalX: b.standX, obj: b)
        } else if let c = pick as? Collectible {
            routeTo(platform: c.platformId, finalX: c.position.x, obj: c)
        } else if let bw = pick as? SKNode {
            routeTo(platform: 0, finalX: bw.position.x, obj: bw)
        } else {
            // walk to the nearest platform surface under the tap
            let target = nearestPlatform(to: p)
            let span = platform(target)
            let fx = min(max(p.x, span.cx - span.width / 2 + 16), span.cx + span.width / 2 - 16)
            routeTo(platform: target, finalX: fx, obj: nil)
        }
    }

    private func nearestPlatform(to p: CGPoint) -> Int {
        var bestId = 0; var bestD = CGFloat.greatestFiniteMagnitude
        for plat in platforms {
            let sx = min(max(p.x, plat.cx - plat.width / 2), plat.cx + plat.width / 2)
            let sy = floorY + plat.topY
            let d = hypot(p.x - sx, p.y - sy)
            if d < bestD { bestD = d; bestId = plat.id }
        }
        return bestId
    }

    // Breadth-first search over the climb graph.
    private func route(from: Int, to: Int) -> [Int] {
        if from == to { return [from] }
        var prev: [Int: Int] = [:]
        var queue = [from]; var seen: Set<Int> = [from]
        var head = 0
        while head < queue.count {
            let cur = queue[head]; head += 1
            for n in adjacency[cur] ?? [] where !seen.contains(n) {
                seen.insert(n); prev[n] = cur; queue.append(n)
                if n == to {
                    var path = [to]; var c = to
                    while let p = prev[c] { path.append(p); c = p }
                    return path.reversed()
                }
            }
        }
        return [from]
    }

    private func routeTo(platform target: Int, finalX: CGFloat, obj: AnyObject?) {
        action = .none; actT = 0; isHopping = false; hopCharged = false
        let plats = route(from: catPlatform, to: target)
        var wps: [Waypoint] = []
        var cur = catPlatform
        for nxt in plats.dropFirst() {
            guard let link = linkBetween(cur, nxt) else { break }
            wps.append(Waypoint(x: link.x, y: platformWorldY(cur), climb: false, platform: cur))
            wps.append(Waypoint(x: link.x, y: platformWorldY(nxt), climb: true, platform: nxt))
            cur = nxt
        }
        wps.append(Waypoint(x: finalX, y: platformWorldY(target), climb: false, platform: target))
        path = wps
        targetObj = obj
        drawRoutePreview()
    }

    private func drawRoutePreview() {
        routePreview?.removeFromParent()
        guard !path.isEmpty else { routePreview = nil; return }
        let p = UIBezierPath()
        p.move(to: cat.position)
        for wp in path { p.addLine(to: CGPoint(x: wp.x, y: wp.y)) }
        let dashed = p.cgPath.copy(dashingWithPhase: 0, lengths: [8, 7])
        let line = SKShapeNode(path: dashed)
        line.strokeColor = UIColor(hex: 0x4A3526, alpha: 0.4); line.lineWidth = 3
        line.lineCap = .round; line.zPosition = -40
        world.addChild(line); routePreview = line
    }

    // MARK: loop
    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime; debugCheckpoint("Game.update:first") }
        var dt = currentTime - lastTime; lastTime = currentTime
        dt = min(dt, 0.05)
        if ended { return }
        let dtf = CGFloat(dt)

        dayT += dt
        sunX = worldWidth * (0.06 + 0.16 * CGFloat(dayT / cfg.length))
        updateSun()
        if dayT >= cfg.length { return finish(caught: false) }

        // gaze
        gazeTimer -= dt
        if gazeTimer <= 0 { setGaze(nextGaze) }
        else if watching { human.lookAt(lookDir) }
        setBanner()

        // movement
        moveAlongPath(dtf)
        updateCamera()

        // passive drains
        energy = max(0, min(maxEnergy, energy - dtf * 0.2))

        // combo decay
        if comboTimer > 0 { comboTimer -= dt; if comboTimer <= 0 { combo = 0 } }

        // refuel + innocence
        let inSun = !onHigh && abs(cat.position.x - sunX) < size.width * 0.08
        if action == .nap || (idle && inSun) {
            if action != .nap { action = .nap; cat.setNapping(true) }
            energy = min(maxEnergy, energy + dtf * (7 + CGFloat(upNap) * 2))
        } else if action == .eat {
            energy = min(maxEnergy, energy + dtf * 16)
        } else if action == .drink {
            energy = min(maxEnergy, energy + dtf * 11)
        }

        // suspicion: the heart of the risk/reward
        if watching {
            if isHopping { susp = min(100, susp + dtf * 46) }           // climbing in plain sight
            else if onHigh && !idle { susp = min(100, susp + dtf * 24) } // moving around up high
            else if onHigh { susp = min(100, susp + dtf * 11) }          // lurking somewhere you shouldn't be
            else if action == .nap || action == .eat || action == .drink || idle {
                susp = max(0, susp - dtf * (5 + CGFloat(upCharm)))       // act innocent on the floor
            } else {
                susp = max(0, susp - dtf * 1.5)
            }
            // caught red-handed next to a fresh mess
            for b in breakables where b.messed {
                if hypot(cat.position.x - b.position.x, cat.position.y - b.position.y) < 56 {
                    susp = min(100, susp + dtf * 10)
                }
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

    private func updateSun() {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: sunX - 42, y: floorY))
        p.addLine(to: CGPoint(x: sunX + 42, y: floorY))
        p.addLine(to: CGPoint(x: sunX + 66, y: floorY - floorY))   // taper to bottom of floor area
        p.addLine(to: CGPoint(x: sunX - 66, y: floorY - floorY))
        p.close()
        sunbeam.path = p.cgPath
    }

    private func updateCamera() {
        let camX = min(max(cat.position.x - size.width / 2, 0), max(0, worldWidth - size.width))
        let camY = min(max(cat.position.y - size.height * 0.46, 0), max(0, worldHeight - size.height))
        world.position = CGPoint(x: -camX, y: -camY)
    }

    private func moveAlongPath(_ dt: CGFloat) {
        guard action == .none || action == .nap else { return }
        guard let wp = path.first else {
            cat.setWalking(false); isHopping = false
            if let obj = targetObj { targetObj = nil; clearPreview(); beginAction(on: obj) }
            return
        }
        if action == .nap { action = .none; cat.setNapping(false) }

        let dx = wp.x - cat.position.x
        let dy = wp.y - cat.position.y

        if wp.climb {
            let goingUp = dy > 1
            if goingUp && !hopCharged {
                if energy < hopCost { abortPath("too tired to climb — eat or nap first"); return }
                energy = max(0, energy - hopCost); hopCharged = true
            }
            isHopping = true
            let dist = max(0.001, hypot(dx, dy))
            let step = min(dist, climbSpeed * dt)
            if dist <= 2.5 {
                cat.position = CGPoint(x: wp.x, y: wp.y)
                catPlatform = wp.platform
                isHopping = false; hopCharged = false
                path.removeFirst()
            } else {
                cat.position = CGPoint(x: cat.position.x + dx / dist * step, y: cat.position.y + dy / dist * step)
                cat.setWalking(true)
            }
        } else {
            isHopping = false
            if abs(dx) <= 2.5 {
                cat.position = CGPoint(x: wp.x, y: wp.y)
                catPlatform = wp.platform
                path.removeFirst()
            } else {
                cat.face(dx > 0 ? 1 : -1)
                let step = min(abs(dx), walkSpeed * dt)
                cat.position.x += (dx > 0 ? 1 : -1) * step
                cat.position.y = wp.y
                cat.setWalking(true)
                energy = max(0, energy - dt * 0.35)
            }
        }
    }

    private func abortPath(_ msg: String) {
        path.removeAll(); targetObj = nil; isHopping = false; hopCharged = false
        cat.setWalking(false); clearPreview()
        showThought(msg)
    }
    private func clearPreview() { routePreview?.removeFromParent(); routePreview = nil }

    private func beginAction(on obj: AnyObject) {
        if let b = obj as? BreakableSprite {
            if b.messed { return }
            if energy < CGFloat(b.def.energyCost) { showThought("too tired to wreck that — refuel first"); b.highlight(false); return }
            action = .knock; actT = 0; cat.face(b.position.x >= cat.position.x ? 1 : -1); cat.knock()
        } else if let c = obj as? Collectible {
            collect(c)
        } else if obj === foodBowl {
            action = .eat; actT = 0; cat.face(1)
        } else if obj === waterBowl {
            action = .drink; actT = 0; cat.face(1)
        }
    }

    private func tickAction(_ dt: Double) {
        guard action != .none else { return }
        actT += dt
        switch action {
        case .eat: if actT > 2.2 { action = .none }
        case .drink: if actT > 1.8 { action = .none }
        case .knock:
            if actT > 0.42, let b = breakables.first(where: { !$0.messed && abs($0.standX - cat.position.x) < 50 && abs($0.position.y - cat.position.y) < 40 }) {
                commitCrime(b); action = .none
            } else if actT > 0.8 { action = .none }
        default: break
        }
    }

    private func commitCrime(_ b: BreakableSprite) {
        b.makeMessed(); b.highlight(false)

        // combo: chaining while unseen builds a multiplier
        if !watching {
            combo = min(comboCap, combo + 1); comboTimer = comboWindow
        } else {
            combo = 0
        }
        let valueMult = 1 + 0.15 * CGFloat(upValue)
        let gainChaos = Int(CGFloat(b.chaosValue) * valueMult * comboFactor)
        let gainCoins = Int(CGFloat(b.coinValue) * valueMult)
        chaos += gainChaos
        runCoins += gainCoins
        GameData.shared.addCoins(gainCoins)
        energy = max(0, energy - CGFloat(b.def.energyCost))
        SFX.crash(); shake()

        let label = combo >= 2 ? "+\(gainChaos)  ×\(combo)" : "+\(gainChaos)"
        popText(label, at: CGPoint(x: b.position.x, y: b.position.y + 44), color: combo >= 2 ? Palette.gold : Palette.flameDeep)

        if watching {
            susp = min(100, susp + 38); human.mad = 1.2
            human.setGaze(.watch, lookDir: lookDir); redFlash()
            showThought("seen! that one's going to cost me")
        } else if inRoom {
            let heard = max(2, 8 - 2 * CGFloat(upPaws))
            susp = min(100, susp + heard)
            if human.gaze == .distract && Double.random(in: 0...1) < 0.6 { nextGaze = .watch; gazeTimer = min(gazeTimer, 0.8) }
        }
        syncHUD()
    }

    // MARK: collectibles
    private func spawnCollectibles(_ dt: Double) {
        spawnTimer -= dt
        if spawnTimer <= 0 && collectibles.count < 3 {
            spawnTimer = Double.random(in: 4.5...7.5)
            let gem = Double.random(in: 0...1) < 0.2
            // bias gems onto high platforms so climbing pays off
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
        for c in collectibles where hypot(cat.position.x - c.position.x, cat.position.y - c.position.y) < 30 {
            collect(c)
        }
    }
    private func collect(_ c: Collectible) {
        guard collectibles.contains(where: { $0 === c }) else { return }
        collectibles.removeAll { $0 === c }
        runCoins += c.value; GameData.shared.addCoins(c.value)
        SFX.coin(); popText("+\(c.value)🪙", at: c.position, color: Palette.gold)
        if targetObj === c { targetObj = nil; path.removeAll(); clearPreview() }
        c.run(.sequence([.group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        syncHUD()
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
        cat.setWalking(false); clearPreview()
        var stars = 0
        if !caught {
            stars = chaos >= Int(Double(cfg.target) * 1.6) ? 3 : (chaos >= cfg.target ? 2 : 1)
            GameData.shared.setStars(room: roomId, day: day, value: stars)
            let bonus = cfg.target / 2
            runCoins += bonus; GameData.shared.addCoins(bonus)
            SFX.win()
        } else {
            SFX.caught()
        }
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
