import Foundation
import SwiftUI
import UIKit

@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var adBlock: Bool { didSet { defaults.set(adBlock, forKey: "adBlock") } }
    @Published var sponsorBlock: Bool { didSet { defaults.set(sponsorBlock, forKey: "sponsorBlock") } }
    @Published var categories: Set<String> { didSet { defaults.set(Array(categories), forKey: "categories") } }
    @Published var accentHex: String { didSet { defaults.set(accentHex, forKey: "accentHex") } }
    @Published var appearance: String { didSet { defaults.set(appearance, forKey: "appearance") } }
    @Published var onboardingDone: Bool { didSet { defaults.set(onboardingDone, forKey: "onboardingDone") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["adBlock": true, "sponsorBlock": true, "categories": ["sponsor"], "accentHex": "FF0000", "appearance": "dark", "onboardingDone": false])
        adBlock = defaults.bool(forKey: "adBlock")
        sponsorBlock = defaults.bool(forKey: "sponsorBlock")
        categories = Set(defaults.stringArray(forKey: "categories") ?? ["sponsor"])
        let saved = defaults.string(forKey: "accentHex") ?? "FF0000"
        accentHex = saved.range(of: "^[A-Fa-f0-9]{6}$", options: .regularExpression) != nil ? saved : "FF0000"
        appearance = defaults.string(forKey: "appearance") ?? "dark"
        onboardingDone = defaults.bool(forKey: "onboardingDone")
    }
    var accent: Color { Color(hex: accentHex) }
    var colorScheme: ColorScheme? { appearance == "system" ? nil : appearance == "light" ? .light : .dark }
    func setColor(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        accentHex = String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    var payload: [String: Any] {
        ["adBlock": adBlock, "sponsorBlock": sponsorBlock, "categories": Array(categories), "accent": "#\(accentHex)", "appearance": appearance]
    }
    var fingerprint: String { "\(adBlock)|\(sponsorBlock)|\(categories.sorted())|\(accentHex)|\(appearance)" }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0xFF0000
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}
