import AppKit
import CoreGraphics

// Renders the 1024×1024 App Store icon for "Bad Cat" using CoreGraphics (display-independent,
// so it runs headless on CI). Output goes into the AppIcon asset set before the Xcode build.

let W = 1024
let outPath = "App/Assets.xcassets/AppIcon.appiconset/icon1024.png"

func rgb(_ h: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 0xFF) / 255.0,
            green: CGFloat((h >> 8) & 0xFF) / 255.0,
            blue: CGFloat(h & 0xFF) / 255.0, alpha: a)
}

let cs = CGColorSpaceCreateDeviceRGB()
// noneSkipLast → opaque image with no alpha channel (App Store icons must not have alpha).
guard let ctx = CGContext(data: nil, width: W, height: W, bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fputs("icon: could not create context\n", stderr); exit(1)
}

func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}
func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ color: CGColor) {
    ctx.beginPath(); ctx.move(to: a); ctx.addLine(to: b); ctx.addLine(to: c); ctx.closePath()
    ctx.setFillColor(color); ctx.fillPath()
}

// Background: warm flame gradient (full-bleed; iOS masks the corners).
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0xF2A85A), rgb(0xDA7638)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(W)), end: CGPoint(x: 0, y: 0), options: [])
// Soft spotlight behind the cat.
ell(512, 470, 400, 400, rgb(0xFFFFFF, 0.12))

let cream = rgb(0xF7EFE3), flame = rgb(0xE0834C), pink = rgb(0xE6A7A0)
let ink = rgb(0x4A3526), eye = rgb(0x5FA8C4)

// Ears (outer flame + inner pink).
tri(CGPoint(x: 300, y: 640), CGPoint(x: 250, y: 910), CGPoint(x: 470, y: 720), flame)
tri(CGPoint(x: 724, y: 640), CGPoint(x: 774, y: 910), CGPoint(x: 554, y: 720), flame)
tri(CGPoint(x: 322, y: 662), CGPoint(x: 300, y: 838), CGPoint(x: 430, y: 720), pink)
tri(CGPoint(x: 702, y: 662), CGPoint(x: 724, y: 838), CGPoint(x: 594, y: 720), pink)

// Head + flame mask.
ell(512, 460, 300, 278, cream)
ell(512, 430, 205, 150, rgb(0xE0834C, 0.9))

// Eyes — big and a little mischievous.
for cx in [CGFloat(408), CGFloat(616)] {
    ell(cx, 500, 62, 78, rgb(0xFFFFFF))
    ell(cx, 496, 50, 64, eye)
    ell(cx, 492, 22, 50, ink)
    ell(cx - 14, 520, 12, 12, rgb(0xFFFFFF))
}

// Nose + smirk.
tri(CGPoint(x: 512, y: 372), CGPoint(x: 484, y: 400), CGPoint(x: 540, y: 400), pink)
ctx.setStrokeColor(ink); ctx.setLineWidth(9); ctx.setLineCap(.round)
ctx.beginPath()
ctx.move(to: CGPoint(x: 512, y: 372)); ctx.addLine(to: CGPoint(x: 512, y: 340))
ctx.move(to: CGPoint(x: 512, y: 340)); ctx.addCurve(to: CGPoint(x: 452, y: 322), control1: CGPoint(x: 496, y: 328), control2: CGPoint(x: 474, y: 322))
ctx.move(to: CGPoint(x: 512, y: 340)); ctx.addCurve(to: CGPoint(x: 572, y: 322), control1: CGPoint(x: 528, y: 328), control2: CGPoint(x: 550, y: 322))
ctx.strokePath()

// Whiskers.
ctx.setStrokeColor(rgb(0x4A3526, 0.55)); ctx.setLineWidth(7)
for dy in [CGFloat(-18), 24] {
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 470, y: 372 + dy)); ctx.addLine(to: CGPoint(x: 300, y: 392 + dy * 1.4))
    ctx.move(to: CGPoint(x: 554, y: 372 + dy)); ctx.addLine(to: CGPoint(x: 724, y: 392 + dy * 1.4))
    ctx.strokePath()
}

// Mischief sparkle.
tri(CGPoint(x: 800, y: 760), CGPoint(x: 820, y: 800), CGPoint(x: 840, y: 760), rgb(0xFFE39A))
tri(CGPoint(x: 800, y: 760), CGPoint(x: 820, y: 720), CGPoint(x: 840, y: 760), rgb(0xFFE39A))

guard let cg = ctx.makeImage() else { fputs("icon: makeImage failed\n", stderr); exit(1) }
let rep = NSBitmapImageRep(cgImage: cg)
guard let png = rep.representation(using: .png, properties: [:]) else { fputs("icon: png failed\n", stderr); exit(1) }
do { try png.write(to: URL(fileURLWithPath: outPath)); print("icon: wrote \(outPath)") }
catch { fputs("icon: write failed \(error)\n", stderr); exit(1) }
