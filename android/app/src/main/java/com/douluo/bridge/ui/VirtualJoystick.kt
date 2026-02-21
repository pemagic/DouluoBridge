package com.douluo.bridge.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

class VirtualJoystick @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    enum class Direction { LEFT, RIGHT, NONE }

    var onDirectionChange: ((Direction) -> Unit)? = null

    private var currentDirection = Direction.NONE
    private var thumbX = 0f
    private var thumbY = 0f
    private var isDragging = false

    private val outerRadius = dpToPx(50f)
    private val thumbRadius = dpToPx(25f)
    private val deadZone = dpToPx(10f)

    private val outerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb((255 * 0.12).toInt(), 102, 89, 71)
        style = Paint.Style.FILL
    }
    private val outerStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb((255 * 0.35).toInt(), 127, 114, 89)
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(2f)
    }
    private val thumbPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb((255 * 0.4).toInt(), 127, 114, 89)
        style = Paint.Style.FILL
    }
    private val thumbStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb((255 * 0.65).toInt(), 140, 127, 102)
        style = Paint.Style.STROKE
        strokeWidth = dpToPx(2f)
    }

    private fun dpToPx(dp: Float): Float {
        return dp * context.resources.displayMetrics.density
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        thumbX = w / 2f
        thumbY = h / 2f
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f

        canvas.drawCircle(cx, cy, outerRadius, outerPaint)
        canvas.drawCircle(cx, cy, outerRadius, outerStrokePaint)

        // Draw thumb
        if (isDragging) {
            thumbPaint.color = Color.argb((255 * 0.6).toInt(), 140, 127, 102)
        } else {
            thumbPaint.color = Color.argb((255 * 0.4).toInt(), 127, 114, 89)
        }
        canvas.drawCircle(thumbX, thumbY, thumbRadius, thumbPaint)
        canvas.drawCircle(thumbX, thumbY, thumbRadius, thumbStrokePaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        parent.requestDisallowInterceptTouchEvent(true)
        val cx = width / 2f
        val cy = height / 2f

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                isDragging = true
                val dx = event.x - cx
                val dy = event.y - cy
                val distance = hypot(dx.toDouble(), dy.toDouble()).toFloat()

                val clampedDist = Math.min(distance, outerRadius - 5f)
                val angle = atan2(dy.toDouble(), dx.toDouble())

                thumbX = cx + cos(angle).toFloat() * clampedDist
                thumbY = cy + sin(angle).toFloat() * clampedDist

                val newDir = when {
                    Math.abs(dx) < deadZone -> Direction.NONE
                    dx < 0 -> Direction.LEFT
                    else -> Direction.RIGHT
                }

                if (newDir != currentDirection) {
                    currentDirection = newDir
                    onDirectionChange?.invoke(newDir)
                }
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                isDragging = false
                thumbX = cx
                thumbY = cy
                if (currentDirection != Direction.NONE) {
                    currentDirection = Direction.NONE
                    onDirectionChange?.invoke(Direction.NONE)
                }
                invalidate()
                return true
            }
        }
        return super.onTouchEvent(event)
    }
}
