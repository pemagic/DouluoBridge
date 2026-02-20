import SpriteKit
import UIKit

// MARK: - Shared Texture Cache (v1.6.2: Pre-rendered animation frames)
// All enemies of the same visual type share pre-rendered frame textures.
// Zero per-frame rendering cost — just array index lookup.
private class EnemyFrameCache {
    static let shared = EnemyFrameCache()
    private var cache: [String: [SKTexture]] = [:]
    static let frameCount = 6
    
    func frames(forKey key: String) -> [SKTexture]? { cache[key] }
    func store(frames: [SKTexture], forKey key: String) { cache[key] = frames }
}

class EnemyNode: SKNode {
    
    // MARK: - Properties
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
    var aimTimer: Int = 0
    var damage: Int = 12
    var enemyTier: Int = 1
    var bossType: BossType?
    var martialCombo: Int = 0
    var martialTimer: Int = 0
    var rageMode: Bool = false
    
    // v1.6.2: Pre-rendered sprite
    private var stickSprite: SKSpriteNode!
    private var hpFill: SKSpriteNode?
    private var aimLine: SKShapeNode?
    private var lastFrameIndex: Int = -1
    private var lastFlashState: Bool = false
    private var normalFrames: [SKTexture] = []
    private var flashFrames: [SKTexture] = []
    private var martialNormalFrames: [[SKTexture]] = []
    private var martialFlashFrames: [[SKTexture]] = []
    private var texW: CGFloat { enemyWidth + 80 }
    private var texH: CGFloat { enemyHeight + 60 }
    
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
            let lvlBonus = CGFloat(playerWeaponLevel - 1) * 0.15
            let baseHp: CGFloat = (type == .heavy) ? 450 : 120
            self.hp = baseHp * (1 + lvlBonus) * hpMultiplier
            self.maxHp = self.hp
            let rawSpeed = 8 + CGFloat.random(in: 0...6)
            let typeMult: CGFloat
            switch type {
            case .chaser: typeMult = 1.8
            case .heavy:  typeMult = 0.4
            default:      typeMult = 0.7
            }
            self.baseSpeed = rawSpeed * typeMult
            self.enemyWidth = (type == .heavy) ? 80 : 50
            self.enemyHeight = (type == .heavy) ? 90 : 70
            self.shootTimer = 40 + CGFloat.random(in: 0...60)
            self.damage = 12
        }
        
        super.init()
        
        stickSprite = SKSpriteNode()
        addChild(stickSprite)
        
        if isBoss {
            let barW: CGFloat = enemyWidth + 20
            let bg = SKSpriteNode(color: UIColor(white: 0.15, alpha: 1), size: CGSize(width: barW, height: 6))
            bg.position = CGPoint(x: 0, y: enemyHeight / 2 + 10)
            bg.zPosition = 10
            addChild(bg)
            let fill = SKSpriteNode(color: UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1), size: CGSize(width: barW - 2, height: 4))
            fill.position = CGPoint(x: 0, y: enemyHeight / 2 + 10)
            fill.zPosition = 11
            addChild(fill)
            hpFill = fill
        }
        
        prepareFrames()
        updateTexture()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    // MARK: - Cache key
    
    private func cacheKey(flash: Bool, combo: Int = 0) -> String {
        let bt = bossType.map { "\($0)" } ?? "x"
        return "\(enemyType)_\(enemyTier)_\(isBoss)_\(bt)_\(flash)_\(combo)_\(Int(enemyWidth))"
    }
    
    // MARK: - Prepare frames (once per visual type)
    
    private func prepareFrames() {
        let fc = EnemyFrameCache.frameCount
        
        if enemyType == .martial && !isBoss {
            for combo in 0..<4 {
                let nKey = cacheKey(flash: false, combo: combo)
                let fKey = cacheKey(flash: true, combo: combo)
                if let nf = EnemyFrameCache.shared.frames(forKey: nKey),
                   let ff = EnemyFrameCache.shared.frames(forKey: fKey) {
                    martialNormalFrames.append(nf)
                    martialFlashFrames.append(ff)
                } else {
                    var nf: [SKTexture] = [], ff: [SKTexture] = []
                    for i in 0..<fc {
                        let phase = CGFloat(i) / CGFloat(fc) * .pi * 2
                        nf.append(renderFrame(phase: phase, flash: false, combo: combo))
                        ff.append(renderFrame(phase: phase, flash: true, combo: combo))
                    }
                    EnemyFrameCache.shared.store(frames: nf, forKey: nKey)
                    EnemyFrameCache.shared.store(frames: ff, forKey: fKey)
                    martialNormalFrames.append(nf)
                    martialFlashFrames.append(ff)
                }
            }
        } else {
            let nKey = cacheKey(flash: false)
            let fKey = cacheKey(flash: true)
            if let nf = EnemyFrameCache.shared.frames(forKey: nKey),
               let ff = EnemyFrameCache.shared.frames(forKey: fKey) {
                normalFrames = nf; flashFrames = ff
            } else {
                for i in 0..<fc {
                    let phase = CGFloat(i) / CGFloat(fc) * .pi * 2
                    normalFrames.append(renderFrame(phase: phase, flash: false, combo: 0))
                    flashFrames.append(renderFrame(phase: phase, flash: true, combo: 0))
                }
                EnemyFrameCache.shared.store(frames: normalFrames, forKey: nKey)
                EnemyFrameCache.shared.store(frames: flashFrames, forKey: fKey)
            }
        }
    }
    
    private func updateTexture() {
        let fc = EnemyFrameCache.frameCount
        let frameIndex = abs(Int(animPhase / (.pi * 2) * CGFloat(fc))) % fc
        let isFlash = damageFlash > 0
        if frameIndex == lastFrameIndex && isFlash == lastFlashState { return }
        lastFrameIndex = frameIndex
        lastFlashState = isFlash
        
        let frames: [SKTexture]
        if enemyType == .martial && !isBoss {
            let c = min(martialCombo, 3)
            frames = isFlash ? martialFlashFrames[c] : martialNormalFrames[c]
        } else {
            frames = isFlash ? flashFrames : normalFrames
        }
        guard frameIndex < frames.count else { return }
        stickSprite.texture = frames[frameIndex]
        stickSprite.size = CGSize(width: texW, height: texH)
    }
    
    // MARK: - Render single frame (all drawing in one function, no closures passed)
    
    private func renderFrame(phase: CGFloat, flash: Bool, combo: Int) -> SKTexture {
        let drawColor = flash ? UIColor.white : color
        let lineW: CGFloat = isBoss ? 6 : (enemyType == .heavy ? 8 : 4)
        let h = enemyHeight
        let w = texW
        let th = texH
        let glowBlur: CGFloat = isBoss ? 12 : 8
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: th))
        let image = renderer.image { ctx in
            let g = ctx.cgContext
            let cx = w / 2
            let cy = th / 2
            let t = phase
            
            // --- Helper: line ---
            func L(_ fx: CGFloat, _ fy: CGFloat, _ tx: CGFloat, _ ty: CGFloat, _ c: UIColor, _ lw: CGFloat) {
                g.saveGState()
                g.setShadow(offset: .zero, blur: glowBlur, color: c.cgColor)
                g.setStrokeColor(c.cgColor); g.setLineWidth(lw); g.setLineCap(.square)
                g.beginPath()
                g.move(to: CGPoint(x: cx + fx, y: cy - fy))
                g.addLine(to: CGPoint(x: cx + tx, y: cy - ty))
                g.strokePath(); g.restoreGState()
            }
            // --- Helper: filled rect (no stroke) ---
            func R(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ fc: UIColor) {
                let r = CGRect(x: cx + x - rw/2, y: cy - y - rh/2, width: rw, height: rh)
                g.setFillColor(fc.cgColor); g.fill(r)
            }
            // --- Helper: stroked rect ---
            func RS(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ fc: UIColor, _ sc: UIColor, _ sw: CGFloat) {
                let r = CGRect(x: cx + x - rw/2, y: cy - y - rh/2, width: rw, height: rh)
                g.setFillColor(fc.cgColor); g.fill(r)
                g.setStrokeColor(sc.cgColor); g.setLineWidth(sw); g.stroke(r)
            }
            // --- Helper: circle ---
            func C(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ fc: UIColor) {
                let rect = CGRect(x: cx + x - r, y: cy - y - r, width: r * 2, height: r * 2)
                g.setFillColor(fc.cgColor); g.fillEllipse(in: rect)
            }
            func CS(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ sc: UIColor, _ sw: CGFloat) {
                let rect = CGRect(x: cx + x - r, y: cy - y - r, width: r * 2, height: r * 2)
                g.setStrokeColor(sc.cgColor); g.setLineWidth(sw); g.strokeEllipse(in: rect)
            }
            
            // ========= BOSS =========
            if self.isBoss {
                RS(0, h/2-14, 28, 28, .clear, drawColor, lineW)
                L(0, h/2-28, 0, -10, drawColor, lineW)
                let hs = sin(t) * 15
                L(0, -10, 18, -30-cos(t)*10, drawColor, lineW)
                L(0, -10, -18, -30+cos(t)*10, drawColor, lineW)
                
                guard let bt = self.bossType else {
                    L(0, 5, 20, hs, drawColor, lineW)
                    L(0, 5, -20, -hs, drawColor, lineW)
                    return
                }
                switch bt {
                case .banditChief:
                    R(0, h/2+3, 40, 6, drawColor)
                    L(0, 5, 30, hs, drawColor, lineW)
                    L(30, hs, 40, hs-5, drawColor, 8)
                case .wolfKing:
                    L(-10, h/2, -15, h/2+15, drawColor, lineW); L(-15, h/2+15, -5, h/2, drawColor, lineW)
                    L(10, h/2, 15, h/2+15, drawColor, lineW); L(15, h/2+15, 5, h/2, drawColor, lineW)
                    L(0, 5, 20, hs, drawColor, lineW); L(0, 5, -20, -hs, drawColor, lineW)
                    for c in 0..<3 { R(18+CGFloat(c)*4, hs, 2, 8, drawColor) }
                case .ironFist:
                    R(0, h/2-2, 36, 5, UIColor(red:1,green:0.27,blue:0,alpha:1))
                    L(0, 5, 25, hs, drawColor, 10); R(28, hs, 16, 16, drawColor)
                    L(0, 5, -25, -hs, drawColor, 10); R(-28, -hs, 16, 16, drawColor)
                case .shieldGeneral:
                    R(0, h/2+4, 32, 8, drawColor); R(0, h/2+12, 4, 10, drawColor)
                    RS(-21, 0, 18, 30, drawColor.withAlphaComponent(0.3), drawColor, 3)
                    L(0, 5, 35, hs+10, drawColor, lineW)
                case .phantomArcher:
                    L(-15, h/2-5, 0, h/2+12, drawColor, lineW); L(0, h/2+12, 15, h/2-5, drawColor, lineW)
                    g.saveGState()
                    g.setShadow(offset: .zero, blur: 8, color: drawColor.cgColor)
                    g.setStrokeColor(drawColor.cgColor); g.setLineWidth(lineW)
                    g.addArc(center: CGPoint(x: cx+20, y: cy), radius: 20, startAngle: -.pi/3, endAngle: .pi/3, clockwise: true)
                    g.strokePath(); g.restoreGState()
                    L(20, 10, 20, -10, drawColor, lineW)
                case .twinBlade:
                    L(0, 5, 25, hs+15, drawColor, 3); L(25, hs+15, 28, hs+20, drawColor, 3)
                    L(0, 5, -25, -hs+15, drawColor, 3); L(-25, -hs+15, -28, -hs+20, drawColor, 3)
                    g.saveGState()
                    g.setStrokeColor(UIColor(red:1,green:0.4,blue:1,alpha:1).cgColor); g.setLineWidth(2)
                    g.beginPath(); g.move(to: CGPoint(x: cx-14, y: cy-(h/2-10)))
                    g.addCurve(to: CGPoint(x: cx-40-sin(t*3)*8, y: cy-(h/2-5)),
                               control1: CGPoint(x: cx-25, y: cy-(h/2-5)),
                               control2: CGPoint(x: cx-35-sin(t*2)*10, y: cy-(h/2+5)))
                    g.strokePath(); g.restoreGState()
                case .thunderMonk:
                    C(0, h/2-14, 14, drawColor)
                    let bc = UIColor(red:1,green:0.8,blue:0,alpha:1)
                    for b in 0..<8 { let a = CGFloat(b) * .pi / 4; C(cos(a)*12, sin(a)*12+h/2-14, 3, bc) }
                    L(0, 5, 15, hs, drawColor, lineW); L(0, 5, -15, -hs, drawColor, lineW)
                case .bloodDemon:
                    L(-10, h/2, -18, h/2+18, drawColor, lineW); L(10, h/2, 18, h/2+18, drawColor, lineW)
                    L(0, 5, 20, hs, drawColor, lineW); L(0, 5, -20, -hs, drawColor, lineW)
                    g.saveGState()
                    g.setStrokeColor(drawColor.cgColor); g.setLineWidth(lineW); g.beginPath()
                    g.move(to: CGPoint(x: cx, y: cy+10))
                    g.addCurve(to: CGPoint(x: cx-35, y: cy),
                               control1: CGPoint(x: cx-20, y: cy+20),
                               control2: CGPoint(x: cx-30, y: cy+10-sin(t)*10))
                    g.strokePath(); g.restoreGState()
                    CS(0, 0, 35+sin(t*2)*5, UIColor(red:0.8,green:0,blue:0,alpha:0.3), 1)
                case .shadowLord:
                    g.saveGState()
                    g.setFillColor(drawColor.cgColor); g.beginPath()
                    g.move(to: CGPoint(x: cx-18, y: cy-(h/2-10)))
                    g.addLine(to: CGPoint(x: cx, y: cy-(h/2+15)))
                    g.addLine(to: CGPoint(x: cx+18, y: cy-(h/2-10)))
                    g.closePath(); g.fillPath(); g.restoreGState()
                    L(0, 5, 15, hs, drawColor, lineW); L(0, 5, -15, -hs, drawColor, lineW)
                    let tc = UIColor(red:0.4,green:0.2,blue:0.8,alpha:1)
                    for td in 0..<4 {
                        let ta = CGFloat(td) * .pi / 2 + t * 0.5
                        g.saveGState(); g.setStrokeColor(tc.cgColor); g.setLineWidth(2); g.beginPath()
                        g.move(to: CGPoint(x: cx, y: cy+10))
                        g.addCurve(to: CGPoint(x: cx+cos(ta)*35, y: cy+25+sin(ta+1)*10),
                                   control1: CGPoint(x: cx+cos(ta)*20, y: cy+20+sin(ta)*10),
                                   control2: CGPoint(x: cx+cos(ta)*30, y: cy+30))
                        g.strokePath(); g.restoreGState()
                    }
                case .swordSaint:
                    let cc=UIColor(red:1,green:0.8,blue:0,alpha:1)
                    R(0, h/2+2, 24, 4, cc)
                    for p in stride(from:CGFloat(-8),through:8,by:8) { R(p, h/2+8, 4, 8, cc) }
                    L(0, 5, 35, hs+10, .white, 3); L(35, hs+10, 38, hs+20, .white, 3)
                    L(0, 5, -15, -hs, drawColor, lineW)
                    g.saveGState()
                    g.setFillColor(drawColor.withAlphaComponent(0.3).cgColor); g.beginPath()
                    g.move(to: CGPoint(x: cx-14, y: cy-(h/2-28)))
                    g.addLine(to: CGPoint(x: cx-20, y: cy+30))
                    g.addLine(to: CGPoint(x: cx+20, y: cy+30))
                    g.addLine(to: CGPoint(x: cx+14, y: cy-(h/2-28)))
                    g.closePath(); g.fillPath(); g.restoreGState()
                }
                return
            }
            
            // ========= MARTIAL =========
            if self.enemyType == .martial {
                RS(0, h/2-10, 20, 20, .clear, drawColor, lineW)
                let bandColor = self.enemyTier == 3 ? UIColor(red:0.8,green:0,blue:0,alpha:1) :
                    (self.enemyTier == 2 ? UIColor(red:0.27,green:0.53,blue:0.8,alpha:1) :
                     UIColor(red:1,green:0.27,blue:0.27,alpha:1))
                R(0, h/2, 28, 4, bandColor)
                L(0, h/2-20, 0, -5, drawColor, lineW)
                
                if combo == 0 {
                    L(0, 10, 25, 15, drawColor, lineW); L(0, 10, -15, 0, drawColor, lineW)
                    L(0, -5, 20, -25, drawColor, lineW); L(0, -5, -20, -25, drawColor, lineW)
                } else if combo == 1 {
                    L(0, 10, -10, 25, drawColor, lineW); L(0, 10, -20, -5, drawColor, lineW)
                    L(0, -5, 35, -5, drawColor, lineW); L(0, -5, -10, -30, drawColor, lineW)
                } else if combo == 2 {
                    let sw = sin(t*3)*30
                    L(0, 10, 10+sw, 20, drawColor, lineW); L(0, 10, -10-sw, 20, drawColor, lineW)
                    L(0, -5, 25+sw, -20, drawColor, lineW); L(0, -5, -25-sw, -20, drawColor, lineW)
                } else {
                    L(0, 10, 5, 35, drawColor, lineW); L(0, 10, 20, 5, drawColor, lineW)
                    L(0, -5, 10, -30, drawColor, lineW); L(0, -5, -10, -30, drawColor, lineW)
                    let kc = self.enemyTier == 3 ? UIColor(red:0.8,green:0,blue:0,alpha:1) : UIColor(red:1,green:0.65,blue:0,alpha:1)
                    CS(5, 30, 8, kc, 2)
                }
                return
            }
            
            // ========= NORMAL ENEMIES =========
            RS(0, h/2-10, 20, 20, .clear, drawColor, lineW)
            L(0, h/2-20, 0, -5, drawColor, lineW)
            let hs = sin(t) * 20
            L(0, 10, 15, hs, drawColor, lineW); L(0, 10, -15, -hs, drawColor, lineW)
            let ls = cos(t) * 20
            L(0, -5, 15, -25-ls, drawColor, lineW); L(0, -5, -15, -25+ls, drawColor, lineW)
            
            if self.enemyType == .scout { R(25, hs-5, 20, 5, drawColor) }
            if self.enemyType == .heavy { RS(18, -5, 15, 50, .clear, drawColor, lineW) }
            
            if self.enemyTier == 1 {
                R(0, h/2+1.5, 28, 3, drawColor.withAlphaComponent(0.4))
            } else if self.enemyTier == 2 {
                R(0, h/2+2.5, 24, 5, drawColor); R(0, h/2+9, 3, 8, drawColor)
                R(-15, 10, 6, 6, drawColor); R(15, 10, 6, 6, drawColor)
            } else if self.enemyTier >= 3 {
                R(0, h/2+3, 28, 6, drawColor); R(0, h/2+11, 4, 10, drawColor)
                R(-17, 12, 10, 8, drawColor); R(17, 12, 10, 8, drawColor)
                R(-4, h/2-5, 4, 3, .red); R(4, h/2-5, 4, 3, .red)
            }
        }
        
        return SKTexture(image: image)
    }
    
    // MARK: - Update
    
    func update(playerPosition: CGPoint, platforms: [PlatformData]) {
        animPhase += 0.15
        if damageFlash > 0 { damageFlash -= 1 }
        
        let dist = playerPosition.x - position.x
        let dir: CGFloat = dist > 0 ? 1 : -1
        
        switch enemyType {
        case .chaser: vx += (dir * baseSpeed - vx) * 0.12
        case .sniper:
            if abs(dist) < 500 { vx += (-dir * baseSpeed - vx) * 0.1 }
            else if abs(dist) > 700 { vx += (dir * baseSpeed - vx) * 0.1 }
            aimTimer += 1
        default: vx += (dir * baseSpeed - vx) * 0.1
        }
        
        if isBoss && !rageMode && hp < maxHp / 2 { rageMode = true; baseSpeed *= 1.5 }
        
        vy -= Physics.gravity
        position.x += vx; position.y += vy
        
        grounded = false
        for plat in platforms {
            let platTop = plat.y + plat.height
            let eb = position.y - enemyHeight / 2
            if position.x + enemyWidth/2 > plat.x && position.x - enemyWidth/2 < plat.x + plat.width &&
               eb < platTop && eb > plat.y - 20 && vy < 0 {
                position.y = platTop + enemyHeight / 2; vy = 0; grounded = true
            }
        }
        
        if grounded && CGFloat.random(in: 0...1) < 0.01 { vy = CGFloat.random(in: 12...18) }
        if enemyType != .chaser && enemyType != .sniper { shootTimer -= 1 }
        if isBoss, let fill = hpFill { fill.xScale = max(0, hp / maxHp) }
        
        xScale = playerPosition.x > position.x ? 1 : -1
        stickSprite.position.y = sin(animPhase) * 6
        
        updateTexture()
        if enemyType == .sniper { updateAimLine(playerPosition: playerPosition) }
    }
    
    private func updateAimLine(playerPosition: CGPoint) {
        guard aimTimer > 30 else { aimLine?.isHidden = true; return }
        if aimLine == nil {
            let l = SKShapeNode(); l.strokeColor = .white; l.lineWidth = 1; l.alpha = 0.3; l.zPosition = -1
            addChild(l); aimLine = l
        }
        aimLine?.alpha = min(1.0, CGFloat(aimTimer) / 100.0)
        aimLine?.isHidden = false
        let dx = (playerPosition.x - position.x) * xScale  // compensate for node's xScale flip
        let dy = playerPosition.y - position.y
        let path = CGMutablePath(); path.move(to: .zero); path.addLine(to: CGPoint(x: dx, y: dy))
        aimLine?.path = path
    }
}
