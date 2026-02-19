import UIKit

extension UIColor {
    func darkened(_ factor: CGFloat = 0.5) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: max(r * factor, 0), green: max(g * factor, 0), blue: max(b * factor, 0), alpha: a)
        }
        return self
    }
}
