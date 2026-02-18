import SpriteKit
import UIKit

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
    
    // Boss
    var rageMode: Bool = false
    
    // Stick figure node group
    private var stickGroup: SKNode!
    private var hpBar: SKShapeNode?
    private var hpFill: SKShapeNode?
    private var aimLine: SKShapeNode?  // sniper dotted line
    
    /// Original init matching HTML's spawnEnemy()
    /// Stats: hp = (heavy?450:120) * (1 + lvlBonus), baseSpeed = (8+rand*6) * typeMult * (1+lvlBonus*0.5)
    init(type: EnemyType, playerWeaponLevel: Int, isBoss: Bool = false, bossHp: Int = 0, bossSpeed: CGFloat = 0, color: UIColor, enemyTier: Int = 1, bossType: BossType? = nil) {
        self.enemyType = type
        self.isBoss = isBoss
        self.color = color
        self.enemyTier = enemyTier
        self.bossType = bossType
        
        if isBoss {
            self.hp = CGFloat(bossHp)
            self.maxHp = CGFloat(bossHp)
            self.baseSpeed = bossSpeed * 3
            self.damage = 15
            self.enemyWidth = 80
            self.enemyHeight = 100
        } else {
            // Match original: const lvlBonus = (player.weaponLevel - 1) * 0.15;
            let lvlBonus = CGFloat(playerWeaponLevel - 1) * 0.15
            
            // hp: (type === 'heavy' ? 450 : 120) * (1 + lvlBonus)
            let baseHp: CGFloat = (type == .heavy) ? 450 : 120
            self.hp = baseHp * (1 + lvlBonus)
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
        
        stickGroup = SKNode()
        addChild(stickGroup)
        
        // Boss HP bar
        if isBoss {
            let barWidth: CGFloat = enemyWidth + 20
            let bar = SKShapeNode(rectOf: CGSize(width: barWidth, height: 6))
            bar.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
            bar.strokeColor = UIColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 1)
            bar.lineWidth = 1
            bar.position = CGPoint(x: 0, y: enemyHeight / 2 + 10)
            bar.zPosition = 10
            addChild(bar)
            hpBar = bar
            
            let fill = SKShapeNode(rectOf: CGSize(width: barWidth - 2, height: 4))
            fill.fillColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1)
            fill.strokeColor = .clear
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
    
    // MARK: - Stick Figure Drawing (exact match to drawPixelStickman)
    
    private func drawStickFigure() {
        stickGroup.removeAllChildren()
        
        let drawColor = damageFlash > 0 ? UIColor.white : color
        let lineW: CGFloat = isBoss ? 6 : (enemyType == .heavy ? 8 : 4)
        let t = animPhase
        let h = enemyHeight
        
        // Hover
        let hover = sin(animPhase) * 6
        stickGroup.position.y = hover
        
        if isBoss {
            drawBossVisual(drawColor: drawColor, lineW: lineW, t: t, h: h)
            return
        }
        
        if enemyType == .martial {
            drawMartialVisual(drawColor: drawColor, lineW: lineW, t: t, h: h)
            return
        }
        
        // Normal enemies with tier-based accessories (v1.1 lines 2237-2277)
        // Head
        let head = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
        head.fillColor = .clear
        head.strokeColor = drawColor
        head.lineWidth = lineW
        head.position = CGPoint(x: 0, y: h / 2 - 10)
        head.glowWidth = 8
        stickGroup.addChild(head)
        
        // Spine
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: h / 2 - 20), to: CGPoint(x: 0, y: -5), color: drawColor, width: lineW))
        
        // Arms
        let handSwing = sin(t) * 20
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 15, y: handSwing), color: drawColor, width: lineW))
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: -15, y: -handSwing), color: drawColor, width: lineW))
        
        // Legs
        let legSwing = cos(t) * 20
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: 15, y: -25 - legSwing), color: drawColor, width: lineW))
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: -15, y: -25 + legSwing), color: drawColor, width: lineW))
        
        // Type weapons
        if enemyType == .scout {
            let blade = SKShapeNode(rectOf: CGSize(width: 20, height: 5))
            blade.fillColor = drawColor
            blade.strokeColor = .clear
            blade.position = CGPoint(x: 25, y: handSwing - 5)
            blade.glowWidth = 6
            stickGroup.addChild(blade)
        }
        if enemyType == .heavy {
            let shield = SKShapeNode(rectOf: CGSize(width: 15, height: 50))
            shield.fillColor = .clear
            shield.strokeColor = drawColor
            shield.lineWidth = lineW
            shield.position = CGPoint(x: 18, y: -5)
            shield.glowWidth = 6
            stickGroup.addChild(shield)
        }
        
        // Tier accessories (v1.1 lines 2252-2277)
        if enemyTier == 1 {
            // Straw hat
            let hat = SKShapeNode(rectOf: CGSize(width: 28, height: 3))
            hat.fillColor = drawColor
            hat.strokeColor = .clear
            hat.alpha = 0.4
            hat.position = CGPoint(x: 0, y: h / 2 + 1.5)
            stickGroup.addChild(hat)
        } else if enemyTier == 2 {
            // Helmet with plume
            let helmet = SKShapeNode(rectOf: CGSize(width: 24, height: 5))
            helmet.fillColor = drawColor
            helmet.strokeColor = .clear
            helmet.position = CGPoint(x: 0, y: h / 2 + 2.5)
            stickGroup.addChild(helmet)
            let plume = SKShapeNode(rectOf: CGSize(width: 3, height: 8))
            plume.fillColor = drawColor
            plume.strokeColor = .clear
            plume.position = CGPoint(x: 0, y: h / 2 + 9)
            stickGroup.addChild(plume)
            // Shoulder pads
            let lShoulder = SKShapeNode(rectOf: CGSize(width: 6, height: 6))
            lShoulder.fillColor = drawColor
            lShoulder.strokeColor = .clear
            lShoulder.position = CGPoint(x: -15, y: 10)
            stickGroup.addChild(lShoulder)
            let rShoulder = SKShapeNode(rectOf: CGSize(width: 6, height: 6))
            rShoulder.fillColor = drawColor
            rShoulder.strokeColor = .clear
            rShoulder.position = CGPoint(x: 15, y: 10)
            stickGroup.addChild(rShoulder)
        } else if enemyTier >= 3 {
            // Full armor + crest
            let helmet = SKShapeNode(rectOf: CGSize(width: 28, height: 6))
            helmet.fillColor = drawColor
            helmet.strokeColor = .clear
            helmet.position = CGPoint(x: 0, y: h / 2 + 3)
            stickGroup.addChild(helmet)
            let crest = SKShapeNode(rectOf: CGSize(width: 4, height: 10))
            crest.fillColor = drawColor
            crest.strokeColor = .clear
            crest.position = CGPoint(x: 0, y: h / 2 + 11)
            stickGroup.addChild(crest)
            // Shoulder armor
            let lArmor = SKShapeNode(rectOf: CGSize(width: 10, height: 8))
            lArmor.fillColor = drawColor
            lArmor.strokeColor = .clear
            lArmor.position = CGPoint(x: -17, y: 12)
            stickGroup.addChild(lArmor)
            let rArmor = SKShapeNode(rectOf: CGSize(width: 10, height: 8))
            rArmor.fillColor = drawColor
            rArmor.strokeColor = .clear
            rArmor.position = CGPoint(x: 17, y: 12)
            stickGroup.addChild(rArmor)
            // Glowing eyes
            let lEye = SKShapeNode(rectOf: CGSize(width: 4, height: 3))
            lEye.fillColor = .red
            lEye.strokeColor = .clear
            lEye.glowWidth = 3
            lEye.position = CGPoint(x: -4, y: h / 2 - 5)
            stickGroup.addChild(lEye)
            let rEye = SKShapeNode(rectOf: CGSize(width: 4, height: 3))
            rEye.fillColor = .red
            rEye.strokeColor = .clear
            rEye.glowWidth = 3
            rEye.position = CGPoint(x: 4, y: h / 2 - 5)
            stickGroup.addChild(rEye)
        }
    }
    
    // MARK: - Martial Arts Drawing (v1.1 lines 2205-2236)
    private func drawMartialVisual(drawColor: UIColor, lineW: CGFloat, t: CGFloat, h: CGFloat) {
        // Head
        let head = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
        head.fillColor = .clear
        head.strokeColor = drawColor
        head.lineWidth = lineW
        head.position = CGPoint(x: 0, y: h / 2 - 10)
        head.glowWidth = 8
        stickGroup.addChild(head)
        
        // Headband
        let bandColor = enemyTier == 3 ? UIColor(red: 0.8, green: 0, blue: 0, alpha: 1) :
                         (enemyTier == 2 ? UIColor(red: 0.27, green: 0.53, blue: 0.8, alpha: 1) :
                          UIColor(red: 1, green: 0.27, blue: 0.27, alpha: 1))
        let band = SKShapeNode(rectOf: CGSize(width: 28, height: 4))
        band.fillColor = bandColor
        band.strokeColor = .clear
        band.position = CGPoint(x: 0, y: h / 2)
        stickGroup.addChild(band)
        
        // Spine
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: h / 2 - 20), to: CGPoint(x: 0, y: -5), color: drawColor, width: lineW))
        
        // 4 martial arts poses
        let combo = martialCombo
        if combo == 0 {
            // Horse stance
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 25, y: 15), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: -15, y: 0), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: 20, y: -25), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: -20, y: -25), color: drawColor, width: lineW))
        } else if combo == 1 {
            // Palm strike
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: -10, y: 25), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: -20, y: -5), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: 35, y: -5), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: -10, y: -30), color: drawColor, width: lineW))
        } else if combo == 2 {
            // Whirlwind kick
            let sw = sin(t * 3) * 30
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 10 + sw, y: 20), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: -10 - sw, y: 20), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: 25 + sw, y: -20), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: -25 - sw, y: -20), color: drawColor, width: lineW))
        } else {
            // Flying kick
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 5, y: 35), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 10), to: CGPoint(x: 20, y: 5), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: 10, y: -30), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -5), to: CGPoint(x: -10, y: -30), color: drawColor, width: lineW))
            // Flying kick energy circle
            let kickColor = enemyTier == 3 ? UIColor(red: 0.8, green: 0, blue: 0, alpha: 1) : UIColor(red: 1, green: 0.65, blue: 0, alpha: 1)
            let circle = SKShapeNode(circleOfRadius: 8)
            circle.fillColor = .clear
            circle.strokeColor = kickColor
            circle.lineWidth = 2
            circle.position = CGPoint(x: 5, y: 30)
            stickGroup.addChild(circle)
        }
    }
    
    // MARK: - Boss Drawing (v1.1 lines 2088-2204)
    private func drawBossVisual(drawColor: UIColor, lineW: CGFloat, t: CGFloat, h: CGFloat) {
        // Common boss body: larger head + body + legs
        let head = SKShapeNode(rectOf: CGSize(width: 28, height: 28))
        head.fillColor = .clear
        head.strokeColor = drawColor
        head.lineWidth = lineW
        head.position = CGPoint(x: 0, y: h / 2 - 14)
        head.glowWidth = 12
        stickGroup.addChild(head)
        
        // Spine
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: h / 2 - 28), to: CGPoint(x: 0, y: -10), color: drawColor, width: lineW))
        
        // Legs
        let hs = sin(t) * 15
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -10), to: CGPoint(x: 18, y: -30 - cos(t) * 10), color: drawColor, width: lineW))
        stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: -10), to: CGPoint(x: -18, y: -30 + cos(t) * 10), color: drawColor, width: lineW))
        
        // Boss type-specific accessories
        guard let bt = bossType else {
            // Default: basic arms
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 20, y: hs), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -20, y: -hs), color: drawColor, width: lineW))
            return
        }
        
        switch bt {
        case .banditChief:
            // Straw hat + club
            let hat = SKShapeNode(rectOf: CGSize(width: 40, height: 6))
            hat.fillColor = drawColor
            hat.strokeColor = .clear
            hat.position = CGPoint(x: 0, y: h / 2 + 3)
            stickGroup.addChild(hat)
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 30, y: hs), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 30, y: hs), to: CGPoint(x: 40, y: hs - 5), color: drawColor, width: 8))
            
        case .wolfKing:
            // Wolf ears + claws
            stickGroup.addChild(makeLine(from: CGPoint(x: -10, y: h / 2), to: CGPoint(x: -15, y: h / 2 + 15), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: -15, y: h / 2 + 15), to: CGPoint(x: -5, y: h / 2), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 10, y: h / 2), to: CGPoint(x: 15, y: h / 2 + 15), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 15, y: h / 2 + 15), to: CGPoint(x: 5, y: h / 2), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 20, y: hs), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -20, y: -hs), color: drawColor, width: lineW))
            // Claws
            for c in 0..<3 {
                let claw = SKShapeNode(rectOf: CGSize(width: 2, height: 8))
                claw.fillColor = drawColor
                claw.strokeColor = .clear
                claw.position = CGPoint(x: 18 + CGFloat(c) * 4, y: hs)
                stickGroup.addChild(claw)
            }
            
        case .ironFist:
            // Headband + giant fists
            let headband = SKShapeNode(rectOf: CGSize(width: 36, height: 5))
            headband.fillColor = UIColor(red: 1, green: 0.27, blue: 0, alpha: 1)
            headband.strokeColor = .clear
            headband.position = CGPoint(x: 0, y: h / 2 - 2)
            stickGroup.addChild(headband)
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 25, y: hs), color: drawColor, width: 10))
            let rFist = SKShapeNode(rectOf: CGSize(width: 16, height: 16))
            rFist.fillColor = drawColor
            rFist.strokeColor = .clear
            rFist.position = CGPoint(x: 28, y: hs)
            stickGroup.addChild(rFist)
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -25, y: -hs), color: drawColor, width: 10))
            let lFist = SKShapeNode(rectOf: CGSize(width: 16, height: 16))
            lFist.fillColor = drawColor
            lFist.strokeColor = .clear
            lFist.position = CGPoint(x: -28, y: -hs)
            stickGroup.addChild(lFist)
            
        case .shieldGeneral:
            // Helmet + shield + spear
            let helmet = SKShapeNode(rectOf: CGSize(width: 32, height: 8))
            helmet.fillColor = drawColor
            helmet.strokeColor = .clear
            helmet.position = CGPoint(x: 0, y: h / 2 + 4)
            stickGroup.addChild(helmet)
            let helmetSpike = SKShapeNode(rectOf: CGSize(width: 4, height: 10))
            helmetSpike.fillColor = drawColor
            helmetSpike.strokeColor = .clear
            helmetSpike.position = CGPoint(x: 0, y: h / 2 + 12)
            stickGroup.addChild(helmetSpike)
            // Shield
            let shield = SKShapeNode(rectOf: CGSize(width: 18, height: 30))
            shield.fillColor = drawColor.withAlphaComponent(0.3)
            shield.strokeColor = drawColor
            shield.lineWidth = 3
            shield.position = CGPoint(x: -21, y: 0)
            stickGroup.addChild(shield)
            // Spear
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 35, y: hs + 10), color: drawColor, width: lineW))
            
        case .phantomArcher:
            // Hood + bow
            stickGroup.addChild(makeLine(from: CGPoint(x: -15, y: h / 2 - 5), to: CGPoint(x: 0, y: h / 2 + 12), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: h / 2 + 12), to: CGPoint(x: 15, y: h / 2 - 5), color: drawColor, width: lineW))
            // Bow (arc)
            let bowPath = UIBezierPath(arcCenter: CGPoint(x: 20, y: 0), radius: 20, startAngle: -.pi / 3, endAngle: .pi / 3, clockwise: true)
            let bow = SKShapeNode(path: bowPath.cgPath)
            bow.strokeColor = drawColor
            bow.lineWidth = lineW
            bow.fillColor = .clear
            bow.glowWidth = 8
            stickGroup.addChild(bow)
            // Bowstring
            stickGroup.addChild(makeLine(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 20, y: -10), color: drawColor, width: lineW))
            
        case .twinBlade:
            // Two swords + flowing scarf
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 25, y: hs + 15), color: drawColor, width: 3))
            stickGroup.addChild(makeLine(from: CGPoint(x: 25, y: hs + 15), to: CGPoint(x: 28, y: hs + 20), color: drawColor, width: 3))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -25, y: -hs + 15), color: drawColor, width: 3))
            stickGroup.addChild(makeLine(from: CGPoint(x: -25, y: -hs + 15), to: CGPoint(x: -28, y: -hs + 20), color: drawColor, width: 3))
            // Scarf
            let scarfPath = UIBezierPath()
            scarfPath.move(to: CGPoint(x: -14, y: h / 2 - 10))
            scarfPath.addCurve(to: CGPoint(x: -40 - sin(t * 3) * 8, y: h / 2 - 5),
                              controlPoint1: CGPoint(x: -25, y: h / 2 - 5),
                              controlPoint2: CGPoint(x: -35 - sin(t * 2) * 10, y: h / 2 + 5))
            let scarf = SKShapeNode(path: scarfPath.cgPath)
            scarf.strokeColor = UIColor(red: 1, green: 0.4, blue: 1, alpha: 1) // #ff66ff
            scarf.lineWidth = 2
            scarf.fillColor = .clear
            stickGroup.addChild(scarf)
            
        case .thunderMonk:
            // Bald head (circle) + prayer beads
            let bald = SKShapeNode(circleOfRadius: 14)
            bald.fillColor = drawColor
            bald.strokeColor = .clear
            bald.position = CGPoint(x: 0, y: h / 2 - 14)
            stickGroup.addChild(bald)
            // Prayer beads
            let beadColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
            for b in 0..<8 {
                let ba = CGFloat(b) * .pi / 4
                let bead = SKShapeNode(circleOfRadius: 3)
                bead.fillColor = beadColor
                bead.strokeColor = .clear
                bead.position = CGPoint(x: cos(ba) * 12, y: sin(ba) * 12 + h / 2 - 14)
                stickGroup.addChild(bead)
            }
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 15, y: hs), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -15, y: -hs), color: drawColor, width: lineW))
            
        case .bloodDemon:
            // Horns + tail
            stickGroup.addChild(makeLine(from: CGPoint(x: -10, y: h / 2), to: CGPoint(x: -18, y: h / 2 + 18), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 10, y: h / 2), to: CGPoint(x: 18, y: h / 2 + 18), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 20, y: hs), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -20, y: -hs), color: drawColor, width: lineW))
            // Tail
            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: 0, y: -10))
            tailPath.addCurve(to: CGPoint(x: -35, y: 0),
                             controlPoint1: CGPoint(x: -20, y: -20),
                             controlPoint2: CGPoint(x: -30, y: -10 + sin(t) * 10))
            let tail = SKShapeNode(path: tailPath.cgPath)
            tail.strokeColor = drawColor
            tail.lineWidth = lineW
            tail.fillColor = .clear
            stickGroup.addChild(tail)
            // Red aura
            let aura = SKShapeNode(circleOfRadius: 35 + sin(t * 2) * 5)
            aura.fillColor = .clear
            aura.strokeColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.3)
            aura.lineWidth = 1
            stickGroup.addChild(aura)
            
        case .shadowLord:
            // Hood + shadow tendrils
            let hoodPath = UIBezierPath()
            hoodPath.move(to: CGPoint(x: -18, y: h / 2 - 10))
            hoodPath.addLine(to: CGPoint(x: 0, y: h / 2 + 15))
            hoodPath.addLine(to: CGPoint(x: 18, y: h / 2 - 10))
            hoodPath.close()
            let hood = SKShapeNode(path: hoodPath.cgPath)
            hood.fillColor = drawColor
            hood.strokeColor = drawColor
            hood.lineWidth = lineW
            stickGroup.addChild(hood)
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 15, y: hs), color: drawColor, width: lineW))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -15, y: -hs), color: drawColor, width: lineW))
            // Shadow tendrils
            let tendrilColor = UIColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1) // #6633cc
            for td in 0..<4 {
                let ta = CGFloat(td) * .pi / 2 + t * 0.5
                let tendrilPath = UIBezierPath()
                tendrilPath.move(to: CGPoint(x: 0, y: -10))
                tendrilPath.addCurve(to: CGPoint(x: cos(ta) * 35, y: -25 - sin(ta + 1) * 10),
                                    controlPoint1: CGPoint(x: cos(ta) * 20, y: -20 - sin(ta) * 10),
                                    controlPoint2: CGPoint(x: cos(ta) * 30, y: -30))
                let tendril = SKShapeNode(path: tendrilPath.cgPath)
                tendril.strokeColor = tendrilColor
                tendril.lineWidth = 2
                tendril.fillColor = .clear
                stickGroup.addChild(tendril)
            }
            
        case .swordSaint:
            // Crown + glowing sword + cape
            let crown = SKShapeNode(rectOf: CGSize(width: 24, height: 4))
            crown.fillColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
            crown.strokeColor = .clear
            crown.position = CGPoint(x: 0, y: h / 2 + 2)
            stickGroup.addChild(crown)
            for p in stride(from: CGFloat(-8), through: 8, by: 8) {
                let spike = SKShapeNode(rectOf: CGSize(width: 4, height: 8))
                spike.fillColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
                spike.strokeColor = .clear
                spike.position = CGPoint(x: p, y: h / 2 + 8)
                stickGroup.addChild(spike)
            }
            // Glowing sword
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 35, y: hs + 10), color: .white, width: 3))
            stickGroup.addChild(makeLine(from: CGPoint(x: 35, y: hs + 10), to: CGPoint(x: 38, y: hs + 20), color: .white, width: 3))
            stickGroup.addChild(makeLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: -15, y: -hs), color: drawColor, width: lineW))
            // Cape
            let capePath = UIBezierPath()
            capePath.move(to: CGPoint(x: -14, y: h / 2 - 28))
            capePath.addLine(to: CGPoint(x: -20, y: -30))
            capePath.addLine(to: CGPoint(x: 20, y: -30))
            capePath.addLine(to: CGPoint(x: 14, y: h / 2 - 28))
            capePath.close()
            let cape = SKShapeNode(path: capePath.cgPath)
            cape.fillColor = drawColor.withAlphaComponent(0.3)
            cape.strokeColor = .clear
            stickGroup.addChild(cape)
        }
    }
    
    private func makeLine(from: CGPoint, to: CGPoint, color: UIColor, width: CGFloat) -> SKShapeNode {
        let path = UIBezierPath()
        path.move(to: from)
        path.addLine(to: to)
        let line = SKShapeNode(path: path.cgPath)
        line.strokeColor = color
        line.lineWidth = width
        line.lineCap = .square
        // Original: ctx.shadowBlur = 15; ctx.shadowColor = color;
        line.glowWidth = isBoss ? 12 : 8
        return line
    }
    
    // MARK: - Update (called from GameScene, AI + physics only — shooting handled by GameScene)
    
    func update(playerPosition: CGPoint, platforms: [PlatformData]) {
        animPhase += 0.15
        if damageFlash > 0 { damageFlash -= 1 }
        
        let dist = playerPosition.x - position.x
        let dir: CGFloat = dist > 0 ? 1 : -1
        
        // AI behavior — exact match to original
        switch enemyType {
        case .chaser:
            // e.vx += (dir * e.baseSpeed - e.vx) * 0.12;
            vx += (dir * baseSpeed - vx) * 0.12
            // Kamikaze: if close, deal damage and self-destruct
            // (Contact damage handled by GameScene; here we just track for hp=0)
            
        case .sniper:
            // if(Math.abs(dist) < 500) e.vx += (-dir * e.baseSpeed - e.vx) * 0.1;  // retreat
            // else if(Math.abs(dist) > 700) e.vx += (dir * e.baseSpeed - e.vx) * 0.1;  // approach
            if abs(dist) < 500 {
                vx += (-dir * baseSpeed - vx) * 0.1
            } else if abs(dist) > 700 {
                vx += (dir * baseSpeed - vx) * 0.1
            }
            aimTimer += 1
            // Shooting handled by GameScene (checks aimTimer > 80)
            
        default:
            // scout, heavy: e.vx += (dir * e.baseSpeed - e.vx) * 0.1;
            vx += (dir * baseSpeed - vx) * 0.1
        }
        
        // Boss rage
        if isBoss && !rageMode && hp < maxHp / 2 {
            rageMode = true
            baseSpeed *= 1.5
        }
        if rageMode { vx *= 1.3 }
        
        // Gravity: e.vy += GRAVITY; (canvas down = positive)
        // SpriteKit: down = negative
        vy -= Physics.gravity
        
        // Movement: e.x += e.vx; e.y += e.vy;
        position.x += vx
        position.y += vy
        
        // Platform collision (same AABB as original, adapted for SpriteKit coords)
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
        
        // Random jumping — enemies jump occasionally when grounded
        if grounded && CGFloat.random(in: 0...1) < 0.01 {
            vy = CGFloat.random(in: 12...18)  // Random jump force
        }
        
        // Shoot timer (for scout/heavy — decrements here, checked by GameScene)
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
        
        // Redraw stick figure for animation
        drawStickFigure()
        
        // Update sniper aim line
        updateAimLine(playerPosition: playerPosition)
    }
    
    // MARK: - Sniper Aim Line
    
    private func updateAimLine(playerPosition: CGPoint) {
        aimLine?.removeFromParent()
        aimLine = nil
        
        guard enemyType == .sniper && aimTimer > 30 else { return }
        
        // Original: ctx.moveTo(e.x+e.w/2, e.y+e.h/2); ctx.lineTo(e.x+e.w/2 + Math.sign(player.x-e.x)*1000, ...)
        // Since the node's xScale already handles facing direction,
        // we always draw the line in the POSITIVE X direction — xScale will flip it.
        let lineAlpha = min(1.0, CGFloat(aimTimer) / 100.0)
        
        let path = UIBezierPath()
        let dashLen: CGFloat = 5
        let gapLen: CGFloat = 5
        var x: CGFloat = 0
        let endX: CGFloat = 1000  // Always rightward; xScale flips to face player
        while x < endX {
            path.move(to: CGPoint(x: x, y: 0))
            let dashEnd = min(x + dashLen, endX)
            path.addLine(to: CGPoint(x: dashEnd, y: 0))
            x += dashLen + gapLen
        }
        
        let line = SKShapeNode(path: path.cgPath)
        line.strokeColor = UIColor(white: 1, alpha: lineAlpha)
        line.lineWidth = 1
        line.zPosition = -1
        addChild(line)
        aimLine = line
    }
}
