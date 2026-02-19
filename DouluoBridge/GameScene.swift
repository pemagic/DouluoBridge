import SpriteKit
import UIKit

// MARK: - Game Scene
class GameScene: SKScene {
    
    // MARK: - Game State
    enum GameState {
        case menu, playing, paused, gameOver, levelTransition
    }
    
    var gameState: GameState = .menu
    var currentLevel: Int = 1
    var levelKills: Int = 0
    var totalKills: Int = 0
    var combo: Int = 0
    var comboTimer: Int = 0
    var gameTime: Int = 0
    var hitstop: Int = 0
    var spawnCooldown: Int = 0
    var spawnGrace: Int = 0
    var bossActive: Bool = false
    var bossSpawned: Bool = false
    var screenFlash: Int = 0
    var bossStallTimer: Int = 0  // Safety timer to detect boss stuck/lost

    
    // MARK: - Camera
    var cameraNode: SKCameraNode!
    var camX: CGFloat = 0
    var camY: CGFloat = 0
    
    // MARK: - Nodes
    var backgroundNode: SKNode!
    var platformLayer: SKNode!
    var entityLayer: SKNode!
    var effectLayer: SKNode!
    
    // MARK: - Player
    var playerNode: PlayerNode!
    
    // MARK: - Collections
    var enemies: [EnemyNode] = []
    var projectiles: [ProjectileNode] = []
    var particles: [ParticleEffect] = []
    var platforms: [PlatformData] = []
    var drops: [DropData] = []

    var lightningBolts: [LightningBolt] = []
    
    // MARK: - Input State
    var inputLeft: Bool = false
    var inputRight: Bool = false
    var inputJump: Bool = false
    var inputDash: Bool = false
    var inputAttack: Bool = false
    
    // MARK: - Delegates
    weak var gameDelegate: GameSceneDelegate?
    
    // MARK: - Computed
    var currentLevelDef: LevelDef {
        let idx = max(0, min(currentLevel - 1, GameConfig.levels.count - 1))
        return GameConfig.levels[idx]
    }
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)  // #050505
        anchorPoint = CGPoint(x: 0, y: 0)  // Bottom-left origin
        
        // Setup camera
        cameraNode = SKCameraNode()
        cameraNode.setScale(1.8)  // Zoom out to show more game world (like browser viewport)
        camera = cameraNode
        addChild(cameraNode)
        
        // Setup layers
        backgroundNode = SKNode()
        backgroundNode.zPosition = -100
        addChild(backgroundNode)
        
        platformLayer = SKNode()
        platformLayer.zPosition = 0
        addChild(platformLayer)
        
        entityLayer = SKNode()
        entityLayer.zPosition = 10
        addChild(entityLayer)
        
        effectLayer = SKNode()
        effectLayer.zPosition = 50
        addChild(effectLayer)
        
        // Create player
        playerNode = PlayerNode()
        playerNode.position = CGPoint(x: 400, y: 150)  // Above ground level
        entityLayer.addChild(playerNode)
        
        // Initial state
        gameState = .menu
        gameDelegate?.gameStateChanged(.menu)
        
        // Add CRT Scanline Overlay (Visual Fidelity)
        createCRTOverlay()
    }
    
    func createCRTOverlay() {
        // Create a pattern texture for scanlines (1px clear, 1px dark)
        let size = CGSize(width: 4, height: 4)
        // IMPORTANT: opaque must be false so UIColor.clear actually produces transparent pixels
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.clear(CGRect(x: 0, y: 0, width: 4, height: 4))  // Fully transparent
        // Reduced from 0.15 to 0.06 — v1.1 scanlines were very subtle
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.06).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 2)) // Dark lines
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest  // Keep crisp scanline pixels
        let overlay = SKSpriteNode(texture: texture)
        overlay.size = CGSize(width: Physics.gameWidth * 4, height: Physics.gameHeight * 4)
        overlay.alpha = 1.0
        overlay.zPosition = 1000 // Topmost
        overlay.blendMode = .alpha
        cameraNode.addChild(overlay)
    }
    
    // MARK: - Game Flow
    
    func startGame() {
        // Reset all state
        currentLevel = 1
        levelKills = 0
        totalKills = 0
        combo = 0
        comboTimer = 0
        gameTime = 0
        bossActive = false
        bossSpawned = false
        spawnGrace = 120
        
        // Reset player
        playerNode.reset()
        playerNode.position = CGPoint(x: 400, y: 300)  // Above ground, will fall
        
        // Clear entities
        enemies.forEach { $0.removeFromParent() }
        enemies.removeAll()
        projectiles.forEach { $0.removeFromParent() }
        projectiles.removeAll()
        drops.forEach { $0.node?.removeFromParent() }
        drops.removeAll()
        particles.removeAll()

        lightningBolts.removeAll()
        
        // Generate platforms
        generatePlatforms()
        
        // Draw background
        drawBackground()
        
        gameState = .playing
        gameDelegate?.gameStateChanged(.playing)
    }
    
    func pauseGame() {
        if gameState == .playing {
            gameState = .paused
            gameDelegate?.gameStateChanged(.paused)
        }
    }
    
    func resumeGame() {
        if gameState == .paused {
            gameState = .playing
            gameDelegate?.gameStateChanged(.playing)
        }
    }
    
    func endGame(victory: Bool) {
        gameState = .gameOver
        gameDelegate?.gameStateChanged(.gameOver)
        gameDelegate?.gameEnded(kills: totalKills, time: gameTime, level: currentLevel, victory: victory)
    }
    
    func completeLevel() {
        if currentLevel < 10 {
            gameState = .levelTransition
            currentLevel += 1
            levelKills = 0
            bossActive = false
            bossSpawned = false
            spawnGrace = 120
            
            // Regenerate world
            generatePlatforms()
            drawBackground()
            
            // Level up a random skill
            levelUpRandomSkill()
            
            // Level banner
            gameDelegate?.showLevelBanner(currentLevelDef.name)
            
            // Resume after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.gameState = .playing
                self?.gameDelegate?.gameStateChanged(.playing)
            }
        } else {
            endGame(victory: true)
        }
    }
    
    // MARK: - Platform Generation (match v1.1 original)
    
    func generatePlatforms() {
        platformLayer.removeAllChildren()
        platforms.removeAll()
        
        let colors = currentLevelDef.colors
        
        // V1.1 (douluo_ios.html lines 1206-1220):
        // Ground: {x: i*600, y: 700+random*100, w: 650, h: 600} → In SpriteKit Y-up, surface ≈ 100-200
        // Mid-float: {x: i*600+150, y: 450-random*250, w: 280, h: 22} (65% chance)
        // Sky: {x: i*600+random*400, y: 200-random*180, w: 180+random*120, h: 18} (50% chance)
        // High: {x: i*600+random*300, y: 50-random*100, w: 140+random*80, h: 15} (30% chance)
        for i in 0..<500 {
            // Ground blocks: surface at ~50-100, block extends 600px below
            let surfaceY: CGFloat = 50 + CGFloat.random(in: 0...50)
            let groundHeight: CGFloat = 600
            let groundBottom: CGFloat = surfaceY - groundHeight
            let groundColor = colors.platformGround.randomElement() ?? UIColor(white: 0.1, alpha: 1)
            let groundPlat = PlatformData(
                x: CGFloat(i) * 600, y: groundBottom, width: 650, height: groundHeight,
                color: groundColor, isGround: true
            )
            platforms.append(groundPlat)
            drawPlatform(groundPlat)
            
            // Mid-level floating platforms (65% chance)
            if CGFloat.random(in: 0...1) > 0.35 {
                let floatColor = colors.platformFloat.randomElement() ?? UIColor(white: 0.2, alpha: 1)
                let midPlat = PlatformData(
                    x: CGFloat(i) * 600 + 150, y: 175 + CGFloat.random(in: 0...125),
                    width: 280, height: 22, color: floatColor, isGround: false
                )
                platforms.append(midPlat)
                drawPlatform(midPlat)
            }
            
            // Sky platforms (50% chance) — Rainbow colors!
            if CGFloat.random(in: 0...1) > 0.5 {
                let rainbowColors: [UIColor] = [
                    UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),   // Red
                    UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),   // Orange
                    UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1),   // Yellow
                    UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1),   // Green
                    UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1),   // Cyan
                    UIColor(red: 0.3, green: 0.4, blue: 1.0, alpha: 1),   // Blue
                    UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1),   // Purple
                    UIColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1),   // Magenta
                ]
                let skyColor = rainbowColors[i % rainbowColors.count]
                let skyPlat = PlatformData(
                    x: CGFloat(i) * 600 + CGFloat.random(in: 0...400),
                    y: 260 + CGFloat.random(in: 0...90),
                    width: 180 + CGFloat.random(in: 0...120), height: 18,
                    color: skyColor, isGround: false
                )
                platforms.append(skyPlat)
                drawPlatform(skyPlat)
            }
            
            // High platforms (30% chance) — Rainbow colors!
            if CGFloat.random(in: 0...1) > 0.7 {
                let rainbowColors: [UIColor] = [
                    UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),
                    UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),
                    UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1),
                    UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1),
                    UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1),
                    UIColor(red: 0.3, green: 0.4, blue: 1.0, alpha: 1),
                    UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1),
                    UIColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1),
                ]
                let highColor = rainbowColors[(i + 3) % rainbowColors.count]
                let highPlat = PlatformData(
                    x: CGFloat(i) * 600 + CGFloat.random(in: 0...300),
                    y: 350 + CGFloat.random(in: 0...50),
                    width: 140 + CGFloat.random(in: 0...80), height: 15,
                    color: highColor, isGround: false
                )
                platforms.append(highPlat)
                drawPlatform(highPlat)
            }
        }
    }
    
    private func drawPlatform(_ plat: PlatformData) {
        // V1.1 (lines 1794-1813): solid fill + brush stroke top edge + floating shadow
        let node = SKShapeNode(rectOf: CGSize(width: plat.width, height: plat.height))
        node.fillColor = plat.color
        node.strokeColor = .clear
        node.lineWidth = 0
        node.alpha = plat.isGround ? 0.5 : 0.35  // Semi-transparent so background shows through
        node.position = CGPoint(
            x: plat.x + plat.width / 2,
            y: plat.y + plat.height / 2
        )
        node.zPosition = 0
        platformLayer.addChild(node)
        
        // Brush stroke wavy top edge (v1.1 lines 1800-1807)
        let edgePath = CGMutablePath()
        let topY = plat.y + plat.height
        edgePath.move(to: CGPoint(x: plat.x, y: topY))
        var bx = plat.x
        while bx <= plat.x + plat.width {
            edgePath.addLine(to: CGPoint(x: bx, y: topY + sin(bx * 0.1) * 1.5))
            bx += 8
        }
        let edge = SKShapeNode(path: edgePath)
        edge.strokeColor = plat.isGround
            ? UIColor(red: 0.54, green: 0.48, blue: 0.38, alpha: 1)  // #8a7a60
            : UIColor(red: 0.44, green: 0.38, blue: 0.31, alpha: 1)  // #706050
        edge.lineWidth = plat.isGround ? 3 : 2
        edge.fillColor = .clear
        edge.zPosition = 1
        platformLayer.addChild(edge)
        
        // Floating platform drop shadow (v1.1 lines 1809-1812)
        if !plat.isGround {
            let shadow = SKShapeNode(rectOf: CGSize(width: plat.width - 10, height: 4))
            shadow.fillColor = UIColor(white: 0, alpha: 0.08)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(
                x: plat.x + plat.width / 2 + 5,
                y: plat.y - 2  // just below platform bottom
            )
            shadow.zPosition = 0
            platformLayer.addChild(shadow)
        }
    }
    
    // MARK: - Background (Level-Specific Ink-Wash Painting)
    
    func drawBackground() {
        backgroundNode.removeAllChildren()
        
        // Clear all camera background elements
        cameraNode.children.filter { $0.name == "bgSky" || $0.name == "bgMist" || $0.name == "bgCloud" || $0.name == "bgMtn" }.forEach { $0.removeFromParent() }
        
        // For camera children, visible area = scene size (camera scale affects both equally)
        let visW = self.size.width
        let visH = self.size.height
        
        // Level-specific ink-wash painting background (bg_level_1 through bg_level_10)
        let bgName = "bg_level_\(currentLevel)"
        if let bgImage = UIImage(named: bgName) {
            let texture = SKTexture(image: bgImage)
            let bgNode = SKSpriteNode(texture: texture)
            
            // Fit mode: show the FULL image without cropping
            let imgAspect = bgImage.size.width / bgImage.size.height  // 3040/1408 ≈ 2.16
            let viewAspect = visW / visH
            
            if imgAspect > viewAspect {
                // Image is wider than viewport — fit width, image will be shorter
                bgNode.size = CGSize(width: visW, height: visW / imgAspect)
            } else {
                // Image is taller — fit height, image will be narrower
                bgNode.size = CGSize(width: visH * imgAspect, height: visH)
            }
            
            bgNode.position = CGPoint(x: 0, y: 0)  // Center of camera
            bgNode.zPosition = -200
            bgNode.name = "bgSky"
            cameraNode.addChild(bgNode)
        }
        
        // Set scene bg color as fallback
        if let lastColor = currentLevelDef.colors.bgColors.last {
            backgroundColor = lastColor
        }
    }
    
    // Helper for gradient interpolation
    func interpolationColor(from: UIColor, to: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat=0, g1: CGFloat=0, b1: CGFloat=0, a1: CGFloat=0
        var r2: CGFloat=0, g2: CGFloat=0, b2: CGFloat=0, a2: CGFloat=0
        
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(
            red: r1 + (r2 - r1) * ratio,
            green: g1 + (g2 - g1) * ratio,
            blue: b1 + (b2 - b1) * ratio,
            alpha: a1 + (a2 - a1) * ratio
        )
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        // 1. Hitstop (HTML L237)
        if hitstop > 0 {
            hitstop -= 1
            return
        }
        
        // 2. Game Time (HTML L239)
        gameTime += 1
        
        // 3. Combo Timer (HTML L240)
        if comboTimer > 0 {
            comboTimer -= 1
            if comboTimer <= 0 { combo = 0 }
        }
        
        // 4. Spawn Logic (HTML L243-249: spawnCooldown is checked/decremented BEFORE entities)
        updateSpawning()
        
        // 5. Player Update (HTML L251-263: anim, dash, movement, cooldowns)
        updatePlayer()
        
        // 6. Enemy Update (HTML L272-319)
        updateEnemies()
        
        // 7. Drop Update (HTML L321-347)
        updateDrops()
        
        // 8. Projectile Update (HTML L352-366)
        updateProjectiles()
        
        // 9. Effects Update (HTML L368-374: particles, trails)
        updateEffects()
        
        // 10. Camera Follow (HTML L376)
        updateCamera()
        
        // 11. UI/HUD (HTML L379)
        updateHUD()
        
        // 12. Death Check (HTML L388: if(player.hp <= 0 || player.y > 2500) endGame)
        if playerNode.hp <= 0 || playerNode.position.y < -1600 {
            endGame(victory: false)
        }
    }
    
    // MARK: - Player Update
    
    func updatePlayer() {
        let p = playerNode!
        
        // Original: dash overrides ALL movement
        if p.dashActive > 0 {
            p.vx = CGFloat(p.facing) * Physics.dashForce
            p.vy = 0  // No gravity during dash
            p.dashActive -= 1
            // Trail/afterimage (add particle trail)
            createParticles(x: p.position.x, y: p.position.y,
                           color: p.weaponLevel >= 10 ? PlayerNode.neonColors[gameTime % PlayerNode.neonColors.count] : .white,
                           count: 3, speedScale: 0.3, sizeScale: 2)
        } else {
            // Normal input
            if inputLeft {
                p.vx = -Physics.playerSpeed
                p.facing = -1
            } else if inputRight {
                p.vx = Physics.playerSpeed
                p.facing = 1
            } else {
                p.vx *= 0.82
            }
            // Gravity only when NOT dashing
            p.vy -= Physics.gravity
        }
        
        // Apply velocity
        p.position.x += p.vx
        p.position.y += p.vy
        
        // Cooldowns
        if p.dashCooldown > 0 { p.dashCooldown -= 1 }
        if p.iframe > 0 { p.iframe -= 1 }
        if p.shootTimer > 0 { p.shootTimer -= 1 }
        if p.ultActive > 0 { p.ultActive -= 1 }
        
        // Skill cooldowns
        for def in GameConfig.skillDefs {
            let sk = p.skills[def.id]!
            if sk.cooldown > 0 { sk.cooldown -= 1 }
            if sk.active > 0 { sk.active -= 1 }
        }
        
        // Platform collision
        p.grounded = false
        for plat in platforms {
            let platTop = plat.y + plat.height
            let playerBottom = p.position.y - p.height / 2
            
            if p.position.x + p.width / 2 > plat.x &&
               p.position.x - p.width / 2 < plat.x + plat.width &&
               playerBottom < platTop &&
               playerBottom > plat.y - 20 &&
               p.vy < 0 {
                p.position.y = platTop + p.height / 2
                p.vy = 0
                p.grounded = true
                p.jumpCount = 0
            }
        }
        
        // Fall off screen death: original y > 2500 → SpriteKit y < -1600
        if p.position.y < -1600 {
            p.hp = 0
        }
        
        // Death check removed from here, moved to end of update() to match HTML L388
        
        // Update visual
        p.updateVisual()
    }
    
    // MARK: - Enemy Update (match original exactly)
    func updateEnemies() {
        for (i, enemy) in enemies.enumerated().reversed() {
            enemy.update(playerPosition: playerNode.position, platforms: platforms)
            
            // Off-screen cleanup — tighter threshold so distant enemies don't clog maxEnemies
            let enemyRelX = abs(enemy.position.x - cameraNode.position.x)
            let enemyRelY = enemy.position.y
            if enemyRelY < -200 || enemyRelX > Physics.gameWidth {
                // BOSS: never remove — teleport back near the player instead
                if enemy.isBoss {
                    // Teleport boss to a position near the player
                    let side: CGFloat = playerNode.facing > 0 ? 1 : -1
                    enemy.position = CGPoint(
                        x: playerNode.position.x + side * 400,
                        y: playerNode.position.y + 200
                    )
                    enemy.vx = 0
                    enemy.vy = 0
                    continue
                }
                // Regular enemies: count toward levelKills so the kill target
                // isn't "leaked" by enemies wandering off
                levelKills += 1
                totalKills += 1
                enemy.removeFromParent()
                enemies.remove(at: i)
                continue
            }
            
            let dx = abs(enemy.position.x - playerNode.position.x)
            let dy = abs(enemy.position.y - playerNode.position.y)
            
            // Chaser kamikaze: if close, deal 15 damage, self-destruct
            if enemy.enemyType == .chaser {
                if dx < 60 && dy < 70 {
                    if playerNode.iframe <= 0 {
                        playerNode.hp -= 15
                        playerNode.iframe = 30  // original: iframe = 30
                    }
                    enemy.hp = 0  // self-destruct
                }
            }
            
            // Enemy death check (before other interactions)
            if enemy.hp <= 0 {
                handleEnemyDeath(at: i)
                continue
            }
            
            // NO Dash damage or Ultimate AOE in original HTML
            // Only direct checks (chaser contact, bullet hits)
            
            // Enemy shooting — only scout & heavy (NOT chaser/sniper)
            // 360° aimed at player position
            if enemy.enemyType != .chaser && enemy.enemyType != .sniper {
                if enemy.shootTimer <= 0 && dx < 1000 {
                    let angle = atan2(playerNode.position.y - enemy.position.y,
                                     playerNode.position.x - enemy.position.x)
                    let speed: CGFloat = 14
                    let neonColor = PlayerNode.neonColors[Int.random(in: 0..<PlayerNode.neonColors.count)]
                    let proj = ProjectileNode(
                        vx: cos(angle) * speed,
                        vy: sin(angle) * speed,
                        damage: 12,
                        owner: .enemy,
                        color: neonColor,
                        life: 120,
                        size: 10
                    )
                    proj.position = CGPoint(x: enemy.position.x,
                                           y: enemy.position.y)
                    entityLayer.addChild(proj)
                    projectiles.append(proj)
                    enemy.shootTimer = 70 + CGFloat.random(in: 0...50)
                }
            }
            
            // Sniper: fires when aimTimer > 80, 360° aimed
            if enemy.enemyType == .sniper && enemy.aimTimer > 80 {
                let angle = atan2(playerNode.position.y - enemy.position.y,
                                 playerNode.position.x - enemy.position.x)
                let speed: CGFloat = 42
                let neonColor = PlayerNode.neonColors[Int.random(in: 0..<PlayerNode.neonColors.count)]
                let proj = ProjectileNode(
                    vx: cos(angle) * speed,
                    vy: sin(angle) * speed,
                    damage: 30,
                    owner: .enemy,
                    color: neonColor,
                    life: 100,
                    size: 10
                )
                proj.position = CGPoint(x: enemy.position.x,
                                       y: enemy.position.y)
                entityLayer.addChild(proj)
                projectiles.append(proj)
                enemy.aimTimer = 0
            }
        }
    }
    
    // MARK: - Projectile Update
    func updateProjectiles() {
        for (i, proj) in projectiles.enumerated().reversed() {
            proj.update(enemies: enemies)
            
            // Remove dead projectiles
            if proj.life <= 0 {
                proj.removeFromParent()
                projectiles.remove(at: i)
                continue
            }
            
            // Off-screen
            if !isOnScreen(proj) {
                proj.removeFromParent()
                projectiles.remove(at: i)
                continue
            }
            
            if proj.owner == .player {
                // Check hit enemies
                // Original AABB: pj.x < e.x+e.w && pj.x+70 > e.x && pj.y < e.y+e.h && pj.y+pj.size > e.y
                // In center-distance: dx < (e.w + 70) / 2, dy < (e.h + pj.size) / 2
                for (ei, enemy) in enemies.enumerated().reversed() {
                    let dx = abs(proj.position.x - enemy.position.x)
                    let dy = abs(proj.position.y - enemy.position.y)
                    if dx < (enemy.enemyWidth + 70) / 2 &&
                       dy < (enemy.enemyHeight + CGFloat(proj.size)) / 2 {
                        enemy.hp -= CGFloat(proj.damage)
                        enemy.damageFlash = 6
                        proj.removeFromParent()
                        projectiles.remove(at: i)
                        if enemy.hp <= 0 {
                            handleEnemyDeath(at: ei)
                        }
                        break
                    }
                }
            } else {
                // Enemy projectile → player
                // Original AABB: pj.x < player.x+player.w && pj.x+20 > player.x && pj.y < player.y+player.h && pj.y+15 > player.y
                let dx = abs(proj.position.x - playerNode.position.x)
                let dy = abs(proj.position.y - playerNode.position.y)
                if dx < (playerNode.width / 2 + CGFloat(proj.size)) &&
                   dy < (playerNode.height / 2 + CGFloat(proj.size)) &&
                   playerNode.iframe <= 0 {
                    if let shieldState = playerNode.skills["shield"], shieldState.active > 0 {
                        shieldState.active = max(0, shieldState.active - 10)
                    } else {
                        playerNode.hp -= proj.damage
                        playerNode.iframe = 35  // Original: player.iframe = 35
                        createParticles(x: playerNode.position.x, y: playerNode.position.y,
                                       color: .red, count: 15)
                        gameDelegate?.triggerHaptic(.medium)
                    }
                    proj.removeFromParent()
                    projectiles.remove(at: i)
                }
            }
        }
    }
    
    // MARK: - Drop Update (extracted to match HTML order)
    func updateDrops() {
        for (i, _) in drops.enumerated().reversed() {
            // Physics: d.vy += GRAVITY*0.6; d.x += d.vx; d.y += d.vy;
            drops[i].vy -= Physics.gravity * 0.6  // SpriteKit: subtract for down
            drops[i].x += drops[i].vx
            drops[i].y += drops[i].vy
            drops[i].life -= 1
            
            // Platform collision for drops
            for plat in platforms {
                let dBottom = drops[i].y - 14  // half of 28px drop height
                let platTop = plat.y + plat.height
                if drops[i].x < plat.x + plat.width &&
                   drops[i].x + 32 > plat.x &&
                   dBottom < platTop &&
                   dBottom > plat.y - 20 &&
                   drops[i].vy < 0 {
                    drops[i].y = platTop + 14
                    drops[i].vy = 0
                    drops[i].vx *= 0.7  // Ground friction
                }
            }
            
            if drops[i].life <= 0 {
                // Remove drop node if exists
                drops[i].node?.removeFromParent()
                drops.remove(at: i)
                continue
            }
            
            // Update drop visual position
            if let node = drops[i].node {
                let bob = sin(CGFloat(gameTime) * 0.1) * 10
                node.position = CGPoint(x: drops[i].x, y: drops[i].y + bob)
            }
            
            // Pickup: original Math.abs(d.x - player.x) < 50 && Math.abs(d.y - player.y) < 70
            let dx = abs(drops[i].x - playerNode.position.x)
            let dy = abs(drops[i].y - playerNode.position.y)
            if dx < 50 && dy < 70 {
                switch drops[i].type {
                case .health:
                    playerNode.hp = min(100, playerNode.hp + 30)  // Original: +30
                    gameDelegate?.triggerHaptic(.medium) // Tone 800 (health)
                case .weapon:
                    if playerNode.weaponLevel < currentLevelDef.weaponCap {
                        playerNode.weaponLevel += 1
                        playerNode.rebuildVisual()
                        createParticles(x: playerNode.position.x, y: playerNode.position.y,
                                       color: UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1), count: 30, speedScale: 2)
                        gameDelegate?.triggerHaptic(.heavy) // Tone 1200 (weapon)
                    }
                }
                drops[i].node?.removeFromParent()
                drops.remove(at: i)
            }
        }
    }
    
    // MARK: - Effects Update
    func updateEffects() {
        if screenFlash > 0 { screenFlash -= 1 }
        
        // Clean up lightning bolts
        lightningBolts = lightningBolts.filter { $0.life > 0 }
        for i in 0..<lightningBolts.count {
            lightningBolts[i].life -= 1
        }
    }
    
    // MARK: - Spawning
    func updateSpawning() {
        if spawnGrace > 0 {
            spawnGrace -= 1
            return
        }
        
        let lvl = currentLevelDef
        
        // Boss spawn check
        if levelKills >= lvl.killTarget && !bossSpawned {
            bossSpawned = true
            bossActive = true
            
            let bossColor = PlayerNode.neonColors.randomElement() ?? .red
            let boss = EnemyNode(
                type: lvl.enemies.last ?? .scout,
                playerWeaponLevel: playerNode.weaponLevel,
                isBoss: true,
                bossHp: lvl.bossHp,
                bossSpeed: lvl.bossSpeed,
                color: bossColor,
                enemyTier: lvl.enemyTier,
                bossType: lvl.bossType
            )
            boss.position = CGPoint(
                x: playerNode.position.x + (playerNode.facing > 0 ? 500 : -500),
                y: Physics.gameHeight + 100
            )
            entityLayer.addChild(boss)
            enemies.append(boss)
            
            gameDelegate?.triggerHaptic(.heavy)
            return
        }
        
        // Don't spawn regular enemies during boss fight
        if bossActive {
            // Safety: if boss is active but no boss exists in array, reset after timer
            // Only reset bossActive (NOT bossSpawned) so a new boss won't spawn
            bossStallTimer += 1
            let hasBoss = enemies.contains { $0.isBoss }
            if !hasBoss && bossStallTimer > 300 {
                bossActive = false
                // Do NOT reset bossSpawned — that would cause a new full-HP boss to appear
                bossStallTimer = 0
            }
            return
        }
        bossStallTimer = 0
        
        // Regular spawning — scaled for level intensity
        spawnCooldown -= 1
        if spawnCooldown > 0 { return }
        
        // Fix 6: Scale max enemies with BOTH level and weapon level
        let maxEnemies = 10 + currentLevel * 3 + playerNode.weaponLevel * 3
        if enemies.count >= maxEnemies { return }
        
        // Fast respawn: if NO enemies exist and level isn't complete, spawn immediately
        if enemies.isEmpty && levelKills < lvl.killTarget {
            spawnCooldown = 0  // Force immediate spawn
        }
        
        // Batch spawn: more enemies per tick at higher levels
        let batchSize = max(1, (currentLevel - 3) / 2)  // 1@L1-4, 2@L5-6, 3@L7-8, 4@L9-10
        
        for _ in 0..<batchSize {
            if enemies.count >= maxEnemies { break }
            
            let type = lvl.enemies.randomElement() ?? .scout
            let color = lvl.colors.enemyColors.randomElement() ?? .cyan
            
            let enemy = EnemyNode(
                type: type,
                playerWeaponLevel: playerNode.weaponLevel,
                color: color,
                enemyTier: lvl.enemyTier
            )
            
            // At higher levels, spawn from all directions (left, right, above, diagonal)
            let spawnX: CGFloat
            let spawnY: CGFloat
            if currentLevel >= 7 {
                // 4-directional spawning for intense later levels
                let direction = Int.random(in: 0...3)
                switch direction {
                case 0: // Right
                    spawnX = playerNode.position.x + 700 + CGFloat.random(in: 0...400)
                    spawnY = playerNode.position.y + CGFloat.random(in: -200...300)
                case 1: // Left
                    spawnX = playerNode.position.x - 700 - CGFloat.random(in: 0...400)
                    spawnY = playerNode.position.y + CGFloat.random(in: -200...300)
                case 2: // Above
                    spawnX = playerNode.position.x + CGFloat.random(in: -600...600)
                    spawnY = Physics.gameHeight + 200 + CGFloat.random(in: 0...200)
                default: // Diagonal
                    let side: CGFloat = Bool.random() ? -1 : 1
                    spawnX = playerNode.position.x + side * (500 + CGFloat.random(in: 0...300))
                    spawnY = Physics.gameHeight + 100 + CGFloat.random(in: 0...300)
                }
            } else {
                let side: CGFloat = Bool.random() ? -1 : 1
                spawnX = playerNode.position.x + side * (900 + CGFloat.random(in: 0...400))
                spawnY = Physics.gameHeight + 200
            }
            
            enemy.position = CGPoint(x: spawnX, y: spawnY)
            entityLayer.addChild(enemy)
            enemies.append(enemy)
        }
        
        // Faster spawn cooldown at higher levels
        spawnCooldown = max(3, 35 - currentLevel * 2 - playerNode.weaponLevel * 2)
    }
    
    // MARK: - Camera (match original offset)
    
    func updateCamera() {
        // Camera follows player — v1.1: camY = player.y - canvas.height/2
        // In v1.1, ground is at y≈700 (canvas Y-down), so camera center ≈ 250 from top.
        // This puts ground at ~75% down the screen (bottom 25%).
        let targetX = playerNode.position.x - Physics.gameWidth / 3.5
        let targetY = playerNode.position.y - Physics.gameHeight / 2 + 200
        
        camX += (targetX - camX) * 0.12
        camY += (targetY - camY) * 0.1
        
        // Camera position is center of view
        cameraNode.position = CGPoint(
            x: camX + Physics.gameWidth / 2,
            y: camY + Physics.gameHeight / 2
        )
    }
    
    // MARK: - HUD Update
    
    func updateHUD() {
        gameDelegate?.updateHUD(
            hp: playerNode.hp,
            maxHp: 100,
            energy: playerNode.energy,
            kills: totalKills,
            combo: combo,
            weaponLevel: playerNode.weaponLevel,
            level: currentLevel
        )
    }
    
    // MARK: - Input Handlers
    
    func handleJump() {
        guard gameState == .playing else { return }
        if playerNode.jumpCount < 2 {
            playerNode.vy = Physics.jumpForce  // positive = up
            playerNode.jumpCount += 1
            gameDelegate?.triggerHaptic(.light)
        }
    }
    
    func handleDash() {
        guard gameState == .playing, playerNode.dashCooldown <= 0 else { return }
        playerNode.dashActive = 15  // Original: player.dashActive = 15
        playerNode.dashCooldown = 35  // Original: player.dashCooldown = 35
        playerNode.vx = CGFloat(playerNode.facing) * Physics.dashForce
        
        // Create particles (trail) logic is in updatePlayer
        
        gameDelegate?.triggerHaptic(.heavy)
    }
    
    func handleAttack() {
        guard gameState == .playing, playerNode.shootTimer <= 0 else { return }
        let lvl = playerNode.weaponLevel
        
        // Damage scales with level, doubled during ult
        let bDmg = (40 + lvl * 12) * (playerNode.ultActive > 0 ? 2 : 1)
        let bSpeed = 45 + CGFloat(lvl) * 1.5
        let interval = playerNode.ultActive > 0 ? 3 : max(3, 10 - lvl)
        
        // Color by weapon level (from original)
        var bColor: UIColor
        if playerNode.ultActive > 0 { bColor = .white }
        else if lvl >= 10 { bColor = PlayerNode.neonColors[gameTime % PlayerNode.neonColors.count] }
        else if lvl >= 7 { bColor = UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1) } // #fbbf24
        else if lvl >= 4 { bColor = UIColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1) } // #a855f7
        else { bColor = UIColor(red: 1, green: 0.24, blue: 0.24, alpha: 1) } // #ff3e3e
        
        // Bullet pattern grows with level
        let fire = { (vy: CGFloat, sizeMult: CGFloat) in
            let proj = ProjectileNode(
                vx: CGFloat(self.playerNode.facing) * bSpeed,
                vy: vy,
                damage: bDmg,
                owner: .player,
                color: bColor,
                life: 50,
                size: Int(10 * sizeMult)
            )
            // Canvas: x = player.x + (facing === 1 ? player.w : -80)
            //   facing right: rightEdge = leftEdge + w = leftEdge + 40
            //   facing left:  leftEdge - 80
            // SpriteKit (center-based):
            //   facing right: position.x + width/2 (= rightEdge)
            //   facing left:  position.x - width/2 - 80 (= leftEdge - 80)
            // Canvas: y = player.y + 20 (20 below top edge)
            // SpriteKit: position.y + height/2 - 20 (20 below top edge)
            let spawnX = self.playerNode.facing == 1
                ? self.playerNode.position.x + self.playerNode.width / 2
                : self.playerNode.position.x - self.playerNode.width / 2 - 80
            proj.position = CGPoint(
                x: spawnX,
                y: self.playerNode.position.y + self.playerNode.height / 2 - 20
            )
            self.entityLayer.addChild(proj)
            self.projectiles.append(proj)
        }
        
        if lvl < 4 {
            fire(0, 1)
        } else if lvl < 7 {
            fire(-4, 1); fire(0, 1.2); fire(4, 1)
        } else if lvl < 10 {
            fire(-8, 1); fire(-4, 1); fire(0, 1.4); fire(4, 1); fire(8, 1)
        } else {
            // Lv10: massive fan
            var spread: CGFloat = -16
            while spread <= 16 {
                fire(spread, spread == 0 ? 2.2 : 1.2)
                spread += 4
            }
        }
        
        playerNode.shootTimer = interval
        gameDelegate?.triggerHaptic(.light)
    }
    
    func handleSkill(_ skillId: String) {
        guard gameState == .playing else { return }
        guard let def = GameConfig.skillDefs.first(where: { $0.id == skillId }) else { return }
        guard let sk = playerNode.skills[skillId], sk.level > 0, sk.cooldown <= 0 else { return }
        
        // Skill implementations — Phase 4
        let lvl = sk.level
        
        switch skillId {
        case "fire":
            let dmg = def.baseDamage + lvl * 15
            let count = (1 + lvl / 3) * 4
            for i in 0..<count {
                let spread = CGFloat(i - count / 2) * 8
                let ang = CGFloat(i - count / 2) * 0.12
                let proj = ProjectileNode(
                    vx: CGFloat(playerNode.facing) * (35 + CGFloat(lvl) * 2) * cos(ang),
                    vy: sin(ang) * 12 + CGFloat.random(in: -2...2),
                    damage: dmg,
                    owner: .player,
                    color: UIColor(red: 1, green: 0.27, blue: 0, alpha: 1),
                    life: 50 + lvl * 4,
                    size: 14 + lvl
                )
                proj.position = CGPoint(
                    x: playerNode.position.x,
                    y: playerNode.position.y + spread
                )
                entityLayer.addChild(proj)
                projectiles.append(proj)
            }
            sk.cooldown = max(40, def.baseCooldown - lvl * 8)
            
        case "whirlwind":
            let dmg = def.baseDamage + lvl * 12
            let count = 4 + lvl / 2
            for i in 0..<count {
                let a = CGFloat(i) / CGFloat(count) * .pi * 2
                let proj = ProjectileNode(
                    vx: cos(a) * 20,
                    vy: sin(a) * 20,
                    damage: dmg,
                    owner: .player,
                    color: UIColor(red: 0, green: 0.8, blue: 1, alpha: 1),
                    life: 25 + lvl * 2,
                    size: 12 + lvl
                )
                proj.position = playerNode.position
                entityLayer.addChild(proj)
                projectiles.append(proj)
            }
            sk.cooldown = max(50, def.baseCooldown - lvl * 10)
            
        case "shield":
            let duration = 180 + lvl * 30
            sk.active = duration
            sk.cooldown = Int(Double(duration) * 1.5) + 60
            
        case "lightning":
            let dmg = def.baseDamage + lvl * 20
            for enemy in enemies {
                enemy.hp -= CGFloat(dmg)
                enemy.damageFlash = 12
            }
            screenFlash = 12
            sk.cooldown = max(60, def.baseCooldown - lvl * 12)
            
        case "ghost":
            let dmg = def.baseDamage + lvl * 18
            let count = (1 + lvl / 4) * 4
            for i in 0..<count {
                let ang = (CGFloat(i) / CGFloat(count) - 0.5) * 2.0
                let proj = ProjectileNode(
                    vx: CGFloat(playerNode.facing) * 15 + cos(ang) * 6,
                    vy: sin(ang) * 10,
                    damage: dmg,
                    owner: .player,
                    color: UIColor(red: 0.2, green: 1, blue: 0.53, alpha: 1),
                    life: 90 + lvl * 5,
                    size: 14,
                    homing: true
                )
                proj.position = CGPoint(
                    x: playerNode.position.x,
                    y: playerNode.position.y + CGFloat(i - count / 2) * 10
                )
                entityLayer.addChild(proj)
                projectiles.append(proj)
            }
            sk.cooldown = max(60, def.baseCooldown - lvl * 12)
            
        default:
            break
        }
        
        gameDelegate?.triggerHaptic(.medium)
    }
    
    func handleUltimate() {
        guard gameState == .playing, playerNode.energy >= 100 else { return }
        playerNode.energy = 0
        playerNode.ultActive = 240
        playerNode.iframe = 240
        gameDelegate?.triggerHaptic(.heavy)
    }
    
    // MARK: - Cheat (Debug)
    
    func cheatKillAll() {
        guard gameState == .playing else { return }
        
        // Kill all enemies (iterate reversed so handleEnemyDeath index removal works)
        for i in (0..<enemies.count).reversed() {
            handleEnemyDeath(at: i)
        }
        
        // Clear all enemy projectiles
        for (i, proj) in projectiles.enumerated().reversed() {
            if proj.owner == .enemy {
                proj.removeFromParent()
                projectiles.remove(at: i)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func handleEnemyDeath(at index: Int) {
        let enemy = enemies[index]
        let wasBoss = enemy.isBoss
        
        // Particles on death (original: createParticles(e.x+e.w/2, e.y+e.h/2, e.color, 12, 1.2, 2))
        createParticles(x: enemy.position.x, y: enemy.position.y,
                       color: enemy.color, count: 12, speedScale: 1.2, sizeScale: 2)
        
        enemy.removeFromParent()
        enemies.remove(at: index)
        totalKills += 1
        levelKills += 1
        combo += 1
        comboTimer = 150
        hitstop = wasBoss ? 12 : 4
        // Original: player.energy = Math.min(100, player.energy + 4) — always 4
        playerNode.energy = min(100, playerNode.energy + 4)
        
        // Drop
        spawnDrop(at: enemy.position)
        
        gameDelegate?.triggerHaptic(wasBoss ? .heavy : .medium)
        
        if wasBoss {
            bossActive = false
            if currentLevel < 10 {
                completeLevel()
            } else {
                endGame(victory: true)
            }
        }
    }
    
    /// Spawn drop with smooth weapon scaling across levels
    func spawnDrop(at position: CGPoint) {
        let comboBonus = Double(combo) * 0.005
        let cap = currentLevelDef.weaponCap
        
        // Fix 4: Smooth weapon scaling — target ~1 weapon level per game level
        let weaponProb: Double
        if playerNode.weaponLevel >= 10 {
            weaponProb = 0.01  // Max level, almost no drops
        } else if playerNode.weaponLevel >= cap {
            weaponProb = 0.02  // Already at cap for this level, very rare
        } else {
            // Scale based on deficit from cap — more drops if behind
            let deficit = cap - playerNode.weaponLevel
            let levelProgress = Double(levelKills) / max(1.0, Double(currentLevelDef.killTarget))
            weaponProb = min(0.15, 0.04 + Double(deficit) * 0.035) * (1.0 - levelProgress * 0.4) + comboBonus
        }
        
        let healthProb = 0.08 + Double(max(0, 100 - playerNode.hp)) * 0.002 + comboBonus
        let rand = Double.random(in: 0...1)
        
        if rand < weaponProb {
            let drop = DropData(
                x: position.x, y: position.y + 40,
                vx: CGFloat.random(in: -4...4),
                vy: 10,
                type: .weapon, life: 800
            )
            addDropWithNode(drop)
        } else if rand < weaponProb + healthProb {
            let drop = DropData(
                x: position.x, y: position.y + 40,
                vx: CGFloat.random(in: -3...3),
                vy: 12,
                type: .health, life: 800
            )
            addDropWithNode(drop)
        }
    }
    
    /// Create visual node for a drop and add to drops array
    private func addDropWithNode(_ drop: DropData) {
        var d = drop
        let node = SKNode()
        node.position = CGPoint(x: d.x, y: d.y)
        node.zPosition = 5
        
        if d.type == .health {
            // Heart shape with green glow
            let heart = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addArc(withCenter: CGPoint(x: -6, y: 6), radius: 8, startAngle: 0, endAngle: .pi, clockwise: true)
            path.addArc(withCenter: CGPoint(x: 6, y: 6), radius: 8, startAngle: 0, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: 0, y: -10))
            path.close()
            heart.path = path.cgPath
            heart.fillColor = UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)  // #22c55e
            heart.strokeColor = .clear
            heart.glowWidth = 10
            node.addChild(heart)
        } else {
            // Weapon: rotating golden square with white cross
            let square = SKShapeNode(rectOf: CGSize(width: 32, height: 32))
            square.fillColor = UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)  // #fbbf24
            square.strokeColor = .clear
            square.glowWidth = 12
            node.addChild(square)
            
            // White cross
            let crossV = SKShapeNode(rectOf: CGSize(width: 8, height: 24))
            crossV.fillColor = .white
            crossV.strokeColor = .clear
            node.addChild(crossV)
            let crossH = SKShapeNode(rectOf: CGSize(width: 24, height: 8))
            crossH.fillColor = .white
            crossH.strokeColor = .clear
            node.addChild(crossH)
            
            // Rotate
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2)  // Original: gameTime*0.05 ≈ 3 rad/s
            square.run(SKAction.repeatForever(rotate))
        }
        
        entityLayer.addChild(node)
        d.node = node
        drops.append(d)
    }
    
    func levelUpRandomSkill() {
        let ids = GameConfig.skillDefs.map { $0.id }
        if let randomId = ids.randomElement(), let sk = playerNode.skills[randomId] {
            if sk.level < 10 {
                sk.level += 1
            }
        }
    }
    
    func isOnScreen(_ node: SKNode) -> Bool {
        let dx = abs(node.position.x - cameraNode.position.x)
        let dy = abs(node.position.y - cameraNode.position.y)
        return dx < Physics.gameWidth / 2 + 200 && dy < Physics.gameHeight / 2 + 200
    }
    
    // MARK: - Particle System (match original createParticles)
    
    func createParticles(x: CGFloat, y: CGFloat, color: UIColor, count: Int, speedScale: CGFloat = 1, sizeScale: CGFloat = 1) {
        for _ in 0..<count {
            let size = (2 + CGFloat.random(in: 0...4)) * sizeScale
            let particle = SKShapeNode(rectOf: CGSize(width: size, height: size))
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.position = CGPoint(x: x, y: y)
            particle.zPosition = 40
            particle.glowWidth = 2
            
            let vx = (CGFloat.random(in: 0...1) - 0.5) * 25 * speedScale
            let vy = (CGFloat.random(in: 0...1) - 0.5) * 25 * speedScale
            let life = 1.0
            let decay = 0.02 + CGFloat.random(in: 0...0.02)
            let duration = life / decay / 60.0  // approximate frame-based to time-based
            
            let move = SKAction.moveBy(x: vx * CGFloat(duration) * 30, y: vy * CGFloat(duration) * 30, duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()
            particle.run(SKAction.sequence([group, remove]))
            
            entityLayer.addChild(particle)
        }
    }
}

// MARK: - Data Structures

struct PlatformData {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: UIColor
    let isGround: Bool
}



struct LightningBolt {
    var targetX: CGFloat
    var targetY: CGFloat
    var life: Int
    var maxLife: Int
    var segments: [(CGFloat, CGFloat)]
}

struct ParticleEffect {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var color: UIColor
    var size: CGFloat
    var decay: CGFloat
}

struct DropData {
    enum DropType { case health, weapon }
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var type: DropType
    var life: Int
    var node: SKNode? = nil
}

// MARK: - Haptic Type
enum HapticType {
    case light, medium, heavy
}

// MARK: - Delegate Protocol
protocol GameSceneDelegate: AnyObject {
    func gameStateChanged(_ state: GameScene.GameState)
    func updateHUD(hp: Int, maxHp: Int, energy: Int, kills: Int, combo: Int, weaponLevel: Int, level: Int)
    func showLevelBanner(_ name: String)
    func gameEnded(kills: Int, time: Int, level: Int, victory: Bool)
    func triggerHaptic(_ type: HapticType)
}
