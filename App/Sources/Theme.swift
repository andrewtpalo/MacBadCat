import SpriteKit
import UIKit

// MARK: - Palette
enum Palette {
    static let coat      = UIColor(hex: 0xF7EFE3)
    static let coatShade = UIColor(hex: 0xEADDC9)
    static let flame     = UIColor(hex: 0xE0834C)
    static let flameDeep = UIColor(hex: 0xC96A38)
    static let pink      = UIColor(hex: 0xE6A7A0)
    static let eye       = UIColor(hex: 0x5FA8C4)
    static let eyeDeep   = UIColor(hex: 0x3E7F98)
    static let ink       = UIColor(hex: 0x4A3526)
    static let inkSoft   = UIColor(hex: 0x7A6452)
    static let wall      = UIColor(hex: 0xB6BFA6)
    static let wallDeep  = UIColor(hex: 0xA6B095)
    static let wood      = UIColor(hex: 0xC09467)
    static let woodDeep  = UIColor(hex: 0xA67A4E)
    static let panel     = UIColor(hex: 0xFBF6EE)
    static let edge      = UIColor(hex: 0x4A3526, alpha: 0.12)
    static let couch     = UIColor(hex: 0x9E6B79)
    static let couchDeep = UIColor(hex: 0x85586A)
    static let skin      = UIColor(hex: 0xE8C2A0)
    static let shirt     = UIColor(hex: 0x6E8FA8)
    static let sun       = UIColor(hex: 0xFFE39A)
    static let water     = UIColor(hex: 0x7FB7C8)
    static let energy    = UIColor(hex: 0x5FA8C4)
    static let susp      = UIColor(hex: 0xD7453A)
    static let gold      = UIColor(hex: 0xE0A93C)
    static let good      = UIColor(hex: 0x6E9C58)
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                  green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(hex & 0xFF) / 255.0, alpha: alpha)
    }
}

extension UIFont {
    /// System font with the rounded design when available.
    static func rounded(_ size: CGFloat, _ weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }
}

// MARK: - Label helper
func makeLabel(_ text: String, size: CGFloat, color: UIColor = Palette.ink,
               weight: UIFont.Weight = .bold,
               h: SKLabelHorizontalAlignmentMode = .center,
               v: SKLabelVerticalAlignmentMode = .center) -> SKLabelNode {
    let l = SKLabelNode(text: text)
    l.fontName = UIFont.rounded(size, weight).fontName
    l.fontSize = size
    l.fontColor = color
    l.horizontalAlignmentMode = h
    l.verticalAlignmentMode = v
    return l
}

// MARK: - Rounded panel
func roundedPanel(_ size: CGSize, fill: UIColor, corner: CGFloat = 18,
                  shadow: Bool = true) -> SKShapeNode {
    let rect = CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height)
    if shadow {
        let s = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
        s.fillColor = UIColor(hex: 0x4A3526, alpha: 0.13)
        s.strokeColor = .clear
        s.position = CGPoint(x: 0, y: -4)
        let node = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
        node.fillColor = fill
        node.strokeColor = .clear
        node.addChild(s)
        s.zPosition = -1
        return node
    }
    let node = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
    node.fillColor = fill
    node.strokeColor = .clear
    return node
}

// MARK: - Button
final class ButtonNode: SKNode {
    private let bg: SKShapeNode
    private let label: SKLabelNode
    var onTap: (() -> Void)?
    var isEnabledButton = true { didSet { bg.alpha = isEnabledButton ? 1 : 0.45 } }

    init(_ title: String, size: CGSize, fill: UIColor = Palette.ink,
         textColor: UIColor = Palette.panel, fontSize: CGFloat = 18, shadow: Bool = true) {
        bg = roundedPanel(size, fill: fill, corner: min(18, size.height/2), shadow: shadow)
        label = makeLabel(title, size: fontSize, color: textColor, weight: .heavy)
        super.init()
        addChild(bg)
        addChild(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ t: String) { label.text = t }

    func trigger() {
        guard isEnabledButton else { return }
        run(.sequence([
            .scale(to: 0.94, duration: 0.05),
            .scale(to: 1.0, duration: 0.07)
        ]))
        onTap?()
    }
}

// MARK: - Meter bar
final class BarNode: SKNode {
    private let track: SKShapeNode
    private let fill: SKShapeNode
    private let w: CGFloat
    private let h: CGFloat
    init(width: CGFloat, height: CGFloat = 10, color: UIColor) {
        w = width; h = height
        let rect = CGRect(x: 0, y: -height/2, width: width, height: height)
        track = SKShapeNode(path: UIBezierPath(roundedRect: rect, cornerRadius: height/2).cgPath)
        track.fillColor = UIColor(hex: 0x4A3526, alpha: 0.16); track.strokeColor = .clear
        fill = SKShapeNode()
        fill.fillColor = color; fill.strokeColor = .clear
        super.init()
        addChild(track); addChild(fill)
        setValue(1)
    }
    required init?(coder: NSCoder) { fatalError() }
    func setColor(_ c: UIColor) { fill.fillColor = c }
    func setValue(_ v: CGFloat) {
        let clamped = max(0, min(1, v))
        let rect = CGRect(x: 0, y: -h/2, width: max(0.001, w * clamped), height: h)
        fill.path = UIBezierPath(roundedRect: rect, cornerRadius: h/2).cgPath
    }
}

// Triangle path helper for ears, noses, etc.
func triPath(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPath {
    let p = UIBezierPath()
    p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.close()
    return p.cgPath
}
