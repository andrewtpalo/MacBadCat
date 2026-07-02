import SwiftUI
import SpriteKit
import UIKit
import AudioToolbox

// Lightweight persistent breadcrumb (kept for any future crash tracing; harmless).
func debugCheckpoint(_ s: String) {
    UserDefaults.standard.set(s, forKey: "macbadcat.lastCheckpoint")
}

@main
struct MacBadCatApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct GameContainerView: View {
    var body: some View {
        SpriteHost().ignoresSafeArea()
    }
}

/// An SKView that presents the menu scene the moment UIKit gives it a real size, via
/// layoutSubviews (which is reliably called once laid out). Presenting at the real bounds
/// means the scene builds at the actual screen size — true dynamic sizing.
final class HostSKView: SKView {
    private var didPresent = false
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didPresent, bounds.width > 1, bounds.height > 1 else { return }
        didPresent = true
        let scene = MenuScene(size: bounds.size)
        scene.scaleMode = .resizeFill
        presentScene(scene)
    }
}

struct SpriteHost: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let v = HostSKView(frame: .zero)
        v.ignoresSiblingOrder = true
        return v
    }
    func updateUIView(_ v: SKView, context: Context) {}
}

// Audio kept tiny via optional system sounds.
enum SFX {
    static func play(_ id: SystemSoundID) {
        guard GameData.shared.soundOn else { return }
        AudioServicesPlaySystemSound(id)
    }
    // generic light feedback
    static func tap() { play(1104) }
    static func crash() { play(1051) }
    static func coin() { play(1057) }
    static func win() { play(1025) }
    static func caught() { play(1053) }
}

// MARK: - Base scene
class BaseScene: SKScene {
    var topInset: CGFloat { view?.safeAreaInsets.top ?? 20 }
    var bottomInset: CGFloat { view?.safeAreaInsets.bottom ?? 12 }

    override func didMove(to view: SKView) {
        debugCheckpoint("didMove:\(type(of: self))")
        anchorPoint = .zero
        build()
    }

    /// Subclasses build their content here.
    func build() {}

    func navigate(to scene: BaseScene, _ transition: SKTransition = .push(with: .left, duration: 0.32)) {
        scene.scaleMode = .resizeFill
        scene.size = size
        view?.presentScene(scene, transition: transition)
    }

    // Walk the node tree to find a tapped ButtonNode, else hand off to world tap.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        for n in nodes(at: loc) {
            var node: SKNode? = n
            while let cur = node {
                if let b = cur as? ButtonNode { SFX.tap(); b.trigger(); return }
                node = cur.parent
            }
        }
        worldTouch(at: loc)
    }
    func worldTouch(at point: CGPoint) {}

    // Shared: a coin chip in the top-right
    func addCoinChip() -> SKLabelNode {
        let chip = roundedPanel(CGSize(width: 110, height: 34), fill: Palette.panel, corner: 17)
        chip.position = CGPoint(x: size.width - 70, y: size.height - topInset - 26)
        chip.zPosition = 50
        addChild(chip)
        let icon = SKShapeNode(circleOfRadius: 9); icon.fillColor = Palette.gold; icon.strokeColor = .clear
        icon.position = CGPoint(x: -38, y: 0); chip.addChild(icon)
        let label = makeLabel("\(GameData.shared.coins)", size: 17, color: Palette.ink, weight: .heavy, h: .left)
        label.position = CGPoint(x: -22, y: 0)
        chip.addChild(label)
        return label
    }

    func addBackButton(_ action: @escaping () -> Void) {
        let b = ButtonNode("‹", size: CGSize(width: 40, height: 40), fill: Palette.panel, textColor: Palette.ink, fontSize: 24)
        b.position = CGPoint(x: 34, y: size.height - topInset - 26)
        b.zPosition = 50
        b.onTap = action
        addChild(b)
    }

    func addRoomBackground(_ wall: UIColor) {
        let top = SKSpriteNode(color: wall, size: CGSize(width: size.width, height: size.height))
        top.anchorPoint = .zero; top.zPosition = -100; addChild(top)
    }

    /// Slide-in toasts for newly unlocked achievements (staggered when several unlock at once).
    func showAchievements(_ list: [Achievement]) {
        for (i, a) in list.enumerated() {
            run(.sequence([.wait(forDuration: Double(i) * 0.5), .run { [weak self] in self?.toast(a) }]))
        }
    }
    private func toast(_ a: Achievement) {
        let w = min(320, size.width - 32)
        let panel = roundedPanel(CGSize(width: w, height: 62), fill: Palette.panel, corner: 16)
        panel.zPosition = 400
        panel.position = CGPoint(x: size.width / 2, y: size.height + 40)
        let icon = IconFactory.trophy(); icon.position = CGPoint(x: -w / 2 + 30, y: 0); panel.addChild(icon)
        let t = makeLabel("Achievement!", size: 11, color: Palette.inkSoft, weight: .heavy, h: .left)
        t.position = CGPoint(x: -w / 2 + 52, y: 13); panel.addChild(t)
        let nm = makeLabel("\(a.name)  ·  +\(a.reward)", size: 15, color: Palette.ink, weight: .black, h: .left)
        nm.position = CGPoint(x: -w / 2 + 52, y: -9); panel.addChild(nm)
        addChild(panel)
        Haptics.win(); SFX.win()
        panel.run(.sequence([
            .move(to: CGPoint(x: size.width / 2, y: size.height - topInset - 40), duration: 0.3),
            .wait(forDuration: 2.4),
            .group([.moveBy(x: 0, y: 60, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }
}
