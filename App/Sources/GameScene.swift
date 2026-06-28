import SpriteKit
import UIKit

// MARK: - Breakable sprite
final class BreakableSprite: SKNode {
    let def: Breakable
    let approachX: CGFloat
    private(set) var messed = false
    private let icon: SKLabelNode
    private var surface: SKShapeNode?

    init(def: Breakable, x: CGFloat, floorY: CGFloat, topPx: CGFloat) {
        self.def = def
        self.approachX = x
        self.icon = makeLabel(BreakableSprite.emoji(def.kind), size: 30)
        super.init()
        position = CGPoint(x: x, y: floorY)
        if topPx > 8 {
            let s = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: -28, y: topPx - 4, width: 56, height: 7), cornerRadius: 3).cgPath)
            s.fillColor = Palette.woodDeep; s.strokeColor = .clear
            // legs to floor for tables
            if topPx < 120 {
                let l1 = SKShapeNode(rect: CGRect(x: -22, y: 0, width: 5, height: topPx - 4)); l1.fillColor = Palette.woodDeep; l1.strokeColor = .clear
                let l2 = SKShapeNode(rect: CGRect(x: 17, y: 0, width: 5, height: topPx - 4)); l2.fillColor = Palette.woodDeep; l2.strokeColor = .clear
                s.addChild(l1); s.addChild(l2)
            }
            addChild(s); surface = s
        }
        icon.position = CGPoint(x: 0, y: topPx + 16)
        addChild(icon)
    }
    required init?(coder: NSCoder) { fatalError() }

    func makeMessed() {
        guard !messed else { return }
        messed = true
        icon.run(.group([
            .move(to: CGPoint(x: CGFloat.random(in: -14...14), y: 6), duration: 0.25),
            .rotate(toAngle: .pi/2, duration: 0.25),
            .fadeAlpha(to: 0.45, duration: 0.25)
        ]))
    }
    func restore() {
        messed = false
        icon.removeAllActions()
        icon.alpha = 1; icon.zRotation = 0
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
    init(value: Int, isGem: Bool) {
        self.value = value; self.isGem = isGem
        super.init()
        let l = makeLabel(isGem ? "💎" : "🪙", size: isGem ? 26 : 22)
        addChild(l)
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.6), .moveBy(x: 0, y: -6, duration: 0.6)])))
    }
    required init?(coder: NSCoder) { fatalError() }
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

    // state
    private var energy: CGFloat = 70
    private var maxEnergy: CGFloat = 100
    private var susp: CGFloat = 12
    private var chaos = 0
    private var runCoins = 0
    private var dayT: Double = 0
    private var sunX: CGFloat = 0
    private var ended = false
    private var lastTime: TimeInterval = 0
    private var floorY: CGFloat = 0
    private var spawnTimer: Double = 4

    // cat control
    private enum Action { case none, knock, eat, drink, nap }
    private var action: Action = .none
    private var actT: Double = 0
    private var targetX: CGFloat?
    private var targetObj: AnyObject?

    // human gaze
    private var gazeTimer: Double = 4
    private var nextGaze: HumanNode.Gaze = .watch

    // HUD
    private var energyBar: BarNode!
    private var suspBar: BarNode!
    private var chaosLabel: SKLabelNode!
    private var coinLabel: SKLabelNode!
    private var dayBar: BarNode!
    private var bannerLabel: SKLabelNode!
    private var bannerPanel: SKShapeNode!
    private var thoughtNode: SKNode?

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
        let d = GameData.shared
        upPaws = d.upgradeLevel("up_paws"); upBelly = d.upgradeLevel("up_belly")
        upNap = d.upgradeLevel("up_nap"); upCharm = d.upgradeLevel("up_charm"); upValue = d.upgradeLevel("up_value")
        maxEnergy = 100 + CGFloat(upBelly) * 20
        energy = min(70, maxEnergy)

        floorY = bottomInset + 150 + 30
        buildRoom()
        buildBowls()
        buildBreakables()

        human.position = CGPoint(x: size.width * 0.84, y: floorY)
        human.setScale(min(1.1, size.width / 390))
        addChild(human)

        cat.position = CGPoint(x: size.width * 0.4, y: floorY)
        cat.baseScale = min(1.15, size.width / 360)
        addChild(cat)

        buildHUD()
        setGaze(.distract)
        showThought("that vase looks unstable. let me help")
    }

    // MARK: build world
    private func buildRoom() {
        let wall = SKSpriteNode(color: room.wall, size: CGSize(width: size.width, height: size.height))
        wall.anchorPoint = .zero; wall.zPosition = -100; addChild(wall)
        let woodH = floorY
        let floor = SKSpriteNode(color: Palette.wood, size: CGSize(width: size.width, height: woodH))
        floor.anchorPoint = .zero; floor.zPosition = -90; addChild(floor)
        // window
        let win = SKShapeNode(rect: CGRect(x: size.width*0.12, y: size.height*0.62, width: size.width*0.22, height: size.height*0.2), cornerRadius: 6)
        win.fillColor = UIColor(hex: 0xBFE3F2); win.strokeColor = Palette.woodDeep; win.lineWidth = 5; win.zPosition = -80
        addChild(win)
        // sunbeam
        sunbeam = SKShapeNode()
        sunbeam.fillColor = Palette.sun; sunbeam.strokeColor = .clear; sunbeam.alpha = 0.32; sunbeam.zPosition = -70
        addChild(sunbeam)
    }
    private func buildBowls() {
        func bowl(_ x: CGFloat, _ color: UIColor) -> SKNode {
            let n = SKNode(); n.position = CGPoint(x: x, y: floorY)
            let dish = SKShapeNode(ellipseIn: CGRect(x: -20, y: -8, width: 40, height: 16))
            dish.fillColor = color; dish.strokeColor = .clear; n.addChild(dish)
            return n
        }
        foodBowl = bowl(size.width * 0.10, Palette.flameDeep)
        let fl = makeLabel("🐟", size: 16); fl.position = CGPoint(x: 0, y: 0); foodBowl.addChild(fl)
        addChild(foodBowl)
        waterBowl = bowl(size.width * 0.20, Palette.water)
        let wl = makeLabel("💧", size: 14); wl.position = CGPoint(x: 0, y: 0); waterBowl.addChild(wl)
        addChild(waterBowl)
    }
    private func buildBreakables() {
        for b in room.breakables {
            let x = 28 + b.x * (size.width - 56)
            let topPx = b.top * (size.height * 0.42)
            let s = BreakableSprite(def: b, x: x, floorY: floorY, topPx: topPx)
            addChild(s); breakables.append(s)
        }
    }

    // MARK: HUD
    private func buildHUD() {
        // top: quit, coins, gaze banner
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

        bannerPanel = roundedPanel(CGSize(width: 240, height: 30), fill: UIColor(hex: 0xFBF6EE, alpha: 0.92), corner: 15)
        bannerPanel.position = CGPoint(x: size.width/2, y: size.height - topInset - 64); bannerPanel.zPosition = 60
        addChild(bannerPanel)
        bannerLabel = makeLabel("", size: 14, color: Palette.inkSoft, weight: .heavy)
        bannerPanel.addChild(bannerLabel)

        // bottom HUD panel
        let hud = roundedPanel(CGSize(width: size.width, height: 150 + bottomInset), fill: UIColor(hex: 0xA6B095, alpha: 0.96), corner: 0, shadow: false)
        hud.position = CGPoint(x: size.width/2, y: (150 + bottomInset)/2); hud.zPosition = 55; addChild(hud)

        let barW = (size.width - 60) * 0.42
        energyBar = BarNode(width: barW, color: Palette.energy)
        energyBar.position = CGPoint(x: -size.width/2 + 24, y: 28); hud.addChild(energyBar)
        let eLab = makeLabel("ENERGY", size: 10, color: Palette.ink, weight: .heavy, h: .left); eLab.position = CGPoint(x: -size.width/2 + 24, y: 44); hud.addChild(eLab)

        suspBar = BarNode(width: barW, color: Palette.susp)
        suspBar.position = CGPoint(x: 6, y: 28); hud.addChild(suspBar)
        let sLab = makeLabel("SUSPICION", size: 10, color: Palette.ink, weight: .heavy, h: .left); sLab.position = CGPoint(x: 6, y: 44); hud.addChild(sLab)

        chaosLabel = makeLabel("0", size: 26, color: Palette.ink, weight: .black, h: .right)
        chaosLabel.position = CGPoint(x: size.width/2 - 24, y: 24); hud.addChild(chaosLabel)
        let cLab = makeLabel("MISCHIEF", size: 10, color: Palette.ink, weight: .heavy, h: .right); cLab.position = CGPoint(x: size.width/2 - 24, y: 46); hud.addChild(cLab)

        dayBar = BarNode(width: size.width - 48, height: 6, color: Palette.gold)
        dayBar.position = CGPoint(x: -size.width/2 + 24, y: -4); hud.addChild(dayBar)
        let goal = makeLabel("Day \(day + 1) · goal \(cfg.target) mischief", size: 11, color: Palette.ink, weight: .bold, h: .left)
        goal.position = CGPoint(x: -size.width/2 + 24, y: -20); hud.addChild(goal)
        syncHUD()
    }

    private func syncHUD() {
        energyBar.setValue(energy / maxEnergy)
        suspBar.setValue(susp / 100)
        suspBar.setColor(susp > 70 ? Palette.susp : susp > 40 ? Palette.flame : Palette.good)
        chaosLabel.text = "\(chaos)"
        coinLabel.text = "\(GameData.shared.coins)"
        dayBar.setValue(CGFloat(dayT / cfg.length))
    }

    private func setBanner() {
        let g = human.gaze
        var txt = ""; var col = Palette.inkSoft
        let telegraph = (nextGaze == .watch && g == .distract && gazeTimer < 0.9)
        if g == .watch { txt = "👀  WATCHING — be good!"; col = UIColor(hex: 0xB23A2E) }
        else if telegraph { txt = "⚠  about to look up…"; col = UIColor(hex: 0xC98A2E) }
        else if g == .distract { txt = "📱  distracted — go wild"; col = Palette.good }
        else { txt = "🚪  left the room — free reign!"; col = Palette.good }
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
        case .watch: gazeTimer = Double.random(in: 2.4...4.6) - Double(Content.roomIndex(roomId)) * 0.1
        case .distract: gazeTimer = Double.random(in: 3.0...6.0)
        case .away: gazeTimer = Double.random(in: 4.0...7.0)
        }
        nextGaze = planNext(g)
        let look = max(-1, min(1, (cat.position.x - human.position.x) / 120))
        human.setGaze(g, lookDir: look)
        if g == .away { tidyOne() }
    }
    private func tidyOne() {
        let messed = breakables.filter { $0.messed }
        if let one = messed.randomElement(), Double.random(in: 0...1) < 0.85 { one.restore() }
    }
    private var watching: Bool { human.gaze == .watch }
    private var inRoom: Bool { human.gaze != .away }

    // MARK: input
    override func worldTouch(at point: CGPoint) {
        guard !ended else { return }
        var pick: AnyObject? = nil
        var best: CGFloat = 50
        for b in breakables where !b.messed {
            let d = hypot(point.x - b.position.x, point.y - (b.position.y + 40))
            if d < best { best = d; pick = b }
        }
        for c in collectibles {
            let d = hypot(point.x - c.position.x, point.y - c.position.y)
            if d < best { best = d; pick = c }
        }
        let bowls: [SKNode] = [foodBowl, waterBowl]
        for bw in bowls {
            let d = hypot(point.x - bw.position.x, point.y - bw.position.y)
            if d < best { best = d; pick = bw }
        }
        action = .none; actT = 0
        if let obj = pick {
            targetObj = obj
            if let b = obj as? BreakableSprite { targetX = b.approachX }
            else { targetX = (obj as! SKNode).position.x }
        } else {
            targetObj = nil
            targetX = max(24, min(size.width - 24, point.x))
        }
    }

    // MARK: loop
    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime; lastTime = currentTime
        dt = min(dt, 0.05)
        if ended { return }
        let dtf = CGFloat(dt)

        // day clock + sun
        dayT += dt
        sunX = size.width * (0.12 + 0.72 * CGFloat(dayT / cfg.length))
        updateSun()
        if dayT >= cfg.length { return finish(caught: false) }

        // gaze
        gazeTimer -= dt
        if gazeTimer <= 0 { setGaze(nextGaze) }
        else if watching {
            human.lookAt(max(-1, min(1, (cat.position.x - human.position.x) / 120)))
        }
        setBanner()

        // movement
        moveCat(dtf)

        // passive meters
        energy = max(0, min(maxEnergy, energy - dtf * 0.25))
        susp = max(0, susp - dtf * 0.4)
        human.mad = max(0, human.mad - dtf * 1.5)

        // behaviour-based suspicion / refuel
        let inSun = abs(cat.position.x - sunX) < size.width * 0.07
        let idle = (targetX == nil && action == .none)
        if action == .nap || (idle && inSun) {
            if action != .nap { action = .nap; cat.setNapping(true) }
            energy = min(maxEnergy, energy + dtf * (7 + CGFloat(upNap) * 2))
            if watching { susp = max(0, susp - dtf * (5 + CGFloat(upCharm))) }
        } else if action == .eat || action == .drink {
            if watching { susp = max(0, susp - dtf * 2.5) }
        } else if idle {
            if watching { susp = max(0, susp - dtf * (4 + CGFloat(upCharm))) }
            else { susp = max(0, susp - dtf * 1) }
        }
        // caught lingering at a fresh mess
        if watching {
            for b in breakables where b.messed {
                if hypot(cat.position.x - b.position.x, cat.position.y - floorY) < 52 { susp = min(100, susp + dtf * 9) }
            }
        }

        tickAction(dt)
        spawnCollectibles(dt)
        autoCollect()

        if susp >= 100 { return finish(caught: true) }
        syncHUD()
    }

    private func updateSun() {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: sunX - 42, y: floorY))
        p.addLine(to: CGPoint(x: sunX + 42, y: floorY))
        p.addLine(to: CGPoint(x: sunX + 66, y: 0))
        p.addLine(to: CGPoint(x: sunX - 66, y: 0))
        p.close()
        sunbeam.path = p.cgPath
    }

    private func moveCat(_ dt: CGFloat) {
        if action != .none && action != .nap { return }
        guard let tx = targetX else { return }
        let d = tx - cat.position.x
        if abs(d) > 4 {
            if action == .nap { action = .none; cat.setNapping(false) }
            cat.face(d > 0 ? 1 : -1)
            cat.position.x += (d > 0 ? 1 : -1) * min(abs(d), 150 * dt)
            cat.setWalking(true)
        } else {
            cat.setWalking(false)
            if let obj = targetObj { beginAction(on: obj) }
            targetX = nil; targetObj = nil
        }
    }

    private func beginAction(on obj: AnyObject) {
        if let b = obj as? BreakableSprite {
            if b.messed { return }
            if energy < CGFloat(b.def.energyCost) { showThought("too tired to be bad. unacceptable"); return }
            action = .knock; actT = 0; cat.knock()
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
        case .eat:
            energy = min(maxEnergy, energy + CGFloat(dt) * 16)
            if actT > 2.2 { action = .none }
        case .drink:
            energy = min(maxEnergy, energy + CGFloat(dt) * 12)
            if actT > 1.8 { action = .none }
        case .knock:
            if actT > 0.42, let b = breakables.first(where: { !$0.messed && abs($0.approachX - cat.position.x) < 60 }) {
                commitCrime(b); action = .none
            } else if actT > 0.8 { action = .none }
        default: break
        }
    }

    private func commitCrime(_ b: BreakableSprite) {
        b.makeMessed()
        let mult = 1 + 0.15 * CGFloat(upValue)
        let gainChaos = Int(CGFloat(b.def.chaos) * mult)
        let gainCoins = Int(CGFloat(b.def.coins) * mult)
        chaos += gainChaos
        runCoins += gainCoins
        GameData.shared.addCoins(gainCoins)
        energy = max(0, energy - CGFloat(b.def.energyCost))
        SFX.crash()
        shake()
        popText("+\(gainChaos)", at: CGPoint(x: b.position.x, y: b.position.y + 60), color: Palette.flameDeep)

        if watching {
            susp = min(100, susp + 36); human.mad = 1.2
            let look = max(-1, min(1, (cat.position.x - human.position.x)/120)); human.setGaze(.watch, lookDir: look)
            redFlash()
        } else if inRoom {
            let heard = max(2, 8 - 2 * CGFloat(upPaws))
            susp = min(100, susp + heard)
            if human.gaze == .distract && Double.random(in: 0...1) < 0.7 { nextGaze = .watch; gazeTimer = min(gazeTimer, 0.8) }
        }
        syncHUD()
    }

    // MARK: collectibles
    private func spawnCollectibles(_ dt: Double) {
        spawnTimer -= dt
        if spawnTimer <= 0 && collectibles.count < 3 {
            spawnTimer = Double.random(in: 4.5...7.5)
            let gem = Double.random(in: 0...1) < 0.18
            let c = Collectible(value: gem ? 25 : 5, isGem: gem)
            c.position = CGPoint(x: CGFloat.random(in: 40...(size.width - 40)), y: floorY + 14)
            c.alpha = 0; c.run(.fadeIn(withDuration: 0.3))
            addChild(c); collectibles.append(c)
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
        SFX.coin()
        popText("+\(c.value)🪙", at: c.position, color: Palette.gold)
        if targetObj === c { targetObj = nil; targetX = nil }
        c.run(.sequence([.group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        syncHUD()
    }

    // MARK: feedback
    private func shake() {
        run(.sequence([.moveBy(x: 6, y: 0, duration: 0.03), .moveBy(x: -12, y: 0, duration: 0.05),
                       .moveBy(x: 6, y: 0, duration: 0.03)]))
    }
    private func redFlash() {
        let f = SKSpriteNode(color: UIColor(hex: 0xE2554B, alpha: 0.35), size: size)
        f.anchorPoint = .zero; f.zPosition = 80
        addChild(f); f.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
    private func popText(_ t: String, at p: CGPoint, color: UIColor) {
        let l = makeLabel(t, size: 18, color: color, weight: .black)
        l.position = p; l.zPosition = 70; addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 36, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }
    private func showThought(_ text: String) {
        thoughtNode?.removeFromParent()
        let node = SKNode()
        let label = makeLabel(text, size: 13, color: Palette.ink, weight: .semibold)
        label.preferredMaxLayoutWidth = min(220, size.width - 60)
        label.numberOfLines = 0
        label.verticalAlignmentMode = .center
        let w = min(label.frame.width + 24, size.width - 40)
        let h = label.frame.height + 18
        let bubble = roundedPanel(CGSize(width: w, height: h), fill: Palette.panel, corner: 12, shadow: false)
        node.addChild(bubble); node.addChild(label)
        node.position = CGPoint(x: min(max(cat.position.x, w/2 + 8), size.width - w/2 - 8), y: cat.position.y + 92)
        node.zPosition = 65
        addChild(node); thoughtNode = node
        node.run(.sequence([.wait(forDuration: 2.6), .fadeOut(withDuration: 0.3), .removeFromParent()]))
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
        card.position = CGPoint(x: size.width/2, y: size.height/2); card.zPosition = 101; addChild(card)

        let title = makeLabel(caught ? "TIME OUT!" : "Day \(day + 1) survived", size: 24, color: Palette.ink, weight: .black)
        title.position = CGPoint(x: 0, y: cardH/2 - 40); card.addChild(title)

        if !caught {
            let st = makeLabel(String(repeating: "★", count: stars) + String(repeating: "·", count: 3 - stars), size: 36, color: Palette.gold, weight: .heavy)
            st.position = CGPoint(x: 0, y: cardH/2 - 86); card.addChild(st)
        }
        let chaosL = makeLabel("Mischief: \(chaos)   ·   goal \(cfg.target)", size: 15, color: Palette.inkSoft, weight: .bold)
        chaosL.position = CGPoint(x: 0, y: cardH/2 - 132); card.addChild(chaosL)
        let coinsL = makeLabel("Coins earned: \(runCoins) 🪙", size: 16, color: Palette.flameDeep, weight: .heavy)
        coinsL.position = CGPoint(x: 0, y: cardH/2 - 160); card.addChild(coinsL)

        // buttons
        let bw = cardW - 48
        let hasNext = !caught && day + 1 < room.days
        let primary = ButtonNode(caught ? "Try again" : (hasNext ? "Next day" : "Back to rooms"),
                                 size: CGSize(width: bw, height: 50), fill: Palette.ink, fontSize: 18)
        primary.position = CGPoint(x: 0, y: -cardH/2 + 92); primary.zPosition = 102
        primary.onTap = { [weak self] in
            guard let s = self else { return }
            if caught { s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: s.day), .fade(withDuration: 0.3)) }
            else if hasNext { s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: s.day + 1), .fade(withDuration: 0.3)) }
            else { s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        }
        card.addChild(primary)

        let row = SKNode(); row.position = CGPoint(x: 0, y: -cardH/2 + 38); card.addChild(row)
        let half = (bw - 12) / 2
        let shopB = ButtonNode("Shop", size: CGSize(width: half, height: 44), fill: Palette.flame, fontSize: 16)
        shopB.position = CGPoint(x: -half/2 - 6, y: 0)
        shopB.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: ShopScene(size: s.size), .fade(withDuration: 0.3)) }
        row.addChild(shopB)
        let roomsB = ButtonNode("Levels", size: CGSize(width: half, height: 44), fill: UIColor(hex: 0x4A3526, alpha: 0.1), textColor: Palette.ink, fontSize: 16)
        roomsB.position = CGPoint(x: half/2 + 6, y: 0)
        roomsB.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        row.addChild(roomsB)

        card.setScale(0.8); card.alpha = 0
        card.run(.group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.25)]))
    }
}
