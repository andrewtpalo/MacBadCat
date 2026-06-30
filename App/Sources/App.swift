import SwiftUI
import SpriteKit
import UIKit
import Metal
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
    // TEMPORARY crash-diagnostic gate: a pure-SwiftUI screen that renders BEFORE any
    // SpriteKit scene exists, so if the scene crashes on launch we can still read the
    // last checkpoint from the previous run. Remove once the launch crash is fixed.
    @State private var playing = false

    var body: some View {
        if playing {
            SpriteHost().ignoresSafeArea()
        } else {
            LaunchGate { debugCheckpoint("gate:play-tapped"); playing = true }
        }
    }
}

/// Hosts an SKView directly so we control scene presentation precisely: the view is created
/// once and the scene presented once, avoiding SwiftUI SpriteView's re-presentation lifecycle.
struct SpriteHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        // SpriteKit REQUIRES a Metal device — it has no software fallback. If the simulator
        // has no GPU device, creating an SKView crashes. Detect that and show a message
        // instead of crashing, so we can confirm the cause.
        let hasMetal = (MTLCreateSystemDefaultDevice() != nil)
        debugCheckpoint("SpriteHost:make metal=\(hasMetal)")
        guard hasMetal else {
            debugCheckpoint("SpriteHost:NO-METAL")
            let label = PaddedLabel()
            label.text = "This environment has no Metal GPU,\nso SpriteKit can't render.\n(The game logic is fine — it needs a\nMetal-capable simulator/device.)"
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = UIColor(hex: 0x4A3526)
            label.backgroundColor = UIColor(hex: 0xB6BFA6)
            label.font = .systemFont(ofSize: 16, weight: .semibold)
            return label
        }
        let v = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        debugCheckpoint("SpriteHost:skview")
        v.ignoresSiblingOrder = true
        let scene = MenuScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        debugCheckpoint("SpriteHost:scene")
        v.presentScene(scene)
        debugCheckpoint("SpriteHost:presented")
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let v = uiView as? SKView else { return }
        let b = v.bounds.size
        if b.width > 1, b.height > 1, let s = v.scene, s.size != b { s.size = b }
    }
}

/// Plain UILabel that fills available space (used only for the no-Metal fallback message).
final class PaddedLabel: UILabel {}

struct LaunchGate: View {
    let onPlay: () -> Void
    var body: some View {
        let last = UserDefaults.standard.string(forKey: "macbadcat.lastCheckpoint") ?? "(none)"
        ZStack {
            Color(red: 0.71, green: 0.75, blue: 0.65).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("Bad Cat")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.29, green: 0.21, blue: 0.15))
                Text("last checkpoint")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.48, green: 0.39, blue: 0.32))
                Text(last)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.29, green: 0.21, blue: 0.15))
                    .padding(.horizontal, 24)
                Button(action: onPlay) {
                    Text("Play")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 64).padding(.vertical, 16)
                        .background(Color(red: 0.29, green: 0.21, blue: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
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
}
