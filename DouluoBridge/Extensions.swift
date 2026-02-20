import UIKit

extension UIColor {
    func darkened(_ factor: CGFloat = 0.5) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: max(r * factor, 0), green: max(g * factor, 0), blue: max(b * factor, 0), alpha: a)
        }
        return self
    }
    
    func lightened(minBrightness: CGFloat = 0.85, maxSaturation: CGFloat = 0.3) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(
                hue: h,
                saturation: min(s, maxSaturation),     // Fade out strong colors to pastel
                brightness: max(b, minBrightness),     // Ensure it's very bright
                alpha: a
            )
        }
        return self
    }
}
