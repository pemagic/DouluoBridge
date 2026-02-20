import SpriteKit
import UIKit

// MARK: - Texture Cache for Performance
// Pre-rendered stick figure textures to avoid creating hundreds of SKShapeNodes per frame
private class EnemyTextureCache {
    static let shared = EnemyTextureCache()
    private var cache: [String: SKTexture] = [:]
    
    func texture(forKey key: String, size: CGSize, drawBlock: (CGContext) -> Void) -> SKTexture {
        if let cached = cache[key] { return cached }
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            drawBlock(ctx.cgContext)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        cache[key] = texture
        return texture
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

class EnemyNode: SKNode {
    
    // MARK: - Properties (match original HTML exactly)
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var hp: CGFloat
    var maxHp: CGFloat
    var baseSpeed: CGFloat
    var enemyType: EnemyType
    var isBoss: Bool
    var color: UIColor
    var enemyWidth: CGFloat
    var enemyHeight: CGFloat
    var grounded: Bool = false
    var shootTimer: CGFloat = 0
    var damageFlash: Int = 0
    var animPhase: CGFloat = CGFloat.random(in: 0...(CGFloat.pi * 2))
    var aimTimer: Int = 0  // sniper only
    var damage: Int = 12   // default enemy bullet damage
    var enemyTier: Int = 1
    var bossType: BossType?
    var martialCombo: Int = 0
    var martialTimer: Int = 0
    private var lastDrawnPhase: Int = -1  // Performance: skip redundant redraws
    private var lastDamageFlashState: Bool = false  // Track flash state transitions
    
    // Boss
    var rageMode: Bool = false
    
    // v1.6 Performance: Single sprite node replaces entire stickGroup of SKShapeNodes
    private var stickSprite: SKSpriteNode!
    private var hpBar: SKSpriteNode?      // v1.6: SKSpriteNode instead of SKShapeNode
    private var hpFill: SKSpriteNode?     // v1.6: SKSpriteNode instead of SKShapeNode
    private var aimLine: SKSpriteNode?    // v1.6: SKSpriteNode for sniper aim line
    private var lastAimAlphaLevel: Int = -1  // Quantized aim alpha to avoid re-render
    
    // Rendering constants
    private let renderScale: CGFloat = 2.0  // Retina quality
    private var renderSize: CGSize { CGSize(width: (enemyWidth + 80) * renderScale, height: (enemyHeight + 60) * renderScale) }
    private var renderCenter: CGPoint { CGPoint(x: renderSize.width / 2, y: renderSize.height / 2) }
    
    /// Original init matching HTML's spawnEnemy()
    /// Stats: hp = (heavy?450:120) * (1 + lvlBonus), baseSpeed = (8+rand*6) * typeMult * (1+lvlBonus*0.5)
    init(type: EnemyType, playerWeaponLevel: Int, isBoss: Bool = false, bossHp: Int = 0, bossSpeed: CGFloat = 0, color: UIColor, enemyTier: Int = 1, bossType: BossType? = nil, hpMultiplier: CGFloat = 1.0) {
        self.enemyType = type
        self.isBoss = isBoss
        self.color = color
        self.enemyTier = enemyTier
        self.bossType = bossType
        
        if isBoss {
            self.hp = CGFloat(bossHp) * hpMultiplier
            self.maxHp = CGFloat(bossHp) * hpMultiplier
            self.baseSpeed = bossSpeed * 3
            self.damage = 15
            self.enemyWidth = 80
            self.enemyHeight = 100
        } else {
            // Match original: const lvlBonus = (player.weaponLevel - 1) * 0.15;
            let lvlBonus = CGFloat(playerWeaponLevel - 1) * 0.15
            
            // hp: (type === 'heavy' ? 450 : 120) * (1 + lvlBonus) * hpMultiplier
            let baseHp: CGFloat = (type == .heavy) ? 450 : 120
            self.hp = baseHp * (1 + lvlBonus) * hpMultiplier
            self.maxHp = self.hp
            
            // baseSpeed: (8 + Math.random()*6) * typeMult * (1 + lvlBonus * 0.5)
            let rawSpeed = 8 + CGFloat.random(in: 0...6)
            let typeMult: CGFloat
            switch type {
            case .chaser: typeMult = 1.8
            case .heavy:  typeMult = 0.4
            default:      typeMult = 0.7  // scout, sniper
            }
            self.baseSpeed = rawSpeed * typeMult * (1 + lvlBonus * 0.5)
            
            // Dimensions: w = heavy ? 80 : 50, h = heavy ? 90 : 70
            self.enemyWidth = (type == .heavy) ? 80 : 50
            self.enemyHeight = (type == .heavy) ? 90 : 70
            
            // shootTimer: 40 + Math.random()*60
            self.shootTimer = 40 + CGFloat.random(in: 0...60)
            
            self.damage = 12  // flat 12 for all regular enemy bullets
        }
        
        super.init()
        
        // v1.6: Single sprite node instead of stickGroup with many SKShapeNodes
        stickSprite = SKSpriteNode()
        addChild(stickSprite)
        
        // Boss HP bar — use SKSpriteNode for performance
        if isBoss {
            let barWidth: CGFloat = enemyWidth + 20
            let bar = SKSpriteNode(color: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1), size: CGSize(width: barWidth, height: 6))
            bar.position = CGPoint(x: 0, y: enemyHeight / 2 + 10)
            bar.zPosition = 10
            addChild(bar)
            hpBar = bar
            
            let fill = SKSpriteNode(color: UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1), size: CGSize(width: barWidth - 2, height: 4))
            fill.position = CGPoint(x: 0, y: enemyHeight / 2 + 10)
            fill.zPosition = 11
            addChild(fill)
            hpFill = fill
        }
        
        drawStickFigure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Stick Figure Drawing — Renders to texture for performance
    
    private func drawStickFigure() {
        let drawColor = damageFlash > 0 ? UIColor.white : color
        let lineW: CGFloat = isBoss ? 6 : (enemyType == .heavy ? 8 : 4)
        let t = animPhase
        let h = enemyHeight
        
        // Hover
        let hover = sin(animPhase) * 6
        stickSprite.position.y = hover
        
        // Render to texture using UIGraphicsImageRenderer (v1.6 optimization)
        let size = renderSize
        let cx = renderCenter.x  // center X in render space
        let cy = renderCenter.y  // center Y in render space
        let scale = renderScale
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let g = ctx.cgContext
            g.scaleBy(x: scale, y: scale)
            let cx2 = cx / scale
            let cy2 = cy / scale
            
            // Helper: draw line with glow
            func drawLine(from: CGPoint, to: CGPoint, color: UIColor, width: CGFloat, glow: CGFloat = 0) {
                g.saveGState()
                if glow > 0 {
                    g.setShadow(offset: .zero, blur: glow, color: color.cgColor)
                }
                g.setStrokeColor(color.cgColor)
                g.setLineWidth(width)
                g.setLineCap(.square)
                g.beginPath()
                // Note: CoreGraphics Y is flipped vs SpriteKit — we draw in screen coords (Y-down)
                g.move(to: CGPoint(x: cx2 + from.x, y: cy2 - from.y))
                g.addLine(to: CGPoint(x: cx2 + to.x, y: cy2 - to.y))
                g.strokePath()
                g.restoreGState()
            }
            
            // Helper: draw filled rect with optional glow  
            func drawRect(x: CGFloat, y: CGFloat, w: CGFloat, rh: CGFloat, fillColor: UIColor, strokeColor: UIColor? = nil, strokeWidth: CGFloat = 0, glow: CGFloat = 0) {
                g.saveGState()
                if glow > 0 {
                    g.setShadow(offset: .zero, blur: glow, color: fillColor.cgColor)
                }
                let rect = CGRect(x: cx2 + x - w/2, y: cy2 - y - rh/2, width: w, height: rh)
                g.setFillColor(fillColor.cgColor)
                g.fill(rect)
                if let sc = strokeColor, strokeWidth > 0 {
                    g.setStrokeColor(sc.cgColor)
                    g.setLineWidth(strokeWidth)
                    g.stroke(rect)
                }
                g.restoreGState()
            }
            
            // Helper: draw circle
            func drawCircle(x: CGFloat, y: CGFloat, radius: CGFloat, fillColor: UIColor? = nil, strokeColor: UIColor? = nil, strokeWidth: CGFloat = 1, glow: CGFloat = 0) {
                g.saveGState()
                if glow > 0 {
                    let glowColor = (fillColor ?? strokeColor ?? .white)
                    g.setShadow(offset: .zero, blur: glow, color: glowColor.cgColor)
                }
                let rect = CGRect(x: cx2 + x - radius, y: cy2 - y - radius, width: radius * 2, height: radius * 2)
                if let fc = fillColor {
                    g.setFillColor(fc.cgColor)
                    g.fillEllipse(in: rect)
                }
                if let sc = strokeColor {
                    g.setStrokeColor(sc.cgColor)
                    g.setLineWidth(strokeWidth)
                    g.strokeEllipse(in: rect)
                }
                g.restoreGState()
            }
            
            let glowSize: CGFloat = isBoss ? 12 : 8
            
            if isBoss {
                self.renderBossVisual(g: g, drawColor: drawColor, lineW: lineW, t: t, h: h, cx: cx2, cy: cy2, glowSize: glowSize, drawLine: drawLine, drawRect: drawRect, drawCircle: drawCircle)
                return
            }
            
            if enemyType == .martial {
                self.renderMartialVisual(g: g, drawColor: drawColor, lineW: lineW, t: t, h: h, cx: cx2, cy: cy2, glowSize: glowSize, drawLine: drawLine, drawRect: drawRect, drawCircle: drawCircle)
                return
            }
            
            // Normal enemies with tier-based accessories
            // Head
            drawRect(x: 0, y: h / 2 - 10, w: 20, rh: 20, fillColor: .clear, strokeColor: drawColor, strokeWidth: lineW, glow: glowSize)
            
            // Spine
            drawLine(from: CGPoint(x: 0, y: h / 2 - 20), to: CGPoint(x: 0, y: -5), color: drawColor, width: lineW, glow: glowSize)
            
            // Arms
            let handSwing = sin(t) * 20
            drawLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 15, y: handSwing), color: drawColor, width: lineW, glow: glowSize)
            drawLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: -15, y: -handSwing), color: drawColor, width: lineW, glow: glowSize)
            
            // Legs
            let legSwing = cos(t) * 20
            drawLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: 15, y: -25 - legSwing), color: drawColor, width: lineW, glow: glowSize)
            drawLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: -15, y: -25 + legSwing), color: drawColor, width: lineW, glow: glowSize)
            
            // Type weapons
            if enemyType == .scout {
                drawRect(x: 25, y: handSwing - 5, w: 20, rh: 5, fillColor: drawColor, glow: 6)
            }
            if enemyType == .heavy {
                drawRect(x: 18, y: -5, w: 15, rh: 50, fillColor: .clear, strokeColor: drawColor, strokeWidth: lineW, glow: 6)
            }
            
            // Tier accessories
            if enemyTier == 1 {
                // Straw hat
                drawRect(x: 0, y: h / 2 + 1.5, w: 28, rh: 3, fillColor: drawColor.withAlphaComponent(0.4))
            } else if enemyTier == 2 {
                // Helmet with plume
                drawRect(x: 0, y: h / 2 + 2.5, w: 24, rh: 5, fillColor: drawColor)
                drawRect(x: 0, y: h / 2 + 9, w: 3, rh: 8, fillColor: drawColor)
                // Shoulder pads
                drawRect(x: -15, y: 10, w: 6, rh: 6, fillColor: drawColor)
                drawRect(x: 15, y: 10, w: 6, rh: 6, fillColor: drawColor)
            } else if enemyTier >= 3 {
                // Full armor + crest
                drawRect(x: 0, y: h / 2 + 3, w: 28, rh: 6, fillColor: drawColor)
                drawRect(x: 0, y: h / 2 + 11, w: 4, rh: 10, fillColor: drawColor)
                // Shoulder armor
                drawRect(x: -17, y: 12, w: 10, rh: 8, fillColor: drawColor)
                drawRect(x: 17, y: 12, w: 10, rh: 8, fillColor: drawColor)
                // Glowing eyes
                drawRect(x: -4, y: h / 2 - 5, w: 4, rh: 3, fillColor: .red, glow: 3)
                drawRect(x: 4, y: h / 2 - 5, w: 4, rh: 3, fillColor: .red, glow: 3)
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        stickSprite.texture = texture
        stickSprite.size = CGSize(width: size.width / renderScale, height: size.height / renderScale)
    }
    
    // MARK: - Martial Arts Rendering
    private func renderMartialVisual(g: CGContext, drawColor: UIColor, lineW: CGFloat, t: CGFloat, h: CGFloat, cx: CGFloat, cy: CGFloat, glowSize: CGFloat,
                                     drawLine: (CGPoint, CGPoint, UIColor, CGFloat, CGFloat) -> Void,
                                     drawRect: (CGFloat, CGFloat, CGFloat, CGFloat, UIColor, UIColor?, CGFloat, CGFloat) -> Void,
                                     drawCircle: (CGFloat, CGFloat, CGFloat, UIColor?, UIColor?, CGFloat, CGFloat) -> Void) {
        // Head
        drawRect(0, h / 2 - 10, 20, 20, .clear, drawColor, lineW, glowSize)
        
        // Headband
        let bandColor = enemyTier == 3 ? UIColor(red: 0.8, green: 0, blue: 0, alpha: 1) :
                         (enemyTier == 2 ? UIColor(red: 0.27, green: 0.53, blue: 0.8, alpha: 1) :
                          UIColor(red: 1, green: 0.27, blue: 0.27, alpha: 1))
        drawRect(0, h / 2, 28, 4, bandColor, nil, 0, 0)
        
        // Spine
        drawLine(CGPoint(x: 0, y: h / 2 - 20), CGPoint(x: 0, y: -5), drawColor, lineW, glowSize)
        
        // 4 martial arts poses
        let combo = martialCombo
        if combo == 0 {
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: 25, y: 15), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: -15, y: 0), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: 20, y: -25), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: -20, y: -25), drawColor, lineW, glowSize)
        } else if combo == 1 {
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: -10, y: 25), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: -20, y: -5), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: 35, y: -5), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: -10, y: -30), drawColor, lineW, glowSize)
        } else if combo == 2 {
            let sw = sin(t * 3) * 30
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: 10 + sw, y: 20), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: -10 - sw, y: 20), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: 25 + sw, y: -20), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: -25 - sw, y: -20), drawColor, lineW, glowSize)
        } else {
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: 5, y: 35), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 10), CGPoint(x: 20, y: 5), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: 10, y: -30), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: -5), CGPoint(x: -10, y: -30), drawColor, lineW, glowSize)
            // Flying kick energy circle
            let kickColor = enemyTier == 3 ? UIColor(red: 0.8, green: 0, blue: 0, alpha: 1) : UIColor(red: 1, green: 0.65, blue: 0, alpha: 1)
            drawCircle(5, 30, 8, nil, kickColor, 2, 0)
        }
    }
    
    // MARK: - Boss Rendering
    private func renderBossVisual(g: CGContext, drawColor: UIColor, lineW: CGFloat, t: CGFloat, h: CGFloat, cx: CGFloat, cy: CGFloat, glowSize: CGFloat,
                                  drawLine: (CGPoint, CGPoint, UIColor, CGFloat, CGFloat) -> Void,
                                  drawRect: (CGFloat, CGFloat, CGFloat, CGFloat, UIColor, UIColor?, CGFloat, CGFloat) -> Void,
                                  drawCircle: (CGFloat, CGFloat, CGFloat, UIColor?, UIColor?, CGFloat, CGFloat) -> Void) {
        // Common boss body: larger head + body + legs
        drawRect(0, h / 2 - 14, 28, 28, .clear, drawColor, lineW, 12)
        
        // Spine
        drawLine(CGPoint(x: 0, y: h / 2 - 28), CGPoint(x: 0, y: -10), drawColor, lineW, glowSize)
        
        // Legs
        let hs = sin(t) * 15
        drawLine(CGPoint(x: 0, y: -10), CGPoint(x: 18, y: -30 - cos(t) * 10), drawColor, lineW, glowSize)
        drawLine(CGPoint(x: 0, y: -10), CGPoint(x: -18, y: -30 + cos(t) * 10), drawColor, lineW, glowSize)
        
        // Boss type-specific accessories
        guard let bt = bossType else {
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 20, y: hs), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -20, y: -hs), drawColor, lineW, glowSize)
            return
        }
        
        switch bt {
        case .banditChief:
            drawRect(0, h / 2 + 3, 40, 6, drawColor, nil, 0, 0)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 30, y: hs), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 30, y: hs), CGPoint(x: 40, y: hs - 5), drawColor, 8, glowSize)
            
        case .wolfKing:
            drawLine(CGPoint(x: -10, y: h / 2), CGPoint(x: -15, y: h / 2 + 15), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: -15, y: h / 2 + 15), CGPoint(x: -5, y: h / 2), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 10, y: h / 2), CGPoint(x: 15, y: h / 2 + 15), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 15, y: h / 2 + 15), CGPoint(x: 5, y: h / 2), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 20, y: hs), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -20, y: -hs), drawColor, lineW, glowSize)
            // Claws
            for c in 0..<3 {
                drawRect(18 + CGFloat(c) * 4, hs, 2, 8, drawColor, nil, 0, 0)
            }
            
        case .ironFist:
            let headband = UIColor(red: 1, green: 0.27, blue: 0, alpha: 1)
            drawRect(0, h / 2 - 2, 36, 5, headband, nil, 0, 0)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 25, y: hs), drawColor, 10, glowSize)
            drawRect(28, hs, 16, 16, drawColor, nil, 0, 0)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -25, y: -hs), drawColor, 10, glowSize)
            drawRect(-28, -hs, 16, 16, drawColor, nil, 0, 0)
            
        case .shieldGeneral:
            drawRect(0, h / 2 + 4, 32, 8, drawColor, nil, 0, 0)
            drawRect(0, h / 2 + 12, 4, 10, drawColor, nil, 0, 0)
            // Shield
            drawRect(-21, 0, 18, 30, drawColor.withAlphaComponent(0.3), drawColor, 3, 0)
            // Spear
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 35, y: hs + 10), drawColor, lineW, glowSize)
            
        case .phantomArcher:
            drawLine(CGPoint(x: -15, y: h / 2 - 5), CGPoint(x: 0, y: h / 2 + 12), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: h / 2 + 12), CGPoint(x: 15, y: h / 2 - 5), drawColor, lineW, glowSize)
            // Bow (arc) — simplified for CoreGraphics
            g.saveGState()
            g.setShadow(offset: .zero, blur: 8, color: drawColor.cgColor)
            g.setStrokeColor(drawColor.cgColor)
            g.setLineWidth(lineW)
            g.addArc(center: CGPoint(x: cx + 20, y: cy), radius: 20, startAngle: -.pi / 3, endAngle: .pi / 3, clockwise: true)
            g.strokePath()
            g.restoreGState()
            // Bowstring
            drawLine(CGPoint(x: 20, y: 10), CGPoint(x: 20, y: -10), drawColor, lineW, glowSize)
            
        case .twinBlade:
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 25, y: hs + 15), drawColor, 3, glowSize)
            drawLine(CGPoint(x: 25, y: hs + 15), CGPoint(x: 28, y: hs + 20), drawColor, 3, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -25, y: -hs + 15), drawColor, 3, glowSize)
            drawLine(CGPoint(x: -25, y: -hs + 15), CGPoint(x: -28, y: -hs + 20), drawColor, 3, glowSize)
            // Scarf — simplified bezier
            g.saveGState()
            g.setStrokeColor(UIColor(red: 1, green: 0.4, blue: 1, alpha: 1).cgColor)
            g.setLineWidth(2)
            g.beginPath()
            g.move(to: CGPoint(x: cx - 14, y: cy - (h / 2 - 10)))
            g.addCurve(to: CGPoint(x: cx - 40 - sin(t * 3) * 8, y: cy - (h / 2 - 5)),
                       control1: CGPoint(x: cx - 25, y: cy - (h / 2 - 5)),
                       control2: CGPoint(x: cx - 35 - sin(t * 2) * 10, y: cy - (h / 2 + 5)))
            g.strokePath()
            g.restoreGState()
            
        case .thunderMonk:
            // Bald head (circle)
            drawCircle(0, h / 2 - 14, 14, drawColor, nil, 0, 0)
            // Prayer beads
            let beadColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
            for b in 0..<8 {
                let ba = CGFloat(b) * .pi / 4
                drawCircle(cos(ba) * 12, sin(ba) * 12 + h / 2 - 14, 3, beadColor, nil, 0, 0)
            }
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 15, y: hs), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -15, y: -hs), drawColor, lineW, glowSize)
            
        case .bloodDemon:
            // Horns
            drawLine(CGPoint(x: -10, y: h / 2), CGPoint(x: -18, y: h / 2 + 18), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 10, y: h / 2), CGPoint(x: 18, y: h / 2 + 18), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 20, y: hs), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -20, y: -hs), drawColor, lineW, glowSize)
            // Tail
            g.saveGState()
            g.setStrokeColor(drawColor.cgColor)
            g.setLineWidth(lineW)
            g.beginPath()
            g.move(to: CGPoint(x: cx, y: cy + 10))
            g.addCurve(to: CGPoint(x: cx - 35, y: cy),
                       control1: CGPoint(x: cx - 20, y: cy + 20),
                       control2: CGPoint(x: cx - 30, y: cy + 10 - sin(t) * 10))
            g.strokePath()
            g.restoreGState()
            // Red aura
            drawCircle(0, 0, 35 + sin(t * 2) * 5, nil, UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.3), 1, 0)
            
        case .shadowLord:
            // Hood
            g.saveGState()
            g.setFillColor(drawColor.cgColor)
            g.setStrokeColor(drawColor.cgColor)
            g.setLineWidth(lineW)
            g.beginPath()
            g.move(to: CGPoint(x: cx - 18, y: cy - (h / 2 - 10)))
            g.addLine(to: CGPoint(x: cx, y: cy - (h / 2 + 15)))
            g.addLine(to: CGPoint(x: cx + 18, y: cy - (h / 2 - 10)))
            g.closePath()
            g.drawPath(using: .fillStroke)
            g.restoreGState()
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 15, y: hs), drawColor, lineW, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -15, y: -hs), drawColor, lineW, glowSize)
            // Shadow tendrils
            let tendrilColor = UIColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1)
            for td in 0..<4 {
                let ta = CGFloat(td) * .pi / 2 + t * 0.5
                g.saveGState()
                g.setStrokeColor(tendrilColor.cgColor)
                g.setLineWidth(2)
                g.beginPath()
                g.move(to: CGPoint(x: cx, y: cy + 10))
                g.addCurve(to: CGPoint(x: cx + cos(ta) * 35, y: cy + 25 + sin(ta + 1) * 10),
                           control1: CGPoint(x: cx + cos(ta) * 20, y: cy + 20 + sin(ta) * 10),
                           control2: CGPoint(x: cx + cos(ta) * 30, y: cy + 30))
                g.strokePath()
                g.restoreGState()
            }
            
        case .swordSaint:
            // Crown
            let crownColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
            drawRect(0, h / 2 + 2, 24, 4, crownColor, nil, 0, 0)
            for p in stride(from: CGFloat(-8), through: 8, by: 8) {
                drawRect(p, h / 2 + 8, 4, 8, crownColor, nil, 0, 0)
            }
            // Glowing sword
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: 35, y: hs + 10), .white, 3, glowSize)
            drawLine(CGPoint(x: 35, y: hs + 10), CGPoint(x: 38, y: hs + 20), .white, 3, glowSize)
            drawLine(CGPoint(x: 0, y: 5), CGPoint(x: -15, y: -hs), drawColor, lineW, glowSize)
            // Cape
            g.saveGState()
            g.setFillColor(drawColor.withAlphaComponent(0.3).cgColor)
            g.beginPath()
            g.move(to: CGPoint(x: cx - 14, y: cy - (h / 2 - 28)))
            g.addLine(to: CGPoint(x: cx - 20, y: cy + 30))
            g.addLine(to: CGPoint(x: cx + 20, y: cy + 30))
            g.addLine(to: CGPoint(x: cx + 14, y: cy - (h / 2 - 28)))
            g.closePath()
            g.fillPath()
            g.restoreGState()
        }
    }
    
    // MARK: - Update (called from GameScene, AI + physics only)
    
    func update(playerPosition: CGPoint, platforms: [PlatformData]) {
        animPhase += 0.15
        if damageFlash > 0 { damageFlash -= 1 }
        
        let dist = playerPosition.x - position.x
        let dir: CGFloat = dist > 0 ? 1 : -1
        
        // AI behavior — exact match to original
        switch enemyType {
        case .chaser:
            vx += (dir * baseSpeed - vx) * 0.12
            
        case .sniper:
            if abs(dist) < 500 {
                vx += (-dir * baseSpeed - vx) * 0.1
            } else if abs(dist) > 700 {
                vx += (dir * baseSpeed - vx) * 0.1
            }
            aimTimer += 1
            
        default:
            vx += (dir * baseSpeed - vx) * 0.1
        }
        
        // Boss rage
        if isBoss && !rageMode && hp < maxHp / 2 {
            rageMode = true
            baseSpeed *= 1.5
        }
        
        // Gravity
        vy -= Physics.gravity
        
        // Movement
        position.x += vx
        position.y += vy
        
        // Platform collision
        grounded = false
        for plat in platforms {
            let platTop = plat.y + plat.height
            let enemyBottom = position.y - enemyHeight / 2
            
            if position.x + enemyWidth / 2 > plat.x &&
               position.x - enemyWidth / 2 < plat.x + plat.width &&
               enemyBottom < platTop &&
               enemyBottom > plat.y - 20 &&
               vy < 0 {
                position.y = platTop + enemyHeight / 2
                vy = 0
                grounded = true
            }
        }
        
        // Random jumping
        if grounded && CGFloat.random(in: 0...1) < 0.01 {
            vy = CGFloat.random(in: 12...18)
        }
        
        // Shoot timer
        if enemyType != .chaser && enemyType != .sniper {
            shootTimer -= 1
        }
        
        // Boss HP bar
        if isBoss, let fill = hpFill {
            let ratio = hp / maxHp
            fill.xScale = max(0, ratio)
        }
        
        // Face player
        let facingDir: CGFloat = playerPosition.x > position.x ? 1 : -1
        xScale = facingDir
        
        // v1.6: Throttled redraw — only when animation phase changes OR damage flash transitions
        let currentPhase = Int(animPhase * 3)  // Quantize to ~3 frames per redraw
        let currentFlashState = damageFlash > 0
        if currentPhase != lastDrawnPhase || currentFlashState != lastDamageFlashState {
            drawStickFigure()
            lastDrawnPhase = currentPhase
            lastDamageFlashState = currentFlashState
        }
        
        // Update sniper aim line
        updateAimLine(playerPosition: playerPosition)
    }
    
    // MARK: - Sniper Aim Line (v1.6: cached as SKSpriteNode)
    
    private func updateAimLine(playerPosition: CGPoint) {
        guard enemyType == .sniper && aimTimer > 30 else {
            aimLine?.isHidden = true
            return
        }
        
        let lineAlpha = min(1.0, CGFloat(aimTimer) / 100.0)
        let alphaLevel = Int(lineAlpha * 5)  // Quantize to 5 levels
        
        if alphaLevel != lastAimAlphaLevel {
            lastAimAlphaLevel = alphaLevel
            aimLine?.removeFromParent()
            
            // Render aim line to texture
            let lineWidth: CGFloat = 1000
            let lineHeight: CGFloat = 4
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: lineWidth, height: lineHeight))
            let image = renderer.image { ctx in
                let g = ctx.cgContext
                g.setStrokeColor(UIColor(white: 1, alpha: lineAlpha).cgColor)
                g.setLineWidth(1)
                var x: CGFloat = 0
                while x < lineWidth {
                    g.move(to: CGPoint(x: x, y: lineHeight / 2))
                    g.addLine(to: CGPoint(x: min(x + 5, lineWidth), y: lineHeight / 2))
                    x += 10
                }
                g.strokePath()
            }
            
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.anchorPoint = CGPoint(x: 0, y: 0.5)
            sprite.size = CGSize(width: lineWidth, height: lineHeight)
            sprite.zPosition = -1
            addChild(sprite)
            aimLine = sprite
        }
        
        aimLine?.isHidden = false
    }
}
