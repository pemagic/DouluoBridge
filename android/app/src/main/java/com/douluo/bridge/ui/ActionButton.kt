package com.douluo.bridge.ui

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView

class ActionButton @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    var onKeyEvent: ((String, Boolean) -> Unit)? = null
    var keyCode: String = ""
    var holdable: Boolean = false
    
    private var isPressedState = false
    private val handlerObj = Handler(Looper.getMainLooper())
    private var holdRunnable: Runnable? = null

    private val emojiLabel = TextView(context)
    private val subLabel = TextView(context)
    private val cooldownOverlay = View(context)
    private val cooldownLabel = TextView(context)
    private val lockOverlay = FrameLayout(context)

    var isLocked = false
        private set

    init {
        // Background
        val bgDrawable = GradientDrawable()
        bgDrawable.shape = GradientDrawable.RECTANGLE
        bgDrawable.cornerRadius = dpToPx(18f)
        bgDrawable.setColor(Color.argb((255 * 0.7).toInt(), 224, 214, 199))
        bgDrawable.setStroke(dpToPx(2.5f).toInt(), Color.argb((255 * 0.6).toInt(), 89, 76, 56))
        background = bgDrawable

        elevation = dpToPx(6f)

        // Emoji
        emojiLabel.gravity = Gravity.CENTER
        emojiLabel.textSize = 28f
        
        // Sublabel
        subLabel.gravity = Gravity.CENTER
        subLabel.textSize = 13f
        subLabel.setTextColor(Color.argb((255 * 0.85).toInt(), 76, 64, 46))
        subLabel.setTypeface(null, Typeface.BOLD)

        val textContainer = FrameLayout(context)
        val emojiParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        emojiParams.gravity = Gravity.CENTER
        emojiParams.topMargin = dpToPx(-6f).toInt()
        textContainer.addView(emojiLabel, emojiParams)

        val subParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        subParams.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        subParams.bottomMargin = dpToPx(4f).toInt()
        textContainer.addView(subLabel, subParams)

        addView(textContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        // Cooldown
        cooldownOverlay.setBackgroundColor(Color.argb((255 * 0.55).toInt(), 0, 0, 0))
        cooldownOverlay.visibility = View.GONE
        addView(cooldownOverlay, LayoutParams(LayoutParams.MATCH_PARENT, 0, Gravity.TOP))

        cooldownLabel.setTextColor(Color.WHITE)
        cooldownLabel.textSize = 10f
        cooldownLabel.setTypeface(null, Typeface.BOLD)
        cooldownLabel.visibility = View.GONE
        val cdLParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        cdLParams.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        cdLParams.bottomMargin = dpToPx(2f).toInt()
        addView(cooldownLabel, cdLParams)

        // Lock
        lockOverlay.setBackgroundColor(Color.argb((255 * 0.7).toInt(), 38, 38, 38))
        val lockDrawable = GradientDrawable()
        lockDrawable.cornerRadius = dpToPx(18f)
        lockDrawable.setColor(Color.argb((255 * 0.7).toInt(), 38, 38, 38))
        lockOverlay.background = lockDrawable
        lockOverlay.visibility = View.GONE

        val lockIcon = TextView(context)
        lockIcon.text = "🔒"
        lockIcon.textSize = 16f
        val lockParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        lockParams.gravity = Gravity.CENTER
        lockOverlay.addView(lockIcon, lockParams)

        addView(lockOverlay, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    fun setup(label: String, sublabel: String, color: Int, code: String, isHoldable: Boolean) {
        emojiLabel.text = label
        subLabel.text = sublabel
        keyCode = code
        holdable = isHoldable
    }

    private fun dpToPx(dp: Float): Float {
        return dp * context.resources.displayMetrics.density
    }

    fun setLocked(locked: Boolean) {
        isLocked = locked
        lockOverlay.visibility = if (locked) View.VISIBLE else View.GONE
        alpha = if (locked) 0.6f else 1.0f
    }

    fun setCooldown(ratio: Float, seconds: Double) {
        val clamped = Math.max(0f, Math.min(1f, ratio))
        if (clamped <= 0) {
            cooldownOverlay.visibility = View.GONE
            cooldownLabel.visibility = View.GONE
        } else {
            cooldownOverlay.visibility = View.VISIBLE
            cooldownLabel.visibility = View.VISIBLE
            
            val params = cooldownOverlay.layoutParams as LayoutParams
            params.height = (height * clamped).toInt()
            cooldownOverlay.layoutParams = params

            cooldownLabel.text = String.format("%.1fs", seconds)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (isLocked) return true

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                pressDown()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                pressUp()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun pressDown() {
        if (isPressedState) return
        isPressedState = true

        onKeyEvent?.invoke(keyCode, true)

        animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).start()
        (background as GradientDrawable).setColor(Color.argb((255 * 0.35).toInt(), 89, 76, 56))

        if (holdable) {
            holdRunnable = object : Runnable {
                override fun run() {
                    if (isPressedState) {
                        onKeyEvent?.invoke(keyCode, true)
                        handlerObj.postDelayed(this, 80)
                    }
                }
            }
            handlerObj.postDelayed(holdRunnable!!, 80)
        }
    }

    private fun pressUp() {
        if (!isPressedState) return
        isPressedState = false

        holdRunnable?.let { handlerObj.removeCallbacks(it) }
        holdRunnable = null

        onKeyEvent?.invoke(keyCode, false)

        animate().scaleX(1.0f).scaleY(1.0f).setDuration(150).start()
        (background as GradientDrawable).setColor(Color.argb((255 * 0.7).toInt(), 224, 214, 199))
    }
}
