import SpriteKit
import UIKit

/// Hand-drawn vector icons (no emoji) for in-game objects. Everything is centered on the
/// node origin and sized to roughly a 30pt box so it drops in where emoji labels used to be.
enum IconFactory {

    // MARK: shape helpers
    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ c: UIColor, stroke: UIColor? = nil) -> SKShapeNode {
        let n = SKShapeNode(path: UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r).cgPath)
        n.fillColor = c; n.strokeColor = stroke ?? .clear; n.lineWidth = stroke == nil ? 0 : 2
        return n
    }
    private static func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ c: UIColor, stroke: UIColor? = nil) -> SKShapeNode {
        let n = SKShapeNode(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        n.fillColor = c; n.strokeColor = stroke ?? .clear; n.lineWidth = stroke == nil ? 0 : 2
        return n
    }
    private static func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ color: UIColor) -> SKShapeNode {
        let n = SKShapeNode(path: triPath(a, b, c)); n.fillColor = color; n.strokeColor = .clear; return n
    }

    // MARK: breakables
    static func breakable(_ kind: String) -> SKNode {
        let n = SKNode()
        switch kind {
        case "vase":
            n.addChild(ell(0, -2, 11, 13, UIColor(hex: 0xE0834C)))
            n.addChild(ell(0, 9, 7, 4, UIColor(hex: 0xC96A38)))
            n.addChild(rect(-6, 10, 12, 4, 2, UIColor(hex: 0xC96A38)))
        case "plant":
            n.addChild(tri(CGPoint(x: -9, y: 12), CGPoint(x: -12, y: 14), CGPoint(x: -2, y: -2), UIColor(hex: 0x6E9C58)))
            n.addChild(tri(CGPoint(x: 9, y: 12), CGPoint(x: 12, y: 14), CGPoint(x: 2, y: -2), UIColor(hex: 0x6E9C58)))
            n.addChild(tri(CGPoint(x: 0, y: 16), CGPoint(x: -6, y: 0), CGPoint(x: 6, y: 0), UIColor(hex: 0x83B36A)))
            n.addChild(rect(-9, -14, 18, 14, 2, UIColor(hex: 0xC09467)))
        case "cup":
            n.addChild(rect(-8, -10, 16, 20, 3, UIColor(hex: 0xE6E1D6)))
            n.addChild(rect(-8, 6, 16, 5, 2, UIColor(hex: 0xE0834C)))
        case "books":
            n.addChild(rect(-11, -12, 22, 7, 1, UIColor(hex: 0xB23A2E)))
            n.addChild(rect(-10, -5, 20, 7, 1, UIColor(hex: 0x5FA8C4)))
            n.addChild(rect(-9, 2, 18, 7, 1, UIColor(hex: 0xE0A93C)))
        case "tp":
            n.addChild(ell(0, 0, 11, 12, UIColor(hex: 0xFBF6EE)))
            n.addChild(ell(0, 0, 4, 5, UIColor(hex: 0xC09467)))
        case "lamp":
            n.addChild(tri(CGPoint(x: -11, y: 4), CGPoint(x: 11, y: 4), CGPoint(x: 0, y: 16), UIColor(hex: 0xFFE39A)))
            n.addChild(rect(-2, -14, 4, 18, 1, UIColor(hex: 0x7A6452)))
            n.addChild(rect(-7, -14, 14, 3, 1, UIColor(hex: 0x7A6452)))
        case "glass":
            n.addChild(tri(CGPoint(x: -8, y: 14), CGPoint(x: 8, y: 14), CGPoint(x: 0, y: 2), UIColor(hex: 0x9E1B32, alpha: 0.85)))
            n.addChild(rect(-1, -14, 2, 16, 1, UIColor(hex: 0xDDE3E6)))
            n.addChild(rect(-6, -14, 12, 2, 1, UIColor(hex: 0xDDE3E6)))
        case "fruit":
            n.addChild(ell(0, -1, 11, 11, UIColor(hex: 0xD7453A)))
            n.addChild(tri(CGPoint(x: 1, y: 9), CGPoint(x: 4, y: 15), CGPoint(x: 7, y: 10), UIColor(hex: 0x6E9C58)))
        case "plate":
            n.addChild(ell(0, 0, 13, 5, UIColor(hex: 0xE6E1D6)))
            n.addChild(ell(0, 0, 7, 2.5, UIColor(hex: 0xCFC9BC)))
        case "perfume":
            n.addChild(rect(-7, -12, 14, 18, 3, UIColor(hex: 0xE6A7A0, alpha: 0.9)))
            n.addChild(rect(-3, 6, 6, 6, 1, UIColor(hex: 0x7A6452)))
        case "mug":
            n.addChild(rect(-8, -9, 14, 18, 3, UIColor(hex: 0x5FA8C4)))
            n.addChild(ell(9, 0, 4, 5, .clear, stroke: UIColor(hex: 0x5FA8C4)))
        case "clock":
            n.addChild(ell(0, 0, 12, 12, UIColor(hex: 0xFBF6EE), stroke: UIColor(hex: 0x4A3526)))
            n.addChild(rect(-1, 0, 2, 8, 1, UIColor(hex: 0x4A3526)))
            n.addChild(rect(0, -1, 6, 2, 1, UIColor(hex: 0x4A3526)))
        case "duck":
            n.addChild(ell(-2, -2, 11, 8, UIColor(hex: 0xE0A93C)))
            n.addChild(ell(7, 6, 5, 5, UIColor(hex: 0xE0A93C)))
            n.addChild(tri(CGPoint(x: 11, y: 6), CGPoint(x: 17, y: 7), CGPoint(x: 11, y: 3), UIColor(hex: 0xE0834C)))
        case "keyboard":
            n.addChild(rect(-13, -6, 26, 12, 2, UIColor(hex: 0x33414D)))
            for gx in stride(from: CGFloat(-10), through: 10, by: 4) {
                n.addChild(rect(gx - 1.2, -1, 2.4, 2.4, 0.5, UIColor(hex: 0x9FD0E8)))
            }
        default:
            n.addChild(rect(-10, -10, 20, 20, 3, UIColor(hex: 0xC09467)))
        }
        return n
    }

    // MARK: currency
    static func coin() -> SKNode {
        let n = SKNode()
        n.addChild(ell(0, 0, 11, 11, UIColor(hex: 0xE0A93C), stroke: UIColor(hex: 0xB8862B)))
        n.addChild(ell(0, 0, 6, 6, UIColor(hex: 0xF0C24C)))
        return n
    }
    static func gem() -> SKNode {
        let n = SKNode()
        n.addChild(tri(CGPoint(x: -10, y: 4), CGPoint(x: 10, y: 4), CGPoint(x: 0, y: -12), UIColor(hex: 0x5FA8C4)))
        n.addChild(tri(CGPoint(x: -10, y: 4), CGPoint(x: 10, y: 4), CGPoint(x: 0, y: 12), UIColor(hex: 0x7FC8DE)))
        return n
    }

    // MARK: loot chest
    static func loot() -> SKNode {
        let n = SKNode()
        n.addChild(rect(-15, -12, 30, 20, 3, UIColor(hex: 0xB07A3C), stroke: UIColor(hex: 0x7A5226)))
        n.addChild(rect(-15, 4, 30, 9, 3, UIColor(hex: 0xC98A2E), stroke: UIColor(hex: 0x7A5226)))
        n.addChild(rect(-4, -2, 8, 8, 1, UIColor(hex: 0xE0A93C)))
        return n
    }

    // MARK: bowls
    static func fish() -> SKNode {
        let n = SKNode()
        n.addChild(ell(-1, 0, 8, 5, UIColor(hex: 0xE0834C)))
        n.addChild(tri(CGPoint(x: 6, y: 0), CGPoint(x: 12, y: 4), CGPoint(x: 12, y: -4), UIColor(hex: 0xE0834C)))
        n.addChild(ell(-4, 1, 1.4, 1.4, UIColor(hex: 0x4A3526)))
        return n
    }
    static func droplet() -> SKNode {
        let n = SKNode()
        n.addChild(ell(0, -2, 6, 7, UIColor(hex: 0x5FA8C4)))
        n.addChild(tri(CGPoint(x: -4, y: 2), CGPoint(x: 4, y: 2), CGPoint(x: 0, y: 12), UIColor(hex: 0x5FA8C4)))
        return n
    }

    // MARK: HUD glyphs
    static func lightning(_ color: UIColor = .white) -> SKNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 3, y: 14)); p.addLine(to: CGPoint(x: -7, y: 0)); p.addLine(to: CGPoint(x: -1, y: 0))
        p.addLine(to: CGPoint(x: -3, y: -14)); p.addLine(to: CGPoint(x: 7, y: 2)); p.addLine(to: CGPoint(x: 1, y: 2)); p.close()
        let n = SKShapeNode(path: p.cgPath); n.fillColor = color; n.strokeColor = .clear
        return n
    }
    static func pawGlyph(_ color: UIColor = .white) -> SKNode {
        let n = SKNode()
        n.addChild(ell(0, -3, 7, 6, color))
        for dx in [CGFloat(-7), -2.5, 2.5, 7] { n.addChild(ell(dx, 7, 2.6, 3.2, color)) }
        return n
    }
}
