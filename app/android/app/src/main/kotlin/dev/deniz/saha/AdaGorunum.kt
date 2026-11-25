package dev.deniz.saha

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextUtils
import android.text.style.AbsoluteSizeSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.text.style.TypefaceSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.ceil
import kotlin.math.max

/**
 * The island over other apps, in Agent Presence's look (github.com/DenizTanisman/agent-presence):
 *
 * - **Minimal**: one circle right under the camera hole. Its number is the set to do; the ring shows the sets done.
 * - **Compact**: a pill under the status bar: circle, the exercise's animation, its name and the one datum (the rest
 *   countdown, or sets done). A capsule under it says what comes next. Its resting size during a rest or a timed set,
 *   and after a rest until the next set is logged.
 * - **Open**: a card with the exercise (animation, set, dose, what will be logged), the countdown, the buttons and
 *   the day's exercises as a task list (Bitti / Sürüyor / Sırada).
 *
 * When a rest is over the card opens by itself for a few seconds and glows amber, like an agent waiting for its owner.
 * Dart (lib/ada.dart) decides every word; this only draws. Main thread only.
 */
@SuppressLint("ViewConstructor", "SetTextI18n")
class AdaGorunum(private val c: Context, private val wm: WindowManager) {
    private enum class Mod { MINIMAL, KOMPAKT, ACIK }

    private val el = Handler(Looper.getMainLooper())
    private val kok = AdaKok(c).apply {
        orientation = LinearLayout.VERTICAL
        clipToPadding = false
        clipChildren = false
    }
    private val lp = WindowManager.LayoutParams(
        WRAP, WRAP,
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        if (Build.VERSION.SDK_INT >= 30) {
            setFitInsetsTypes(0)
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (Build.VERSION.SDK_INT >= 28) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        title = "SahaAda"
    }

    // ---- state ---------------------------------------------------------------------------

    private var d: Map<*, *> = emptyMap<Any, Any>()

    /** A size set for a while (a tap, the end of a rest). Null = the resting size. */
    private var elle: Mod? = null
    private val elleBitti = Runnable {
        elle = null
        ciz()
    }
    private var eskiDikkat = false
    private var sekil: String? = null

    private val daire = AdaDaire(c)
    private val sayaclar = ArrayList<TextView>()
    private var cubuk: Cubuk? = null
    private val animlar = ArrayList<ImageView>()

    private var kareId: String? = null
    private var kareler: List<Bitmap> = emptyList()
    private var kareMs = 100
    private var kareNo = 0

    private fun s(k: String) = d[k] as? String ?: ""
    private fun l(k: String) = (d[k] as? Number)?.toLong() ?: 0L
    private fun i(k: String) = (d[k] as? Number)?.toInt() ?: 0
    private fun kelime(k: String) = (d["L"] as? Map<*, *>)?.get(k) as? String ?: ""

    private val mod get() = s("mod")
    private val dikkat get() = d["dikkat"] == true
    private val sayac get() = mod == "mola" || mod == "is"
    private val bitis get() = if (mod == "mola") l("molaSon") else if (mod == "is") l("isSon") else 0L
    private val toplamSn get() = if (mod == "mola") i("molaToplam") else i("isToplam")

    fun ekle() {
        wm.addView(kok, lp)
        el.post(saat)
    }

    fun kaldir() {
        el.removeCallbacksAndMessages(null)
        runCatching { wm.removeView(kok) }
    }

    fun yenile(yeni: Map<*, *>) {
        d = yeni
        // A rest just ended: open for a few seconds, amber, like an agent asking for its owner.
        if (dikkat && !eskiDikkat) birSure(Mod.ACIK, 8000)
        eskiDikkat = dikkat

        val id = d["id"] as? String
        val k = Ada.kareler(id)
        if (id != kareId || (k != null && k.second !== kareler)) {
            kareId = id
            kareler = k?.second ?: emptyList()
            kareMs = max(40, k?.first ?: 100)
            kareNo = 0
        }
        ciz()
    }

    /** Rest or timed set over (the service rings): a short pulse. */
    fun uyar() {
        val v = kok.getChildAt(0) ?: return
        ValueAnimator.ofFloat(1f, 1.08f, 1f).apply {
            duration = 480
            repeatCount = 1
            addUpdateListener {
                val f = it.animatedValue as Float
                v.scaleX = f
                v.scaleY = f
                kok.invalidate()
            }
            start()
        }
    }

    private fun birSure(m: Mod, ms: Long) {
        elle = m
        el.removeCallbacks(elleBitti)
        el.postDelayed(elleBitti, ms)
    }

    private fun dinlenme(): Mod = when {
        sayac || dikkat -> Mod.KOMPAKT
        else -> Mod.MINIMAL
    }

    private fun ac() {
        birSure(Mod.ACIK, 20000)
        ciz()
    }

    private fun kucult() {
        el.removeCallbacks(elleBitti)
        elle = null
        ciz()
    }

    /** A button on the open card: keeps it open a while longer. */
    private fun bas(v: View, e: String) {
        v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
        if (elle == Mod.ACIK) birSure(Mod.ACIK, 20000)
        Ada.eylem(e)
    }

    private fun uygulamayiAc() {
        val i = Intent(c, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        runCatching { c.startActivity(i) }
    }

    // ---- drawing -----------------------------------------------------------------------------

    private fun ciz() {
        val m = elle ?: dinlenme()
        sayaclar.clear()
        animlar.clear()
        cubuk = null
        kok.removeAllViews()
        (daire.parent as? ViewGroup)?.removeView(daire)

        val chip = if (m == Mod.MINIMAL) dp(32) else dp(44)
        val ana = when (m) {
            Mod.ACIK -> acik()
            Mod.KOMPAKT -> kompakt()
            Mod.MINIMAL -> daireCip(chip)
        }
        kok.addView(ana, LinearLayout.LayoutParams(WRAP, WRAP).apply {
            gravity = if (m == Mod.MINIMAL) Gravity.START else Gravity.CENTER_HORIZONTAL
        })
        val kapsulYazi = s("kapsul")
        var kapsul: View? = null
        if (m == Mod.KOMPAKT && kapsulYazi.isNotEmpty()) {
            kapsul = kapsul(kapsulYazi, if (dikkat) Renk.AMBER else Renk.GREEN)
            kok.addView(kapsul, LinearLayout.LayoutParams(WRAP, WRAP).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                topMargin = dp(8) - dp(10)
            })
        }

        // The glow: amber, pulsing, when a rest is over; green when the day is done; nothing while it runs.
        kok.radius = dpf(14f)
        val renk = when {
            dikkat -> Renk.AMBER
            mod == "bitti" -> Renk.GREEN
            else -> null
        }
        kok.glows = if (renk == null) emptyList() else listOf(
            AdaKok.Glow(ana, renk, pulse = dikkat, corner = when (m) {
                Mod.MINIMAL -> -1f
                Mod.ACIK -> dpf(28f)
                Mod.KOMPAKT -> dpf(24f)
            }),
        )
        yerlestir(m, chip, parlak = renk != null)

        val yeniSekil = "$m/${kapsul != null}/$mod"
        if (yeniSekil != sekil) {
            ana.alpha = 0f
            ana.scaleX = 0.94f
            ana.scaleY = 0.94f
            ana.pivotY = 0f
            ana.addOnLayoutChangeListener(object : View.OnLayoutChangeListener {
                override fun onLayoutChange(v: View, l: Int, t: Int, r: Int, b: Int, ol: Int, ot: Int, orr: Int, ob: Int) {
                    v.removeOnLayoutChangeListener(this)
                    v.pivotX = if (m == Mod.MINIMAL) 0f else v.width / 2f
                }
            })
            ana.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(320).setInterpolator(OvershootInterpolator(0.7f))
                .setUpdateListener { kok.invalidate() }
                .withEndAction { kok.invalidate() }
                .start()
            kapsul?.let {
                it.alpha = 0f
                it.scaleX = 0.92f
                it.scaleY = 0.92f
                it.animate().alpha(1f).scaleX(1f).scaleY(1f).setStartDelay(60).setDuration(320)
                    .setInterpolator(OvershootInterpolator(0.7f)).start()
            }
        }
        sekil = yeniSekil

        daire.bind(
            when {
                mod == "bitti" -> AdaDaire.Look.DONE
                dikkat -> AdaDaire.Look.WAITING
                else -> AdaDaire.Look.ACTIVE
            },
            max(1, i("setNo")), null,
        )
        el.removeCallbacks(oynat)
        if (kareler.isNotEmpty()) el.post(oynat)
        saatYaz()
    }

    /** The circle on a dark disc, under the camera. */
    private fun daireCip(size: Int): View {
        val f = FrameLayout(c).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Renk.CHIP)
                setStroke(kil(), Renk.BORDER)
            }
            elevation = dp(3).toFloat()
            contentDescription = s("baslik")
            setOnClickListener { ac() }
        }
        daire.fill = 0.66f
        f.addView(daire, FrameLayout.LayoutParams(size, size))
        return f
    }

    private fun kompakt(): View {
        val pill = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = kart(24)
            elevation = dp(8).toFloat()
            minimumWidth = dp(180)
            setPadding(dp(2), 0, dp(12), 0)
            setOnClickListener { ac() }
        }
        daire.fill = 0.55f
        pill.addView(daire, LinearLayout.LayoutParams(dp(48), dp(48)))
        pill.addView(anim(28, 8))

        val sag = yazi("0:00", 13.5f, Renk.TEXT, kalin = true).apply {
            isSingleLine = true
            fontFeatureSettings = "tnum"
            setPadding(dp(12), 0, dp(2), 0)
        }
        if (sayac) sayaclar += sag else sag.text = s("sag")
        if (dikkat) sag.setTextColor(Renk.AMBER_TEXT)
        val ikinci = when {
            mod == "mola" -> kelime("mola")
            dikkat -> kelime("molaBitti")
            else -> s("set")
        }
        sag.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        pill.addView(TextView(c).apply {
            text = baslikSatiri(s("baslik").ifEmpty { s("gun") }, ikinci)
            letterSpacing = -0.013f
            isSingleLine = true
            ellipsize = TextUtils.TruncateAt.END
            maxWidth = enGenis() - dp(48 + 28 + 22) - max(sag.measuredWidth, dp(48))
            includeFontPadding = false
            setPadding(dp(8), 0, 0, 0)
        }, LinearLayout.LayoutParams(WRAP, WRAP))
        pill.addView(sag, LinearLayout.LayoutParams(WRAP, WRAP))
        return pill
    }

    /** What comes next, in a capsule under the pill (Agent Presence's directive capsule). */
    private fun kapsul(t: String, vurgu: Int): View {
        val g = dp(10)
        val box = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = AdaKapsul(
                fill = Renk.CAPSULE,
                border = Renk.alpha(vurgu, 0.40f),
                glowColor = Renk.alpha(vurgu, 0.25f),
                glow = g.toFloat(),
                stroke = kil().toFloat(),
            )
            minimumHeight = dp(36) + 2 * g
            setPadding(g + dp(7), g, g + dp(15), g)
            setOnClickListener { ac() }
        }
        val amber = vurgu == Renk.AMBER
        val rozet = FrameLayout(c).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                if (amber) intArrayOf(0xFFFFB340.toInt(), 0xFFFF9F0A.toInt()) else Renk.DO_GRADIENT,
            ).apply { shape = GradientDrawable.OVAL }
        }
        if (amber) {
            rozet.addView(yazi("!", 13f, 0xFF000000.toInt(), kalin = true).apply { gravity = Gravity.CENTER },
                FrameLayout.LayoutParams(MATCH, MATCH))
        } else {
            rozet.addView(ikonGorunum(R.drawable.ada_ic_check, 12f, 0xFFFFFFFF.toInt()))
        }
        box.addView(rozet, LinearLayout.LayoutParams(dp(22), dp(22)))
        box.addView(yazi(t, 13.5f, Renk.TEXT, kalin = true).apply {
            isSingleLine = true
            ellipsize = TextUtils.TruncateAt.END
            maxWidth = enGenis() - 2 * g - dp(22 + 8 + 22)
            setPadding(dp(8), 0, 0, 0)
        })
        return box
    }

    // ---- the open card -------------------------------------------------------------------

    private fun acik(): View {
        val box = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            background = kart(28)
            elevation = dp(12).toFloat()
            setPadding(dp(16), dp(16), dp(16), dp(12))
            layoutParams = LinearLayout.LayoutParams(minOf(enGenis(), dp(420)), WRAP)
        }

        // Header: circle · "Saha · Gün A  Adım 3/9" · status badge. A tap on it folds the card.
        val bas = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setOnClickListener { kucult() }
        }
        daire.fill = 0.62f
        bas.addView(daire, LinearLayout.LayoutParams(dp(36), dp(36)))
        val ad = SpannableStringBuilder()
        span(ad, listOf(c.applicationInfo.loadLabel(c.packageManager).toString(), s("gun")).filter { it.isNotEmpty() }.joinToString(" · "), Renk.TEXT, 15f, true)
        if (s("adimYazi").isNotEmpty()) {
            ad.append("  ")
            span(ad, s("adimYazi"), Renk.TEXT2, 11.5f, true)
        }
        bas.addView(TextView(c).apply {
            text = ad
            letterSpacing = -0.013f
            isSingleLine = true
            ellipsize = TextUtils.TruncateAt.END
            includeFontPadding = false
            setPadding(dp(10), 0, dp(8), 0)
        }, LinearLayout.LayoutParams(0, WRAP, 1f))
        when {
            mod == "bitti" -> bas.addView(rozet(kelime("bitti"), Renk.GREEN, Renk.GREEN_TEXT))
            dikkat -> bas.addView(rozet(kelime("siraSende"), Renk.AMBER, Renk.AMBER_TEXT))
            mod == "mola" -> bas.addView(rozet(kelime("mola"), Renk.BLUE, Renk.BLUE_TEXT))
            else -> bas.addView(rozet(kelime("suruyor"), Renk.BLUE, Renk.BLUE_TEXT))
        }
        box.addView(bas)

        box.addView(simdiki(), LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = dp(12) })

        val liste = (d["liste"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        if (liste.isNotEmpty()) box.addView(gorevler(liste), LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = dp(10) })

        // Bottom: ‹ › through the day's exercises, then open the app, fold, close.
        val alt = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val beyaz10 = Renk.alpha(0xFFFFFFFF.toInt(), 0.10f)
        if (d["gezinme"] == true) {
            alt.addView(yuvarlak(R.drawable.ada_ic_chevron_left) { bas(it, "onceki") })
            alt.addView(yuvarlak(R.drawable.ada_ic_chevron_right) { bas(it, "sonraki") }, LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginStart = dp(6) })
        }
        alt.addView(View(c), LinearLayout.LayoutParams(0, 1, 1f))
        alt.addView(dugme(kelime("ac"), null, beyaz10, Renk.TEXT) { uygulamayiAc() })
        alt.addView(dugme(kelime("kucult"), R.drawable.ada_ic_chevron_up, beyaz10, Renk.TEXT) { kucult() }, LinearLayout.LayoutParams(WRAP, WRAP).apply { marginStart = dp(6) })
        alt.addView(yuvarlak(R.drawable.ada_ic_close) { bas(it, "kapat") }, LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginStart = dp(6) })
        box.addView(alt, LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = dp(8) })
        return box
    }

    /** The exercise to do now: animation, set, name, dose, what will be logged; the countdown; the buttons. */
    private fun simdiki(): View {
        val p = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            background = zemin(Renk.PANEL, dpf(18f))
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        val satir = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        if (kareler.isNotEmpty() || d["id"] != null) satir.addView(anim(76, 18))
        val col = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(if (satir.childCount > 0) dp(14) else 0, 0, 0, 0)
        }
        val ust = if (mod == "mola") kelime("mola").uppercase() else s("set")
        if (ust.isNotEmpty()) {
            col.addView(yazi(ust, 11.5f, if (dikkat) Renk.AMBER_TEXT else Renk.BLUE_TEXT, kalin = true).apply { letterSpacing = 0.06f })
        }
        // Fixed line counts, so the buttons below never move between exercises.
        col.addView(yazi(s("baslik"), 16f, Renk.TEXT, kalin = true).apply {
            isSingleLine = true
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(4), 0, 0)
        })
        if (s("doz").isNotEmpty()) {
            col.addView(yazi(s("doz"), 24f, Renk.TEXT, kalin = true).apply {
                fontFeatureSettings = "tnum"
                setPadding(0, dp(4), 0, 0)
            })
        }
        val not = s("not")
        val kayit = not.ifEmpty { s("kayit") }
        col.addView(yazi(kayit, 12.5f, if (not.isNotEmpty()) Renk.GREEN_TEXT else Renk.TEXT2).apply {
            setLines(2)
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(4), 0, 0)
        })
        satir.addView(col, LinearLayout.LayoutParams(0, WRAP, 1f))
        p.addView(satir)

        if (sayac) {
            val sure = yazi("0:00", 40f, Renk.TEXT, kalin = true).apply {
                gravity = Gravity.CENTER
                fontFeatureSettings = "tnum"
            }
            sayaclar += sure
            p.addView(sure, LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = dp(10) })
            val b = Cubuk(c)
            cubuk = b
            p.addView(b, LinearLayout.LayoutParams(MATCH, dp(4)).apply { topMargin = dp(8) })
            if (s("sonraki").isNotEmpty()) {
                p.addView(yazi(s("sonraki"), 12.5f, Renk.TEXT2).apply { gravity = Gravity.CENTER },
                    LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = dp(8) })
            }
        }

        // Second row: −15 / +15 in a rest, kg and reps steps before a set, "OK" for a timed warm-up.
        val dl = (d["dugmeler"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        if (dl.isNotEmpty() || mod == "set") {
            val sira = LinearLayout(c).apply {
                orientation = LinearLayout.HORIZONTAL
                isBaselineAligned = false
                // Kept (empty) when a step has no such buttons, so the main button stays where it was.
                minimumHeight = dp(40)
                if (dl.isEmpty()) visibility = View.INVISIBLE
            }
            dl.forEachIndexed { k, m ->
                val e = m["e"] as? String ?: return@forEachIndexed
                sira.addView(yazi(m["y"] as? String ?: "", if (dl.size > 2) 13f else 14f, Renk.TEXT, kalin = true).apply {
                    gravity = Gravity.CENTER
                    background = zemin(Renk.alpha(0xFFFFFFFF.toInt(), 0.08f), dpf(14f))
                    setOnClickListener { bas(it, e) }
                }, LinearLayout.LayoutParams(0, dp(40), 1f).apply { if (k > 0) marginStart = dp(6) })
            }
            p.addView(sira, LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = dp(10) })
        }

        val birincil = s("birincil")
        if (birincil.isNotEmpty()) {
            val (bg, fg) = when {
                mod == "bitti" -> Renk.alpha(Renk.GREEN, 0.18f) to Renk.GREEN_TEXT
                dikkat -> Renk.AMBER to 0xFF000000.toInt()
                else -> Renk.BLUE to 0xFFFFFFFF.toInt()
            }
            p.addView(yazi(birincil, 15f, fg, kalin = true).apply {
                gravity = Gravity.CENTER
                isSingleLine = true
                ellipsize = TextUtils.TruncateAt.END
                background = zemin(bg, dpf(22f))
                setPadding(dp(14), 0, dp(14), 0)
                setOnClickListener { bas(it, "birincil") }
            }, LinearLayout.LayoutParams(MATCH, dp(46)).apply { topMargin = dp(10) })
        }
        return p
    }

    /** The day's exercises one under another, like Agent Presence's task list: a window around the current one. */
    private fun gorevler(liste: List<Map<*, *>>): View {
        val box = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            background = zemin(Renk.PANEL, dpf(16f))
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }
        val enCok = 4
        val simdi = liste.indexOfFirst { it["d"] == "s" }.let { if (it < 0) liste.indexOfFirst { r -> r["d"] == "q" } else it }.coerceAtLeast(0)
        val bas = if (liste.size <= enCok) 0 else (simdi - 1).coerceIn(0, liste.size - enCok)
        val son = minOf(liste.size, bas + enCok)
        // Always the same height (the "+n" lines keep their place even when empty), so the buttons under the list
        // never move as the window slides.
        val uzun = liste.size > enCok
        if (uzun) box.addView(dahaSatiri("+$bas", liste.take(bas).all { it["d"] == "b" }).apply { if (bas == 0) visibility = View.INVISIBLE })
        for (k in bas until son) {
            if (k > bas && liste[k - 1]["d"] != "s" && liste[k]["d"] != "s") box.addView(ayrac())
            else if (k > bas) box.addView(ayrac().apply { visibility = View.INVISIBLE })
            box.addView(gorevSatiri(liste[k], k + 1), LinearLayout.LayoutParams(MATCH, dp(46)))
        }
        if (uzun) box.addView(dahaSatiri("+${liste.size - son}", false).apply { if (son >= liste.size) visibility = View.INVISIBLE })
        return box
    }

    private fun gorevSatiri(g: Map<*, *>, no: Int): View {
        val durum = g["d"] as? String ?: "q"
        val vurgu = when (durum) {
            "b" -> Renk.GREEN
            "s" -> if (dikkat) Renk.AMBER else Renk.BLUE
            else -> Renk.PENDING
        }
        val satir = LinearLayout(c).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = dp(42)
            setPadding(dp(6), dp(5), dp(10), dp(5))
            if (durum == "s") {
                background = GradientDrawable(
                    GradientDrawable.Orientation.LEFT_RIGHT,
                    intArrayOf(Renk.alpha(vurgu, 0.14f), Renk.alpha(vurgu, 0f)),
                ).apply { cornerRadius = dpf(12f) }
            }
        }
        val daireK = AdaDaire(c).apply {
            fill = 0.625f
            if (durum == "s") oran = (g["oran"] as? Number)?.toFloat() ?: 0f
            bind(
                when (durum) {
                    "b" -> AdaDaire.Look.DONE
                    "s" -> if (dikkat) AdaDaire.Look.WAITING else AdaDaire.Look.ACTIVE
                    else -> AdaDaire.Look.PENDING
                },
                no, null,
            )
        }
        satir.addView(daireK, LinearLayout.LayoutParams(dp(30), dp(30)))
        val col = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), 0, dp(8), 0)
        }
        val ad = g["ad"] as? String ?: ""
        col.addView(
            when (durum) {
                "b" -> yazi(ad, 13.5f, Renk.TEXT_DONE)
                "q" -> yazi(ad, 13.5f, Renk.PENDING)
                else -> yazi(ad, 13.5f, Renk.TEXT, kalin = true)
            }.apply {
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            },
        )
        val alt = g["alt"] as? String ?: ""
        if (alt.isNotEmpty()) {
            col.addView(yazi(alt, 12f, if (durum == "s") Renk.TEXT2 else Renk.alpha(Renk.TEXT2, 0.7f)).apply {
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, dp(2), 0, 0)
            })
        }
        satir.addView(col, LinearLayout.LayoutParams(0, WRAP, 1f))
        satir.addView(
            when (durum) {
                "b" -> rozet(kelime("bitti"), Renk.GREEN, Renk.GREEN_TEXT)
                "s" -> if (dikkat) rozet(kelime("siraSende"), Renk.AMBER, Renk.AMBER_TEXT) else rozet(kelime("suruyor"), Renk.BLUE, Renk.BLUE_TEXT)
                else -> rozet(kelime("sirada"), Renk.PENDING, Renk.PENDING)
            },
        )
        return satir
    }

    private fun dahaSatiri(sayi: String, bitti: Boolean) = LinearLayout(c).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(14), dp(5), dp(10), dp(5))
        val (vurgu, fg) = if (bitti) Renk.GREEN to Renk.GREEN_TEXT else Renk.PENDING to Renk.PENDING
        addView(yazi(sayi, 12.5f, fg, kalin = true), LinearLayout.LayoutParams(0, WRAP, 1f))
        addView(rozet(kelime(if (bitti) "bitti" else "sirada"), vurgu, fg))
    }

    private fun ayrac() = View(c).apply {
        setBackgroundColor(Renk.DIVIDER)
        layoutParams = LinearLayout.LayoutParams(MATCH, kil()).apply {
            marginStart = dp(44)
            marginEnd = dp(10)
        }
    }

    // ---- small parts ---------------------------------------------------------------------

    private fun kart(r: Int) = GradientDrawable().apply {
        cornerRadius = dpf(r.toFloat())
        setColor(Renk.SURFACE)
        setStroke(kil(), Renk.BORDER)
    }

    private fun zemin(renk: Int, r: Float) = GradientDrawable().apply {
        cornerRadius = r
        setColor(renk)
    }

    private fun kil() = maxOf(1, (c.resources.displayMetrics.density * 0.75f).toInt())

    private fun enGenis() = (c.resources.displayMetrics.widthPixels * 0.92f).toInt()

    private fun yazi(t: CharSequence?, sp: Float, renk: Int, kalin: Boolean = false) = TextView(c).apply {
        text = t
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(renk)
        typeface = if (kalin) Yazi.kalin else Yazi.normal
        includeFontPadding = false
    }

    /** A status badge: capsule, 11.5 semibold, the accent at 16 % behind the accent's text color. */
    private fun rozet(kelime: String, vurgu: Int, fg: Int) = yazi(kelime, 11.5f, fg, kalin = true).apply {
        isSingleLine = true
        background = zemin(Renk.alpha(vurgu, 0.16f), dpf(12f))
        setPadding(dp(8), dp(3), dp(8), dp(3))
    }

    /** A capsule button: 30 dp tall inside a 40 dp touch target, optional leading icon, 12.5 semibold. */
    private fun dugme(t: String, ikon: Int?, bg: Int, fg: Int, f: (View) -> Unit) = yazi(t, 12.5f, fg, kalin = true).apply {
        isSingleLine = true
        gravity = Gravity.CENTER
        val v = dp(5)
        background = InsetDrawable(zemin(bg, dpf(15f)), 0, v, 0, v)
        minHeight = dp(40)
        setPadding(dp(if (ikon != null) 10 else 14), 0, dp(14), 0)
        if (ikon != null) {
            setCompoundDrawablesRelative(ikonCiz(ikon, 15f, fg), null, null, null)
            compoundDrawablePadding = dp(4)
        }
        setOnClickListener {
            it.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            f(it)
        }
    }

    /** A round icon button (‹, ›, ✕). */
    private fun yuvarlak(ikon: Int, f: (View) -> Unit): View = FrameLayout(c).apply {
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Renk.alpha(0xFFFFFFFF.toInt(), 0.10f))
        }
        layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
        addView(ikonGorunum(ikon, 20f, Renk.TEXT))
        setOnClickListener { f(it) }
    }

    private fun ikonGorunum(res: Int, sizeDp: Float, tint: Int): View {
        val px = dpf(sizeDp).toInt()
        return ImageView(c).apply {
            setImageDrawable(c.getDrawable(res)!!.mutate().apply { setTint(tint) })
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = FrameLayout.LayoutParams(px, px, Gravity.CENTER)
        }
    }

    private fun ikonCiz(res: Int, sizeDp: Float, tint: Int): Drawable = c.getDrawable(res)!!.mutate().apply {
        setTint(tint)
        val px = dpf(sizeDp).toInt()
        setBounds(0, 0, px, px)
    }

    /** The exercise's animation in a rounded square; the frames play in all of them at once. */
    private fun anim(boyDp: Int, yaricapDp: Int): View {
        val v = ImageView(c).apply {
            background = zemin(Renk.alpha(0xFFFFFFFF.toInt(), 0.06f), dpf(yaricapDp.toFloat()))
            scaleType = ImageView.ScaleType.FIT_CENTER
            val r = dpf(yaricapDp.toFloat())
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, o: Outline) = o.setRoundRect(0, 0, view.width, view.height, r)
            }
            clipToOutline = true
            layoutParams = LinearLayout.LayoutParams(dp(boyDp), dp(boyDp))
            if (kareler.isNotEmpty()) setImageBitmap(kareler[kareNo % kareler.size])
        }
        animlar += v
        return v
    }

    /** The name in the title style and the second part in the secondary style, on one line. */
    private fun baslikSatiri(ana: String, ikinci: String?): CharSequence {
        val sb = SpannableStringBuilder()
        span(sb, ana, Renk.TEXT, 15f, true)
        if (!ikinci.isNullOrBlank()) {
            sb.append("  ")
            span(sb, ikinci, Renk.TEXT2, 13f, false)
        }
        return sb
    }

    private fun span(sb: SpannableStringBuilder, t: String, renk: Int, sp: Float, kalin: Boolean) {
        val bas = sb.length
        sb.append(t)
        sb.setSpan(ForegroundColorSpan(renk), bas, sb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        val px = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, c.resources.displayMetrics).toInt()
        sb.setSpan(AbsoluteSizeSpan(px, false), bas, sb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (Build.VERSION.SDK_INT >= 28) {
            sb.setSpan(TypefaceSpan(if (kalin) Yazi.kalin else Yazi.normal), bas, sb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        } else if (kalin) {
            sb.setSpan(StyleSpan(Typeface.BOLD), bas, sb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    // ---- window placement ----------------------------------------------------------------

    private fun ustBosluk(): Int {
        if (Build.VERSION.SDK_INT >= 30) {
            return wm.currentWindowMetrics.windowInsets
                .getInsetsIgnoringVisibility(WindowInsets.Type.statusBars() or WindowInsets.Type.displayCutout()).top
        }
        val id = c.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) c.resources.getDimensionPixelSize(id) else dp(24)
    }

    /** The camera hole at the top of the screen, if the phone has one. */
    private fun kamera(): Rect? {
        if (Build.VERSION.SDK_INT >= 30) {
            return wm.currentWindowMetrics.windowInsets.displayCutout?.boundingRectTop?.takeIf { !it.isEmpty }
        }
        if (Build.VERSION.SDK_INT >= 28) {
            return kok.rootWindowInsets?.displayCutout?.boundingRects?.firstOrNull { it.top == 0 && !it.isEmpty }
        }
        return null
    }

    /** Minimal: right under the camera hole, centred on it. Compact and open: top centre, under the status bar. */
    private fun yerlestir(m: Mod, chip: Int, parlak: Boolean) {
        val top = ustBosluk()
        val pay = if (parlak) dp(18) else 0
        val gx: Int
        val gy: Int
        val gravity: Int
        if (m == Mod.MINIMAL) {
            kok.setPadding(pay, pay, pay, pay + dp(2))
            gravity = Gravity.TOP or Gravity.START
            val ortaX = kamera()?.centerX() ?: (c.resources.displayMetrics.widthPixels / 2)
            gx = ortaX - chip / 2 - pay
            gy = top + dp(4) - pay
        } else {
            val yan = maxOf(dp(6), pay)
            val ust = maxOf(dp(3), pay)
            kok.setPadding(yan, ust, yan, yan)
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            gx = 0
            gy = top + dp(4) - ust
        }
        // A wrap-content app window is first measured at the dialog width (~320 dp) and single-line text then
        // ellipsizes early; measured here against the whole screen and set exactly.
        val ekran = c.resources.displayMetrics
        kok.measure(
            View.MeasureSpec.makeMeasureSpec(ekran.widthPixels, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(ekran.heightPixels, View.MeasureSpec.AT_MOST),
        )
        val w = kok.measuredWidth.coerceAtMost(ekran.widthPixels)
        if (lp.gravity != gravity || lp.x != gx || lp.y != gy || lp.width != w) {
            lp.gravity = gravity
            lp.x = gx
            lp.y = gy
            lp.width = w
            // Right after addView the view is not attached yet, but it already has its window: update it anyway.
            if (kok.parent != null) runCatching { wm.updateViewLayout(kok, lp) }
        }
    }

    // ---- clocks ----------------------------------------------------------------------------

    private val oynat = object : Runnable {
        override fun run() {
            if (kareler.isEmpty()) return
            val b = kareler[kareNo % kareler.size]
            for (v in animlar) v.setImageBitmap(b)
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
        val son = bitis
        if (son > 0) {
            val kalanMs = son - System.currentTimeMillis()
            val kalan = max(0, ceil(kalanMs / 1000.0).toInt())
            val t = "${kalan / 60}:${(kalan % 60).toString().padStart(2, '0')}"
            for (v in sayaclar) v.text = t
            val oran = if (toplamSn > 0) (kalanMs / (toplamSn * 1000f)).coerceIn(0f, 1f) else 0f
            daire.oran = oran
            cubuk?.oran = oran
        } else {
            daire.oran = ((d["ilerleme"] as? Number)?.toFloat() ?: 0f)
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), c.resources.displayMetrics).toInt()
    private fun dpf(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, c.resources.displayMetrics)

    private companion object {
        const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
        const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    }
}

/** Thin progress bar for the countdown, in the island's blue. */
class Cubuk(c: Context) : View(c) {
    var oran = 0f
        set(v) { if (field != v) { field = v; invalidate() } }
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val r = RectF()

    override fun onDraw(cv: Canvas) {
        val h = height.toFloat()
        p.color = Renk.PENDING_FILL
        r.set(0f, 0f, width.toFloat(), h)
        cv.drawRoundRect(r, h / 2, h / 2, p)
        p.color = Renk.BLUE
        r.set(0f, 0f, width * oran, h)
        if (oran > 0f) cv.drawRoundRect(r, h / 2, h / 2, p)
    }
}
