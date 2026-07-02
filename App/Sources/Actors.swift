import SpriteKit
import UIKit

// MARK: - Mac
final class CatNode: SKNode {
    private let upright = SKNode()
    private let curled = SKNode()
    private let headGroup = SKNode()
    private let bodyGroup = SKNode()
    private var raisedPaw: SKShapeNode!
    private var accessory: SKNode?
    private let st = Breeds.style(GameData.shared.equippedBreed)
    private(set) var facing = 1
    /// Set the cat's display size with this instead of setScale so direction flips keep the size.
    var baseScale: CGFloat = 1 { didSet { yScale = baseScale; xScale = baseScale * CGFloat(facing) } }

    override init() {
        super.init()
        debugCheckpoint("Cat.init:start")
        buildUpright()
        buildCurled()
        addChild(upright)
        addChild(curled)
        curled.isHidden = true
        // ambient breathing
        bodyGroup.run(.repeatForever(.sequence([
            .scaleY(to: 1.03, duration: 1.0),
            .scaleY(to: 0.98, duration: 1.0)
        ])))
        applySkin(GameData.shared.equippedSkin)
        debugCheckpoint("Cat.init:done")
    }
    required init?(coder: NSCoder) { fatalError() }

    private func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: UIColor) -> SKShapeNode {
        let n = SKShapeNode(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx*2, height: ry*2))
        n.fillColor = color; n.strokeColor = .clear; return n
    }
    private func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: UIColor) -> SKShapeNode {
        let n = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r).cgPath)
        n.fillColor = color; n.strokeColor = .clear; return n
    }
    private func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ color: UIColor) -> SKShapeNode {
        let n = SKShapeNode(path: triPath(a, b, c)); n.fillColor = color; n.strokeColor = .clear; return n
    }

    private func buildUpright() {
        // shadow
        let shadow = ell(0, 2, 30, 7, UIColor(hex: 0x000000, alpha: 0.14)); upright.addChild(shadow)

        // tail
        let tail = SKShapeNode()
        let tp = UIBezierPath(); tp.move(to: CGPoint(x: -20, y: 20))
        tp.addQuadCurve(to: CGPoint(x: -30, y: 50), controlPoint: CGPoint(x: -38, y: 26))
        tail.path = tp.cgPath; tail.lineWidth = 8; tail.lineCap = .round; tail.strokeColor = st.coat
        let tip = SKShapeNode(); let tip2 = UIBezierPath()
        tip2.move(to: CGPoint(x: -29, y: 40)); tip2.addQuadCurve(to: CGPoint(x: -30, y: 50), controlPoint: CGPoint(x: -33, y: 45))
        tip.path = tip2.cgPath; tip.lineWidth = 8; tip.lineCap = .round; tip.strokeColor = st.accent
        tail.addChild(tip)
        upright.addChild(tail)
        tail.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.18, duration: 1.1), .rotate(toAngle: -0.10, duration: 1.1)
        ])))

        // body
        bodyGroup.addChild(ell(-2, 22, 22, 20, st.coat))
        bodyGroup.addChild(ell(-8, 14, 15, 12, st.shade))
        // legs + socks
        bodyGroup.addChild(rrect(2, 0, 8, 20, 4, st.coat))
        let backPaw = rrect(11, 0, 8, 18, 4, st.coat)
        bodyGroup.addChild(backPaw)
        bodyGroup.addChild(rrect(2, 0, 8, 6, 3, st.accent))
        bodyGroup.addChild(rrect(11, 0, 8, 6, 3, st.accent))
        raisedPaw = rrect(15, 2, 8, 16, 4, st.coat)
        bodyGroup.addChild(raisedPaw)
        upright.addChild(bodyGroup)

        // head
        headGroup.position = CGPoint(x: 14, y: 44)
        // ears
        headGroup.addChild(tri(CGPoint(x: -12, y: 8), CGPoint(x: -20, y: 26), CGPoint(x: -3, y: 15), st.accent))
        headGroup.addChild(tri(CGPoint(x: 12, y: 8), CGPoint(x: 20, y: 26), CGPoint(x: 3, y: 15), st.accent))
        headGroup.addChild(tri(CGPoint(x: -11, y: 11), CGPoint(x: -16, y: 22), CGPoint(x: -5, y: 14), Palette.pink))
        headGroup.addChild(tri(CGPoint(x: 11, y: 11), CGPoint(x: 16, y: 22), CGPoint(x: 5, y: 14), Palette.pink))
        // head base + accent mask
        headGroup.addChild(ell(0, 0, 19, 17, st.coat))
        let mask = ell(0, -5, 12, 9, st.accent); mask.alpha = 0.85; headGroup.addChild(mask)
        // eyes
        for ex in [CGFloat(-7), 7] {
            headGroup.addChild(ell(ex, 0, 4.2, 5, .white))
            headGroup.addChild(ell(ex, 0, 3.5, 4.4, st.eye))
            headGroup.addChild(ell(ex, 0.4, 1.4, 3.4, Palette.ink))
            let glint = ell(ex - 1.2, 1.4, 0.9, 0.9, .white); headGroup.addChild(glint)
        }
        // nose
        headGroup.addChild(tri(CGPoint(x: 0, y: -6), CGPoint(x: -2.5, y: -3.5), CGPoint(x: 2.5, y: -3.5), Palette.pink))
        upright.addChild(headGroup)
    }

    private func buildCurled() {
        curled.addChild(ell(0, 2, 32, 7, UIColor(hex: 0x000000, alpha: 0.14)))
        curled.addChild(ell(0, 16, 30, 17, st.coat))
        curled.addChild(ell(5, 12, 22, 11, st.shade))
        let tail = SKShapeNode(); let tp = UIBezierPath()
        tp.move(to: CGPoint(x: -26, y: 14)); tp.addQuadCurve(to: CGPoint(x: 16, y: 4), controlPoint: CGPoint(x: -14, y: -2))
        tail.path = tp.cgPath; tail.lineWidth = 10; tail.lineCap = .round; tail.strokeColor = st.coat
        curled.addChild(tail)
        let head = SKNode(); head.position = CGPoint(x: -20, y: 18)
        head.addChild(ell(0, 0, 15, 13, st.coat))
        let m = ell(-3, -3, 8, 6, st.accent); m.alpha = 0.85; head.addChild(m)
        head.addChild(tri(CGPoint(x: -8, y: 7), CGPoint(x: -13, y: 19), CGPoint(x: 0, y: 11), st.accent))
        head.addChild(tri(CGPoint(x: 7, y: 9), CGPoint(x: 12, y: 19), CGPoint(x: 0, y: 11), st.accent))
        // closed eyes
        for ex in [CGFloat(-6), 4] {
            let e = SKShapeNode(); let p = UIBezierPath()
            p.addArc(withCenter: CGPoint(x: ex, y: -2), radius: 3.5, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: true)
            e.path = p.cgPath; e.lineWidth = 1.8; e.strokeColor = Palette.ink; head.addChild(e)
        }
        curled.addChild(head)
        // zzz
        let z = makeLabel("z", size: 14, color: Palette.ink, weight: .heavy); z.position = CGPoint(x: 24, y: 36); z.alpha = 0.7
        z.run(.repeatForever(.sequence([
            .group([.moveBy(x: 6, y: 18, duration: 1.4), .fadeOut(withDuration: 1.4)]),
            .run { z.position = CGPoint(x: 24, y: 36); z.alpha = 0.7 }
        ])))
        curled.addChild(z)
    }

    // MARK: skins
    func applySkin(_ id: String) {
        accessory?.removeFromParent(); accessory = nil
        let acc = SKNode()
        switch id {
        case "skin_mask":
            let band = rrect(-12, -3, 24, 7, 3, UIColor(hex: 0x2C2C2C)); acc.addChild(band)
        case "skin_glasses":
            let l = SKShapeNode(circleOfRadius: 5); l.position = CGPoint(x: -7, y: 0); l.fillColor = UIColor(hex: 0x222222); l.strokeColor = .clear
            let r = SKShapeNode(circleOfRadius: 5); r.position = CGPoint(x: 7, y: 0); r.fillColor = UIColor(hex: 0x222222); r.strokeColor = .clear
            let bridge = rrect(-2, -1, 4, 2, 1, UIColor(hex: 0x222222))
            acc.addChild(l); acc.addChild(r); acc.addChild(bridge)
        case "skin_bow":
            let bow = SKNode(); bow.position = CGPoint(x: 14, y: 8)
            bow.addChild(tri(CGPoint(x: 0, y: 0), CGPoint(x: -8, y: 5), CGPoint(x: -8, y: -5), Palette.flameDeep))
            bow.addChild(tri(CGPoint(x: 0, y: 0), CGPoint(x: 8, y: 5), CGPoint(x: 8, y: -5), Palette.flameDeep))
            bow.addChild({ let c = SKShapeNode(circleOfRadius: 2.4); c.fillColor = Palette.flame; c.strokeColor = .clear; return c }())
            upright.addChild(bow); accessory = bow; return
        case "skin_crown":
            let crown = SKShapeNode()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -10, y: 14)); p.addLine(to: CGPoint(x: -6, y: 22)); p.addLine(to: CGPoint(x: -2, y: 15))
            p.addLine(to: CGPoint(x: 2, y: 23)); p.addLine(to: CGPoint(x: 6, y: 15)); p.addLine(to: CGPoint(x: 10, y: 22))
            p.addLine(to: CGPoint(x: 10, y: 14)); p.addLine(to: CGPoint(x: -10, y: 14)); p.close()
            crown.path = p.cgPath; crown.fillColor = Palette.gold; crown.strokeColor = .clear
            acc.addChild(crown)
        case "skin_scarf":
            let wrap = rrect(-13, -16, 26, 7, 3, UIColor(hex: 0xB23A2E))
            let dangle = rrect(2, -30, 7, 16, 3, UIColor(hex: 0xB23A2E))
            let stripe = rrect(2, -22, 7, 3, 1, UIColor(hex: 0xE6A7A0))
            acc.addChild(wrap); acc.addChild(dangle); acc.addChild(stripe)
        case "skin_tophat":
            acc.addChild(rrect(-12, 12, 24, 4, 2, UIColor(hex: 0x2C2C34)))
            acc.addChild(rrect(-8, 14, 16, 16, 2, UIColor(hex: 0x2C2C34)))
            acc.addChild(rrect(-8, 15, 16, 4, 1, UIColor(hex: 0xB23A2E)))
        case "skin_flower":
            let fl = SKNode(); fl.position = CGPoint(x: -12, y: 16)
            for i in 0..<5 {
                let a = CGFloat(i) / 5 * .pi * 2
                let petal = SKShapeNode(circleOfRadius: 3.4)
                petal.fillColor = UIColor(hex: 0xE6A7A0); petal.strokeColor = .clear
                petal.position = CGPoint(x: cos(a) * 4.4, y: sin(a) * 4.4)
                fl.addChild(petal)
            }
            let core = SKShapeNode(circleOfRadius: 2.6); core.fillColor = Palette.gold; core.strokeColor = .clear
            fl.addChild(core)
            acc.addChild(fl)
        default:
            return
        }
        headGroup.addChild(acc); accessory = acc
    }

    // MARK: poses
    func face(_ dir: Int) {
        facing = dir >= 0 ? 1 : -1
        xScale = baseScale * CGFloat(facing)
        yScale = baseScale
    }
    func setWalking(_ on: Bool) {
        let key = "walk"
        if on {
            if bodyGroup.action(forKey: key) == nil {
                bodyGroup.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 2, duration: 0.12), .moveBy(x: 0, y: -2, duration: 0.12)
                ])), withKey: key)
            }
        } else {
            bodyGroup.removeAction(forKey: key)
            bodyGroup.position.y = 0
        }
    }
    func setNapping(_ on: Bool) {
        upright.isHidden = on
        curled.isHidden = !on
    }
    func knock() {
        raisedPaw.removeAllActions()
        raisedPaw.run(.sequence([
            .group([.moveBy(x: 0, y: 14, duration: 0.12), .rotate(byAngle: -0.4, duration: 0.12)]),
            .group([.moveBy(x: 0, y: -14, duration: 0.12), .rotate(byAngle: 0.4, duration: 0.12)])
        ]))
        upright.run(.sequence([.scaleY(to: 0.85, duration: 0.06), .scaleY(to: 1.0, duration: 0.1)]))
    }
}

// MARK: - The Human
final class HumanNode: SKNode {
    enum Gaze { case watch, distract, away }

    private let couch = SKNode()
    private let person = SKNode()
    private let head = SKNode()
    private var eyesNode = SKNode()
    private let phone: SKShapeNode
    private let doorMark: SKNode
    private(set) var gaze: Gaze = .distract
    var mad: CGFloat = 0

    override init() {
        phone = SKShapeNode(rect: CGRect(x: -10, y: 18, width: 20, height: 12), cornerRadius: 2)
        // small drawn "left the room" door marker
        let door = SKNode()
        let frame = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: -11, y: -14, width: 22, height: 30), cornerRadius: 3).cgPath)
        frame.fillColor = UIColor(hex: 0xA67A4E); frame.strokeColor = UIColor(hex: 0x7A5226); frame.lineWidth = 2
        door.addChild(frame)
        let knob = SKShapeNode(circleOfRadius: 2.2)
        knob.fillColor = UIColor(hex: 0xE0A93C); knob.strokeColor = .clear
        knob.position = CGPoint(x: 6, y: 0); door.addChild(knob)
        doorMark = door
        super.init()
        debugCheckpoint("Human.init:start")
        buildCouch()
        buildPerson()
        addChild(couch)
        addChild(person)
        doorMark.position = CGPoint(x: 0, y: 96); doorMark.isHidden = true
        addChild(doorMark)
        setGaze(.distract, lookDir: 0)
        debugCheckpoint("Human.init:done")
    }
    required init?(coder: NSCoder) { fatalError() }

    private func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ c: UIColor) -> SKShapeNode {
        let n = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r).cgPath)
        n.fillColor = c; n.strokeColor = .clear; return n
    }

    private func buildCouch() {
        couch.addChild(rrect(-56, 0, 112, 78, 14, Palette.couchDeep))
        couch.addChild(rrect(-56, 40, 112, 38, 14, Palette.couch))
        couch.addChild(rrect(-60, -6, 18, 90, 10, Palette.couchDeep))
        couch.addChild(rrect(42, -6, 18, 90, 10, Palette.couchDeep))
    }

    private func buildPerson() {
        person.addChild(rrect(-22, 22, 44, 56, 16, Palette.shirt))
        head.position = CGPoint(x: 0, y: 92)
        let face = SKShapeNode(circleOfRadius: 18); face.fillColor = Palette.skin; face.strokeColor = .clear
        head.addChild(face)
        let hair = SKShapeNode(path: { let p = UIBezierPath(); p.addArc(withCenter: .zero, radius: 18, startAngle: 0, endAngle: .pi, clockwise: false); return p.cgPath }())
        hair.fillColor = UIColor(hex: 0x5B4636); hair.strokeColor = .clear; hair.position = CGPoint(x: 0, y: 0)
        head.addChild(hair)
        head.addChild(eyesNode)
        person.addChild(head)
        phone.fillColor = UIColor(hex: 0x33414D); phone.strokeColor = .clear
        let screen = SKShapeNode(rect: CGRect(x: -8, y: 20, width: 16, height: 8), cornerRadius: 1)
        screen.fillColor = UIColor(hex: 0x9FD0E8); screen.strokeColor = .clear
        phone.addChild(screen)
        person.addChild(phone)
    }

    private func rebuildEyes(watching: Bool, lookDir: CGFloat) {
        eyesNode.removeAllChildren()
        let y: CGFloat = watching ? 0 : -4
        let dx = watching ? lookDir * 4 : 0
        let color = (watching && mad > 0) ? UIColor(hex: 0xB23A2E) : Palette.ink
        for ex in [CGFloat(-6), 6] {
            let e = SKShapeNode(circleOfRadius: 2.4)
            e.fillColor = color; e.strokeColor = .clear
            e.position = CGPoint(x: ex + dx, y: y)
            eyesNode.addChild(e)
        }
        if watching && mad > 0 {
            for sx in [CGFloat(-1), 1] {
                let brow = SKShapeNode()
                let p = UIBezierPath(); p.move(to: CGPoint(x: sx * 3, y: 4)); p.addLine(to: CGPoint(x: sx * 10, y: 7))
                brow.path = p.cgPath; brow.lineWidth = 2; brow.strokeColor = UIColor(hex: 0xB23A2E)
                eyesNode.addChild(brow)
            }
        }
    }

    func setGaze(_ g: Gaze, lookDir: CGFloat) {
        gaze = g
        let away = (g == .away)
        couch.alpha = 1
        person.isHidden = away
        doorMark.isHidden = !away
        guard !away else { return }
        let watching = (g == .watch)
        phone.isHidden = watching
        head.zRotation = watching ? lookDir * 0.12 : 0
        rebuildEyes(watching: watching, lookDir: lookDir)
    }

    /// Lightweight per-frame head tracking while watching (no node rebuilds).
    func lookAt(_ dir: CGFloat) {
        guard gaze == .watch else { return }
        head.zRotation = dir * 0.12
    }
}
