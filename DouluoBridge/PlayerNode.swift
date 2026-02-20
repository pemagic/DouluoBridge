import SpriteKit
import UIKit

class PlayerNode: SKNode {
    
    // MARK: - Properties
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    let width: CGFloat = 40
    let height: CGFloat = 64
    var hp: Int = 100
    var energy: Int = 0
    var weaponLevel: Int = 1
    var facing: Int = 1
    var grounded: Bool = false
    var jumpCount: Int = 0
    var dashCooldown: Int = 0
    var dashActive: Int = 0
    var shootTimer: Int = 0
    var iframe: Int = 0
    var animTime: CGFloat = 0
    var ultActive: Int = 0
    
    var skills: [String: SkillState] = [:]
    
    // Visual layers
    private var bodyGroup: SKNode!
    private var orbitNode: SKNode?
    private var shieldNode: SKSpriteNode?   // v1.6: Cached shield visual
    private var ultGlowNode: SKSpriteNode?  // v1.6: Cached ult glow visual
    
    // Neon palette (from original)
    static let neonColors: [UIColor] = [
        UIColor(red: 1, green: 0, blue: 1, alpha: 1),      // #ff00ff
        UIColor(red: 0, green: 1, blue: 1, alpha: 1),      // #00ffff
        UIColor(red: 1, green: 1, blue: 0, alpha: 1),      // #ffff00
        UIColor(red: 0, green: 1, blue: 0, alpha: 1),      // #00ff00
        UIColor(red: 1, green: 0, blue: 0, alpha: 1),      // #ff0000
        UIColor(red: 1, green: 0.53, blue: 0, alpha: 1),   // #ff8800
        UIColor(red: 0, green: 1, blue: 0.53, alpha: 1),   // #00ff88
        UIColor(red: 0.53, green: 0, blue: 1, alpha: 1),   // #8800ff
        .white                                               // #ffffff
    ]
    
    override init() {
        super.init()
        setupSkills()
        bodyGroup = SKNode()
        addChild(bodyGroup)
        setupCachedEffects()
        rebuildVisual()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSkills() {
        for def in GameConfig.skillDefs {
            skills[def.id] = SkillState()
        }
    }
    
    // v1.6: Pre-create shield and ult glow nodes (hidden by default)
    private func setupCachedEffects() {
        // Shield circle — rendered to texture
        let shieldSize: CGFloat = 90  // diameter
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: shieldSize, height: shieldSize))
        let shieldImg = renderer.image { ctx in
            let g = ctx.cgContext
            let rect = CGRect(x: 3, y: 3, width: shieldSize - 6, height: shieldSize - 6)
            g.setFillColor(UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.2).cgColor)
            g.fillEllipse(in: rect)
            g.setStrokeColor(UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.8).cgColor)
            g.setLineWidth(3)
            g.strokeEllipse(in: rect)
        }
        let sn = SKSpriteNode(texture: SKTexture(image: shieldImg))
        sn.size = CGSize(width: shieldSize, height: shieldSize)
        sn.zPosition = 10
        sn.isHidden = true
        addChild(sn)
        shieldNode = sn
        
        // Ult glow — rendered to texture
        let glowSize: CGFloat = 110
        let glowRenderer = UIGraphicsImageRenderer(size: CGSize(width: glowSize, height: glowSize))
        let glowImg = glowRenderer.image { ctx in
            let g = ctx.cgContext
            let rect = CGRect(x: 5, y: 5, width: glowSize - 10, height: glowSize - 10)
            g.setFillColor(UIColor(white: 1, alpha: 0.15).cgColor)
            g.fillEllipse(in: rect)
        }
        let gn = SKSpriteNode(texture: SKTexture(image: glowImg))
        gn.size = CGSize(width: glowSize, height: glowSize)
        gn.zPosition = -1
        gn.isHidden = true
        addChild(gn)
        ultGlowNode = gn
    }
    
    func reset() {
        vx = 0; vy = 0; hp = 100; energy = 0; weaponLevel = 1
        facing = 1; grounded = false; jumpCount = 0
        dashCooldown = 0; dashActive = 0; shootTimer = 0
        iframe = 0; animTime = 0; ultActive = 0
        for (_, state) in skills { state.level = 0; state.cooldown = 0; state.active = 0 }
        rebuildVisual()
    }
    
    // MARK: - Rebuild visual to match weapon level
    
    func rebuildVisual() {
        bodyGroup.removeAllChildren()
        orbitNode?.removeFromParent()
        orbitNode = nil
        
        let lvl = weaponLevel
        
        // 1. Cape/Cloak — quadratic curve shape
        let cloakColor: UIColor
        if lvl >= 10 { cloakColor = PlayerNode.neonColors[0].darkened(0.6) }
        else if lvl >= 7 { cloakColor = UIColor(red: 0.30, green: 0.11, blue: 0.58, alpha: 1).darkened(0.6) } // #4c1d95
        else if lvl >= 4 { cloakColor = UIColor(red: 0.19, green: 0.18, blue: 0.51, alpha: 1).darkened(0.6) } // #312e81
        else { cloakColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1).darkened(0.6) } // #222
        
        let capePath = UIBezierPath()
        let capeWidth: CGFloat = 30 + CGFloat(lvl) * 3
        capePath.move(to: CGPoint(x: 0, y: 10))  // shoulder
        capePath.addQuadCurve(to: CGPoint(x: 0, y: -height/2),
                              controlPoint: CGPoint(x: -capeWidth, y: 0))
        capePath.addLine(to: CGPoint(x: 0, y: 10))
        
        let cape = SKShapeNode(path: capePath.cgPath)
        cape.fillColor = cloakColor
        cape.strokeColor = .clear
        cape.zPosition = -1
        bodyGroup.addChild(cape)
        
        // 2. Body/Torso — white rectangle
        let torso = SKShapeNode(rectOf: CGSize(width: 20, height: 40))
        torso.fillColor = (lvl >= 7 ? .white : UIColor(white: 0.93, alpha: 1)).darkened(0.6)
        torso.strokeColor = .clear
        torso.position = CGPoint(x: 0, y: -10)
        bodyGroup.addChild(torso)
        
        // 3. 斗笠 Hat — triangle
        let hatWidth: CGFloat = 25 + CGFloat(lvl) * 1.2
        let hatHeight: CGFloat = 15 + CGFloat(lvl) / 1.5
        let hatColor: UIColor = lvl >= 7
            ? UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1).darkened(0.6)
            : UIColor(red: 0.27, green: 0.27, blue: 0.27, alpha: 1).darkened(0.6)
        
        let hatPath = UIBezierPath()
        hatPath.move(to: CGPoint(x: -hatWidth, y: 25))
        hatPath.addLine(to: CGPoint(x: 0, y: 25 + hatHeight))
        hatPath.addLine(to: CGPoint(x: hatWidth, y: 25))
        hatPath.close()
        
        let hat = SKShapeNode(path: hatPath.cgPath)
        hat.fillColor = hatColor
        hat.strokeColor = lvl >= 10 ? .white.darkened(0.6) : .clear
        hat.lineWidth = lvl >= 10 ? 2 : 0
        hat.zPosition = 2
        if lvl >= 10 {
            hat.glowWidth = 10
        }
        bodyGroup.addChild(hat)
        
        // 4. Sword — line from body
        let swordLength: CGFloat = 35 + CGFloat(lvl) * 2.5
        let swordWidth: CGFloat = 3 + CGFloat(lvl) / 2.5
        let swordColor: UIColor
        if lvl >= 10 { swordColor = PlayerNode.neonColors[0].darkened(0.6) }
        else if lvl >= 7 { swordColor = UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1).darkened(0.6) }
        else { swordColor = .white.darkened(0.6) }
        
        let swordPath = UIBezierPath()
        swordPath.move(to: CGPoint(x: 10, y: 0))
        swordPath.addLine(to: CGPoint(x: 10 + swordLength, y: -10))
        
        let sword = SKShapeNode(path: swordPath.cgPath)
        sword.strokeColor = swordColor
        sword.lineWidth = swordWidth
        sword.lineCap = .round
        sword.zPosition = 3
        if lvl >= 10 {
            sword.glowWidth = 10
        } else if lvl >= 7 {
            sword.glowWidth = 7
        } else if lvl >= 4 {
            sword.glowWidth = 4
        } else {
            sword.glowWidth = 2
        }
        bodyGroup.addChild(sword)
        
        // 5. Lv10: orbiting swords
        if lvl >= 10 {
            let orbit = SKNode()
            orbit.zPosition = -2
            for i in 0..<8 {
                let ang = CGFloat(i) / 8.0 * .pi * 2
                let swordOrbit = SKShapeNode(rectOf: CGSize(width: 4, height: 36))
                swordOrbit.fillColor = PlayerNode.neonColors[i % PlayerNode.neonColors.count].darkened(0.6)
                swordOrbit.strokeColor = .clear
                swordOrbit.position = CGPoint(x: cos(ang) * 55, y: sin(ang) * 55)
                swordOrbit.zRotation = ang + .pi / 2
                swordOrbit.glowWidth = 3
                orbit.addChild(swordOrbit)
            }
            addChild(orbit)
            orbitNode = orbit
            
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 1.05)
            orbit.run(SKAction.repeatForever(rotate))
        }
    }
    
    // MARK: - Per-Frame Visual Update
    
    func updateVisual() {
        animTime += abs(vx) * 0.1 + 0.1
        
        // Flip
        xScale = CGFloat(facing)
        
        // Bob animation
        let bob = sin(animTime) * 5
        bodyGroup.position.y = bob
        
        // Iframe flash
        if iframe > 0 {
            alpha = (iframe % 4 < 2) ? 1.0 : 0.0
        } else {
            alpha = 1.0
        }
        
        // Dash: orange flash
        if dashActive > 0 {
            bodyGroup.children.first(where: { $0.zPosition == 0 })?.run(
                SKAction.sequence([
                    SKAction.colorize(with: UIColor(red: 1, green: 0.5, blue: 0.2, alpha: 1), colorBlendFactor: 1, duration: 0),
                    SKAction.wait(forDuration: 0.05),
                    SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
                ])
            )
        }
        
        // Lv10: update orbit sword colors
        if weaponLevel >= 10, let orbit = orbitNode {
            let gt = Int(animTime)
            for (i, child) in orbit.children.enumerated() {
                if let shape = child as? SKShapeNode {
                    shape.fillColor = PlayerNode.neonColors[(gt + i) % PlayerNode.neonColors.count]
                }
            }
        }
        
        // v1.6: Shield Visual — toggle cached node visibility instead of creating new SKShapeNode
        if let shield = skills["shield"], shield.active > 0 {
            shieldNode?.isHidden = false
        } else {
            shieldNode?.isHidden = true
        }
        
        // v1.6: Ultimate glow — toggle cached node visibility
        ultGlowNode?.isHidden = ultActive <= 0
    }
}
