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

        cache[key]?.let { return it }

        val w = if (owner == ProjectileOwner.PLAYER) 70 else 25
        val h = size
        val padding = 30
        val texW = w + padding * 2
        val texH = h + padding * 2

        val pix = Pixmap(texW, texH, Pixmap.Format.RGBA8888)
        
        // Glow effect (simplified for Pixmap)
        pix.setColor(Color(color).apply { a = 0.3f })
        pix.fillRectangle(padding - 5, padding - 5, w + 10, h + 10)
        
        // Core
        pix.setColor(color)
        pix.fillRectangle(padding, padding, w, h)

        val texture = Texture(pix)
        texture.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest)
        cache[key] = texture
        pix.dispose()

        return texture
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
    val color: Color,
    var life: Int,
    val size: Int = 10,
    val homing: Boolean = false,
    val pierceCount: Int = 1
) : Group() {

    val hitEnemies = mutableSetOf<Int>() // Using System.identityHashCode or similar if needed, or just keep track by Enemy object ref. We'll use object ref hashcode.

    init {
        setupVisual()
    }

    private fun setupVisual() {
        val texture = ProjectileTextureCache.texture(owner, size, color)
        val w = if (owner == ProjectileOwner.PLAYER) 70f else 25f
        val h = size.toFloat()
        val padding = 30f

        val sprite = Image(texture)
        sprite.setSize(w + padding * 2, h + padding * 2)
        sprite.setPosition(-padding - w / 2, -padding - h / 2) // Center the actual core at 0,0
        addActor(sprite)
        
        // Setting Group size to the core size for easier reasoning
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
                // Avoid homing onto dead enemies if hp <= 0
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
