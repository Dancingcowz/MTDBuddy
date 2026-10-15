import SwiftUI

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Relative luminance, used to decide whether a route color needs darkening for contrast
    /// against a white/light background (e.g. Gold/Cream routes are nearly invisible as-is).
    var luminance: Double {
        guard let components = rgbComponents() else { return 1 }
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(components.r) + 0.7152 * channel(components.g) + 0.0722 * channel(components.b)
    }

    private struct RGBComponents { let r: Double; let g: Double; let b: Double }

    private func rgbComponents() -> RGBComponents? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBComponents(r: Double(r), g: Double(g), b: Double(b))
    }

    func darkenedForContrast(threshold: Double = 0.55, by factor: Double = 0.7) -> Color {
        guard luminance > threshold else { return self }
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(v) * factor)
    }
}

enum MTDRouteColor {
    /// MTD's official route color, darkened when needed so route badges stay legible on a
    /// white card in light mode (several MTD colors, e.g. Gold family, are very light).
    static func display(hex: String) -> Color {
        Color(hex: hex).darkenedForContrast()
    }
}

enum IlliniColor {
    static let navy = Color(hex: "13294B")
    static let orange = Color(hex: "FF5F05")
}
