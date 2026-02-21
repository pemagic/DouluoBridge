package com.douluo.bridge

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.scenes.scene2d.Group
import com.badlogic.gdx.scenes.scene2d.ui.Image

// LibGDX translation of ProjectileTextureCache
object ProjectileTextureCache {
    private val cache = mutableMapOf<String, Texture>()

    fun texture(owner: ProjectileOwner, size: Int, color: Color): Texture {
        val cr = (color.r * 10).toInt()
        val cg = (color.g * 10).toInt()
        val cb = (color.b * 10).toInt()
        val key = "${if (owner == ProjectileOwner.PLAYER) "p" else "e"}_${size}_${cr}_${cg}_${cb}"

        // Check if cached texture is still valid (not disposed)
        cache[key]?.let { tex ->
            if (tex.textureObjectHandle != 0) return tex
            // Handle is 0 means GL context was lost - remove stale entry
            cache.remove(key)
        }

        val w = if (owner == ProjectileOwner.PLAYER) 70 else 25
        val h = size.coerceAtLeast(1)
        val padding = 30
        val texW = w + padding * 2
        val texH = h + padding * 2

        val pix = Pixmap(texW, texH, Pixmap.Format.RGBA8888)
        
        // Multi-layer simulated blur glow effect
        for (i in 8 downTo 1) {
            val alpha = 0.02f + (8 - i) * 0.03f
            pix.setColor(color.r, color.g, color.b, alpha)
            pix.fillRectangle(padding - i * 2, padding - i * 2, w + i * 4, h + i * 4)
        }
        
        // Solid Core
        pix.setColor(color)
        pix.fillRectangle(padding, padding, w, h)

        val texture = Texture(pix)
        texture.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest)
        cache[key] = texture
        pix.dispose()

        return texture
    }

    /** Call when GL context is lost (e.g. app resume / orientation change) */
    fun invalidate() {
        // Textures are already invalid after GL context loss; just clear references
        cache.clear()
    }

    /** Fully dispose all textures and clear cache */
    fun dispose() {
        cache.values.forEach { runCatching { it.dispose() } }
        cache.clear()
    }
}

enum class ProjectileOwner {
    PLAYER, ENEMY
}

class ProjectileNode(
    var vx: Float,
    var vy: Float,
    var damage: Int,
    val owner: ProjectileOwner,
    val baseColor: Color,
    var life: Int,
    val size: Int = 10,
    val homing: Boolean = false,
    val pierceCount: Int = 1
) : Group() {

    val hitEnemies = mutableSetOf<Int>()

    init {
        setupVisual()
    }

    private fun setupVisual() {
        val texture = ProjectileTextureCache.texture(owner, size, baseColor)
        val w = if (owner == ProjectileOwner.PLAYER) 70f else 25f
        val h = size.toFloat()
        val padding = 30f

        val sprite = Image(texture)
        sprite.setSize(w + padding * 2, h + padding * 2)
        sprite.setPosition(-padding - w / 2, -padding - h / 2)
        addActor(sprite)
        
        setSize(w, h)
        setOrigin(w/2, h/2)
    }

    fun update(enemies: List<EnemyNode>) {
        x += vx
        y += vy

        if (homing && owner == ProjectileOwner.PLAYER && enemies.isNotEmpty()) {
            var nearest: EnemyNode? = null
            var minDist = Float.MAX_VALUE

            for (enemy in enemies) {
                if (enemy.hp <= 0) continue
                
                val dx = enemy.x - x
                val dy = enemy.y - y
                val dist = Math.hypot(dx.toDouble(), dy.toDouble()).toFloat()
                if (dist < minDist) {
                    minDist = dist
                    nearest = enemy
                }
            }

            nearest?.let { target ->
                val dx = target.x - x
                val dy = target.y - y
                if (minDist > 0) {
                    vx += (dx / minDist) * 1.5f
                    vy += (dy / minDist) * 1.5f
                }
            }
        }

        life -= 1
        
        // Rotate to face velocity
        val angle = Math.atan2(vy.toDouble(), vx.toDouble()).toFloat()
        rotation = angle * com.badlogic.gdx.math.MathUtils.radiansToDegrees
    }
}
