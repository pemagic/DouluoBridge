package com.douluo.bridge

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.content.pm.ActivityInfo
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.backends.android.AndroidApplication
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration
import com.douluo.bridge.ui.ActionButton
import com.douluo.bridge.ui.GameScreenDelegate
import com.douluo.bridge.ui.HapticType
import com.douluo.bridge.ui.VirtualJoystick

class AndroidLauncher : AndroidApplication(), GameScreenDelegate {

    private lateinit var douluoGame: DouluoGame
    private lateinit var uiContainer: FrameLayout

    // HUD
    private lateinit var hudContainer: LinearLayout
    private lateinit var hpFill: View
    private lateinit var ultFill: View
    private lateinit var killLabel: TextView
    private lateinit var comboLabel: TextView
    private lateinit var weaponLabel: TextView
    private lateinit var levelLabel: TextView

    // Menus
    private lateinit var mainMenuView: LinearLayout
    private lateinit var gameOverView: LinearLayout
    private lateinit var pauseOverlay: FrameLayout
    private lateinit var levelBanner: FrameLayout
    private lateinit var levelBannerTitle: TextView

    // Controls
    private lateinit var joystick: VirtualJoystick
    private lateinit var attackButton: ActionButton
    private lateinit var jumpButton: ActionButton
    private lateinit var dashButton: ActionButton
    private val skillButtons = mutableListOf<ActionButton>()
    private val allControls = mutableListOf<View>()

    private var audioManager: AndroidAudioManager? = null

    private lateinit var prefs: android.content.SharedPreferences
    private var bestKills = 0
    private var bestLevel = 1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ---- Force landscape + immersive fullscreen ----
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        window.setFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Hide system bars (status bar + navigation bar) for edge-to-edge gameplay
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        // ------------------------------------------------

        prefs = getSharedPreferences("DouluoGameData", android.content.Context.MODE_PRIVATE)
        bestKills = prefs.getInt("best_kills", 0)
        bestLevel = prefs.getInt("best_level", 1)
        
        audioManager = AndroidAudioManager(this)

        val config = AndroidApplicationConfiguration()
        config.useAccelerometer = false
        config.useCompass = false
        config.useImmersiveMode = true

        douluoGame = DouluoGame(this)
        val gameView = initializeForView(douluoGame, config)

        val rootLayout = FrameLayout(this)
        rootLayout.addView(gameView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)

        uiContainer = FrameLayout(this)
        rootLayout.addView(uiContainer, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)

        setContentView(rootLayout)

        setupHUD()
        setupMainMenu()
        setupGameOver()
        setupPauseOverlay()
        setupLevelBanner()
        setupControls()

        setControlsVisible(false)

        // Show custom Splash overlay (bypasses Android 12+ static splash icon restrictions)
        val splashOverlay = android.widget.ImageView(this)
        splashOverlay.setImageResource(R.drawable.splash_img)
        splashOverlay.scaleType = android.widget.ImageView.ScaleType.CENTER_CROP
        splashOverlay.setBackgroundColor(Color.BLACK)
        rootLayout.addView(splashOverlay, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        
        splashOverlay.postDelayed({
            splashOverlay.animate()
                .alpha(0f)
                .setDuration(400)
                .withEndAction { splashOverlay.visibility = View.GONE }
        }, 1500)
    }

    override fun onDestroy() {
        super.onDestroy()
        audioManager?.release()
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, resources.displayMetrics).toInt()
    }

    private fun setupHUD() {
        hudContainer = LinearLayout(this)
        hudContainer.orientation = LinearLayout.VERTICAL
        hudContainer.visibility = View.GONE
        
        val params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        params.setMargins(dpToPx(16f), dpToPx(8f), dpToPx(16f), 0)
        uiContainer.addView(hudContainer, params)

        val topRow = LinearLayout(this)
        topRow.orientation = LinearLayout.HORIZONTAL
        
        val barsLayout = LinearLayout(this)
        barsLayout.orientation = LinearLayout.VERTICAL
        
        // HP Bar
        val hpBar = FrameLayout(this)
        hpBar.setBackgroundColor(Color.argb((255*0.8).toInt(), 25, 25, 25))
        hpFill = View(this)
        hpFill.setBackgroundColor(Color.argb(255, 216, 40, 40))
        hpBar.addView(hpFill, FrameLayout.LayoutParams(dpToPx(200f), dpToPx(12f)))
        barsLayout.addView(hpBar, LinearLayout.LayoutParams(dpToPx(200f), dpToPx(12f)))

        // Ult Bar
        val ultBar = FrameLayout(this)
        ultBar.setBackgroundColor(Color.argb((255*0.8).toInt(), 25, 25, 25))
        ultFill = View(this)
        ultFill.setBackgroundColor(Color.argb(255, 234, 178, 7))
        val ultParams = LinearLayout.LayoutParams(dpToPx(200f), dpToPx(6f))
        ultParams.topMargin = dpToPx(4f)
        ultBar.addView(ultFill, FrameLayout.LayoutParams(0, dpToPx(6f)))
        barsLayout.addView(ultBar, ultParams)

        weaponLabel = TextView(this)
        weaponLabel.setTextColor(Color.WHITE)
        weaponLabel.setTypeface(null, Typeface.BOLD)
        val wlParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        wlParams.topMargin = dpToPx(4f)
        barsLayout.addView(weaponLabel, wlParams)

        levelLabel = TextView(this)
        levelLabel.setTextColor(Color.argb(255, 76, 64, 46))
        levelLabel.setTypeface(null, Typeface.BOLD)
        barsLayout.addView(levelLabel)

        topRow.addView(barsLayout)

        comboLabel = TextView(this)
        comboLabel.setTextColor(Color.argb(255, 234, 178, 7))
        comboLabel.textSize = 24f
        comboLabel.setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
        comboLabel.visibility = View.GONE
        val comboParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        comboParams.gravity = Gravity.CENTER_HORIZONTAL
        comboLabel.gravity = Gravity.CENTER_HORIZONTAL
        topRow.addView(comboLabel, comboParams)

        killLabel = TextView(this)
        killLabel.setTextColor(Color.WHITE)
        killLabel.textSize = 14f
        killLabel.setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
        val klParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        klParams.gravity = Gravity.RIGHT
        klParams.rightMargin = dpToPx(130f) // Avoid pause and home buttons
        topRow.addView(killLabel, klParams)

        hudContainer.addView(topRow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
    }

    private fun setupMainMenu() {
        mainMenuView = LinearLayout(this)
        mainMenuView.orientation = LinearLayout.VERTICAL
        mainMenuView.gravity = Gravity.CENTER
        mainMenuView.setBackgroundColor(Color.BLACK)
        
        val versionLabel = TextView(this)
        versionLabel.text = "PIXEL WUXIA"
        versionLabel.setTextColor(Color.argb((255*0.3).toInt(), 255, 255, 255))
        versionLabel.textSize = 12f
        versionLabel.letterSpacing = 0.1f
        versionLabel.setTypeface(Typeface.MONOSPACE, Typeface.NORMAL)
        versionLabel.gravity = Gravity.CENTER
        mainMenuView.addView(versionLabel)

        val title = TextView(this)
        title.text = "斗罗大桥"
        title.setTextColor(Color.WHITE)
        title.textSize = 64f
        title.setTypeface(null, Typeface.BOLD)
        // Red glow shadow emulation
        title.setShadowLayer(15f, 0f, 0f, Color.argb(230, 219, 38, 38))
        title.gravity = Gravity.CENTER
        val titleParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        titleParams.topMargin = dpToPx(8f)
        mainMenuView.addView(title, titleParams)

        val engTitle = TextView(this)
        engTitle.text = "万剑归宗 | Ten Thousand Swords"
        engTitle.setTextColor(Color.argb(255, 240, 69, 69))
        engTitle.textSize = 16f
        engTitle.letterSpacing = 0.05f
        engTitle.setTypeface(Typeface.MONOSPACE, Typeface.NORMAL)
        engTitle.gravity = Gravity.CENTER
        val engParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        engParams.topMargin = dpToPx(8f)
        mainMenuView.addView(engTitle, engParams)

        val startBtn = TextView(this)
        startBtn.text = "杀出血路"
        startBtn.setTextColor(Color.WHITE)
        startBtn.textSize = 28f
        startBtn.setTypeface(null, Typeface.BOLD)
        startBtn.setPadding(dpToPx(48f), dpToPx(16f), dpToPx(48f), dpToPx(16f))
        
        val bg = android.graphics.drawable.GradientDrawable()
        bg.setStroke(dpToPx(3f), Color.WHITE)
        bg.setColor(Color.TRANSPARENT)
        startBtn.background = bg
        
        val btnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        btnParams.topMargin = dpToPx(32f)
        mainMenuView.addView(startBtn, btnParams)

        startBtn.setOnClickListener {
            mainMenuView.visibility = View.GONE
            Gdx.app.postRunnable {
                (douluoGame.screen as? DouluoGameScreen)?.startGame()
            }
            audioManager?.startBGM(0, 100f)
        }

        uiContainer.addView(mainMenuView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
    }

    private fun setupGameOver() {
        gameOverView = LinearLayout(this)
        gameOverView.orientation = LinearLayout.VERTICAL
        gameOverView.gravity = Gravity.CENTER
        gameOverView.setBackgroundColor(Color.argb((255*0.85).toInt(), 0, 0, 0))
        gameOverView.visibility = View.GONE
        
        val title = TextView(this)
        title.id = 100
        title.setTextColor(Color.argb(255, 219, 38, 38))
        title.textSize = 48f
        title.setTypeface(null, Typeface.BOLD)
        title.gravity = Gravity.CENTER
        gameOverView.addView(title)

        val stats = TextView(this)
        stats.id = 101
        stats.setTextColor(Color.argb((255*0.7).toInt(), 255, 255, 255))
        stats.textSize = 16f
        stats.gravity = Gravity.CENTER
        stats.setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
        val statsParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        statsParams.topMargin = dpToPx(20f)
        gameOverView.addView(stats, statsParams)

        val restartBtn = TextView(this)
        restartBtn.text = "转世再来"
        restartBtn.setTextColor(Color.argb(255, 240, 69, 69))
        restartBtn.textSize = 20f
        restartBtn.setTypeface(null, Typeface.BOLD)
        restartBtn.setPadding(dpToPx(36f), dpToPx(12f), dpToPx(36f), dpToPx(12f))
        
        val bg = android.graphics.drawable.GradientDrawable()
        bg.setStroke(dpToPx(2f), Color.argb(255, 219, 38, 38))
        bg.setColor(Color.TRANSPARENT)
        restartBtn.background = bg
        
        val btnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        btnParams.topMargin = dpToPx(20f)
        gameOverView.addView(restartBtn, btnParams)

        restartBtn.setOnClickListener {
            gameOverView.visibility = View.GONE
            Gdx.app.postRunnable {
                (douluoGame.screen as? DouluoGameScreen)?.startGame()
            }
            audioManager?.startBGM(0, 100f)
        }

        uiContainer.addView(gameOverView, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
    }

    private fun setupPauseOverlay() {
        pauseOverlay = FrameLayout(this)
        pauseOverlay.setBackgroundColor(Color.argb((255*0.6).toInt(), 0, 0, 0))
        pauseOverlay.visibility = View.GONE

        val label = TextView(this)
        label.text = "暂 停"
        label.setTextColor(Color.argb(255, 191, 176, 143))
        label.textSize = 56f
        label.setTypeface(null, Typeface.BOLD)
        val params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        params.gravity = Gravity.CENTER
        pauseOverlay.addView(label, params)

        pauseOverlay.setOnClickListener {
            Gdx.app.postRunnable {
                (douluoGame.screen as? DouluoGameScreen)?.resumeGame()
            }
        }

        uiContainer.addView(pauseOverlay, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
    }

    private fun setupLevelBanner() {
        levelBanner = FrameLayout(this)
        levelBanner.setBackgroundColor(Color.argb((255*0.6).toInt(), 0, 0, 0))
        val bg = android.graphics.drawable.GradientDrawable()
        bg.setColor(Color.argb((255*0.6).toInt(), 0, 0, 0))
        bg.cornerRadius = dpToPx(12f).toFloat()
        levelBanner.background = bg
        levelBanner.visibility = View.GONE

        levelBannerTitle = TextView(this)
        levelBannerTitle.setTextColor(Color.argb(255, 242, 229, 204))
        levelBannerTitle.textSize = 24f
        levelBannerTitle.setTypeface(null, Typeface.BOLD)
        val txtParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        txtParams.gravity = Gravity.CENTER
        levelBanner.addView(levelBannerTitle, txtParams)

        val params = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dpToPx(60f))
        params.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        params.topMargin = dpToPx(10f)
        levelBanner.setPadding(dpToPx(20f), 0, dpToPx(20f), 0)
        uiContainer.addView(levelBanner, params)
    }

    private fun setupControls() {
        val safeBottom = dpToPx(20f)
        val bigSize = dpToPx(78f)
        val skillSize = dpToPx(48f)
        val gap = dpToPx(4f)

        joystick = VirtualJoystick(this)
        val joyParams = FrameLayout.LayoutParams(dpToPx(140f), dpToPx(140f))
        joyParams.gravity = Gravity.BOTTOM or Gravity.LEFT
        joyParams.leftMargin = dpToPx(20f)
        joyParams.bottomMargin = safeBottom
        uiContainer.addView(joystick, joyParams)
        allControls.add(joystick)

        joystick.onDirectionChange = { dir ->
            // Input state is read on the GL thread — post to avoid race conditions
            Gdx.app.postRunnable {
                val screen = douluoGame.screen as? DouluoGameScreen
                if (screen != null) {
                    when (dir) {
                        VirtualJoystick.Direction.LEFT -> { screen.inputLeft = true; screen.inputRight = false }
                        VirtualJoystick.Direction.RIGHT -> { screen.inputLeft = false; screen.inputRight = true }
                        VirtualJoystick.Direction.NONE -> { screen.inputLeft = false; screen.inputRight = false }
                    }
                }
            }
        }

        attackButton = ActionButton(this)
        attackButton.setup("🏹", "攻", Color.argb(255, 165, 51, 38), "attack", true)
        val atkParams = FrameLayout.LayoutParams(bigSize, bigSize)
        atkParams.gravity = Gravity.BOTTOM or Gravity.RIGHT
        atkParams.rightMargin = dpToPx(20f)
        atkParams.bottomMargin = safeBottom
        uiContainer.addView(attackButton, atkParams)
        allControls.add(attackButton)

        attackButton.onKeyEvent = { _, pressed ->
            // MUST run on GL thread: handleAttack() creates GL Textures via ProjectileTextureCache
            if (pressed) Gdx.app.postRunnable {
                (douluoGame.screen as? DouluoGameScreen)?.handleAttack()
            }
        }

        jumpButton = ActionButton(this)
        jumpButton.setup("⬆", "跳", Color.argb(255, 51, 127, 165), "jump", false)
        val jmpParams = FrameLayout.LayoutParams(bigSize, bigSize)
        jmpParams.gravity = Gravity.BOTTOM or Gravity.RIGHT
        jmpParams.rightMargin = dpToPx(20f)
        jmpParams.bottomMargin = safeBottom + bigSize + gap
        uiContainer.addView(jumpButton, jmpParams)
        allControls.add(jumpButton)

        jumpButton.onKeyEvent = { _, pressed ->
            if (pressed) Gdx.app.postRunnable {
                (douluoGame.screen as? DouluoGameScreen)?.handleJump()
            }
        }

        dashButton = ActionButton(this)
        dashButton.setup("🗡", "杀", Color.argb(255, 102, 71, 38), "dash", false)
        val dashParams = FrameLayout.LayoutParams(skillSize, skillSize)
        dashParams.gravity = Gravity.BOTTOM or Gravity.RIGHT
        dashParams.rightMargin = dpToPx(20f) + bigSize + gap
        dashParams.bottomMargin = safeBottom + (bigSize - skillSize)/2
        uiContainer.addView(dashButton, dashParams)
        allControls.add(dashButton)

        dashButton.onKeyEvent = { _, pressed ->
            if (pressed) Gdx.app.postRunnable {
                (douluoGame.screen as? DouluoGameScreen)?.handleDash()
            }
        }

        fun makeSkillBtn(emoji: String, name: String, color: Int, id: String, rightMarginPx: Int, bottomMarginPx: Int): ActionButton {
            val btn = ActionButton(this)
            btn.setup(emoji, name, color, id, false)
            btn.setLocked(true)
            val p = FrameLayout.LayoutParams(skillSize, skillSize)
            p.gravity = Gravity.BOTTOM or Gravity.RIGHT
            p.rightMargin = rightMarginPx
            p.bottomMargin = bottomMarginPx
            uiContainer.addView(btn, p)
            allControls.add(btn)
            btn.onKeyEvent = { code, pressed ->
                if (pressed) Gdx.app.postRunnable {
                    (douluoGame.screen as? DouluoGameScreen)?.handleSkill(code)
                }
            }
            return btn
        }

        val rMarginCol2 = dpToPx(20f) + bigSize + gap * 2 + skillSize
        val rMarginCol3 = dpToPx(20f) + bigSize + gap * 3 + skillSize * 2
        
        val bMarginRow1 = safeBottom + (bigSize - skillSize)/2
        val bMarginRow2 = safeBottom + bigSize + gap + (bigSize - skillSize)/2

        skillButtons.add(makeSkillBtn("🔥", "火", Color.argb(255, 255, 69, 0), "fire", rMarginCol2, bMarginRow1))
        skillButtons.add(makeSkillBtn("🌀", "风", Color.argb(255, 0, 204, 255), "whirlwind", dpToPx(20f) + bigSize + gap, bMarginRow2))
        skillButtons.add(makeSkillBtn("🛡", "盾", Color.argb(255, 255, 204, 0), "shield", rMarginCol2, bMarginRow2))
        skillButtons.add(makeSkillBtn("⚡", "雷", Color.argb(255, 171, 102, 255), "lightning", rMarginCol3, bMarginRow2))
        skillButtons.add(makeSkillBtn("💀", "魂", Color.argb(255, 51, 255, 135), "ghost", rMarginCol3, bMarginRow1))

        // Home and Pause top right
        val homeBtn = TextView(this)
        homeBtn.text = "🏠"
        homeBtn.textSize = 24f
        homeBtn.gravity = Gravity.CENTER
        val hmParams = FrameLayout.LayoutParams(dpToPx(40f), dpToPx(40f))
        hmParams.gravity = Gravity.TOP or Gravity.RIGHT
        hmParams.topMargin = dpToPx(8f)
        hmParams.rightMargin = dpToPx(16f)
        uiContainer.addView(homeBtn, hmParams)
        allControls.add(homeBtn)
        homeBtn.setOnClickListener {
            (douluoGame.screen as? DouluoGameScreen)?.gameState = GameState.MENU
            audioManager?.stopBGM()
            setControlsVisible(false)
            mainMenuView.visibility = View.VISIBLE
            gameOverView.visibility = View.GONE
            pauseOverlay.visibility = View.GONE
            hudContainer.visibility = View.GONE
        }

        val pauseBtn = TextView(this)
        pauseBtn.text = "⏸"
        pauseBtn.textSize = 24f
        pauseBtn.gravity = Gravity.CENTER
        val psParams = FrameLayout.LayoutParams(dpToPx(40f), dpToPx(40f))
        psParams.gravity = Gravity.TOP or Gravity.RIGHT
        psParams.topMargin = dpToPx(8f)
        psParams.rightMargin = dpToPx(16f) + dpToPx(40f) + dpToPx(8f)
        uiContainer.addView(pauseBtn, psParams)
        allControls.add(pauseBtn)
        pauseBtn.setOnClickListener {
            (douluoGame.screen as? DouluoGameScreen)?.pauseGame()
        }
    }

    private fun setControlsVisible(visible: Boolean) {
        val vis = if (visible) View.VISIBLE else View.GONE
        allControls.forEach { it.visibility = vis }
    }

    override fun gameStateChanged(state: GameState) {
        runOnUiThread {
            when (state) {
                GameState.MENU -> {
                    mainMenuView.visibility = View.VISIBLE
                    hudContainer.visibility = View.GONE
                    gameOverView.visibility = View.GONE
                    pauseOverlay.visibility = View.GONE
                    setControlsVisible(false)
                }
                GameState.PLAYING -> {
                    mainMenuView.visibility = View.GONE
                    hudContainer.visibility = View.VISIBLE
                    gameOverView.visibility = View.GONE
                    pauseOverlay.visibility = View.GONE
                    levelBanner.visibility = View.GONE
                    setControlsVisible(true)
                }
                GameState.PAUSED -> {
                    pauseOverlay.visibility = View.VISIBLE
                }
                GameState.GAME_OVER -> {
                    setControlsVisible(false)
                }
                GameState.LEVEL_TRANSITION -> {}
            }
        }
    }

    override fun updateHUD(hp: Float, maxHp: Int, energy: Int, kills: Int, combo: Int, weaponLevel: Int, level: Int) {
        runOnUiThread {
            val hpRatio = hp / maxHp
            var lp = hpFill.layoutParams
            lp.width = (dpToPx(200f) * Math.max(0f, Math.min(1f, hpRatio))).toInt()
            hpFill.layoutParams = lp

            val ultRatio = energy / 100f
            var up = ultFill.layoutParams
            up.width = (dpToPx(200f) * Math.max(0f, Math.min(1f, ultRatio))).toInt()
            ultFill.layoutParams = up

            killLabel.text = "KILLS: $kills"
            
            if (combo > 1) {
                comboLabel.text = "$combo COMBO!"
                comboLabel.visibility = View.VISIBLE
            } else {
                comboLabel.visibility = View.GONE
            }

            val wIdx = Math.max(0, Math.min(weaponLevel - 1, GameConfig.weaponNames.size - 1))
            weaponLabel.text = "${GameConfig.weaponNames[wIdx]} Lv.$weaponLevel"
            levelLabel.text = GameConfig.levels[Math.max(0, Math.min(level - 1, 9))].name

            val screen = douluoGame.screen as? DouluoGameScreen ?: return@runOnUiThread
            val player = screen.playerNode

            for (i in skillButtons.indices) {
                if (i < GameConfig.skillDefs.size) {
                    val def = GameConfig.skillDefs[i]
                    val sk = player.skills[def.id]
                    skillButtons[i].setLocked(sk == null || sk.level <= 0)
                    if (sk != null && sk.level > 0) {
                        skillButtons[i].setCooldown(sk.cooldown.toFloat() / def.baseCooldown.toFloat(), sk.cooldown / 60.0)
                    }
                }
            }

            val dashCd = player.dashCooldown.toFloat()
            dashButton.setCooldown(dashCd / 35f, dashCd / 60.0)
        }
    }

    override fun showLevelBanner(name: String, updateBGM: Boolean) {
        runOnUiThread {
            if (updateBGM) {
                val screen = douluoGame.screen as? DouluoGameScreen
                if (screen != null) {
                    val songId = screen.currentLevel - 1
                    val bpmTable = listOf(110f, 105f, 140f, 135f, 115f, 145f, 138f, 90f, 80f, 100f)
                    val bpm = bpmTable[Math.min(songId, bpmTable.size - 1)]
                    audioManager?.changeSong(songId, bpm)
                }
            }

            levelBannerTitle.text = name
            levelBanner.visibility = View.VISIBLE
            levelBanner.alpha = 0f
            levelBanner.translationY = -dpToPx(50f).toFloat()

            levelBanner.animate().alpha(1f).translationY(0f).setDuration(400).withEndAction {
                levelBanner.animate().alpha(0f).translationY(-dpToPx(50f).toFloat()).setDuration(400).setStartDelay(2000).withEndAction {
                    levelBanner.visibility = View.GONE
                }.start()
            }.start()
        }
    }

    override fun gameEnded(kills: Int, time: Int, level: Int, victory: Boolean) {
        runOnUiThread {
            audioManager?.stopBGM()
            
            var newRecord = false
            if (kills > bestKills) {
                bestKills = kills
                prefs.edit().putInt("best_kills", bestKills).apply()
                newRecord = true
            }
            if (level > bestLevel) {
                bestLevel = level
                prefs.edit().putInt("best_level", bestLevel).apply()
                newRecord = true
            }

            // Update main menu text for next run dynamically
            if (mainMenuView.childCount > 1) {
                (mainMenuView.getChildAt(1) as? TextView)?.text = "最高层数: 第 $bestLevel 关  |  累计击杀: $bestKills"
            }
            
            val title = gameOverView.findViewById<TextView>(100)
            title?.text = if (victory) "剑神归位" else "气尽人亡"

            val stats = gameOverView.findViewById<TextView>(101)
            val timeStr = String.format("%d:%02d", time / 3600, (time / 60) % 60)
            stats?.text = "击杀: $kills  |  时间: $timeStr  |  到达: 第${level}关"

            gameOverView.visibility = View.VISIBLE
        }
    }

    override fun triggerHaptic(type: HapticType) {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
        if (vibrator != null && vibrator.hasVibrator()) {
            val millis = when (type) {
                HapticType.LIGHT -> 10L
                HapticType.MEDIUM -> 30L
                HapticType.HEAVY -> 60L
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(millis, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(millis)
            }
        }
    }
}
