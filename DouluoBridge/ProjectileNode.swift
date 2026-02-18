import SpriteKit
import UIKit

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
        // Match original: player bullets are 70×size, enemy bullets are 25×10
        let w: CGFloat = owner == .player ? 70 : 25
        let h: CGFloat = CGFloat(size)
        
        let bullet = SKShapeNode(rectOf: CGSize(width: w, height: h))
        bullet.fillColor = color
        bullet.strokeColor = .clear
        bullet.glowWidth = 15  // Neon glow — match HTML shadowBlur=20
        addChild(bullet)
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
