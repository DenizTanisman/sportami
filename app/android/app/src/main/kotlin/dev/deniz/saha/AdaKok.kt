package dev.deniz.saha

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.ColorFilter
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.view.View
import android.widget.LinearLayout

/**
 * The overlay's root. It draws the alert glow (SPEC §4 "Glow") behind its alerting children: a shadow of the
 * child's shape in its accent, radius [radius], 45 % opacity, or pulsing 30 % ↔ 60 % over 1.6 s while the agent waits
 * for the owner. The glow lives in this view's padding, so the window does not clip it. The pulse animator runs only
 * while a pulsing glow is on screen.
 */
internal class AdaKok(c: Context) : LinearLayout(c) {
    /** [view] glows in [color]; [corner] < 0 means a circle (the minimal chip). */
    class Glow(val view: View, val color: Int, val pulse: Boolean, val corner: Float)

    var radius = 0f

    var glows: List<Glow> = emptyList()
        set(v) {
            field = v
            if (v.any { it.pulse }) {
                if (!pulse.isStarted) pulse.start()
            } else if (pulse.isStarted) {
                pulse.cancel()
            }
            invalidate()
        }

    private var level = 0.45f
    private val pulse = ValueAnimator.ofFloat(0.30f, 0.60f).apply {
        duration = 800
        repeatMode = ValueAnimator.REVERSE
        repeatCount = ValueAnimator.INFINITE
        addUpdateListener {
            level = it.animatedValue as Float
            invalidate()
        }
    }
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val rect = Rect()
    private val box = RectF()

    override fun onDetachedFromWindow() {
        pulse.cancel()
        super.onDetachedFromWindow()
    }

    override fun dispatchDraw(canvas: Canvas) {
        for (g in glows) {
            val v = g.view
            if (!v.isAttachedToWindow || v.width == 0 || v.height == 0) continue
            v.getDrawingRect(rect)
            offsetDescendantRectToMyCoords(v, rect)
            box.set(rect)
            // Follow the entrance fade of the shape, so the glow never appears before the card it belongs to.
            var fade = 1f
            var p: View? = v
            while (p != null && p !== this) {
                fade *= p.alpha
                p = p.parent as? View
            }
            if (fade <= 0.01f) continue
            val share = (if (g.pulse) level else 0.45f) * fade
            paint.color = Renk.alpha(Renk.SURFACE, fade)
            paint.setShadowLayer(radius, 0f, 0f, Renk.alpha(g.color, share))
            val r = if (g.corner < 0) box.height() / 2f else g.corner
            canvas.drawRoundRect(box, r, r, paint)
        }
        paint.clearShadowLayer()
        super.dispatchDraw(canvas)
    }
}

/**
 * The directive capsule's body (SPEC §4): near-black capsule, a hairline in the accent at 40 % and a soft glow of the
 * accent around it. The body is drawn inset by [glow] so the glow has room inside the view.
 */
internal class AdaKapsul(
    private val fill: Int,
    private val border: Int,
    private val glowColor: Int,
    private val glow: Float,
    private val stroke: Float,
) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val box = RectF()

    override fun draw(canvas: Canvas) {
        box.set(bounds)
        box.inset(glow, glow)
        val r = box.height() / 2f
        paint.style = Paint.Style.FILL
        paint.color = fill
        paint.setShadowLayer(glow, 0f, 0f, glowColor)
        canvas.drawRoundRect(box, r, r, paint)
        paint.clearShadowLayer()
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = stroke
        paint.color = border
        box.inset(stroke / 2f, stroke / 2f)
        canvas.drawRoundRect(box, r - stroke / 2f, r - stroke / 2f, paint)
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
