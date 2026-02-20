import SpriteKit
import UIKit

// MARK: - Projectile Texture Cache (v1.6 Performance)
private class ProjectileTextureCache {
    static let shared = ProjectileTextureCache()
    private var cache: [String: SKTexture] = [:]
    
    func texture(owner: ProjectileNode.ProjectileOwner, size: Int, color: UIColor) -> SKTexture {
        // Quantize color to reduce cache entries
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let cr = Int(r * 10)
        let cg = Int(g * 10)
        let cb = Int(b * 10)
        let key = "\(owner == .player ? "p" : "e")_\(size)_\(cr)_\(cg)_\(cb)"
        
        if let cached = cache[key] { return cached }
        
        let w: CGFloat = owner == .player ? 70 : 25
        let h: CGFloat = CGFloat(size)
        // Add glow padding
        let padding: CGFloat = 30
        let texW = w + padding * 2
        let texH = h + padding * 2
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: texW, height: texH))
        let image = renderer.image { ctx in
            let g = ctx.cgContext
            // Glow effect
            g.setShadow(offset: .zero, blur: 15, color: color.cgColor)
            g.setFillColor(color.cgColor)
            g.fill(CGRect(x: padding, y: padding, width: w, height: h))
            // Draw again without shadow for solid core
            g.setShadow(offset: .zero, blur: 0)
            g.fill(CGRect(x: padding, y: padding, width: w, height: h))
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        cache[key] = texture
        return texture
    }
}

class ProjectileNode: SKNode {
    
    var vx: CGFloat
    var vy: CGFloat
    var damage: Int
    var owner: ProjectileOwner
    var life: Int
    var size: Int
    var homing: Bool
    var color: UIColor
    
    enum ProjectileOwner {
        case player, enemy
    }
    
    init(vx: CGFloat, vy: CGFloat, damage: Int, owner: ProjectileOwner,
         color: UIColor, life: Int, size: Int = 10, homing: Bool = false) {
        self.vx = vx
        self.vy = vy
        self.damage = damage
        self.owner = owner
        self.color = color
        self.life = life
        self.size = size
        self.homing = homing
        
        super.init()
        setupVisual()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupVisual() {
        // v1.6: Use cached SKSpriteNode texture instead of SKShapeNode with glow
        let texture = ProjectileTextureCache.shared.texture(owner: owner, size: size, color: color)
        let w: CGFloat = owner == .player ? 70 : 25
        let h: CGFloat = CGFloat(size)
        let padding: CGFloat = 30
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: w + padding * 2, height: h + padding * 2)
        addChild(sprite)
    }
    
    func update(enemies: [EnemyNode]) {
        // Move (native SpriteKit Y)
        position.x += vx
        position.y += vy
        
        // Homing
        if homing && owner == .player && !enemies.isEmpty {
            let nearest = enemies.min(by: {
                hypot($0.position.x - position.x, $0.position.y - position.y) <
                hypot($1.position.x - position.x, $1.position.y - position.y)
            })
            if let target = nearest {
                let dx = target.position.x - position.x
                let dy = target.position.y - position.y
                let dist = hypot(dx, dy)
                if dist > 0 {
                    vx += (dx / dist) * 1.5
                    vy += (dy / dist) * 1.5
                }
            }
        }
        
        life -= 1
    }
}
