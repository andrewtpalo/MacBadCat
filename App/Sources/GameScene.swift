import SpriteKit
import UIKit

// MARK: - Breakable sprite
final class BreakableSprite: SKNode {
    let def: Breakable
    let platformId: Int
    let standX: CGFloat
    let mult: CGFloat
    private(set) var messed = false
    private let icon: SKNode

    init(placement: Placement, worldY: CGFloat) {
        self.def = placement.def
        self.platformId = placement.platform
        self.standX = placement.x
        self.mult = placement.mult
        self.icon = IconFactory.breakable(placement.def.kind)
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
}

// MARK: - Collectible
final class Collectible: SKNode {
    let value: Int
    let isGem: Bool
    let platformId: Int
    init(value: Int, isGem: Bool, platformId: Int) {
        self.value = value; self.isGem = isGem; self.platformId = platformId
        super.init()
        addChild(isGem ? IconFactory.gem() : IconFactory.coin())
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.6), .moveBy(x: 0, y: -5, duration: 0.6)])))
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Loot box
final class LootBox: SKNode {
    let platformId: Int
    let tier: CGFloat            // 0..1 height — richer higher up
    private(set) var opened = false
    private let icon = IconFactory.loot()

    init(platformId: Int, tier: CGFloat) {
        self.platformId = platformId; self.tier = tier
        super.init()
        icon.position = CGPoint(x: 0, y: 16); addChild(icon)
        let glow = SKShapeNode(circleOfRadius: 4); glow.fillColor = Palette.gold; glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 38); glow.alpha = 0.85
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.7), .fadeAlpha(to: 0.9, duration: 0.7)])))
        addChild(glow)
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.7), .moveBy(x: 0, y: -4, duration: 0.7)])))
    }
    required init?(coder: NSCoder) { fatalError() }

    func open() {
        guard !opened else { return }
        opened = true
        icon.run(.sequence([.scale(to: 1.5, duration: 0.15), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
}

// MARK: - Watcher (a person with a sweeping vision cone)
final class Watcher {
    let node = HumanNode()
    let platform: Int
    var timer: Double = 3
    var next: HumanNode.Gaze = .watch
    let cone = SKShapeNode()
    var baseAngle: CGFloat = .pi     // direction the cone points when centered
    var phase: Double = 0            // sweep phase
    var facing: CGFloat = .pi        // current cone direction
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
    private var speechTimer: Double = 3.5

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
    private var upHeld = false
    private var downHeld = false
    private var climbLink: LinkDef?
    private var climbTarget = 0
    private var isJumping = false
    private var swatTarget: BreakableSprite?

    // signature ability
    private var abilityCharge: CGFloat = 0     // 0..1, fills from self-care
    private var ghostTimer: Double = 0         // seconds of Ghost Mode remaining
    private var ghost: Bool { ghostTimer > 0 }

    // input — everything is relative to the cat (see assign)
    private enum Role { case left, right, up, down }
    private var touchRoles: [UITouch: Role] = [:]
    private var abilityBtnCenter: CGPoint = .zero
    private var abilityBtnR: CGFloat = 40
    private var quitRect: CGRect = .zero
    private var hudHeight: CGFloat = 140

    // tuning
    private var walkSpeed: CGFloat { ghost ? 300 : 188 }
    private let climbSpeed: CGFloat = 150
    private let swatRange: CGFloat = 66
    private let climbReach: CGFloat = 52
    private let swatTapRadius: CGFloat = 54
    private var hopCost: CGFloat { ghost ? 0 : max(8, 16 - CGFloat(upBelly)) }

    // HUD
    private var energyBar: BarNode!
    private var suspBar: BarNode!
    private var suspMeterBG: SKShapeNode!
    private var alertGlow: SKShapeNode!
    private var alertLabel: SKLabelNode!
    private var chaosLabel: SKLabelNode!
    private var coinLabel: SKLabelNode!
    private var dayBar: BarNode!
    private var comboLabel: SKLabelNode!
    private var bannerLabel: SKLabelNode!
    private var bannerPanel: SKShapeNode!
    private var abilityBtn: SKShapeNode!
    private var abilityRing: SKShapeNode!
    private var abilityLabel: SKLabelNode!
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

        // Windows along the wall — start past the left-corner feeding nook (bowls live there).
        let winW: CGFloat = 108, winH: CGFloat = 134, winBottom = floorY + 118
        var windowXs: [CGFloat] = []
        var wx = worldWidth * 0.30
        while wx < worldWidth - winW {
            let win = SKShapeNode(rect: CGRect(x: wx - winW / 2, y: winBottom, width: winW, height: winH), cornerRadius: 6)
            win.fillColor = UIColor(hex: 0xBFE3F2); win.strokeColor = Palette.woodDeep; win.lineWidth = 5; win.zPosition = -80
            world.addChild(win)
            let mull = SKShapeNode(rect: CGRect(x: wx - 2, y: winBottom, width: 4, height: winH))
            mull.fillColor = Palette.woodDeep; mull.strokeColor = .clear; mull.zPosition = -79; world.addChild(mull)
            windowXs.append(wx)
            wx += max(size.width * 0.82, 280)
        }

        // A single sunbeam pours from ONE window onto the floor — the nap spot, far from the bowls.
        sunX = windowXs.first ?? worldWidth * 0.34
        let beam = SKShapeNode()
        let bp = UIBezierPath()
        bp.move(to: CGPoint(x: sunX - 46, y: winBottom))
        bp.addLine(to: CGPoint(x: sunX + 46, y: winBottom))
        bp.addLine(to: CGPoint(x: sunX + 82, y: floorY))
        bp.addLine(to: CGPoint(x: sunX - 82, y: floorY))
        bp.close()
        beam.path = bp.cgPath; beam.fillColor = Palette.sun; beam.strokeColor = .clear; beam.alpha = 0.26; beam.zPosition = -70
        world.addChild(beam)
        let pool = SKShapeNode(ellipseOf: CGSize(width: 156, height: 30))
        pool.fillColor = Palette.sun; pool.strokeColor = .clear; pool.alpha = 0.34
        pool.position = CGPoint(x: sunX, y: floorY + 5); pool.zPosition = -69; world.addChild(pool)
        sunbeam = beam
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
        func bowl(_ x: CGFloat, _ color: UIColor, _ content: SKNode) -> SKNode {
            let n = SKNode(); n.position = CGPoint(x: x, y: floorY)
            let dish = SKShapeNode(ellipseIn: CGRect(x: -22, y: -9, width: 44, height: 18))
            dish.fillColor = color; dish.strokeColor = .clear; n.addChild(dish)
            content.position = CGPoint(x: 0, y: 2); n.addChild(content)
            return n
        }
        // Feeding nook in the shaded left corner — clear of the sunbeam window (~0.30) and the
        // floor watcher (~0.86).
        foodBowl = bowl(worldWidth * 0.05, Palette.flameDeep, IconFactory.fish()); world.addChild(foodBowl)
        waterBowl = bowl(worldWidth * 0.11, Palette.water, IconFactory.droplet()); world.addChild(waterBowl)
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
            // Face toward the bulk of the room (whichever side has more space).
            w.baseAngle = (spot.x > worldWidth / 2) ? .pi : 0
            w.facing = w.baseAngle
            w.phase = Double.random(in: 0...(.pi * 2))
            w.cone.zPosition = 6; w.cone.strokeColor = .clear; w.cone.alpha = 0
            world.addChild(w.cone)
            world.addChild(w.node)
            watchers.append(w)
            setGaze(w, .distract)
        }
    }

    private let coneHalf: CGFloat = 0.52          // ~30° half-angle
    private var coneRange: CGFloat { max(size.width * 0.6, 240) }
    private func coneApex(_ w: Watcher) -> CGPoint { CGPoint(x: w.node.position.x, y: w.node.position.y + 80) }

    private func drawCone(_ w: Watcher) {
        let apex = coneApex(w)
        let p = UIBezierPath()
        p.move(to: apex)
        let steps = 10
        for i in 0...steps {
            let a = w.facing - coneHalf + (2 * coneHalf) * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: apex.x + cos(a) * coneRange, y: apex.y + sin(a) * coneRange))
        }
        p.close()
        w.cone.path = p.cgPath
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

        // Prominent SUSPICION meter across the top, with alerting.
        let sw = size.width - 56
        suspMeterBG = roundedPanel(CGSize(width: sw + 18, height: 46), fill: UIColor(hex: 0xFBF6EE, alpha: 0.94), corner: 14)
        suspMeterBG.position = CGPoint(x: size.width / 2, y: size.height - topInset - 72); suspMeterBG.zPosition = 61
        addChild(suspMeterBG)
        let sTitle = makeLabel("SUSPICION", size: 12, color: Palette.ink, weight: .black, h: .left)
        sTitle.position = CGPoint(x: -sw / 2, y: 10); suspMeterBG.addChild(sTitle)
        alertLabel = makeLabel("⚠ SPOTTED", size: 13, color: Palette.susp, weight: .black, h: .right)
        alertLabel.position = CGPoint(x: sw / 2, y: 10); alertLabel.alpha = 0; suspMeterBG.addChild(alertLabel)
        suspBar = BarNode(width: sw, height: 16, color: Palette.susp)
        suspBar.position = CGPoint(x: -sw / 2, y: -10); suspMeterBG.addChild(suspBar)

        // Full-screen red alert border (pulses when a watcher can see you).
        alertGlow = SKShapeNode(rect: CGRect(x: 3, y: 3, width: size.width - 6, height: size.height - 6), cornerRadius: 8)
        alertGlow.strokeColor = Palette.susp; alertGlow.lineWidth = 6; alertGlow.fillColor = .clear
        alertGlow.zPosition = 90; alertGlow.alpha = 0; addChild(alertGlow)

        bannerPanel = roundedPanel(CGSize(width: min(280, size.width - 30), height: 28), fill: UIColor(hex: 0xFBF6EE, alpha: 0.9), corner: 14)
        bannerPanel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 112); bannerPanel.zPosition = 60
        addChild(bannerPanel)
        bannerLabel = makeLabel("", size: 13, color: Palette.inkSoft, weight: .heavy)
        bannerPanel.addChild(bannerLabel)

        comboLabel = makeLabel("", size: 22, color: Palette.flameDeep, weight: .black)
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - topInset - 146); comboLabel.zPosition = 60
        addChild(comboLabel)

        // Bottom HUD panel — stamina + mischief + controls (suspicion now lives up top)
        let hud = roundedPanel(CGSize(width: size.width, height: hudHeight), fill: UIColor(hex: 0xA6B095, alpha: 0.96), corner: 0, shadow: false)
        hud.position = CGPoint(x: size.width / 2, y: hudHeight / 2); hud.zPosition = 55; addChild(hud)

        let leftX = -size.width / 2 + 20
        let barW = min(size.width * 0.4, 150)
        energyBar = BarNode(width: barW, height: 13, color: Palette.energy)
        energyBar.position = CGPoint(x: leftX, y: 4); hud.addChild(energyBar)
        let eLab = makeLabel("STAMINA", size: 11, color: Palette.ink, weight: .heavy, h: .left); eLab.position = CGPoint(x: leftX, y: 24); hud.addChild(eLab)

        let chaosX = leftX + barW + 40
        chaosLabel = makeLabel("0", size: 26, color: Palette.ink, weight: .black, h: .center)
        chaosLabel.position = CGPoint(x: chaosX, y: 2); hud.addChild(chaosLabel)
        let cLab = makeLabel("MISCHIEF", size: 9, color: Palette.ink, weight: .heavy, h: .center); cLab.position = CGPoint(x: chaosX, y: 26); hud.addChild(cLab)

        dayBar = BarNode(width: size.width - 40, height: 5, color: Palette.gold)
        dayBar.position = CGPoint(x: -size.width / 2 + 20, y: hudHeight / 2 - 12); hud.addChild(dayBar)
        let goal = makeLabel("Day \(day + 1) · goal \(cfg.target)", size: 10, color: Palette.ink, weight: .bold, h: .left)
        goal.position = CGPoint(x: -size.width / 2 + 20, y: hudHeight / 2 - 28); hud.addChild(goal)

        // Signature-ability button (bottom-right). Movement is done by touching around the cat.
        abilityBtnCenter = CGPoint(x: size.width - 52, y: hudHeight * 0.46)
        abilityBtn = SKShapeNode(circleOfRadius: abilityBtnR)
        abilityBtn.fillColor = Palette.eyeDeep; abilityBtn.strokeColor = UIColor(hex: 0xFBF6EE, alpha: 0.8); abilityBtn.lineWidth = 2
        abilityBtn.position = abilityBtnCenter; abilityBtn.zPosition = 58; addChild(abilityBtn)
        let glyph = IconFactory.lightning(); abilityBtn.addChild(glyph)
        let track = SKShapeNode(circleOfRadius: abilityBtnR + 4)
        track.strokeColor = UIColor(hex: 0xFBF6EE, alpha: 0.25); track.lineWidth = 4; track.fillColor = .clear
        abilityBtn.addChild(track)
        abilityRing = SKShapeNode()   // charge arc, path set in syncHUD
        abilityRing.strokeColor = Palette.gold; abilityRing.lineWidth = 4; abilityRing.fillColor = .clear
        abilityBtn.addChild(abilityRing)
        abilityLabel = makeLabel("ABILITY", size: 9, color: UIColor(hex: 0xFBF6EE), weight: .heavy)
        abilityLabel.position = CGPoint(x: 0, y: -abilityBtnR - 9); abilityBtn.addChild(abilityLabel)

        // hint
        let hint = makeLabel("touch around the cat to move · tap the cat to swat", size: 11, color: UIColor(hex: 0xFBF6EE, alpha: 0.95), weight: .heavy)
        hint.position = CGPoint(x: size.width / 2, y: hudHeight + 16); hint.zPosition = 56; addChild(hint)
        hint.run(.sequence([.wait(forDuration: 5), .fadeOut(withDuration: 0.6), .removeFromParent()]))

        syncHUD()
    }

    private func syncHUD() {
        energyBar.setValue(energy / maxEnergy)
        energyBar.setColor(energy < hopCost + 0.1 ? Palette.flame : Palette.energy)
        suspBar.setValue(susp / 100)
        suspBar.setColor(susp > 70 ? Palette.susp : susp > 40 ? Palette.flame : Palette.good)
        chaosLabel.text = "\(chaos)"
        coinLabel.text = "\(GameData.shared.coins)"
        dayBar.setValue(CGFloat(dayT / cfg.length))
        comboLabel.text = combo >= 2 ? "COMBO ×\(combo)" : ""
        // ability button: ring arc shows charge; glows + pulses when ready
        let ready = abilityCharge >= 1
        let frac = ghost ? 1 : abilityCharge
        if frac > 0.001 {
            let arc = UIBezierPath(arcCenter: .zero, radius: abilityBtnR + 4,
                                   startAngle: .pi / 2, endAngle: .pi / 2 + 2 * .pi * frac, clockwise: true)
            abilityRing.path = arc.cgPath
        } else { abilityRing.path = nil }
        abilityRing.strokeColor = ghost ? Palette.eye : Palette.gold
        abilityBtn.alpha = ready || ghost ? 1 : 0.7
        abilityBtn.fillColor = ghost ? Palette.eye : Palette.eyeDeep
        abilityLabel.text = ghost ? "GHOST!" : (ready ? "READY!" : "ABILITY")
        if ready && abilityBtn.action(forKey: "rdy") == nil {
            abilityBtn.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.4), .scale(to: 1.0, duration: 0.4)])), withKey: "rdy")
        } else if !ready { abilityBtn.removeAction(forKey: "rdy"); abilityBtn.setScale(1) }
    }
    private var comboFactor: CGFloat { combo >= 2 ? 1 + 0.4 * CGFloat(combo - 1) : 1 }

    private func updateAlert() {
        let seen = isSeen
        let pulsing = alertGlow.action(forKey: "pulse") != nil
        if seen && !pulsing {
            alertGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.75, duration: 0.38), .fadeAlpha(to: 0.12, duration: 0.38)])), withKey: "pulse")
            suspMeterBG.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 0.38), .scale(to: 1.0, duration: 0.38)])), withKey: "pulse")
            alertLabel.run(.fadeIn(withDuration: 0.12))
        } else if !seen && pulsing {
            alertGlow.removeAction(forKey: "pulse"); alertGlow.run(.fadeOut(withDuration: 0.3))
            suspMeterBG.removeAction(forKey: "pulse"); suspMeterBG.run(.scale(to: 1, duration: 0.2))
            alertLabel.run(.fadeOut(withDuration: 0.2))
        }
    }

    private func setBanner() {
        var txt = "📱  they're distracted — make your move"; var col = Palette.good
        if isSeen { txt = "👀  SPOTTED — get out of the cone!"; col = UIColor(hex: 0xB23A2E) }
        else if anyWatching { txt = "😼  someone's scanning — mind the cones"; col = UIColor(hex: 0xC98A2E) }
        else if watchers.allSatisfy({ $0.node.gaze == .away }) { txt = "🚪  all clear — free reign!"; col = Palette.good }
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

    private func humanSpeak() {
        let candidates = watchers.filter { $0.node.gaze != .away }
        guard let w = candidates.randomElement() else { return }
        let watching = w.node.gaze == .watch
        let lines = watching
            ? ["I KNOW you're up to something.", "Those guilty little eyes…", "Don't. You. Dare.",
               "I'm watching you, fuzzball.", "What was that noise?!", "Bad cat. BAD.", "Off the counter!"]
            : ["just five more minutes…", "ugh, work emails.", "where's the remote?",
               "so comfy right now.", "did I feed the cat?", "one more episode…", "is it Friday yet?"]
        guard let line = lines.randomElement() else { return }
        let node = SKNode()
        let label = makeLabel(line, size: 12, color: Palette.ink, weight: .semibold)
        label.preferredMaxLayoutWidth = 150; label.numberOfLines = 0; label.verticalAlignmentMode = .center
        let bw = max(60, min(label.frame.width + 20, 184)), bh = max(26, label.frame.height + 14)
        let bubble = roundedPanel(CGSize(width: bw, height: bh), fill: Palette.panel, corner: 12, shadow: false)
        node.addChild(bubble); node.addChild(label)
        let hx = min(max(w.node.position.x, bw / 2 + 6), worldWidth - bw / 2 - 6)
        node.position = CGPoint(x: hx, y: w.node.position.y + 122)
        node.zPosition = 66
        world.addChild(node)
        node.setScale(0.6); node.alpha = 0
        node.run(.sequence([.group([.scale(to: 1, duration: 0.15), .fadeIn(withDuration: 0.15)]),
                            .wait(forDuration: 2.0), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
    private var anyWatching: Bool { watchers.contains { $0.node.gaze == .watch } }
    /// True when the cat sits inside a watching person's vision cone.
    private func catInCone(_ w: Watcher) -> Bool {
        guard w.node.gaze == .watch else { return false }
        let apex = coneApex(w)
        let dx = cat.position.x - apex.x, dy = (cat.position.y + 20) - apex.y
        let dist = hypot(dx, dy)
        guard dist <= coneRange else { return false }
        var diff = atan2(dy, dx) - w.facing
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return abs(diff) <= coneHalf
    }
    private var isSeen: Bool { !ghost && watchers.contains { catInCone($0) } }
    private var onHigh: Bool { catPlatform != 0 }
    private var idle: Bool { moveDir == 0 && climbLink == nil && !isJumping && action == .none && !upHeld && !downHeld }

    // MARK: input — directions are relative to the cat; tap the cat to swat
    private func catScene() -> CGPoint { CGPoint(x: cat.position.x + world.position.x, y: cat.position.y + world.position.y) }
    private func role(for rel: CGPoint) -> Role {
        if abs(rel.x) >= abs(rel.y) { return rel.x < 0 ? .left : .right }
        return rel.y > 0 ? .up : .down
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { assign(t, at: t.location(in: self)) }
        refreshControls()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let cs = catScene()
        for t in touches where touchRoles[t] != nil {
            let loc = t.location(in: self)
            let rel = CGPoint(x: loc.x - cs.x, y: loc.y - cs.y)
            if hypot(rel.x, rel.y) >= swatTapRadius { touchRoles[t] = role(for: rel) }
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
            for n in nodes(at: loc) {
                var node: SKNode? = n
                while let cur = node { if let b = cur as? ButtonNode { SFX.tap(); b.trigger(); return }; node = cur.parent }
            }
            return
        }
        if loc.y <= hudHeight {
            if hypot(loc.x - abilityBtnCenter.x, loc.y - abilityBtnCenter.y) < abilityBtnR + 8 { activateAbility() }
            return
        }
        if quitRect.contains(loc) {
            SFX.tap()
            navigate(to: LevelSelectScene(size: size, roomId: roomId), .push(with: .right, duration: 0.3)); return
        }
        let cs = catScene()
        let rel = CGPoint(x: loc.x - cs.x, y: loc.y - cs.y)
        if hypot(rel.x, rel.y) < swatTapRadius { SFX.tap(); doSwat(); return }
        touchRoles[t] = role(for: rel)
    }

    private func refreshControls() {
        var l = false, r = false, u = false, d = false
        for role in touchRoles.values {
            switch role { case .left: l = true; case .right: r = true; case .up: u = true; case .down: d = true }
        }
        moveDir = (r ? 1 : 0) - (l ? 1 : 0)
        upHeld = u; downHeld = d
    }

    // MARK: climbing helpers
    private var nearestUpLink: LinkDef? {
        var best: LinkDef?; var bestD = climbReach
        for l in layout.links where l.lower == catPlatform {
            let dd = abs(cat.position.x - l.x); if dd < bestD { bestD = dd; best = l }
        }
        return best
    }
    private var nearestDownLink: LinkDef? {
        var best: LinkDef?; var bestD = climbReach
        for l in layout.links where l.upper == catPlatform {
            let dd = abs(cat.position.x - l.x); if dd < bestD { bestD = dd; best = l }
        }
        return best
    }
    private var canClimbNow: Bool { climbLink != nil || nearestUpLink != nil }

    // MARK: signature ability
    private func activateAbility() {
        guard !ended, abilityCharge >= 1, !ghost else { return }
        abilityCharge = 0
        ghostTimer = 5
        SFX.win(); Haptics.bigHit()
        popText("GHOST MODE!", at: CGPoint(x: cat.position.x, y: cat.position.y + 72), color: Palette.eye, big: true)
        cat.removeAction(forKey: "ghost")
        cat.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.3), .fadeAlpha(to: 0.8, duration: 0.3)])), withKey: "ghost")
    }

    private func jumpDown() {
        guard !isJumping, climbLink == nil, catPlatform != 0 else { return }
        let cur = platform(catPlatform)
        let below = platforms.filter {
            $0.topY < cur.topY &&
            cat.position.x >= $0.cx - $0.width / 2 - 12 && cat.position.x <= $0.cx + $0.width / 2 + 12
        }.max(by: { $0.topY < $1.topY })
        let target = below ?? platforms[0]
        isJumping = true
        cat.setNapping(false)
        let landX = min(max(cat.position.x, target.cx - target.width / 2 + 16), target.cx + target.width / 2 - 16)
        let landY = platformWorldY(target.id)
        let hop = SKAction.moveBy(x: 0, y: 22, duration: 0.12); hop.timingMode = .easeOut
        let drop = SKAction.move(to: CGPoint(x: landX, y: landY), duration: 0.30); drop.timingMode = .easeIn
        Haptics.tap()
        cat.run(.sequence([hop, drop, .run { [weak self] in
            guard let s = self else { return }
            s.catPlatform = target.id; s.isJumping = false; Haptics.climb()
        }]), withKey: "jump")
    }

    // MARK: loop
    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime; lastTime = currentTime
        dt = min(dt, 0.05)
        if ended { return }
        let dtf = CGFloat(dt)

        dayT += dt
        if dayT >= cfg.length { return finish(caught: false) }

        // watcher gaze + sweeping vision cones
        for w in watchers {
            w.timer -= dt
            if w.timer <= 0 { setGaze(w, w.next) }
            if w.node.gaze == .watch {
                w.phase += dt * 0.9
                w.facing = w.baseAngle + CGFloat(sin(w.phase)) * 0.55
                drawCone(w)
                let hot = catInCone(w)
                w.cone.fillColor = (hot ? Palette.susp : Palette.sun).withAlphaComponent(1)
                if w.cone.alpha < 0.15 { w.cone.run(.fadeAlpha(to: hot ? 0.24 : 0.15, duration: 0.15)) }
                else { w.cone.alpha = hot ? 0.24 : 0.15 }
                w.node.lookAt(cos(w.facing) >= 0 ? 1 : -1)
            } else if w.cone.alpha > 0 {
                w.cone.run(.fadeAlpha(to: 0, duration: 0.2))
            }
        }
        setBanner()

        // movement & climbing
        stepCat(dtf)
        updateCamera()

        // passive drain
        energy = max(0, min(maxEnergy, energy - dtf * 0.2))
        if comboTimer > 0 { comboTimer -= dt; if comboTimer <= 0 { combo = 0 } }
        if ghostTimer > 0 { ghostTimer -= dt; if ghostTimer <= 0 { cat.removeAction(forKey: "ghost"); cat.alpha = 1 } }

        // refuel: stand still on a bowl to eat/drink, or in the sunbeam to nap.
        // Self-care also charges the signature ability.
        if action != .knock {
            let stationary = moveDir == 0 && climbLink == nil && !isJumping && !upHeld && !downHeld
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
            if action == .eat || action == .drink || action == .nap {
                abilityCharge = min(1, abilityCharge + dtf * 0.13)
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
        speechTimer -= dt
        if speechTimer <= 0 { humanSpeak(); speechTimer = Double.random(in: 5...9) }
        updateAlert()

        if susp >= 100 { return finish(caught: true) }
        syncHUD()
    }

    private func stepCat(_ dt: CGFloat) {
        // any movement intent cancels passive states (nap/eat-while-moving fix)
        if (moveDir != 0 || upHeld || downHeld) && (action == .eat || action == .drink || action == .nap) {
            action = .none; cat.setNapping(false)
        }
        guard !isJumping else { return }
        guard action == .none || action == .nap else { return }

        // climb UP toward a reachable ladder above
        if upHeld && climbLink == nil {
            if let l = nearestUpLink {
                if energy < hopCost { showThought("too tired to climb — refuel first") }
                else {
                    climbLink = l; climbTarget = l.upper
                    energy = max(0, energy - hopCost)
                    if action == .nap { action = .none; cat.setNapping(false) }
                }
            }
        }
        // DOWN: use a ladder if one's in reach, otherwise hop off the edge
        if downHeld && climbLink == nil {
            if let l = nearestDownLink {
                climbLink = l; climbTarget = l.lower
                if action == .nap { action = .none; cat.setNapping(false) }
            } else if catPlatform != 0 {
                jumpDown(); return
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
                cat.setWalking(false); Haptics.climb()
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
        guard !ended, action == .none, climbLink == nil, !isJumping else { return }
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
        SFX.crash(); shake(combo >= 3 ? 9 : 6)
        burst(at: b.position, color: Palette.flameDeep, count: combo >= 3 ? 14 : 9)
        if combo >= 3 { Haptics.bigHit(); comboFlash() } else { Haptics.knock() }
        let label = combo >= 2 ? "+\(gainChaos)  ×\(combo)" : "+\(gainChaos)"
        popText(label, at: CGPoint(x: b.position.x, y: b.position.y + 44), color: combo >= 2 ? Palette.gold : Palette.flameDeep, big: combo >= 3)

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
        SFX.coin(); shake(7); Haptics.loot()
        burst(at: lb.position, color: Palette.gold, count: 16)
        popText("+\(coins)", at: CGPoint(x: lb.position.x, y: lb.position.y + 46), color: Palette.gold, big: true)
        popText("+\(bonusChaos)", at: CGPoint(x: lb.position.x, y: lb.position.y + 70), color: Palette.flameDeep)
        if gem { popText("gem +25", at: CGPoint(x: lb.position.x + 30, y: lb.position.y + 54), color: Palette.eye) }
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
        SFX.coin(); popText("+\(c.value)", at: c.position, color: Palette.gold)
        c.run(.sequence([.group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        syncHUD()
    }

    private func updateCamera() {
        let camX = min(max(cat.position.x - size.width / 2, 0), max(0, worldWidth - size.width))
        let camY = min(max(cat.position.y - size.height * 0.42, 0), max(0, worldHeight - size.height))
        world.position = CGPoint(x: -camX, y: -camY)
    }

    // MARK: feedback / juice
    private func shake(_ amount: CGFloat = 6) {
        run(.sequence([.moveBy(x: amount, y: 0, duration: 0.03),
                       .moveBy(x: -amount * 2, y: 0, duration: 0.05),
                       .moveBy(x: amount, y: 0, duration: 0.03)]))
    }
    private func redFlash() {
        let f = SKSpriteNode(color: UIColor(hex: 0xE2554B, alpha: 0.35), size: size)
        f.anchorPoint = .zero; f.zPosition = 80
        addChild(f); f.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
    private func comboFlash() {
        comboLabel.removeAllActions()
        comboLabel.setScale(1.6); comboLabel.alpha = 1
        comboLabel.run(.scale(to: 1.0, duration: 0.25))
    }
    /// A quick shower of little shards flying out from a point (in world space).
    private func burst(at p: CGPoint, color: UIColor, count: Int) {
        for _ in 0..<count {
            let s = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 3...6), height: CGFloat.random(in: 3...6)), cornerRadius: 1)
            s.fillColor = color; s.strokeColor = .clear
            s.position = p; s.zPosition = 71
            world.addChild(s)
            let ang = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 24...70)
            let dv = CGVector(dx: cos(ang) * dist, dy: sin(ang) * dist + 20)
            s.run(.sequence([
                .group([.move(by: dv, duration: 0.5),
                        .rotate(byAngle: CGFloat.random(in: -3...3), duration: 0.5),
                        .fadeOut(withDuration: 0.5),
                        .scale(to: 0.3, duration: 0.5)]),
                .removeFromParent()
            ]))
        }
    }
    private func popText(_ t: String, at p: CGPoint, color: UIColor, big: Bool = false) {
        let l = makeLabel(t, size: big ? 26 : 18, color: color, weight: .black)
        l.position = p; l.zPosition = 72; world.addChild(l)
        l.setScale(big ? 0.4 : 1)
        l.run(.sequence([
            .group([.scale(to: big ? 1.15 : 1, duration: 0.16),
                    .moveBy(x: 0, y: big ? 44 : 34, duration: 0.7),
                    .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent()
        ]))
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
        alertGlow?.removeAllActions(); alertGlow?.alpha = 0
        suspMeterBG?.removeAllActions(); suspMeterBG?.setScale(1)
        var stars = 0
        if !caught {
            stars = chaos >= Int(Double(cfg.target) * 1.6) ? 3 : (chaos >= cfg.target ? 2 : 1)
            GameData.shared.setStars(room: roomId, day: day, value: stars)
            let bonus = cfg.target / 2
            runCoins += bonus; GameData.shared.addCoins(bonus)
            SFX.win(); Haptics.win()
            // Ask for a rating at a genuine peak-happiness moment: a 3-star clear, once ever.
            if stars >= 3 && !GameData.shared.ratingPrompted {
                GameData.shared.ratingPrompted = true; GameData.shared.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { AppReview.request() }
            }
        } else { SFX.caught(); Haptics.caught() }
        showResults(caught: caught, stars: stars)
    }

    private func showResults(caught: Bool, stars: Int) {
        let dim = SKSpriteNode(color: UIColor(hex: 0x4A3526, alpha: 0.5), size: size)
        dim.anchorPoint = .zero; dim.zPosition = 100; addChild(dim)
        let cardW = min(330, size.width - 40), cardH: CGFloat = 396
        let card = roundedPanel(CGSize(width: cardW, height: cardH), fill: Palette.panel, corner: 24)
        card.position = CGPoint(x: size.width / 2, y: size.height / 2); card.zPosition = 101; addChild(card)
        let top = cardH / 2

        let title = makeLabel(caught ? "BUSTED!" : "Day \(day + 1) survived", size: 24, color: Palette.ink, weight: .black)
        title.position = CGPoint(x: 0, y: top - 40); card.addChild(title)
        if !caught {
            let st = makeLabel(String(repeating: "★", count: stars) + String(repeating: "·", count: 3 - stars), size: 36, color: Palette.gold, weight: .heavy)
            st.position = CGPoint(x: 0, y: top - 84); card.addChild(st)
        }
        let chaosL = makeLabel("Mischief: \(chaos)   ·   goal \(cfg.target)", size: 15, color: Palette.inkSoft, weight: .bold)
        chaosL.position = CGPoint(x: 0, y: top - 128); card.addChild(chaosL)
        let coinsL = makeLabel("Coins earned: \(runCoins)", size: 16, color: Palette.flameDeep, weight: .heavy)
        coinsL.position = CGPoint(x: 0, y: top - 154); card.addChild(coinsL)

        let bw = cardW - 48

        // Rewarded "double coins" — the core casual monetization hook.
        if runCoins > 0 {
            let dbl = ButtonNode("📺  Double coins  (+\(runCoins))", size: CGSize(width: bw, height: 46), fill: Palette.good, fontSize: 16)
            dbl.position = CGPoint(x: 0, y: top - 200); dbl.zPosition = 102
            dbl.onTap = { [weak self, weak dbl] in
                guard let s = self else { return }
                dbl?.isEnabledButton = false
                Ads.showRewarded(from: s, reward: "double_coins") { granted in
                    guard granted else { dbl?.isEnabledButton = true; return }
                    GameData.shared.addCoins(s.runCoins); s.runCoins *= 2
                    SFX.coin(); Haptics.loot()
                    dbl?.setTitle("Doubled!  ✓")
                }
            }
            card.addChild(dbl)
        }

        let hasNext = !caught && day + 1 < room.days
        let primary = ButtonNode(caught ? "Try again" : (hasNext ? "Next day" : "Back to rooms"),
                                 size: CGSize(width: bw, height: 50), fill: Palette.ink, fontSize: 18)
        primary.position = CGPoint(x: 0, y: -top + 108); primary.zPosition = 102
        primary.onTap = { [weak self] in
            guard let s = self else { return }
            if caught { s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: s.day), .fade(withDuration: 0.3)) }
            else if hasNext { s.navigate(to: GameScene(size: s.size, roomId: s.roomId, day: s.day + 1), .fade(withDuration: 0.3)) }
            else { s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        }
        card.addChild(primary)

        // Bottom row of three: Shop · Share · Levels
        let row = SKNode(); row.position = CGPoint(x: 0, y: -top + 46); card.addChild(row)
        let third = (bw - 20) / 3
        let shopB = ButtonNode("Shop", size: CGSize(width: third, height: 44), fill: Palette.flame, fontSize: 15)
        shopB.position = CGPoint(x: -third - 10, y: 0)
        shopB.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: ShopScene(size: s.size), .fade(withDuration: 0.3)) }
        row.addChild(shopB)
        let shareB = ButtonNode("Share", size: CGSize(width: third, height: 44), fill: Palette.eyeDeep, fontSize: 15)
        shareB.position = CGPoint(x: 0, y: 0)
        shareB.onTap = { [weak self] in
            guard let s = self else { return }
            let cap = caught ? "Mac got BUSTED in Bad Cat 😹 #BadCat" : "\(s.stars(stars)) — \(s.chaos) mischief in Bad Cat! 😼 #BadCat"
            ShareCard.present(from: s.view, caption: cap)
        }
        row.addChild(shareB)
        let roomsB = ButtonNode("Levels", size: CGSize(width: third, height: 44), fill: UIColor(hex: 0x4A3526, alpha: 0.1), textColor: Palette.ink, fontSize: 15)
        roomsB.position = CGPoint(x: third + 10, y: 0)
        roomsB.onTap = { [weak self] in guard let s = self else { return }; s.navigate(to: LevelSelectScene(size: s.size, roomId: s.roomId), .push(with: .right, duration: 0.3)) }
        row.addChild(roomsB)

        card.setScale(0.8); card.alpha = 0
        card.run(.group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.25)]))
    }

    private func stars(_ n: Int) -> String { String(repeating: "★", count: max(0, n)) }
}
