import SwiftUI
import SpriteKit
import AudioToolbox

// Simple persistent checkpoint helper for crash tracing.
func debugCheckpoint(_ s: String) {
    UserDefaults.standard.set(s, forKey: "macbadcat.lastCheckpoint")
    // Ensure it's written quickly.
    UserDefaults.standard.synchronize()

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
        GeometryReader { geo in
            // record checkpoint before creating the main scene
            debugCheckpoint("MakeScene: size:\(geo.size.width)x\(geo.size.height)")
            SpriteView(scene: makeScene(geo.size))
                .ignoresSafeArea()
        }
    }
    private func makeScene(_ size: CGSize) -> SKScene {
        let s = MenuScene(size: size.width > 0 ? size : CGSize(width: 390, height: 844))
        s.scaleMode = .resizeFill
        return s
    }
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
}
