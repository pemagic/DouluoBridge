package com.douluo.bridge

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.scenes.scene2d.Group
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.math.MathUtils
import com.badlogic.gdx.scenes.scene2d.Actor

// In LibGDX, we just use a static Map for caching generated Textures.
object EnemyFrameCache {
    val frames = mutableMapOf<String, Array<Texture>>()
    const val frameCount = 6

    /** Call on GL context loss so stale GPU textures are not reused */
    fun invalidate() {
        frames.clear()
    }

    /** Dispose all textures and clear cache */
    fun dispose() {
        frames.values.forEach { arr ->
            arr.forEach { runCatching { it.dispose() } }
        }
        frames.clear()
    }
}

data class PlatformData(
    val x: Float, val y: Float, val width: Float, val height: Float,
    val color: Color, val isGround: Boolean
)

class EnemyNode(
    val enemyType: EnemyType,
    val playerWeaponLevel: Int,
    val isBoss: Boolean = false,
    bossHp: Int = 0,
    bossSpeed: Float = 0f,
    val baseColor: Color,
    val enemyTier: Int = 1,
    val bossType: BossType? = null,
    hpMultiplier: Float = 1.0f
) : Group() {

    var vx: Float = 0f
    var vy: Float = 0f
    var hp: Float
    var maxHp: Float
    var baseSpeed: Float
    var enemyWidth: Float
    var enemyHeight: Float
    var grounded: Boolean = false
    var shootTimer: Float = 0f
    var damageFlash: Int = 0
    var animPhase: Float = MathUtils.random(MathUtils.PI2)
    var aimTimer: Int = 0
    var damage: Int = 12
    var martialCombo: Int = 0
    var martialTimer: Int = 0
    var rageMode: Boolean = false

    private val stickSprite: Image
    private var hpFill: Image? = null
    
    private var lastFrameIndex: Int = -1
    private var lastFlashState: Boolean = false
    private var normalFrames: Array<Texture> = emptyArray()
    private var flashFrames: Array<Texture> = emptyArray()
    private var martialNormalFrames = mutableListOf<Array<Texture>>()
    private var martialFlashFrames = mutableListOf<Array<Texture>>()

    private val texW get() = enemyWidth + 80f
    private val texH get() = enemyHeight + 60f

    init {
        if (isBoss) {
            this.hp = bossHp * hpMultiplier
            this.maxHp = this.hp
            this.baseSpeed = bossSpeed * 3
            this.damage = 15
            this.enemyWidth = 120f   // v1.9: Boss bigger
            this.enemyHeight = 150f  // v1.9: Boss bigger
        } else {
            val lvlBonus = (playerWeaponLevel - 1) * 0.15f
            val baseHp = if (enemyType == EnemyType.HEAVY) 450f else 120f
            this.hp = baseHp * (1 + lvlBonus) * hpMultiplier
            this.maxHp = this.hp
            val rawSpeed = 8f + MathUtils.random(6f)
            val typeMult = when (enemyType) {
                EnemyType.CHASER -> 1.8f
                EnemyType.HEAVY -> 0.4f
                else -> 0.7f
            }
            this.baseSpeed = rawSpeed * typeMult
            this.enemyWidth = if (enemyType == EnemyType.HEAVY) 80f else 50f
            this.enemyHeight = if (enemyType == EnemyType.HEAVY) 90f else 70f
            this.shootTimer = 40f + MathUtils.random(60f)
            this.damage = 12
        }

        setSize(enemyWidth, enemyHeight)
        setOrigin(enemyWidth / 2f, 0f)
        setScale(1.3f)

        stickSprite = Image()
        addActor(stickSprite)

        if (isBoss) {
            val barW = enemyWidth + 20f
            
            val bgPix = Pixmap(barW.toInt(), 6, Pixmap.Format.RGBA8888)
            bgPix.setColor(0.15f, 0.15f, 0.15f, 1f)
            bgPix.fill()
            val bg = Image(Texture(bgPix))
            bg.setSize(barW, 6f)
            bg.setPosition((enemyWidth - barW)/2, enemyHeight + 10f)
            bg.zIndex = 10
            addActor(bg)
            bgPix.dispose()

            val fillPix = Pixmap((barW - 2).toInt(), 4, Pixmap.Format.RGBA8888)
            fillPix.setColor(0.8f, 0.1f, 0.1f, 1f)
            fillPix.fill()
            hpFill = Image(Texture(fillPix))
            hpFill!!.setSize(barW - 2, 4f)
            hpFill!!.setPosition((enemyWidth - barW)/2 + 1, enemyHeight + 11f)
            hpFill!!.setOrigin(0f, 2f)
            hpFill!!.zIndex = 11
            addActor(hpFill)
            fillPix.dispose()
        }

        prepareFrames()
        updateTexture()
    }

    private fun cacheKey(flash: Boolean, combo: Int = 0): String {
        val btStr = bossType?.name ?: "x"
        return "${enemyType}_${enemyTier}_${isBoss}_${btStr}_${flash}_${combo}_${enemyWidth.toInt()}"
    }

    private fun prepareFrames() {
        val fc = EnemyFrameCache.frameCount

        if (enemyType == EnemyType.MARTIAL && !isBoss) {
            for (combo in 0 until 4) {
                val nKey = cacheKey(false, combo)
                val fKey = cacheKey(true, combo)
                val cachedN = EnemyFrameCache.frames[nKey]
                val cachedF = EnemyFrameCache.frames[fKey]
                
                if (cachedN != null && cachedF != null) {
                    martialNormalFrames.add(cachedN)
                    martialFlashFrames.add(cachedF)
                } else {
                    val nf = Array<Texture>(fc) { i ->
                        val phase = i.toFloat() / fc * MathUtils.PI2
                        renderFrame(phase, false, combo)
                    }
                    val ff = Array<Texture>(fc) { i ->
                        val phase = i.toFloat() / fc * MathUtils.PI2
                        renderFrame(phase, true, combo)
                    }
                    EnemyFrameCache.frames[nKey] = nf
                    EnemyFrameCache.frames[fKey] = ff
                    martialNormalFrames.add(nf)
                    martialFlashFrames.add(ff)
                }
            }
        } else {
            val nKey = cacheKey(false)
            val fKey = cacheKey(true)
            val cachedN = EnemyFrameCache.frames[nKey]
            val cachedF = EnemyFrameCache.frames[fKey]

            if (cachedN != null && cachedF != null) {
                normalFrames = cachedN
                flashFrames = cachedF
            } else {
                normalFrames = Array(fc) { i ->
                    renderFrame(i.toFloat() / fc * MathUtils.PI2, false, 0)
                }
                flashFrames = Array(fc) { i ->
                    renderFrame(i.toFloat() / fc * MathUtils.PI2, true, 0)
                }
                EnemyFrameCache.frames[nKey] = normalFrames
                EnemyFrameCache.frames[fKey] = flashFrames
            }
        }
    }

    private fun updateTexture() {
        val fc = EnemyFrameCache.frameCount
        val frameIndex = (Math.abs(animPhase / MathUtils.PI2 * fc).toInt()) % fc
        val isFlash = damageFlash > 0
        
        if (frameIndex == lastFrameIndex && isFlash == lastFlashState) return
        lastFrameIndex = frameIndex
        lastFlashState = isFlash

        val frames = if (enemyType == EnemyType.MARTIAL && !isBoss) {
            val c = Math.min(martialCombo, 3)
            if (isFlash) martialFlashFrames[c] else martialNormalFrames[c]
        } else {
            if (isFlash) flashFrames else normalFrames
        }

        if (frameIndex < frames.size) {
            val tex = frames[frameIndex]
            stickSprite.drawable = com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable(tex)
            stickSprite.setSize(texW, texH)
            stickSprite.setPosition(-40f, -30f) // Center based on texW/texH padding
        }
    }

    // Translate iOS CGContext stick-figure drawing to Pixmap.drawLine
    // iOS coordinate system: origin bottom-left, y up → Pixmap: origin top-left, y down
    // iOS: move(cx + fx, cy - fy) → Pixmap: (cx + fx, cy + fy)
    private fun renderFrame(phase: Float, flash: Boolean, combo: Int): Texture {
        val drawColor = if (flash) Color.WHITE else baseColor
        val lineW = if (isBoss) 6 else if (enemyType == EnemyType.HEAVY) 8 else 4
        val w = texW.toInt()
        val h = texH.toInt()
        val pix = Pixmap(w, h, Pixmap.Format.RGBA8888)
        val cx = w / 2
        val cy = h / 2
        val eH = enemyHeight

        // Helper: draw line with given color and width (simulated by offset lines)
        fun L(fx: Float, fy: Float, tx: Float, ty: Float, c: Color = drawColor, lw: Int = lineW) {
            pix.setColor(c)
            val x1 = (cx + fx).toInt(); val y1 = (cy + fy).toInt()
            val x2 = (cx + tx).toInt(); val y2 = (cy + ty).toInt()
            val half = lw / 2
            // Determine if line is more horizontal or vertical for offset direction
            val dx = Math.abs(x2 - x1); val dy = Math.abs(y2 - y1)
            for (off in -half..half) {
                if (dx >= dy) pix.drawLine(x1, y1 + off, x2, y2 + off)
                else pix.drawLine(x1 + off, y1, x2 + off, y2)
            }
        }
        // Helper: filled rect
        fun R(rx: Float, ry: Float, rw: Float, rh: Float, c: Color = drawColor) {
            pix.setColor(c)
            pix.fillRectangle((cx + rx - rw/2).toInt(), (cy + ry - rh/2).toInt(), rw.toInt(), rh.toInt())
        }
        // Helper: stroked rect (outline only, lineW)
        fun RS(rx: Float, ry: Float, rw: Float, rh: Float, c: Color = drawColor) {
            pix.setColor(c)
            val left = (cx + rx - rw/2).toInt(); val top = (cy + ry - rh/2).toInt()
            val right = left + rw.toInt(); val bot = top + rh.toInt()
            for (off in 0..lineW) {
                pix.drawLine(left, top + off, right, top + off)
                pix.drawLine(left, bot - off, right, bot - off)
                pix.drawLine(left + off, top, left + off, bot)
                pix.drawLine(right - off, top, right - off, bot)
            }
        }
        // Helper: filled circle
        fun C(rx: Float, ry: Float, r: Float, c: Color = drawColor) {
            pix.setColor(c)
            pix.fillCircle((cx + rx).toInt(), (cy + ry).toInt(), r.toInt())
        }

        val t = phase
        val hs = Math.sin(t.toDouble()).toFloat() * 20f
        val ls = Math.cos(t.toDouble()).toFloat() * 20f

        when {
            isBoss -> {
                // Boss: body square outline, spine, arm swing
                RS(0f, -eH/2+14f, 28f, 28f)
                L(0f, -eH/2+28f, 0f, 10f)
                val bhs = Math.sin(t.toDouble()).toFloat() * 15f
                L(0f, 10f, 18f, 30f + Math.cos(t.toDouble()).toFloat()*10f)
                L(0f, 10f, -18f, 30f - Math.cos(t.toDouble()).toFloat()*10f)
                // Boss type specific
                val bossHs = bhs
                when (bossType?.name) {
                    "banditChief" -> {
                        R(0f, -eH/2-3f, 40f, 6f)
                        L(0f, -5f, 30f, -bossHs)
                        L(30f, -bossHs, 40f, -bossHs+5f, drawColor, 8)
                    }
                    "wolfKing" -> {
                        L(-10f, -eH/2, -15f, -eH/2-15f); L(-15f, -eH/2-15f, -5f, -eH/2)
                        L(10f, -eH/2, 15f, -eH/2-15f); L(15f, -eH/2-15f, 5f, -eH/2)
                        L(0f, -5f, 20f, -bossHs); L(0f, -5f, -20f, bossHs)
                    }
                    "ironFist" -> {
                        R(0f, -eH/2+2f, 36f, 5f, Color(1f, 0.27f, 0f, 1f))
                        L(0f, -5f, 25f, -bossHs, drawColor, 10); R(28f, -bossHs, 16f, 16f)
                        L(0f, -5f, -25f, bossHs, drawColor, 10); R(-28f, bossHs, 16f, 16f)
                    }
                    "thunderMonk" -> {
                        C(0f, -eH/2+14f, 14f)
                        val bc = Color(1f, 0.8f, 0f, 1f)
                        for (b in 0 until 8) {
                            val a = b * Math.PI / 4
                            C((Math.cos(a)*12).toFloat(), (Math.sin(a)*12).toFloat() - eH/2 + 14f, 3f, bc)
                        }
                        L(0f, -5f, 15f, -bossHs); L(0f, -5f, -15f, bossHs)
                    }
                    else -> {
                        L(0f, -5f, 20f, -bossHs); L(0f, -5f, -20f, bossHs)
                    }
                }
            }
            enemyType == EnemyType.MARTIAL -> {
                // Martial: outfit hat, body line, combo-dependent arm poses
                RS(0f, -eH/2+10f, 20f, 20f)
                val bandColor = when (enemyTier) {
                    3 -> Color(0.8f, 0f, 0f, 1f)
                    2 -> Color(0.27f, 0.53f, 0.8f, 1f)
                    else -> Color(1f, 0.27f, 0.27f, 1f)
                }
                R(0f, -eH/2f, 28f, 4f, bandColor)
                L(0f, -eH/2+20f, 0f, 5f)
                when (combo) {
                    0 -> {
                        L(0f, -10f, 25f, -15f); L(0f, -10f, -15f, 0f)
                        L(0f, 5f, 20f, 25f); L(0f, 5f, -20f, 25f)
                    }
                    1 -> {
                        L(0f, -10f, -10f, -25f); L(0f, -10f, -20f, 5f)
                        L(0f, 5f, 35f, 5f); L(0f, 5f, -10f, 30f)
                    }
                    2 -> {
                        val sw = Math.sin(t.toDouble() * 3).toFloat() * 30f
                        L(0f, -10f, 10f+sw, -20f); L(0f, -10f, -10f-sw, -20f)
                        L(0f, 5f, 25f+sw, 20f); L(0f, 5f, -25f-sw, 20f)
                    }
                    else -> {
                        L(0f, -10f, 5f, -35f); L(0f, -10f, 20f, -5f)
                        L(0f, 5f, 10f, 30f); L(0f, 5f, -10f, 30f)
                        val kc = if (enemyTier == 3) Color(0.8f, 0f, 0f, 1f) else Color(1f, 0.65f, 0f, 1f)
                        C(5f, -30f, 8f, kc)
                    }
                }
            }
            else -> {
                // Normal enemies: head square, spine, swinging arms/legs, tier decorations
                RS(0f, -eH/2+10f, 20f, 20f)
                L(0f, -eH/2+20f, 0f, 5f)
                // Arms: side-to-side swing
                L(0f, -10f, 15f, -hs); L(0f, -10f, -15f, hs)
                // Legs: cos swing
                L(0f, 5f, 15f, 25f + ls); L(0f, 5f, -15f, 25f - ls)

                // Type extras
                if (enemyType == EnemyType.SCOUT) R(25f, -hs+5f, 20f, 5f) // crossbow
                if (enemyType == EnemyType.HEAVY) RS(18f, 5f, 15f, 50f) // shield

                // Tier decorations
                when {
                    enemyTier == 1 -> R(0f, -eH/2-1.5f, 28f, 3f, drawColor.cpy().mul(1f,1f,1f,0.4f))
                    enemyTier == 2 -> {
                        R(0f, -eH/2-2.5f, 24f, 5f); R(0f, -eH/2-9f, 3f, 8f)
                        R(-15f, -10f, 6f, 6f); R(15f, -10f, 6f, 6f)
                    }
                    enemyTier >= 3 -> {
                        R(0f, -eH/2-3f, 28f, 6f); R(0f, -eH/2-11f, 4f, 10f)
                        R(-17f, -12f, 10f, 8f); R(17f, -12f, 10f, 8f)
                        R(-4f, -eH/2+5f, 4f, 3f, Color.RED); R(4f, -eH/2+5f, 4f, 3f, Color.RED)
                    }
                }
            }
        }

        val tex = Texture(pix)
        tex.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear)
        pix.dispose()
        return tex
    }


    fun update(playerPosition: Float, platforms: List<PlatformData>) {
        animPhase += 0.15f
        if (damageFlash > 0) damageFlash -= 1

        val dist = playerPosition - x // comparing X coords
        val dir = if (dist > 0) 1f else -1f

        when (enemyType) {
            EnemyType.CHASER -> vx += (dir * baseSpeed - vx) * 0.12f
            EnemyType.SNIPER -> {
                if (Math.abs(dist) < 500) vx += (-dir * baseSpeed - vx) * 0.1f
                else if (Math.abs(dist) > 700) vx += (dir * baseSpeed - vx) * 0.1f
                aimTimer += 1
            }
            else -> vx += (dir * baseSpeed - vx) * 0.1f
        }

        if (isBoss && !rageMode && hp < maxHp / 2) {
            rageMode = true
            baseSpeed *= 1.5f
        }

        vy -= Physics.gravity
        x += vx
        y += vy

        grounded = false
        for (plat in platforms) {
            val platTop = plat.y + plat.height
            val eb = y
            if (x + enemyWidth / 2 > plat.x && x - enemyWidth / 2 < plat.x + plat.width &&
                eb < platTop && eb > plat.y - 20 && vy < 0
            ) {
                y = platTop
                vy = 0f
                grounded = true
            }
        }

        if (grounded && MathUtils.randomBoolean(0.01f)) {
            vy = MathUtils.random(12f, 18f)
        }
        if (enemyType != EnemyType.CHASER && enemyType != EnemyType.SNIPER) {
            shootTimer -= 1
        }
        
        hpFill?.scaleX = Math.max(0f, hp / maxHp)

        // Scaling stickSprite for facing dir
        stickSprite.setOrigin(texW/2, texH/2)
        stickSprite.scaleX = if (playerPosition > x) 1f else -1f
        stickSprite.y = MathUtils.sin(animPhase) * 6f - 30f // Offset bounce

        updateTexture()
    }
}
