package com.douluo.bridge

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.ScreenAdapter
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.scenes.scene2d.Group
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.badlogic.gdx.math.MathUtils
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.scenes.scene2d.Actor
import com.douluo.bridge.ui.GameScreenDelegate
import com.douluo.bridge.ui.HapticType

enum class GameState {
    MENU, PLAYING, PAUSED, GAME_OVER, LEVEL_TRANSITION
}

data class DropData(
    var x: Float, var y: Float, var vx: Float = 0f, var vy: Float = 0f,
    val type: DropType, var life: Int, var node: Actor? = null
) {
    sealed class DropType {
        object Health : DropType()
        object Weapon : DropType()
        data class Skill(val id: String) : DropType()
    }
}

class DouluoGameScreen(
    private val game: DouluoGame,
    private val delegate: GameScreenDelegate
) : ScreenAdapter() {

    var gameState = GameState.MENU
    var currentLevel = 1
    var levelKills = 0
    var totalKills = 0
    var combo = 0
    var comboTimer = 0
    var gameTime = 0
    var hitstop = 0
    var spawnCooldown = 0
    var spawnGrace = 0
    var bossActive = false
    var bossSpawned = false
    var screenFlash = 0
    var bossStallTimer = 0
    var hpMultiplier = 1.0f
    var enemyProjectileCount = 0

    // Fixed timestep: decouple logic from render frame rate.
    // Enhanced smoothness parameters for Android high-refresh-rate devices
    private var accumulator = 0f
    private val STEP = 1f / 60f

    private val stage: Stage
    private val camera: OrthographicCamera
    private val batch: SpriteBatch = game.batch

    private val backgroundNode = Group()
    private val platformLayer = Group()
    private val entityLayer = Group()
    private val effectLayer = Group()

    lateinit var playerNode: PlayerNode

    val enemies = mutableListOf<EnemyNode>()
    val projectiles = mutableListOf<ProjectileNode>()
    val platforms = mutableListOf<PlatformData>()
    val drops = mutableListOf<DropData>()

    var inputLeft = false
    var inputRight = false
    var inputJump = false
    var inputDash = false
    var inputAttack = false

    val currentLevelDef: LevelDef
        get() {
            val idx = MathUtils.clamp(currentLevel - 1, 0, GameConfig.levels.size - 1)
            return GameConfig.levels[idx]
        }

    init {
        // Use ExtendViewport so the game fills the screen on wide-screen phones
        // (FitViewport would leave letterbox black bars on 20:9 devices)
        camera = OrthographicCamera()
        val viewport = ExtendViewport(Physics.gameWidth, Physics.gameHeight, camera)
        stage = Stage(viewport, batch)

        stage.addActor(backgroundNode)
        stage.addActor(platformLayer)
        stage.addActor(entityLayer)
        stage.addActor(effectLayer)

        playerNode = PlayerNode()
        playerNode.setPosition(400f, 150f)
        entityLayer.addActor(playerNode)

        gameState = GameState.MENU
        delegate.gameStateChanged(gameState)
    }

    fun startGame() {
        currentLevel = 1
        levelKills = 0
        totalKills = 0
        combo = 0
        comboTimer = 0
        gameTime = 0
        bossActive = false
        bossSpawned = false
        
        for (e in enemies) e.remove()
        enemies.clear()
        for (p in projectiles) p.remove()
        projectiles.clear()
        for (d in drops) d.node?.remove()
        drops.clear()
        
        spawnGrace = 120
        hpMultiplier = 1.0f
        enemyProjectileCount = 0

        playerNode.reset()
        playerNode.setPosition(400f, 300f)

        clearEntities()
        generatePlatforms()
        drawBackground()

        gameState = GameState.PLAYING
        delegate.gameStateChanged(gameState)
        delegate.showLevelBanner(currentLevelDef.name, updateBGM = false)
    }

    private fun clearEntities() {
        enemies.forEach { it.remove() }
        enemies.clear()
        projectiles.forEach { it.remove() }
        projectiles.clear()
        drops.forEach { it.node?.remove() }
        drops.clear()
    }

    fun pauseGame() {
        if (gameState == GameState.PLAYING) {
            gameState = GameState.PAUSED
            delegate.gameStateChanged(gameState)
        }
    }

    fun resumeGame() {
        if (gameState == GameState.PAUSED) {
            gameState = GameState.PLAYING
            delegate.gameStateChanged(gameState)
        }
    }

    fun endGame(victory: Boolean) {
        gameState = GameState.GAME_OVER
        delegate.gameStateChanged(gameState)
        delegate.gameEnded(totalKills, gameTime, currentLevel, victory)
    }

    fun completeLevel() {
        if (currentLevel < 10) {
            gameState = GameState.LEVEL_TRANSITION
            currentLevel += 1
            levelKills = 0
            bossActive = false
            bossSpawned = false
            spawnGrace = 120
            hpMultiplier *= 1.5f
            playerNode.hp = 100

            clearEntities()

            generatePlatforms()
            drawBackground()
            levelUpRandomSkill()

            delegate.showLevelBanner(currentLevelDef.name, updateBGM = true)

            // Delayed resume logic using LibGDX Action/Timer
            stage.addAction(com.badlogic.gdx.scenes.scene2d.actions.Actions.sequence(
                com.badlogic.gdx.scenes.scene2d.actions.Actions.delay(2.0f),
                com.badlogic.gdx.scenes.scene2d.actions.Actions.run {
                    gameState = GameState.PLAYING
                    delegate.gameStateChanged(gameState)
                }
            ))
        } else {
            endGame(victory = true)
        }
    }

    private val whiteTex: Texture by lazy {
        val pix = Pixmap(1, 1, Pixmap.Format.RGBA8888)
        pix.setColor(Color.WHITE)
        pix.fill()
        val tex = Texture(pix)
        tex.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear)
        pix.dispose()
        tex
    }

    private val groundWaveTex: Texture by lazy {
        val w = 1500
        val h = 12
        val pix = Pixmap(w, h, Pixmap.Format.RGBA8888)
        pix.setColor(Color(0.54f, 0.48f, 0.38f, 1f).mul(0.58f, 0.58f, 0.58f, 1f))
        val amplitude = 4f
        val frequency = 0.08f
        for (x in 0 until w) {
            val y = (Math.sin(x * frequency.toDouble()) * amplitude + amplitude).toInt()
            for(fillY in (h - y - 4) until h) {
                 if (fillY >= 0) pix.drawPixel(x, fillY)
            }
        }
        val tex = Texture(pix)
        tex.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear)
        pix.dispose()
        tex
    }

    private fun generatePlatforms() {
        platformLayer.clear()
        platforms.clear()

        val colors = currentLevelDef.colors

        // Rainbow colours for sky/high platforms (matches iOS)
        val rainbowColors = listOf(
            Color(1f, 0.3f, 0.3f, 1f),   // Red
            Color(1f, 0.6f, 0.2f, 1f),   // Orange
            Color(1f, 0.9f, 0.2f, 1f),   // Yellow
            Color(0.3f, 0.9f, 0.4f, 1f), // Green
            Color(0.2f, 0.8f, 1f, 1f),   // Cyan
            Color(0.3f, 0.4f, 1f, 1f),   // Blue
            Color(0.7f, 0.3f, 1f, 1f),   // Purple
            Color(1f, 0.4f, 0.8f, 1f)    // Magenta
        )

        for (i in 0 until 500) {
            val surfaceY = 50f + MathUtils.random(0f, 50f)
            val groundHeight = 600f
            val groundBottom = surfaceY - groundHeight
            val groundColor = colors.platformGround.randomOrNull() ?: Color(0.1f, 0.1f, 0.1f, 1f)
            val groundPlat = PlatformData(
                i * 600f, groundBottom, 650f, groundHeight, groundColor, true
            )
            platforms.add(groundPlat)
            drawPlatform(groundPlat)  // ground: only draws wavy top edge

            // Mid-level floating platforms (65% chance)
            if (MathUtils.random() > 0.35f) {
                val floatColor = colors.platformFloat.randomOrNull() ?: Color(0.2f, 0.2f, 0.2f, 1f)
                val midPlat = PlatformData(
                    i * 600f + 150f, 175f + MathUtils.random(0f, 125f),
                    280f, 22f, floatColor, false
                )
                platforms.add(midPlat)
                drawPlatform(midPlat)
            }

            // Sky platforms — rainbow colours (50% chance)
            if (MathUtils.random() > 0.5f) {
                val skyColor = rainbowColors[i % rainbowColors.size]
                val skyPlat = PlatformData(
                    i * 600f + MathUtils.random(0f, 400f),
                    260f + MathUtils.random(0f, 90f),
                    180f + MathUtils.random(0f, 120f), 18f,
                    skyColor, false
                )
                platforms.add(skyPlat)
                drawPlatform(skyPlat)
            }

            // High platforms — rainbow colours (30% chance) — matches iOS
            if (MathUtils.random() > 0.7f) {
                val highColor = rainbowColors[(i + 3) % rainbowColors.size]
                val highPlat = PlatformData(
                    i * 600f + MathUtils.random(0f, 300f),
                    350f + MathUtils.random(0f, 50f),
                    140f + MathUtils.random(0f, 80f), 15f,
                    highColor, false
                )
                platforms.add(highPlat)
                drawPlatform(highPlat)
            }
        }
    }

    private fun drawPlatform(plat: PlatformData) {
        val platGroup = Group()
        platGroup.setPosition(plat.x, plat.y)
        
        if (!plat.isGround) {
            // Floating platforms: draw coloured block + top edge (same as iOS)
            val darkColor = Color(plat.color).mul(0.58f, 0.58f, 0.58f, 1f)
            val platW = plat.width
            val platH = plat.height
            
            val body = Image(whiteTex)
            body.color = darkColor
            body.setSize(platW, platH)
            platGroup.addActor(body)
            
            // Top edge highlight
            val edge = Image(whiteTex)
            edge.color = Color(plat.color)
            edge.setSize(platW, 2f)
            edge.setPosition(0f, platH - 2f)
            platGroup.addActor(edge)
        } else {
            // Ground: draw wavy top edge (a thin wavy strip) — matches iOS
            val eW = plat.width
            val region = com.badlogic.gdx.graphics.g2d.TextureRegion(groundWaveTex, 0, 0, eW.toInt(), groundWaveTex.height)
            val edge = Image(region)
            edge.setSize(eW, 12f)
            edge.setPosition(0f, plat.height - 12f)
            platGroup.addActor(edge)
        }
        platformLayer.addActor(platGroup)
    }

    private val bgTextureCache = mutableMapOf<Int, Texture>()

    private fun drawBackground() {
        backgroundNode.clear()

        val bgName = "images/bg_level_$currentLevel.png"
        var bgLoaded = false
        try {
            if (Gdx.files.internal(bgName).exists()) {
                val tex = Texture(Gdx.files.internal(bgName))
                val bgImg = Image(tex)
                val imgAspect = tex.width.toFloat() / tex.height.toFloat()
                val screenAspect = Physics.gameWidth / Physics.gameHeight
                if (imgAspect > screenAspect) {
                    bgImg.setSize(Physics.gameHeight * imgAspect, Physics.gameHeight)
                } else {
                    bgImg.setSize(Physics.gameWidth, Physics.gameWidth / imgAspect)
                }
                bgImg.setPosition(camera.position.x - Physics.gameWidth/2, camera.position.y - Physics.gameHeight/2)
                bgImg.color.a = 1.0f
                backgroundNode.addActor(bgImg)
                bgTextureCache[currentLevel]?.dispose()
                bgTextureCache[currentLevel] = tex
                bgLoaded = true
            }
        } catch (e: Exception) {
            bgLoaded = false
        }

        // Fallback: draw gradient background using level colours (matches iOS behaviour)
        if (!bgLoaded) {
            val levelColors = currentLevelDef.colors
            val topColor = levelColors.bgColors.getOrElse(0) { Color(0.6f, 0.8f, 1f, 1f) }.cpy().mul(1.3f).apply { clamp() }
            val botColor = levelColors.bgColors.getOrElse(1) { Color(0.9f, 0.95f, 1f, 1f) }

            // Create a 1-pixel-wide gradient to save extremely huge alloc overhead, and stretch it
            val bgW = (Physics.gameWidth * 3).toInt().coerceAtLeast(1)
            val bgH = Physics.gameHeight.toInt().coerceAtLeast(1)
            
            var bgTex = bgTextureCache[currentLevel]
            if (bgTex == null) {
                val pix = Pixmap(1, bgH, Pixmap.Format.RGBA8888)
                for (row in 0 until bgH) {
                    val t = row.toFloat() / bgH
                    val r = botColor.r + (topColor.r - botColor.r) * t
                    val g = botColor.g + (topColor.g - botColor.g) * t
                    val b = botColor.b + (topColor.b - botColor.b) * t
                    pix.setColor(r.coerceIn(0f,1f), g.coerceIn(0f,1f), b.coerceIn(0f,1f), 1f)
                    pix.fillRectangle(0, row, 1, 1)
                }
                bgTex = Texture(pix)
                pix.dispose()
                bgTextureCache[currentLevel] = bgTex
            }
            
            val bgImg = Image(bgTex)
            bgImg.setSize(bgW.toFloat(), bgH.toFloat())
            bgImg.setPosition(-bgW / 3f, 0f)
            backgroundNode.addActor(bgImg)
        }
    }

    override fun render(delta: Float) {
        val bgColor = currentLevelDef.colors.bgColors.firstOrNull() ?: Color.WHITE
        Gdx.gl.glClearColor(bgColor.r, bgColor.g, bgColor.b, 1f)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)

        if (gameState == GameState.PLAYING) {
            // Adaptive accumulation to prevent micro-stuttering on VRR / 120Hz displays
            accumulator += delta.coerceAtMost(0.1f)
            while (accumulator >= STEP) {
                updateLogic()
                accumulator -= STEP
            }
        }

        // Keep background fixed to camera roughly
        if (backgroundNode.children.size > 0) {
            val bg = backgroundNode.children.first()
            bg.setPosition(camera.position.x - bg.width/2, camera.position.y - bg.height/2)
        }

        stage.act(delta)
        stage.draw()
    }

    private fun updateLogic() {
        if (hitstop > 0) {
            hitstop--
            return
        }

        gameTime++
        if (comboTimer > 0) {
            comboTimer--
            if (comboTimer <= 0) combo = 0
        }

        updateSpawning()
        updatePlayer()
        updateEnemies()
        updateDrops()
        updateProjectiles()
        updateEffects()
        updateCamera()
        updateHUD()

        if (playerNode.hp <= 0 || playerNode.y < -1600) {
            endGame(victory = false)
        }
    }

    // ----- Updates -----

    private fun updatePlayer() {
        val p = playerNode
        if (p.dashActive > 0) {
            p.vx = p.facing * Physics.dashForce
            p.vy = 0f
            if (p.dashActive % 2 == 0) spawnDashTrail(p.x, p.y, p.facing)
            p.dashActive -= 1
        } else {
            if (inputLeft) {
                p.vx = -Physics.playerSpeed
                p.facing = -1
            } else if (inputRight) {
                p.vx = Physics.playerSpeed
                p.facing = 1
            } else {
                p.vx *= 0.82f
            }
            p.vy -= Physics.gravity
        }

        p.x += p.vx
        p.y += p.vy

        if (p.dashCooldown > 0) p.dashCooldown--
        if (p.iframe > 0) p.iframe--
        if (p.shootTimer > 0) p.shootTimer--
        if (p.ultActive > 0) p.ultActive--

        for (sk in p.skills.values) {
            if (sk.cooldown > 0) sk.cooldown--
            if (sk.active > 0) sk.active--
        }

        p.grounded = false
        val playerLeft = p.x
        val playerRight = p.x + p.width
        val playerBottom = p.y

        for (plat in platforms) {
            val platLeft = plat.x
            val platRight = plat.x + plat.width
            val platTop = plat.y + plat.height

            if (playerRight > platLeft && playerLeft < platRight &&
                playerBottom <= platTop && playerBottom > plat.y - 20 && p.vy < 0) {
                p.y = platTop
                p.vy = 0f
                p.grounded = true
                p.jumpCount = 0
            }
        }

        if (p.y < -1600f) p.hp = 0

        p.updateVisual()
    }

    private fun updateEnemies() {
        val iter = enemies.iterator()
        while (iter.hasNext()) {
            val enemy = iter.next()
            enemy.update(playerNode.x, platforms)

            val enemyRelX = Math.abs(enemy.x - camera.position.x)
            val enemyRelY = enemy.y
            if (enemyRelY < -200 || enemyRelX > Physics.gameWidth) {
                if (enemy.isBoss) {
                    val side = if (playerNode.facing > 0) 1 else -1
                    enemy.setPosition(playerNode.x + side * 400, playerNode.y + 200)
                    enemy.vx = 0f
                    enemy.vy = 0f
                    continue
                }
                levelKills++
                totalKills++
                enemy.remove()
                iter.remove()
                continue
            }

            val playerCx = playerNode.x + playerNode.width / 2f
            val playerCy = playerNode.y + playerNode.height / 2f
            val enemyCx = enemy.x + enemy.enemyWidth / 2f
            val enemyCy = enemy.y + enemy.enemyHeight / 2f

            val dx = Math.abs(enemyCx - playerCx)
            val dy = Math.abs(enemyCy - playerCy)

            if (!enemy.isBoss && enemy.enemyType == EnemyType.CHASER && dx < 60 && dy < 70) {
                val shield = playerNode.skills["shield"]
                if (shield != null && shield.active > 0) {
                    shield.active = Math.max(0, shield.active - 10)
                    delegate.triggerHaptic(HapticType.LIGHT)
                } else if (playerNode.iframe <= 0) {
                    playerNode.hp -= 15
                    playerNode.iframe = 24
                    delegate.triggerHaptic(HapticType.MEDIUM)
                }
                enemy.hp = 0f
            }

            if (enemy.hp <= 0) {
                handleEnemyDeath(enemy)
                enemy.remove()
                iter.remove()
                continue
            }

            if (enemy.enemyType != EnemyType.CHASER && enemy.enemyType != EnemyType.SNIPER) {
                if (enemy.shootTimer <= 0 && dx < 1000) {
                    val angle = Math.atan2((playerNode.y - enemy.y).toDouble(), (playerNode.x - enemy.x).toDouble()).toFloat()
                    val speed = 14f
                    val neonColor = PlayerNode.neonColors.random()
                    
                    if (enemyProjectileCount < 30) {
                        val proj = ProjectileNode(
                            MathUtils.cos(angle) * speed, MathUtils.sin(angle) * speed,
                            12, ProjectileOwner.ENEMY, neonColor, 60, 10
                        )
                        proj.setPosition(enemy.x, enemy.y)
                        entityLayer.addActor(proj)
                        projectiles.add(proj)
                        enemyProjectileCount++
                    }
                    enemy.shootTimer = 70f + MathUtils.random(50f)
                }
            }

            if (playerNode.dashActive > 0 && dx < 60 && dy < 80) {
                if (enemy.damageFlash == 0) {
                    val dashDmg = 100 + playerNode.weaponLevel * 30
                    enemy.hp -= dashDmg
                    enemy.damageFlash = 10
                    enemy.vx += playerNode.facing * 15f
                    enemy.y += 5f
                    delegate.triggerHaptic(HapticType.MEDIUM)
                }
            }

            if (enemy.enemyType == EnemyType.SNIPER && enemy.aimTimer > 80) {
                 val angle = Math.atan2((playerNode.y - enemy.y).toDouble(), (playerNode.x - enemy.x).toDouble()).toFloat()
                 val speed = 42f
                 val neonColor = PlayerNode.neonColors.random()
                 
                 if (enemyProjectileCount < 30) {
                     val proj = ProjectileNode(
                         MathUtils.cos(angle) * speed, MathUtils.sin(angle) * speed,
                         30, ProjectileOwner.ENEMY, neonColor, 20, 10
                     )
                     proj.setPosition(enemy.x, enemy.y)
                     entityLayer.addActor(proj)
                     projectiles.add(proj)
                     enemyProjectileCount++
                 }
                 enemy.aimTimer = 0
            }
        }
    }

    private fun updateProjectiles() {
        val iter = projectiles.iterator()
        while(iter.hasNext()) {
            val proj = iter.next()
            proj.update(enemies)

            if (proj.life <= 0 || !isOnScreen(proj)) {
                if (proj.owner == ProjectileOwner.ENEMY) enemyProjectileCount--
                proj.remove()
                iter.remove()
                continue
            }

            if (proj.owner == ProjectileOwner.PLAYER) {
                var removed = false
                for (enemy in enemies) {
                    val eid = System.identityHashCode(enemy)
                    if (proj.hitEnemies.contains(eid)) continue

                    // Use center coordinates for both: enemy center = (x + w/2, y + h/2)
                    val projCx = proj.x + 35f  // half of ~70px projectile width
                    val projCy = proj.y + proj.size / 2f
                    val enemyCx = enemy.x + enemy.enemyWidth / 2f
                    val enemyCy = enemy.y + enemy.enemyHeight / 2f
                    val dx = Math.abs(projCx - enemyCx)
                    val dy = Math.abs(projCy - enemyCy)
                    if (dx < (enemy.enemyWidth / 2 + 50) && dy < (enemy.enemyHeight / 2 + proj.size / 2)) {
                        val decayFactor = Math.pow(0.9, proj.hitEnemies.size.toDouble())
                        val pierceDmg = (proj.damage * decayFactor).toInt()
                        
                        enemy.hp -= pierceDmg
                        enemy.damageFlash = 6
                        proj.hitEnemies.add(eid)

                        // NOTE: do NOT call enemies.remove() here — we are currently
                        // iterating over projectiles (inner loop over enemies).
                        // handleEnemyDeath marks hp<=0; updateEnemies' iterator removes them.

                        if (proj.hitEnemies.size >= proj.pierceCount) {
                            proj.remove()
                            iter.remove()
                            removed = true
                            break
                        }
                    }
                }
            } else {
                // Enemy projectile hits player: use center coords
                val projCx = proj.x + 35f
                val projCy = proj.y + proj.size / 2f
                val playerCx = playerNode.x + playerNode.width / 2f
                val playerCy = playerNode.y + playerNode.height / 2f
                val dx = Math.abs(projCx - playerCx)
                val dy = Math.abs(projCy - playerCy)
                if (dx < (playerNode.width / 2 + proj.size) && dy < (playerNode.height / 2 + proj.size) && playerNode.iframe <= 0) {
                    val shield = playerNode.skills["shield"]
                    if (shield != null && shield.active > 0) {
                        shield.active = Math.max(0, shield.active - 10)
                    } else {
                        playerNode.hp -= proj.damage
                        playerNode.iframe = 24
                        delegate.triggerHaptic(HapticType.MEDIUM)
                    }
                    enemyProjectileCount--
                    proj.remove()
                    iter.remove()
                }
            }
        }
    }

    private fun updateDrops() {
        val iter = drops.iterator()
        while(iter.hasNext()) {
            val d = iter.next()
            d.vy -= Physics.gravity * 0.6f
            d.x += d.vx
            d.y += d.vy
            d.life -= 1

            for (plat in platforms) {
                val dBottom = d.y - 14f
                val platTop = plat.y + plat.height
                if (d.x < plat.x + plat.width && d.x + 32 > plat.x &&
                    dBottom < platTop && dBottom > plat.y - 20 && d.vy < 0) {
                    d.y = platTop + 14f
                    d.vy = 0f
                    d.vx *= 0.7f
                }
            }

            if (d.life <= 0) {
                d.node?.remove()
                iter.remove()
                continue
            }

            d.node?.setPosition(d.x, d.y + MathUtils.sin(gameTime * 0.1f) * 10f)

            val dx = Math.abs(d.x - playerNode.x)
            val dy = Math.abs(d.y - playerNode.y)
            if (dx < 50 && dy < 70) {
                when (d.type) {
                    is DropData.DropType.Health -> {
                        playerNode.hp = Math.min(100, playerNode.hp + 30)
                        delegate.triggerHaptic(HapticType.MEDIUM)
                    }
                    is DropData.DropType.Weapon -> {
                        if (playerNode.weaponLevel < currentLevelDef.weaponCap) {
                            playerNode.weaponLevel++
                            playerNode.rebuildVisual()
                            delegate.triggerHaptic(HapticType.HEAVY)
                        }
                    }
                    is DropData.DropType.Skill -> {
                        val skillId = (d.type as DropData.DropType.Skill).id
                        playerNode.skills[skillId]?.let { sk ->
                            sk.level++
                            val def = GameConfig.skillDefs.find { it.id == skillId }
                            delegate.showLevelBanner("获得技能: ${def?.name ?: skillId}", false)
                            delegate.triggerHaptic(HapticType.HEAVY)
                            handleSkill(skillId, true)
                        }
                    }
                }
                d.node?.remove()
                iter.remove()
            }
        }
    }

    private fun updateEffects() {
        if (screenFlash > 0) screenFlash--
    }

    private fun updateSpawning() {
        if (spawnGrace > 0) {
            spawnGrace--
            return
        }

        val lvl = currentLevelDef

        if (levelKills >= lvl.killTarget && !bossSpawned) {
            bossSpawned = true
            bossActive = true
            val b = EnemyNode(
                lvl.enemies.last(), playerNode.weaponLevel, true, lvl.bossHp, lvl.bossSpeed,
                PlayerNode.neonColors.random(), lvl.enemyTier, lvl.bossType, hpMultiplier
            )
            b.setPosition(playerNode.x + (if (playerNode.facing > 0) 500f else -500f), Physics.gameHeight + 100f)
            entityLayer.addActor(b)
            enemies.add(b)
            delegate.triggerHaptic(HapticType.HEAVY)
            return
        }

        if (bossActive) {
            bossStallTimer++
            val hasBoss = enemies.any { it.isBoss }
            if (!hasBoss && bossStallTimer > 300) {
                bossActive = false
                bossStallTimer = 0
            }
            return
        }
        bossStallTimer = 0

        spawnCooldown--
        if (spawnCooldown > 0) return

        val maxEnemies = Math.min(25, 10 + currentLevel * 3 + playerNode.weaponLevel * 2)
        if (enemies.size >= maxEnemies) return

        if (enemies.isEmpty() && levelKills < lvl.killTarget) spawnCooldown = 0

        val batchSize = Math.max(1, Math.min(2, (currentLevel - 3) / 2))
        for (i in 0 until batchSize) {
            if (enemies.size >= maxEnemies) break

            val type = lvl.enemies.random()
            val color = Color(lvl.colors.enemyColors.random()).mul(0.58f)
            val e = EnemyNode(type, playerNode.weaponLevel, baseColor = color, enemyTier = lvl.enemyTier, hpMultiplier = hpMultiplier)
            
            val spawnX = playerNode.x + (if (MathUtils.randomBoolean()) 1 else -1) * (900f + MathUtils.random(400f))
            val spawnY = Physics.gameHeight + 200f
            e.setPosition(spawnX, spawnY)

            entityLayer.addActor(e)
            enemies.add(e)
        }

        spawnCooldown = Math.max(8, 28 - currentLevel * 2 - playerNode.weaponLevel)
    }

    private fun updateCamera() {
        val targetX = playerNode.x - Physics.gameWidth / 3.5f
        val targetY = playerNode.y - Physics.gameHeight / 2f + 200f

        val cx = camera.position.x - Physics.gameWidth/2
        val cy = camera.position.y - Physics.gameHeight/2

        val newCx = cx + (targetX - cx) * 0.12f
        val newCy = cy + (targetY - cy) * 0.1f

        camera.position.set(newCx + Physics.gameWidth/2, newCy + Physics.gameHeight/2, 0f)
        camera.update()
    }

    private fun updateHUD() {
        delegate.updateHUD(
            playerNode.hp.toFloat(), 100, playerNode.energy, totalKills, combo, playerNode.weaponLevel, currentLevel
        )
    }

    // ----- Inputs -----

    fun handleJump() {
        if (gameState != GameState.PLAYING) return
        if (playerNode.jumpCount < 2) {
            playerNode.vy = Physics.jumpForce
            playerNode.jumpCount++
            delegate.triggerHaptic(HapticType.LIGHT)
        }
    }

    fun handleDash() {
        if (gameState != GameState.PLAYING || playerNode.dashCooldown > 0) return
        playerNode.dashActive = 15
        playerNode.dashCooldown = 35
        playerNode.vx = playerNode.facing * Physics.dashForce
        delegate.triggerHaptic(HapticType.HEAVY)
    }

    fun handleAttack() {
        if (gameState != GameState.PLAYING || playerNode.shootTimer > 0) return
        if (projectiles.size < 80) {
            val lvl = playerNode.weaponLevel
            val bDmg = (40 + lvl * 12) * (if (playerNode.ultActive > 0) 2 else 1)
            val bSpeed = 45f + lvl * 1.5f
            val interval = if (playerNode.ultActive > 0) 3 else Math.max(3, 10 - lvl)

            val bColor = when {
                playerNode.ultActive > 0 -> Color.WHITE
                lvl >= 10 -> PlayerNode.neonColors[gameTime % PlayerNode.neonColors.size]
                lvl >= 7 -> Color.valueOf("fbbf24")
                lvl >= 4 -> Color.valueOf("a855f7")
                else -> Color.valueOf("ff3e3e")
            }

            fun fire(vy: Float, sizeMult: Float) {
                val proj = ProjectileNode(
                    playerNode.facing * bSpeed, vy, bDmg, ProjectileOwner.PLAYER, 
                    bColor, 50, (10 * sizeMult).toInt(), false, lvl
                )
                val spawnX = if (playerNode.facing == 1) playerNode.x + playerNode.width/2 else playerNode.x - playerNode.width/2 - 80f
                proj.setPosition(spawnX, playerNode.y + playerNode.height * 0.7f)
                entityLayer.addActor(proj)
                projectiles.add(proj)
            }

            if (lvl < 4) {
                fire(0f, 1f)
            } else if (lvl < 7) {
                fire(-4f, 1f); fire(0f, 1.2f); fire(4f, 1f)
            } else {
                fire(-8f, 1f); fire(-4f, 1f); fire(0f, 1.4f); fire(4f, 1f); fire(8f, 1f)
            }
            playerNode.shootTimer = interval
            delegate.triggerHaptic(HapticType.LIGHT)
        }
    }

    fun handleSkill(skillId: String, ignoreCooldown: Boolean = false) {
        if (gameState != GameState.PLAYING) return
        val def = GameConfig.skillDefs.find { it.id == skillId } ?: return
        val sk = playerNode.skills[skillId] ?: return
        if (sk.level <= 0 || (sk.cooldown > 0 && !ignoreCooldown)) return

        val lvl = sk.level

        when (skillId) {
            "fire" -> {
                val dmg = def.baseDamage + lvl * 15
                val count = (1 + lvl / 3) * 4
                for (i in 0 until count) {
                    val spread = (i - count/2) * 8f
                    val ang = (i - count/2) * 0.12f
                    val proj = ProjectileNode(
                        playerNode.facing * (35f + lvl * 2f) * MathUtils.cos(ang),
                        MathUtils.sin(ang) * 12f + MathUtils.random(-2f, 2f),
                        dmg, ProjectileOwner.PLAYER, Color(1f, 0.27f, 0f, 1f),
                        50 + lvl * 4, 14 + lvl, true, 1
                    )
                    proj.setPosition(playerNode.x, playerNode.y + playerNode.height * 0.7f + spread)
                    entityLayer.addActor(proj)
                    projectiles.add(proj)
                }
                if (!ignoreCooldown) sk.cooldown = Math.max(40, def.baseCooldown - lvl * 8)
            }
            "whirlwind" -> {
                val dmg = def.baseDamage + lvl * 12
                val count = 4 + lvl / 2
                for (i in 0 until count) {
                    val ang = i.toFloat() / count * MathUtils.PI2
                    val proj = ProjectileNode(
                        MathUtils.cos(ang) * 20f, MathUtils.sin(ang) * 20f, dmg, ProjectileOwner.PLAYER,
                        Color(0f, 0.8f, 1f, 1f), 25 + lvl * 2, 12 + lvl, true, 1
                    )
                    proj.setPosition(playerNode.x, playerNode.y + playerNode.height * 0.5f)
                    entityLayer.addActor(proj)
                    projectiles.add(proj)
                }
                if (!ignoreCooldown) sk.cooldown = Math.max(50, def.baseCooldown - lvl * 10)
            }
            "shield" -> {
                val dur = 180 + lvl * 30
                sk.active = dur
                if (!ignoreCooldown) sk.cooldown = (dur * 1.5).toInt() + 60
            }
            "lightning" -> {
                val dmg = def.baseDamage + lvl * 20
                for (e in enemies) {
                    e.hp -= dmg
                    e.damageFlash = 12
                }
                screenFlash = 12
                if (!ignoreCooldown) sk.cooldown = Math.max(60, def.baseCooldown - lvl * 12)
            }
            "ghost" -> {
                val dmg = def.baseDamage + lvl * 18
                val count = (1 + lvl / 4) * 4
                for (i in 0 until count) {
                    val ang = (i.toFloat() / count - 0.5f) * 2f
                    val proj = ProjectileNode(
                        playerNode.facing * 15f + MathUtils.cos(ang) * 6f, MathUtils.sin(ang) * 10f,
                        dmg, ProjectileOwner.PLAYER, Color(0.2f, 1f, 0.53f, 1f),
                        90 + lvl * 5, 14, true, 1
                    )
                    proj.setPosition(playerNode.x, playerNode.y + playerNode.height * 0.7f + (i - count/2) * 10f)
                    entityLayer.addActor(proj)
                    projectiles.add(proj)
                }
                if (!ignoreCooldown) sk.cooldown = Math.max(60, def.baseCooldown - lvl * 12)
            }
        }
        delegate.triggerHaptic(HapticType.MEDIUM)
    }

    fun handleUltimate() {
        if (gameState != GameState.PLAYING || playerNode.energy < 100) return
        playerNode.energy = 0
        playerNode.ultActive = 240
        playerNode.iframe = 240

        val ultDmg = 500 + playerNode.weaponLevel * 100
        for (e in enemies) {
            e.hp -= ultDmg
            e.damageFlash = 20
        }
        screenFlash = 20
        delegate.triggerHaptic(HapticType.HEAVY)
    }

    private fun isOnScreen(actor: Actor): Boolean {
        val dx = Math.abs(actor.x - camera.position.x)
        val dy = Math.abs(actor.y - camera.position.y)
        return dx < Physics.gameWidth / 2 + 200 && dy < Physics.gameHeight / 2 + 200
    }

    private fun handleEnemyDeath(enemy: EnemyNode) {
        val wasBoss = enemy.isBoss
        totalKills++
        levelKills++
        combo++
        comboTimer = 150
        hitstop = if (wasBoss) 12 else 4
        playerNode.energy = Math.min(100, playerNode.energy + 4)

        spawnDrop(enemy.x, enemy.y)
        spawnExplosion(enemy.x + enemy.enemyWidth/2f, enemy.y + enemy.enemyHeight/2f, enemy.baseColor)
        delegate.triggerHaptic(if (wasBoss) HapticType.HEAVY else HapticType.MEDIUM)

        if (wasBoss) {
            bossActive = false
            Gdx.app.postRunnable {
                if (currentLevel < 10) completeLevel() else endGame(true)
            }
        }
    }

    private fun spawnDrop(x: Float, y: Float) {
        val comboBonus = combo * 0.005
        val cap = currentLevelDef.weaponCap

        val weaponProb = if (playerNode.weaponLevel >= 10) 0.01
                         else if (playerNode.weaponLevel >= cap) 0.02
                         else Math.min(0.35, 0.12 + (cap - playerNode.weaponLevel) * 0.08) * (1 - (levelKills.toDouble() / currentLevelDef.killTarget.toDouble()) * 0.3) + comboBonus
        
        val healthProb = 0.08 + Math.max(0, 100 - playerNode.hp) * 0.002 + comboBonus
        val rand = MathUtils.random()

        if (MathUtils.random() < 0.3 + comboBonus * 0.5) {
            val skill = GameConfig.skillDefs.randomOrNull()
            if (skill != null) {
                spawnDropIcon(x, y + 40, DropData.DropType.Skill(skill.id))
                return
            }
        }

        if (rand < weaponProb) {
            spawnDropIcon(x, y + 40, DropData.DropType.Weapon)
        } else if (rand < weaponProb + healthProb) {
            spawnDropIcon(x, y + 40, DropData.DropType.Health)
        }
    }

    private val dropTextureCache = mutableMapOf<String, Texture>()

    private fun getDropTexture(type: DropData.DropType): Texture {
        val key = when (type) {
            is DropData.DropType.Health -> "health"
            is DropData.DropType.Weapon -> "weapon"
            is DropData.DropType.Skill -> "skill_${type.id}"
        }
        if (dropTextureCache.containsKey(key)) return dropTextureCache[key]!!

        val dropSize = 45
        val pix = Pixmap(dropSize, dropSize, Pixmap.Format.RGBA8888)
        
        fun drawThickLine(p: Pixmap, x1: Int, y1: Int, x2: Int, y2: Int, thick: Int) {
            val half = thick / 2    
            val dx = Math.abs(x2 - x1); val dy = Math.abs(y2 - y1)
            for (off in -half..half) {
                if (dx >= dy) p.drawLine(x1, y1 + off, x2, y2 + off)
                else p.drawLine(x1 + off, y1, x2 + off, y2)
            }
        }

        when (type) {
            is DropData.DropType.Health -> {
                pix.setColor(Color.WHITE)
                pix.fillCircle(22, 22, 18)
                pix.setColor(0.82f, 0.08f, 0.08f, 1f)
                pix.fillRectangle(18, 11, 9, 23)
                pix.fillRectangle(11, 18, 23, 9)
            }
            is DropData.DropType.Weapon -> {
                pix.setColor(1.0f, 0.8f, 0.0f, 1f)
                drawThickLine(pix, 8, 36, 36, 8, 5) // main blade
                drawThickLine(pix, 12, 40, 24, 28, 4) // guard
                pix.setColor(Color.WHITE)
                pix.drawLine(8, 36, 36, 8) // highlight
            }
            is DropData.DropType.Skill -> {
                val scDef = GameConfig.skillDefs.find { it.id == type.id }?.color ?: Color.GRAY
                pix.setColor(scDef.r, scDef.g, scDef.b, 0.9f)
                pix.fillRectangle(4, 4, 37, 37)
                pix.setColor(Color.WHITE)
                drawThickLine(pix, 4, 4, 41, 4, 2)
                drawThickLine(pix, 4, 4, 4, 41, 2)
                drawThickLine(pix, 4, 41, 41, 41, 2)
                drawThickLine(pix, 41, 4, 41, 41, 2)
                pix.fillTriangle(22, 10, 14, 30, 30, 30)
                pix.fillTriangle(22, 34, 14, 14, 30, 14)
            }
        }
        val tex = Texture(pix)
        tex.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear)
        pix.dispose()
        dropTextureCache[key] = tex
        return tex
    }

    private fun spawnExplosion(cx: Float, cy: Float, color: Color) {
        for (i in 0 until 12) {
            val img = Image(whiteTex)
            img.color = color
            val size = MathUtils.random(4f, 12f)
            img.setSize(size, size)
            img.setPosition(cx - size/2, cy - size/2)
            
            val angle = MathUtils.random(MathUtils.PI2)
            val speed = MathUtils.random(50f, 200f)
            val dur = MathUtils.random(0.3f, 0.6f)
            
            val move = com.badlogic.gdx.scenes.scene2d.actions.Actions.moveBy(MathUtils.cos(angle)*speed, MathUtils.sin(angle)*speed, dur, com.badlogic.gdx.math.Interpolation.circleOut)
            val fade = com.badlogic.gdx.scenes.scene2d.actions.Actions.fadeOut(dur)
            val parallel = com.badlogic.gdx.scenes.scene2d.actions.Actions.parallel(move, fade)
            val remove = com.badlogic.gdx.scenes.scene2d.actions.Actions.removeActor()
            
            img.addAction(com.badlogic.gdx.scenes.scene2d.actions.Actions.sequence(parallel, remove))
            effectLayer.addActor(img)
        }
    }

    private fun spawnDashTrail(px: Float, py: Float, facing: Int) {
        val img = Image(whiteTex)
        img.color = Color(0f, 1f, 1f, 0.6f)
        val h = playerNode.height * 0.8f
        img.setSize(playerNode.width, h)
        img.setPosition(px + playerNode.width / 2f - img.width / 2f, py + (playerNode.height - h)/2)
        
        val fade = com.badlogic.gdx.scenes.scene2d.actions.Actions.fadeOut(0.3f)
        val remove = com.badlogic.gdx.scenes.scene2d.actions.Actions.removeActor()
        img.addAction(com.badlogic.gdx.scenes.scene2d.actions.Actions.sequence(fade, remove))
        effectLayer.addActor(img)
    }

    private fun spawnDropIcon(x: Float, y: Float, type: DropData.DropType) {
        val dropSize = 45f
        val img = Image(getDropTexture(type))
        img.setSize(dropSize, dropSize)
        img.setPosition(x, y)
        img.zIndex = 5
        if (type is DropData.DropType.Weapon) {
            val rotate = com.badlogic.gdx.scenes.scene2d.actions.Actions.rotateBy(-360f, 2f)
            img.setOrigin(dropSize/2f, dropSize/2f)
            img.addAction(com.badlogic.gdx.scenes.scene2d.actions.Actions.forever(rotate))
        }

        entityLayer.addActor(img)
        drops.add(DropData(x, y, MathUtils.random(-3f, 3f), 12f, type, 800, img))
    }

    private fun levelUpRandomSkill() {
        val id = GameConfig.skillDefs.randomOrNull()?.id ?: return
        val sk = playerNode.skills[id]
        if (sk != null && sk.level < 10) sk.level++
    }

    override fun dispose() {
        super.dispose()
        stage.dispose()
        dropTextureCache.values.forEach { it.dispose() }
        dropTextureCache.clear()
        bgTextureCache.values.forEach { it.dispose() }
        bgTextureCache.clear()
        whiteTex.dispose()
        groundWaveTex.dispose()
    }
}
