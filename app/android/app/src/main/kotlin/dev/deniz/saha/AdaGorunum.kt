package dev.deniz.saha

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * The island: a black pill under the status bar (like a phone's camera cut-out grown wide).
 * Collapsed it shows the animation, the exercise, "SET 2 / 3 · 3 × 10" or the rest countdown.
 * Tapped it opens into a card with the bigger animation, the dose and the buttons.
 * It can be dragged anywhere; a tap without moving opens or closes it.
 */
@SuppressLint("ViewConstructor", "SetTextI18n", "ClickableViewAccessibility")
class AdaGorunum(private val c: Context, private val wm: WindowManager) {
    private val turuncu = Color.rgb(255, 106, 43)
    private val metin2 = Color.rgb(161, 161, 166)
    private val metin3 = Color.rgb(110, 110, 116)
    private val yuzey = Color.rgb(14, 14, 17)
    private val cizgi = Color.rgb(42, 42, 48)
    private val yesil = Color.rgb(48, 209, 88)

    private fun dp(v: Number) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), c.resources.displayMetrics)
    private fun dpi(v: Number) = dp(v).toInt()

    private val inter: Typeface? = try {
        Typeface.createFromAsset(c.assets, "flutter_assets/assets/fonts/Inter.ttf")
    } catch (_: Exception) {
        null
    }

    private fun yazi(w: Int): Typeface {
        if (inter != null && Build.VERSION.SDK_INT >= 26) {
            try {
                return Typeface.Builder(c.assets, "flutter_assets/assets/fonts/Inter.ttf")
                    .setFontVariationSettings("'wght' $w").build()
            } catch (_: Exception) {
            }
        }
        return Typeface.create(inter ?: Typeface.DEFAULT, if (w >= 600) Typeface.BOLD else Typeface.NORMAL)
    }

    private val yazilar = HashMap<Int, Typeface>()
    private fun tf(w: Int) = yazilar.getOrPut(w) { yazi(w) }

    private fun tv(boy: Float, w: Int, renk: Int = Color.WHITE, sayi: Boolean = false) = TextView(c).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, boy)
        typeface = tf(w)
        setTextColor(renk)
        includeFontPadding = false
        if (sayi) fontFeatureSettings = "tnum"
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }

    private fun zemin(renk: Int, yaricap: Float, kenar: Int? = null) = GradientDrawable().apply {
        setColor(renk)
        cornerRadius = yaricap
        if (kenar != null) setStroke(dpi(1), kenar)
    }

    private fun yuvarlat(v: View, r: Float) {
        v.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, o: Outline) = o.setRoundRect(0, 0, view.width, view.height, r)
        }
        v.clipToOutline = true
    }

    // ---- views ---------------------------------------------------------------------

    private val kok = FrameLayout(c)

    private val kAnim = ImageView(c)
    private val kBaslik = tv(13.5f, 650)
    private val kAlt = tv(11.5f, 650, turuncu)
    private val kSag = tv(17f, 700, sayi = true)
    private val kHalka = Halka(c)
    private val kompakt = LinearLayout(c)

    private val gUst = tv(11.5f, 700, turuncu).apply { letterSpacing = 0.08f }
    private val gSira = tv(12f, 560, metin3, sayi = true)
    private val gAnim = ImageView(c)
    private val gBaslik = tv(18f, 700).apply { maxLines = 2 }
    private val gDoz = tv(30f, 720, sayi = true)
    private val gSet = tv(12.5f, 700, turuncu).apply { letterSpacing = 0.06f }
    private val gKayit = tv(12.5f, 500, metin2).apply { maxLines = 2 }
    private val gSure = tv(52f, 660, sayi = true).apply { gravity = Gravity.CENTER }
    private val gCubuk = Cubuk(c)
    private val gSonraki = tv(13f, 560, metin2).apply { gravity = Gravity.CENTER }
    private val gSureBlok = LinearLayout(c)
    private val bOnceki = dugme("‹", false)
    private val bBirincil = dugme("", true)
    private val bSonraki = dugme("›", false)
    private val ikinciSira = LinearLayout(c)
    private val genis = LinearLayout(c)

    private var acikMi = false
    private val lp = WindowManager.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    )

    private fun dugme(yazi: String, ana: Boolean) = TextView(c).apply {
        text = yazi
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, if (yazi == "‹" || yazi == "›") 26f else 15f)
        typeface = tf(680)
        includeFontPadding = false
        setTextColor(if (ana) Color.rgb(20, 10, 4) else Color.WHITE)
        background = zemin(if (ana) turuncu else Color.rgb(38, 38, 44), dp(16))
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
        setPadding(dpi(12), 0, dpi(12), 0)
    }

    init {
        val ekranW = c.resources.displayMetrics.widthPixels

        // collapsed pill
        kompakt.orientation = LinearLayout.HORIZONTAL
        kompakt.gravity = Gravity.CENTER_VERTICAL
        kompakt.background = zemin(Color.BLACK, dp(24), Color.rgb(30, 30, 34))
        kompakt.setPadding(dpi(6), dpi(6), dpi(10), dpi(6))
        kompakt.elevation = dp(10)
        kAnim.background = zemin(Color.rgb(28, 28, 32), dp(14))
        kAnim.scaleType = ImageView.ScaleType.FIT_CENTER
        yuvarlat(kAnim, dp(14))
        kompakt.addView(kAnim, LinearLayout.LayoutParams(dpi(36), dpi(36)))
        val kMetin = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            addView(kBaslik, LinearLayout.LayoutParams(-2, -2))
            addView(kAlt, LinearLayout.LayoutParams(-2, -2).apply { topMargin = dpi(3) })
        }
        kBaslik.maxWidth = min(dpi(220), (ekranW * 0.52).toInt())
        kAlt.maxWidth = kBaslik.maxWidth
        kompakt.addView(kMetin, LinearLayout.LayoutParams(-2, -2).apply { leftMargin = dpi(10); rightMargin = dpi(12) })
        kompakt.addView(kSag, LinearLayout.LayoutParams(-2, -2).apply { rightMargin = dpi(8) })
        kompakt.addView(kHalka, LinearLayout.LayoutParams(dpi(24), dpi(24)))

        // open card
        genis.orientation = LinearLayout.VERTICAL
        genis.background = zemin(yuzey, dp(30), cizgi)
        genis.elevation = dp(14)
        genis.setPadding(dpi(16), dpi(14), dpi(16), dpi(16))
        val ust = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(gUst, LinearLayout.LayoutParams(0, -2, 1f))
            addView(gSira, LinearLayout.LayoutParams(-2, -2).apply { rightMargin = dpi(10) })
            addView(ikon("↗") { uygulamayiAc() })
            addView(ikon("—") { kapat() }, LinearLayout.LayoutParams(dpi(34), dpi(30)).apply { leftMargin = dpi(4) })
            addView(ikon("✕") { Ada.eylem("kapat") }, LinearLayout.LayoutParams(dpi(34), dpi(30)).apply { leftMargin = dpi(4) })
        }
        genis.addView(ust)
        val orta = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        gAnim.background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Color.rgb(36, 36, 42), Color.rgb(22, 22, 26))).apply { cornerRadius = dp(22) }
        gAnim.scaleType = ImageView.ScaleType.FIT_CENTER
        yuvarlat(gAnim, dp(22))
        orta.addView(gAnim, LinearLayout.LayoutParams(dpi(108), dpi(108)))
        val sag = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            addView(gSet)
            addView(gBaslik, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(6) })
            addView(gDoz, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(6) })
            addView(gKayit, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(6) })
        }
        orta.addView(sag, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dpi(14) })
        genis.addView(orta, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(12) })

        gSureBlok.orientation = LinearLayout.VERTICAL
        gSureBlok.addView(gSure, LinearLayout.LayoutParams(-1, -2))
        gSureBlok.addView(gCubuk, LinearLayout.LayoutParams(-1, dpi(6)).apply { topMargin = dpi(10) })
        gSureBlok.addView(gSonraki, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(10) })
        genis.addView(gSureBlok, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(14) })

        val sira = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            isBaselineAligned = false
            addView(bOnceki, LinearLayout.LayoutParams(dpi(52), dpi(52)))
            addView(bBirincil, LinearLayout.LayoutParams(0, dpi(52), 1f).apply { leftMargin = dpi(8); rightMargin = dpi(8) })
            addView(bSonraki, LinearLayout.LayoutParams(dpi(52), dpi(52)))
        }
        genis.addView(sira, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(14) })
        ikinciSira.orientation = LinearLayout.HORIZONTAL
        ikinciSira.isBaselineAligned = false
        genis.addView(ikinciSira, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dpi(8) })

        bBirincil.setOnClickListener { dokun(it); Ada.eylem("birincil") }
        bOnceki.setOnClickListener { dokun(it); Ada.eylem("onceki") }
        bSonraki.setOnClickListener { dokun(it); Ada.eylem("sonraki") }

        val kenar = dpi(8)
        kok.setPadding(kenar, kenar, kenar, kenar)
        kok.clipToPadding = false
        kok.addView(kompakt, FrameLayout.LayoutParams(-2, dpi(48)).apply { gravity = Gravity.CENTER_HORIZONTAL })
        kok.addView(genis, FrameLayout.LayoutParams(min(dpi(372), ekranW - dpi(16)), -2).apply { gravity = Gravity.CENTER_HORIZONTAL })
        genis.visibility = View.GONE

        surukle(kompakt) { ac() }
        surukle(ust) { kapat() }
        surukle(orta) { kapat() }

        lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        lp.y = durumCubugu() + dpi(2)
    }

    private fun ikon(s: String, f: () -> Unit) = TextView(c).apply {
        text = s
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        setTextColor(metin2)
        background = zemin(Color.rgb(30, 30, 35), dp(15))
        layoutParams = LinearLayout.LayoutParams(dpi(34), dpi(30))
        setOnClickListener { dokun(it); f() }
    }

    private fun dokun(v: View) {
        v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }

    private fun durumCubugu(): Int {
        val id = c.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) c.resources.getDimensionPixelSize(id) else dpi(24)
    }

    /** Drag moves the window; a tap (no movement) runs [tik]. */
    private fun surukle(v: View, tik: () -> Unit) {
        var x0 = 0f
        var y0 = 0f
        var lx = 0
        var ly = 0
        var oynadi = false
        v.setOnTouchListener { _, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    x0 = e.rawX; y0 = e.rawY; lx = lp.x; ly = lp.y; oynadi = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - x0
                    val dy = e.rawY - y0
                    if (!oynadi && (abs(dx) > dp(8) || abs(dy) > dp(8))) oynadi = true
                    if (oynadi) {
                        lp.x = lx + dx.toInt()
                        lp.y = max(0, ly + dy.toInt())
                        try { wm.updateViewLayout(kok, lp) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!oynadi) { dokun(v); tik() }
                    true
                }
                else -> true
            }
        }
    }

    // ---- open / close -------------------------------------------------------------------

    private fun ac() {
        if (acikMi) return
        acikMi = true
        kompakt.visibility = View.GONE
        genis.visibility = View.VISIBLE
        genis.pivotY = 0f
        genis.post { genis.pivotX = genis.width / 2f }
        genis.scaleX = 0.55f; genis.scaleY = 0.3f; genis.alpha = 0f
        genis.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(260).setInterpolator(OvershootInterpolator(0.9f)).start()
        yenile(son)
    }

    private fun kapat() {
        if (!acikMi) return
        acikMi = false
        genis.animate().scaleX(0.6f).scaleY(0.3f).alpha(0f).setDuration(160).withEndAction {
            genis.visibility = View.GONE
            kompakt.visibility = View.VISIBLE
            kompakt.scaleX = 0.8f; kompakt.alpha = 0f
            kompakt.animate().scaleX(1f).alpha(1f).setDuration(180).start()
        }.start()
    }

    private fun uygulamayiAc() {
        val i = Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        try { c.startActivity(i) } catch (_: Exception) {}
    }

    fun ekle() {
        wm.addView(kok, lp)
        el.post(saat)
    }

    fun kaldir() {
        el.removeCallbacksAndMessages(null)
        try { wm.removeView(kok) } catch (_: Exception) {}
    }

    // ---- state -------------------------------------------------------------------------------

    private var son: Map<*, *> = emptyMap<Any, Any>()
    private var mod = ""
    private var dugmeImza = ""
    private var bitis = 0L
    private var toplam = 0
    private var kareId: String? = null
    private var kareler: List<Bitmap> = emptyList()
    private var kareMs = 100
    private var kareNo = 0

    private fun s(k: String) = son[k] as? String ?: ""
    private fun l(k: String) = (son[k] as? Number)?.toLong() ?: 0L

    fun yenile(d: Map<*, *>) {
        son = d
        mod = s("mod")
        val L = d["L"] as? Map<*, *>
        val sayac = mod == "mola" || mod == "is"
        bitis = if (mod == "mola") l("molaSon") else if (mod == "is") l("isSon") else 0L
        toplam = ((if (mod == "mola") d["molaToplam"] else d["isToplam"]) as? Number)?.toInt() ?: 0

        kBaslik.text = s("kisa")
        kAlt.text = s("kisaAlt")
        kAlt.setTextColor(if (sayac) turuncu else metin2)
        gUst.text = s("ust")
        gSira.text = s("sira")
        gBaslik.text = s("baslik")
        gDoz.text = s("doz")
        gDoz.visibility = if (s("doz").isEmpty()) View.GONE else View.VISIBLE
        gSet.text = if (mod == "mola") (L?.get("mola") as? String ?: s("kisaAlt")) else s("set")
        // A just-saved note takes the "will log" line for a moment, so the buttons never move under a finger.
        val not = s("not")
        gKayit.text = if (not.isNotEmpty()) not else s("kayit")
        gKayit.setTextColor(if (not.isNotEmpty()) yesil else metin2)
        gKayit.visibility = if (gKayit.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        gSureBlok.visibility = if (sayac) View.VISIBLE else View.GONE
        gSonraki.text = s("sonraki")
        gSonraki.visibility = if (s("sonraki").isEmpty()) View.GONE else View.VISIBLE

        bBirincil.text = s("birincil")
        val gez = d["gezinme"] == true
        bOnceki.visibility = if (gez) View.VISIBLE else View.GONE
        bSonraki.visibility = if (gez) View.VISIBLE else View.GONE
        // second row: −15 / +15 in rest, kg and reps steps before a set, "OK" for a timed warm-up
        val dl = (d["dugmeler"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        val imza = dl.joinToString("|") { "${it["y"]}>${it["e"]}" }
        if (imza != dugmeImza) {
            dugmeImza = imza
            ikinciSira.removeAllViews()
            dl.forEachIndexed { i, m ->
                val e = m["e"] as? String ?: return@forEachIndexed
                val b = dugme(m["y"] as? String ?: "", false).apply {
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, if (dl.size > 2) 13.5f else 15f)
                    setPadding(dpi(4), 0, dpi(4), 0)
                    setOnClickListener { dokun(it); Ada.eylem(e) }
                }
                ikinciSira.addView(b, LinearLayout.LayoutParams(0, dpi(44), 1f).apply { if (i > 0) leftMargin = dpi(6) })
            }
        }
        ikinciSira.visibility = if (dl.isEmpty()) View.GONE else View.VISIBLE

        val id = d["id"] as? String
        val k = Ada.kareler(id)
        if (id != kareId || (k != null && k.second !== kareler)) {
            kareId = id
            kareler = k?.second ?: emptyList()
            kareMs = max(40, k?.first ?: 100)
            kareNo = 0
            el.removeCallbacks(oynat)
            if (kareler.isNotEmpty()) el.post(oynat) else { kAnim.setImageDrawable(null); gAnim.setImageDrawable(null) }
        }
        kAnim.visibility = if (kareler.isEmpty() && id == null) View.GONE else View.VISIBLE
        saatYaz()
    }

    // ---- clocks ------------------------------------------------------------------------------

    private val el = Handler(Looper.getMainLooper())

    private val oynat = object : Runnable {
        override fun run() {
            if (kareler.isEmpty()) return
            val b = kareler[kareNo % kareler.size]
            kAnim.setImageBitmap(b)
            if (acikMi) gAnim.setImageBitmap(b)
            kareNo++
            if (kareler.size > 1) el.postDelayed(this, kareMs.toLong())
        }
    }

    private val saat = object : Runnable {
        override fun run() {
            saatYaz()
            el.postDelayed(this, 250)
        }
    }

    private fun saatYaz() {
        if (bitis > 0) {
            val kalanMs = bitis - System.currentTimeMillis()
            val kalan = max(0, ceil(kalanMs / 1000.0).toInt())
            val yazi = "${kalan / 60}:${(kalan % 60).toString().padStart(2, '0')}"
            kSag.text = yazi
            gSure.text = yazi
            val oran = if (toplam > 0) (kalanMs / (toplam * 1000f)).coerceIn(0f, 1f) else 0f
            kHalka.oran = oran
            gCubuk.oran = oran
            kHalka.renk = turuncu
        } else {
            kSag.text = s("sag")
            kHalka.oran = ((son["ilerleme"] as? Number)?.toFloat() ?: 0f)
            kHalka.renk = if (kHalka.oran >= 1f) yesil else turuncu
        }
        kSag.visibility = if (kSag.text.isNullOrEmpty()) View.GONE else View.VISIBLE
    }

    /** Rest or a timed set is over (the service buzzes and rings): pulse the pill. */
    fun uyar() {
        val hedef = if (acikMi) genis else kompakt
        ValueAnimator.ofFloat(1f, 1.1f, 1f).apply {
            duration = 520
            repeatCount = 1
            addUpdateListener { val f = it.animatedValue as Float; hedef.scaleX = f; hedef.scaleY = f }
            start()
        }
    }
}

/** Ring that fills with [oran] (0..1). */
class Halka(c: Context) : View(c) {
    var oran = 0f
        set(v) { if (field != v) { field = v; invalidate() } }
    var renk = Color.rgb(255, 106, 43)
        set(v) { if (field != v) { field = v; invalidate() } }
    private val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val r = RectF()

    override fun onDraw(cv: Canvas) {
        val w = width.toFloat()
        val k = w * 0.13f
        p.strokeWidth = k
        r.set(k / 2 + 1, k / 2 + 1, w - k / 2 - 1, height - k / 2 - 1)
        p.color = Color.rgb(48, 48, 54)
        cv.drawArc(r, 0f, 360f, false, p)
        p.color = renk
        if (oran > 0f) cv.drawArc(r, -90f, 360f * oran, false, p)
    }
}

/** Thin progress bar for the countdown. */
class Cubuk(c: Context) : View(c) {
    var oran = 0f
        set(v) { if (field != v) { field = v; invalidate() } }
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val r = RectF()

    override fun onDraw(cv: Canvas) {
        val h = height.toFloat()
        p.color = Color.rgb(44, 44, 50)
        r.set(0f, 0f, width.toFloat(), h)
        cv.drawRoundRect(r, h / 2, h / 2, p)
        p.color = Color.rgb(255, 106, 43)
        r.set(0f, 0f, width * oran, h)
        if (oran > 0f) cv.drawRoundRect(r, h / 2, h / 2, p)
    }
}
