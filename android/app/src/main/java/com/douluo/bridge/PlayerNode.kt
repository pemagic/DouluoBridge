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

    // Size defined in iOS is 40x64
    init {
        setSize(40f, 64f)
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

    fun rebuildVisual() {
        bodyGroup.clear()
        orbitNode?.remove()
        orbitNode = null

        val lvl = weaponLevel
        val darkened = { c: Color -> Color(c).mul(0.58f) } // approx iOS darkened(0.42)

        // 1. Cape (Simplification: Triangle in libGDX Pixmap instead of QuadCurve)
        val cloakColor = when {
            lvl >= 10 -> darkened(neonColors[0])
            lvl >= 7 -> darkened(Color.valueOf("4c1d95"))
            lvl >= 4 -> darkened(Color.valueOf("312e81"))
            else -> darkened(Color.valueOf("222222"))
        }
        val capeW = 30 + lvl * 3
        val capeH = height / 2f + 10f
        val pixCape = Pixmap(capeW.toInt() * 2, capeH.toInt() + 20, Pixmap.Format.RGBA8888)
        pixCape.setColor(cloakColor)
        pixCape.fillTriangle(
            capeW.toInt(), 0,
            0, capeH.toInt() + 10,
            capeW.toInt() * 2, capeH.toInt() + 10
        )
        val capeImg = Image(Texture(pixCape))
        capeImg.setPosition(-capeW + width / 2f, height / 2f - capeH)
        capeImg.zIndex = 0
        bodyGroup.addActor(capeImg)
        pixCape.dispose()

        // 2. Torso
        val torsoColor = if (lvl >= 7) darkened(Color.WHITE) else darkened(Color(0.93f, 0.93f, 0.93f, 1f))
        val pixTorso = Pixmap(20, 40, Pixmap.Format.RGBA8888)
        pixTorso.setColor(torsoColor)
        pixTorso.fill()
        val torsoImg = Image(Texture(pixTorso))
        torsoImg.setPosition(width / 2f - 10f, height / 2f - 20f - 10f)
        bodyGroup.addActor(torsoImg)
        pixTorso.dispose()

        // 3. Hat
        val hatW = 25f + lvl * 1.2f
        val hatH = 15f + lvl / 1.5f
        val hatColor = if (lvl >= 7) darkened(Color.valueOf("faca23")) else darkened(Color.valueOf("454545"))
        val pixHat = Pixmap((hatW * 2).toInt(), hatH.toInt(), Pixmap.Format.RGBA8888)
        pixHat.setColor(hatColor)
        pixHat.fillTriangle(hatW.toInt(), 0, 0, hatH.toInt(), (hatW * 2).toInt(), hatH.toInt())
        val hatImg = Image(Texture(pixHat))
        hatImg.setPosition(width / 2f - hatW, height / 2f + 25f)
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
        val pixSword = Pixmap(swordL.toInt(), swordW.toInt() + 4, Pixmap.Format.RGBA8888)
        pixSword.setColor(swordColor)
        pixSword.fillRectangle(0, 2, swordL.toInt(), swordW.toInt())
        val swordImg = Image(Texture(pixSword))
        swordImg.setPosition(width / 2f + 10f, height / 2f)
        swordImg.setOrigin(0f, swordW / 2f)
        swordImg.rotation = -20f
        bodyGroup.addActor(swordImg)
        pixSword.dispose()

        // 5. Orbiting Swords (Level 10)
        if (lvl >= 10) {
            val orbit = Group()
            orbit.setPosition(width / 2f, height / 2f)
            orbit.zIndex = 0
            
            for (i in 0 until 8) {
                val ang = i / 8f * MathUtils.PI2
                val pixOSword = Pixmap(36, 4, Pixmap.Format.RGBA8888)
                pixOSword.setColor(darkened(neonColors[i % neonColors.size]))
                pixOSword.fill()
                val oSword = Image(Texture(pixOSword))
                oSword.setPosition(MathUtils.cos(ang) * 55f - 18f, MathUtils.sin(ang) * 55f - 2f)
                oSword.setOrigin(18f, 2f)
                oSword.rotation = ang * MathUtils.radiansToDegrees + 90f
                orbit.addActor(oSword)
                pixOSword.dispose()
            }
            addActor(orbit)
            orbitNode = orbit
            orbit.addAction(Actions.forever(Actions.rotateBy(360f, 1.05f)))
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
