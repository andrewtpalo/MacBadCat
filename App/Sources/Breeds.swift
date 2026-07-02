import UIKit

/// A cat breed is a color scheme applied to CatNode: base coat, shading, accent
/// (ears / tail tip / mask / socks), and eye color.
struct BreedStyle {
    let coat: UIColor
    let shade: UIColor
    let accent: UIColor
    let eye: UIColor
}

enum Breeds {
    static let styles: [String: BreedStyle] = [
        "breed_flame":   BreedStyle(coat: UIColor(hex: 0xF7EFE3), shade: UIColor(hex: 0xEADDC9),
                                    accent: UIColor(hex: 0xE0834C), eye: UIColor(hex: 0x5FA8C4)),
        "breed_black":   BreedStyle(coat: UIColor(hex: 0x3A3540), shade: UIColor(hex: 0x2C2833),
                                    accent: UIColor(hex: 0x55505E), eye: UIColor(hex: 0xE0A93C)),
        "breed_gray":    BreedStyle(coat: UIColor(hex: 0xA9B2BC), shade: UIColor(hex: 0x939CA8),
                                    accent: UIColor(hex: 0x7E8894), eye: UIColor(hex: 0x6E9C58)),
        "breed_calico":  BreedStyle(coat: UIColor(hex: 0xF7EFE3), shade: UIColor(hex: 0xD8C7AE),
                                    accent: UIColor(hex: 0x9C6B3F), eye: UIColor(hex: 0xC98A2E)),
        "breed_siamese": BreedStyle(coat: UIColor(hex: 0xEFE2CE), shade: UIColor(hex: 0xE0D0B8),
                                    accent: UIColor(hex: 0x6B5240), eye: UIColor(hex: 0x77B8D4)),
        "breed_snow":    BreedStyle(coat: UIColor(hex: 0xFFFFFF), shade: UIColor(hex: 0xEDEDF2),
                                    accent: UIColor(hex: 0xD9DDE8), eye: UIColor(hex: 0x8FB7E8)),
    ]
    static func style(_ id: String) -> BreedStyle {
        styles[id] ?? styles["breed_flame"]!
    }
}
