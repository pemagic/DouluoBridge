package com.douluo.bridge

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.scenes.scene2d.Group
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.actions.Actions
import com.badlogic.gdx.math.MathUtils

class PlayerNode : Group() {
    var vx: Float = 0f
    var vy: Float = 0f
    
    val skills = mutableMapOf<String, SkillState>()
    private lateinit var bodyGroup: Group
    private var orbitNode: Group? = null
    private var shieldNode: Image? = null
    private var ultGlowNode: Image? = null

    // INITIALIZE BEFORE `init` BLOCK to prevent NullPointerException
    private val createdTextures = mutableListOf<Texture>()

    // Size defined in iOS is 40x64
    init {
        setSize(40f, 64f)
        setOrigin(20f, 0f)
        setScale(1.3f)
        setupSkills()
        
        bodyGroup = Group()
        addActor(bodyGroup)
        
        setupCachedEffects()
        rebuildVisual()
    }

    var hp: Int = 100
    var energy: Int = 0
    var weaponLevel: Int = 1
    var facing: Int = 1
    var grounded: Boolean = false
    var jumpCount: Int = 0
    var dashCooldown: Int = 0
    var dashActive: Int = 0
    var shootTimer: Int = 0
    var iframe: Int = 0
    var animTime: Float = 0f
    var ultActive: Int = 0

    companion object {
        val neonColors = listOf(
            Color.valueOf("ff00ff"),
            Color.valueOf("00ffff"),
            Color.valueOf("ffff00"),
            Color.valueOf("00ff00"),
            Color.valueOf("ff0000"),
            Color.valueOf("ff8800"),
            Color.valueOf("00ff88"),
            Color.valueOf("8800ff"),
            Color.WHITE
        )
    }

    private fun setupSkills() {
        for (def in GameConfig.skillDefs) {
            skills[def.id] = SkillState()
        }
    }

    private fun setupCachedEffects() {
        // Shield
        val shieldSize = 90
        val sPix = Pixmap(shieldSize, shieldSize, Pixmap.Format.RGBA8888)
        sPix.setColor(1f, 0.84f, 0f, 0.2f)
        sPix.fillCircle(shieldSize / 2, shieldSize / 2, shieldSize / 2 - 3)
        sPix.setColor(1f, 0.84f, 0f, 0.8f)
        sPix.drawCircle(shieldSize / 2, shieldSize / 2, shieldSize / 2 - 3)
        
        val shieldImg = Image(Texture(sPix))
        shieldImg.setSize(shieldSize.toFloat(), shieldSize.toFloat())
        shieldImg.setPosition(-shieldSize / 2f + width / 2f, -shieldSize / 2f + height / 2f)
        shieldImg.zIndex = 10
        shieldImg.isVisible = false
        addActor(shieldImg)
        shieldNode = shieldImg
        sPix.dispose()

        // Ult Glow
        val glowSize = 110
        val gPix = Pixmap(glowSize, glowSize, Pixmap.Format.RGBA8888)
        gPix.setColor(1f, 1f, 1f, 0.15f)
        gPix.fillCircle(glowSize / 2, glowSize / 2, glowSize / 2 - 5)
        
        val glowImg = Image(Texture(gPix))
        glowImg.setSize(glowSize.toFloat(), glowSize.toFloat())
        glowImg.setPosition(-glowSize / 2f + width / 2f, -glowSize / 2f + height / 2f)
        glowImg.zIndex = 0
        glowImg.isVisible = false
        addActor(glowImg)
        ultGlowNode = glowImg
        gPix.dispose()
    }

    fun reset() {
        vx = 0f; vy = 0f; hp = 100; energy = 0; weaponLevel = 1
        facing = 1; grounded = false; jumpCount = 0
        dashCooldown = 0; dashActive = 0; shootTimer = 0
        iframe = 0; animTime = 0f; ultActive = 0
        for (state in skills.values) {
            state.level = 0
            state.cooldown = 0
            state.active = 0
        }
        rebuildVisual()
    }

    private fun disposeVisual() {
        bodyGroup.clear()
        createdTextures.forEach { it.dispose() }
        createdTextures.clear()
    }

    fun rebuildVisual() {
        disposeVisual()
        orbitNode?.remove()
        orbitNode = null

        val lvl = weaponLevel
        val darkened = { c: Color -> Color(c).mul(0.58f) }

        // Helper: draw thick line
        fun L(pix: Pixmap, cx: Float, cy: Float, fx: Float, fy: Float, tx: Float, ty: Float, c: Color, lw: Int) {
            pix.setColor(c)
            val x1 = (cx + fx).toInt(); val y1 = (cy + fy).toInt()
            val x2 = (cx + tx).toInt(); val y2 = (cy + ty).toInt()
            val half = lw / 2
            val dx = Math.abs(x2 - x1); val dy = Math.abs(y2 - y1)
            for (off in -half..half) {
                if (dx >= dy) pix.drawLine(x1, y1 + off, x2, y2 + off)
                else pix.drawLine(x1 + off, y1, x2 + off, y2)
            }
        }

        // 1. Cape (QuadCurve Simulation)
        val cloakColor = when {
            lvl >= 10 -> darkened(neonColors[0])
            lvl >= 7 -> darkened(Color.valueOf("4c1d95"))
            lvl >= 4 -> darkened(Color.valueOf("312e81"))
            else -> darkened(Color.valueOf("222222"))
        }
        val capeW = 30f + lvl * 3f
        val capeH = 42f // from relative y=42 down to y=0
        val pixCape = Pixmap((capeW * 2).toInt(), capeH.toInt(), Pixmap.Format.RGBA8888)
        pixCape.setColor(cloakColor)
        for (i in 0 until capeH.toInt()) {
            val y = capeH - i
            val t = y / capeH
            val bx = Math.pow(1.0 - t, 2.0) * capeW + 2 * (1 - t) * t * 0.0 + t * t * capeW
            pixCape.drawLine(capeW.toInt(), i, bx.toInt(), i)
        }
        val texCape = Texture(pixCape)
        createdTextures.add(texCape)
        val capeImg = Image(texCape)
        capeImg.setSize(capeW * 2f, capeH)
        capeImg.setPosition(width / 2f - capeW, 0f)
        bodyGroup.addActor(capeImg)
        capeImg.toBack()
        pixCape.dispose()

        // 2. Torso (Rectangle)
        val torsoColor = if (lvl >= 7) darkened(Color.WHITE) else darkened(Color(0.93f, 0.93f, 0.93f, 1f))
        val pixTorso = Pixmap(20, 40, Pixmap.Format.RGBA8888)
        pixTorso.setColor(torsoColor)
        pixTorso.fillRectangle(0, 0, 20, 40)
        val texTorso = Texture(pixTorso)
        createdTextures.add(texTorso)
        val torsoImg = Image(texTorso)
        torsoImg.setSize(20f, 40f)
        // iOS center is (0, -10). In 40x64 Android, center is (20, 32). So torso center = (20, 22). Bottom = 2
        torsoImg.setPosition(width / 2f - 10f, 2f)
        bodyGroup.addActor(torsoImg)
        pixTorso.dispose()

        // 3. Hat (Triangle)
        val hatW = 25f + lvl * 1.2f
        val hatH = 15f + lvl / 1.5f
        val hatColor = if (lvl >= 7) darkened(Color.valueOf("faca23")) else darkened(Color.valueOf("454545"))
        val pixHat = Pixmap((hatW * 2).toInt(), hatH.toInt(), Pixmap.Format.RGBA8888)
        pixHat.setColor(hatColor)
        // Pixmap y is inverted: 0 is top. So base is at bottom (hatH), tip is at top (0).
        pixHat.fillTriangle(hatW.toInt(), 0, 0, hatH.toInt(), (hatW * 2).toInt(), hatH.toInt())
        val texHat = Texture(pixHat)
        createdTextures.add(texHat)
        val hatImg = Image(texHat)
        hatImg.setSize(hatW * 2f, hatH)
        // iOS hat base is at y=25 relative to center. In Android, that is y=32+25=57.
        hatImg.setPosition(width / 2f - hatW, 57f)
        bodyGroup.addActor(hatImg)
        pixHat.dispose()

        // 4. Sword
        val swordL = 35f + lvl * 2.5f
        val swordW = 3f + lvl / 2.5f
        val swordColor = when {
            lvl >= 10 -> darkened(neonColors[0])
            lvl >= 7 -> darkened(Color.valueOf("faca23"))
            else -> darkened(Color.WHITE)
        }
        val pixSword = Pixmap(swordL.toInt() + 10, 40, Pixmap.Format.RGBA8888)
        // iOS: move to (10, 0), line to (10+L, -10)
        // Translated to pixmap coordinates: start at (0, 20), drop to (L, 30)
        L(pixSword, 0f, 0f, 5f, 20f, 5f + swordL, 30f, swordColor, swordW.toInt())
        val texSword = Texture(pixSword)
        createdTextures.add(texSword)
        val swordImg = Image(texSword)
        // LibGDX start position is (20+10, 32+0) = (30, 32). Pixmap start is (5, 20). 
        // 30 - 5 = 25, 32 - 20 (inverted pixmap, so y represents top-down).
        // Let's just place the image such that the start aligns: 
        swordImg.setPosition(width / 2f + 5f, 32f - 20f)
        bodyGroup.addActor(swordImg)
        pixSword.dispose()

        // 5. Orbiting Swords (Level 10)
        if (lvl >= 10) {
            val orbit = Group()
            orbit.setPosition(width / 2f, 32f)
            
            for (i in 0 until 8) {
                val ang = i / 8f * MathUtils.PI2
                val pixOSword = Pixmap(36, 4, Pixmap.Format.RGBA8888)
                pixOSword.setColor(darkened(neonColors[i % neonColors.size]))
                pixOSword.fill()
                val texOSword = Texture(pixOSword)
                createdTextures.add(texOSword)
                val oSword = Image(texOSword)
                oSword.setPosition(MathUtils.cos(ang) * 55f - 18f, MathUtils.sin(ang) * 55f - 2f)
                oSword.setOrigin(18f, 2f)
                oSword.rotation = ang * MathUtils.radiansToDegrees + 90f
                orbit.addActor(oSword)
                pixOSword.dispose()
            }
            bodyGroup.addActor(orbit)
            orbit.toBack()
            orbitNode = orbit
            orbit.addAction(com.badlogic.gdx.scenes.scene2d.actions.Actions.forever(com.badlogic.gdx.scenes.scene2d.actions.Actions.rotateBy(360f, 1.05f)))
        }
    }

    fun updateVisual() {
        animTime += Math.abs(vx) * 0.1f + 0.1f
        
        // Flip (Scene2D scales from origin which by default is bottom-left, we center it for flip)
        setOrigin(width / 2f, height / 2f)
        scaleX = facing.toFloat()
        
        // Bob
        bodyGroup.y = MathUtils.sin(animTime) * 5f
        
        // iFrame Flash
        if (iframe > 0) {
            color.a = if (iframe % 4 < 2) 1f else 0f
        } else {
            color.a = 1f
        }
        
        // Lv10 Orbit Colors (Skipped complex color lerp per frame for perf, handled in rebuild)

        // Shield
        shieldNode?.isVisible = (skills["shield"]?.active ?: 0) > 0
        
        // Ult Glow
        ultGlowNode?.isVisible = ultActive > 0
    }
}
