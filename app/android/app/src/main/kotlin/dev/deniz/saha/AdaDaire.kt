package dev.deniz.saha

import android.animation.AnimatorSet
import android.animation.TimeAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.graphics.Typeface
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import kotlin.math.min

/**
 * Taken from Agent Presence (StepCircleView, MIT, github.com/DenizTanisman/agent-presence); SPEC refers to its spec.
 * Here the number is the set to do, and [oran] can replace the orbiting arc with a fixed ring: sets done, or the
 * time left of a rest.
 *
 * The one circle that tracks the whole task (SPEC §3). Instead of a long row of steps, it shows the current
 * step number and changes in place: an arc orbits it while the agent works, a check draws itself when a step
 * is finished and the next number slides in, a ripple goes out when everything is done, an amber halo pulses
 * while the agent waits for the owner, and it shakes once on failure.
 *
 * Geometry is relative to the view size so the same view serves minimal, compact and expanded: the circle
 * itself is 55 % of the half-size, the rest is room for the orbit, the halo and the ripple.
 */
class AdaDaire(context: Context) : View(context) {
    enum class Look { ACTIVE, SPINNER, PENDING, DONE, WAITING, FAILED }

    /** Circle radius as a share of the half-size; the rest is room for the orbit, halo and ripple. The small chip
     *  beside the camera uses a fuller circle (0.66) so it still reads at status-bar height. */
    var fill = 0.55f
        set(v) { field = v; invalidate() }

    /** A fixed ring (0..1) instead of the orbiting arc; null = orbit. */
    var oran: Float? = null
        set(v) {
            if (field == v) return
            field = v
            updateTicker()
            invalidate()
        }

    private var look = Look.ACTIVE
    private var number = 1
    private var badge: String? = null
    private var bound = false

    // Animation state.
    private var time = 0L
    private var finishing = false
    private var check = 1f
    private var pop = 1f
    private var numberIn = 1f
    private var ripple = -1f
    private var shake = 0f
    private var running: AnimatorSet? = null

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private val path = Path()
    private val part = Path()
    private val box = RectF()

    private val ticker = TimeAnimator().apply {
        setTimeListener { _, total, _ ->
            time = total
            invalidate()
        }
    }

    /** Show this state; plays the transition from the previous one (none on the very first bind). */
    fun bind(newLook: Look, newNumber: Int, newBadge: String?) {
        val oldLook = look
        val oldNumber = number
        look = newLook
        number = newNumber
        badge = newBadge
        if (!bound) {
            bound = true
            check = 1f
            updateTicker()
            invalidate()
            return
        }
        when {
            newLook == Look.DONE && oldLook != Look.DONE -> playDone()
            newLook == Look.FAILED && oldLook != Look.FAILED -> playFailed()
            newLook == Look.ACTIVE && oldLook == Look.ACTIVE && newNumber > oldNumber -> playStepFinished()
            newLook == Look.ACTIVE && (newNumber != oldNumber || oldLook != Look.ACTIVE) -> playNumberIn(0L)
        }
        updateTicker()
        invalidate()
    }

    private fun updateTicker() {
        val orbit = (look == Look.ACTIVE && oran == null) || look == Look.SPINNER
        val needs = isAttachedToWindow && (finishing || orbit || look == Look.WAITING)
        if (needs && !ticker.isStarted) ticker.start()
        if (!needs && ticker.isStarted && ripple < 0f) ticker.end()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        updateTicker()
    }

    override fun onDetachedFromWindow() {
        ticker.end()
        super.onDetachedFromWindow()
    }

    private fun cancelRunning() {
        running?.cancel()
        running = null
        finishing = false
        pop = 1f
        numberIn = 1f
        ripple = -1f
        shake = 0f
    }

    /** Green fill, the check draws itself with a pop, then the next number slides in (SPEC §3 "step finished"). */
    private fun playStepFinished() {
        cancelRunning()
        finishing = true
        check = 0f
        val draw = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 350
            interpolator = DecelerateInterpolator()
            addUpdateListener { check = it.animatedValue as Float; invalidate() }
        }
        val popUp = ValueAnimator.ofFloat(1f, 1.12f, 1f).apply {
            duration = 350
            addUpdateListener { pop = it.animatedValue as Float; invalidate() }
        }
        val next = ValueAnimator.ofFloat(0f, 1f).apply {
            startDelay = 500
            duration = 300
            interpolator = OvershootInterpolator(1.4f)
            addUpdateListener {
                if (finishing) finishing = false
                numberIn = it.animatedValue as Float
                invalidate()
            }
        }
        numberIn = 0f
        running = AnimatorSet().apply {
            play(draw).with(popUp)
            play(next).after(draw)
            start()
        }
        updateTicker()
    }

    private fun playNumberIn(delay: Long) {
        cancelRunning()
        numberIn = 0f
        running = AnimatorSet().apply {
            play(ValueAnimator.ofFloat(0f, 1f).apply {
                startDelay = delay
                duration = 300
                interpolator = OvershootInterpolator(1.4f)
                addUpdateListener { numberIn = it.animatedValue as Float; invalidate() }
            })
            start()
        }
    }

    /** Check draws, then one ripple ring goes out to 1.8× and fades (SPEC §3 "all done"). */
    private fun playDone() {
        cancelRunning()
        check = 0f
        val draw = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 350
            interpolator = DecelerateInterpolator()
            addUpdateListener { check = it.animatedValue as Float; invalidate() }
        }
        val popUp = ValueAnimator.ofFloat(1f, 1.12f, 1f).apply {
            duration = 350
            addUpdateListener { pop = it.animatedValue as Float; invalidate() }
        }
        val wave = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 800
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                ripple = it.animatedValue as Float
                if (ripple >= 1f) ripple = -1f
                invalidate()
            }
        }
        running = AnimatorSet().apply {
            play(draw).with(popUp)
            play(wave).after(200)
            start()
        }
    }

    private fun playFailed() {
        cancelRunning()
        running = AnimatorSet().apply {
            play(ValueAnimator.ofFloat(0f, -6f, 6f, -4f, 4f, -2f, 0f).apply {
                duration = 420
                addUpdateListener { shake = (it.animatedValue as Float) * dp; invalidate() }
            })
            start()
        }
    }

    override fun onDraw(c: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val half = min(width, height) / 2f
        val r = half * fill
        c.save()
        c.translate(shake, 0f)

        if (look == Look.WAITING) {
            val p = (time % 1400L) / 1400f
            paint.color = Renk.AMBER
            paint.alpha = (0.6f * (1f - p) * 255).toInt()
            c.drawCircle(cx, cy, r * (1f + 0.5f * p), paint)
            paint.alpha = 255
        }
        if (ripple in 0f..1f) {
            stroke.color = Renk.GREEN
            stroke.alpha = ((1f - ripple) * 0.75f * 255).toInt()
            stroke.strokeWidth = r * 0.14f
            c.drawCircle(cx, cy, r * (1f + 0.8f * ripple), stroke)
            stroke.alpha = 255
        }

        c.save()
        c.scale(pop, pop, cx, cy)
        when {
            finishing || look == Look.DONE -> {
                paint.color = Renk.GREEN
                c.drawCircle(cx, cy, r, paint)
                drawCheck(c, cx, cy, r, if (finishing || look == Look.DONE) check else 1f)
            }
            look == Look.ACTIVE -> {
                drawBlue(c, cx, cy, r)
                text.color = Renk.BLUE_TEXT
                text.textSize = if (number >= 10) r * 0.92f else r * 1.08f
                text.alpha = (numberIn.coerceIn(0f, 1f) * 255).toInt()
                val dy = (1f - numberIn) * r * 0.7f
                c.save()
                c.clipRect(cx - r, cy - r, cx + r, cy + r)
                c.drawText(number.toString(), cx, cy + dy - (text.descent() + text.ascent()) / 2f, text)
                c.restore()
                text.alpha = 255
            }
            look == Look.PENDING -> {
                paint.color = Renk.PENDING_FILL
                c.drawCircle(cx, cy, r, paint)
                text.color = Renk.PENDING_TEXT
                text.textSize = if (number >= 10) r * 0.92f else r * 1.08f
                c.drawText(number.toString(), cx, cy - (text.descent() + text.ascent()) / 2f, text)
            }
            look == Look.SPINNER -> {
                drawBlue(c, cx, cy, r)
                paint.color = Renk.BLUE_TEXT
                c.drawCircle(cx, cy, r * 0.2f, paint)
            }
            look == Look.WAITING -> {
                paint.color = Renk.AMBER
                c.drawCircle(cx, cy, r, paint)
                text.color = 0xFF000000.toInt()
                text.textSize = r * 1.25f
                c.drawText("!", cx, cy - (text.descent() + text.ascent()) / 2f, text)
            }
            look == Look.FAILED -> {
                paint.color = Renk.RED
                c.drawCircle(cx, cy, r, paint)
                stroke.color = Renk.TEXT
                stroke.strokeWidth = r * 0.2f
                val k = r * 0.34f
                c.drawLine(cx - k, cy - k, cx + k, cy + k, stroke)
                c.drawLine(cx + k, cy - k, cx - k, cy + k, stroke)
            }
        }
        c.restore()

        val ring = oran
        if (!finishing && look == Look.ACTIVE && ring != null) {
            val ro = minOf(half * 0.96f, r + half * 0.19f)
            box.set(cx - ro, cy - ro, cx + ro, cy + ro)
            stroke.strokeWidth = half * 0.08f
            stroke.color = Renk.PENDING_FILL
            c.drawArc(box, 0f, 360f, false, stroke)
            stroke.color = Renk.BLUE_ORBIT
            if (ring > 0f) c.drawArc(box, -90f, 360f * ring.coerceAtMost(1f), false, stroke)
        } else if (!finishing && (look == Look.ACTIVE || look == Look.SPINNER)) {
            val ro = minOf(half * 0.96f, r + half * 0.19f)
            box.set(cx - ro, cy - ro, cx + ro, cy + ro)
            stroke.color = Renk.BLUE_ORBIT
            stroke.strokeWidth = half * 0.08f
            val angle = (time % 1100L) / 1100f * 360f
            c.drawArc(box, angle - 90f, 90f, false, stroke)
        }

        badge?.let { drawBadge(c, cx + r * 0.82f, cy + r * 0.82f, minOf(6.5f * dp, half * 0.3f), it) }
        c.restore()
    }

    private fun drawBlue(c: Canvas, cx: Float, cy: Float, r: Float) {
        paint.color = Renk.BLUE_FILL
        c.drawCircle(cx, cy, r, paint)
        stroke.color = Renk.BLUE
        stroke.strokeWidth = 2f * dp
        c.drawCircle(cx, cy, r - dp, stroke)
    }

    private fun drawCheck(c: Canvas, cx: Float, cy: Float, r: Float, progress: Float) {
        path.reset()
        path.moveTo(cx - r * 0.42f, cy + r * 0.02f)
        path.lineTo(cx - r * 0.12f, cy + r * 0.32f)
        path.lineTo(cx + r * 0.44f, cy - r * 0.28f)
        val m = PathMeasure(path, false)
        part.reset()
        m.getSegment(0f, m.length * progress.coerceIn(0f, 1f), part, true)
        stroke.color = Renk.TEXT
        stroke.strokeWidth = r * 0.2f
        c.drawPath(part, stroke)
    }

    /** Small circle with a laptop or phone glyph: this session drives the other device (a mirror). */
    private fun drawBadge(c: Canvas, x: Float, y: Float, br: Float, device: String) {
        paint.color = 0xFF000000.toInt()
        c.drawCircle(x, y, br + br * 0.23f, paint)
        paint.color = 0xFF3A3A3C.toInt()
        c.drawCircle(x, y, br, paint)
        stroke.color = Renk.TEXT
        stroke.strokeWidth = br * 0.17f
        if (device == "mac") {
            box.set(x - br * 0.5f, y - br * 0.42f, x + br * 0.5f, y + br * 0.18f)
            c.drawRoundRect(box, dp * 0.6f, dp * 0.6f, stroke)
            c.drawLine(x - br * 0.66f, y + br * 0.42f, x + br * 0.66f, y + br * 0.42f, stroke)
        } else {
            box.set(x - br * 0.3f, y - br * 0.55f, x + br * 0.3f, y + br * 0.55f)
            c.drawRoundRect(box, dp * 0.9f, dp * 0.9f, stroke)
        }
    }
}
