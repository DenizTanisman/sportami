package dev.deniz.saha

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between the Dart side (lib/ada.dart) and what the workout shows outside the app:
 * the ongoing notification (a Live Update on Android 16) and the island over other apps.
 * Dart decides what they say; this side only draws them and passes taps back.
 */
object Ada {
    var kanal: MethodChannel? = null
    var durum: Map<*, *> = emptyMap<Any, Any>()
    var servis: AdaServis? = null
    var app: Context? = null

    /** Whether a workout is on (notification, maybe the island). The service checks it once it has started. */
    var istenen = false

    private val kareBaytlari = LinkedHashMap<String, Pair<Int, List<ByteArray>>>()
    private var cozulen: Pair<String, Pair<Int, List<Bitmap>>>? = null

    fun izinVar(c: Context) = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(c)

    fun bildirimIzni(c: Context) = Build.VERSION.SDK_INT < 33 ||
        c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun goster(c: Context): Boolean {
        istenen = true
        val s = servis
        if (s != null) {
            s.yenile()
            return true
        }
        return try {
            val i = Intent(c, AdaServis::class.java)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
            true
        } catch (_: Exception) {
            // Android does not let a background app start a foreground service: the notification still shows.
            Bildirim.yayinla(c)
            true
        }
    }

    fun yenile(c: Context) {
        val s = servis
        if (s != null) s.yenile() else if (istenen) Bildirim.yayinla(c)
    }

    /** Never stops the service before it has called startForeground; it stops itself instead. */
    fun gizle(c: Context?) {
        istenen = false
        servis?.stopSelf()
        c?.let { Bildirim.kaldir(it) }
    }

    fun eylem(a: String) {
        kanal?.invokeMethod("eylem", a)
    }

    fun kareKaydet(id: String, ms: Int, kareler: List<ByteArray>) {
        kareBaytlari.remove(id)
        kareBaytlari[id] = ms to kareler
        while (kareBaytlari.size > 24) kareBaytlari.remove(kareBaytlari.keys.first())
        if (cozulen?.first == id) cozulen = null
        servis?.yenile()
    }

    /** Frames of one exercise as bitmaps; only the one on screen is kept decoded. */
    fun kareler(id: String?): Pair<Int, List<Bitmap>>? {
        if (id == null) return null
        cozulen?.let { if (it.first == id) return it.second }
        val (ms, b) = kareBaytlari[id] ?: return null
        val bmp = b.mapNotNull { BitmapFactory.decodeByteArray(it, 0, it.size) }
        if (bmp.isEmpty()) return null
        cozulen = id to (ms to bmp)
        return ms to bmp
    }

    /** End of a rest or a timed set while the app is in the background: buzz and ring. */
    fun uyar(c: Context) {
        try {
            val v = c.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val desen = longArrayOf(0, 260, 140, 260, 140, 420)
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createWaveform(desen, -1)) else @Suppress("DEPRECATION") v.vibrate(desen, -1)
        } catch (_: Exception) {}
        try {
            RingtoneManager.getRingtone(c, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))?.play()
        } catch (_: Exception) {}
    }
}

/** Foreground service that keeps the app's process (and its rest timer) alive while training. */
class AdaServis : Service() {
    private var gorunum: AdaGorunum? = null
    private val el = Handler(Looper.getMainLooper())
    private var alarmZamani = 0L
    private val alarm = Runnable {
        if (Ada.durum["arkada"] == true) Ada.uyar(this)
        gorunum?.uyar()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Ada.servis = this
        val n = Bildirim.olustur(this)
        try {
            if (Build.VERSION.SDK_INT >= 34) startForeground(Bildirim.ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(Bildirim.ID, n)
        } catch (_: Exception) {
            Bildirim.yayinla(this)
            stopSelf()
            return
        }
        if (!Ada.istenen) {
            stopSelf()
            return
        }
        yenile()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Ada.istenen) stopSelf() else yenile()
        return START_NOT_STICKY
    }

    fun yenile() {
        val d = Ada.durum
        Bildirim.yayinla(this)
        // The island: only when Dart asks for it (app in the background, island on) and it is allowed.
        if (d["ada"] == true && Ada.izinVar(this)) {
            if (gorunum == null) {
                gorunum = try {
                    AdaGorunum(this, getSystemService(WINDOW_SERVICE) as WindowManager).also { it.ekle() }
                } catch (_: Exception) {
                    null
                }
            }
            gorunum?.yenile(d)
        } else {
            gorunum?.kaldir()
            gorunum = null
        }
        // Rest or timed set: ring at its end even if nothing else happens.
        val son = ((d["molaSon"] ?: d["isSon"]) as? Number)?.toLong() ?: 0L
        if (son != alarmZamani) {
            alarmZamani = son
            el.removeCallbacks(alarm)
            val kalan = son - System.currentTimeMillis()
            if (kalan > 0) el.postDelayed(alarm, kalan)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
    }

    override fun onDestroy() {
        el.removeCallbacks(alarm)
        gorunum?.kaldir()
        gorunum = null
        if (Ada.servis === this) Ada.servis = null
        if (!Ada.istenen) Bildirim.kaldir(this)
        super.onDestroy()
    }
}

/** Taps on the notification's buttons. Not exported: only our own PendingIntents reach it. */
class AdaEylem : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val e = intent.getStringExtra("e") ?: return
        Ada.eylem(e)
    }
}

/**
 * The ongoing notification, like Agent Presence's: title, one line, the day's exercises as progress segments and
 * the main button. On Android 16 it asks to be a Live Update (pinned at the top, a chip in the status bar).
 */
object Bildirim {
    const val ID = 0x5A4A
    private const val KANAL = "antrenman"

    private fun kanal(c: Context): NotificationManager {
        val nm = c.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            // The first island version used a silent channel the status bar hides; Live Updates need more.
            if (nm.getNotificationChannel("ada") != null) nm.deleteNotificationChannel("ada")
            if (nm.getNotificationChannel(KANAL) == null) {
                val L = Ada.durum["L"] as? Map<*, *>
                nm.createNotificationChannel(NotificationChannel(KANAL, L?.get("kanal") as? String ?: "Workout", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                })
            }
        }
        return nm
    }

    fun yayinla(c: Context) {
        val nm = kanal(c)
        runCatching { nm.notify(ID, olustur(c)) }
    }

    fun kaldir(c: Context) {
        c.getSystemService(NotificationManager::class.java).cancel(ID)
    }

    private fun s(d: Map<*, *>, k: String) = d[k] as? String ?: ""

    private fun eylemNiyeti(c: Context, e: String, kod: Int) = PendingIntent.getBroadcast(
        c, kod,
        Intent(c, AdaEylem::class.java).setAction("dev.deniz.saha.ADA.$e").putExtra("e", e),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun olustur(c: Context): Notification {
        kanal(c)
        val d = Ada.durum
        val mod = s(d, "mod")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, KANAL) else @Suppress("DEPRECATION") Notification.Builder(c)
        val renk = when {
            mod == "bitti" -> Renk.GREEN
            d["dikkat"] == true -> Renk.AMBER
            else -> Renk.BLUE
        }
        val ac = PendingIntent.getActivity(
            c, 0,
            Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val baslik = s(d, "nBaslik").ifEmpty { c.applicationInfo.loadLabel(c.packageManager).toString() }
        val metin = s(d, "nMetin")
        b.setSmallIcon(R.drawable.ada_bildirim)
            .setContentTitle(baslik)
            .setContentText(metin)
            .setContentIntent(ac)
            .setColor(renk)
            .setOngoing(mod != "bitti")
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
        s(d, "nAlt").takeIf { it.isNotEmpty() }?.let { b.setSubText(it) }

        // A rest or a timed set counts down by itself (in the status bar chip too).
        val son = ((d["molaSon"] ?: d["isSon"]) as? Number)?.toLong() ?: 0L
        val sayiyor = son > System.currentTimeMillis()
        if (sayiyor) {
            b.setWhen(son).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= 24) b.setChronometerCountDown(true)
        } else {
            b.setShowWhen(false)
        }

        val eylemler = (d["nEylemler"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        eylemler.take(3).forEachIndexed { i, m ->
            val e = m["e"] as? String ?: return@forEachIndexed
            @Suppress("DEPRECATION")
            b.addAction(Notification.Action.Builder(null, m["y"] as? String ?: "", eylemNiyeti(c, e, 10 + i)).build())
        }

        val toplam = (d["toplam"] as? Number)?.toInt() ?: 0
        val ilerleme = ((d["ilerlemeTum"] as? Number)?.toFloat() ?: 0f).coerceIn(0f, toplam.toFloat())
        if (Build.VERSION.SDK_INT >= 36 && mod != "bitti") {
            val style = Notification.ProgressStyle().setStyledByProgress(true)
            if (toplam > 0) {
                // One segment per exercise of the day (one long bar when there are too many to tell apart).
                val parcalar = if (toplam <= 12) (1..toplam).map { Notification.ProgressStyle.Segment(100).setColor(renk) }
                else listOf(Notification.ProgressStyle.Segment(toplam * 100).setColor(renk))
                style.setProgressSegments(parcalar)
                style.setProgress((ilerleme * 100).toInt())
            } else {
                style.setProgressIndeterminate(true)
            }
            b.setStyle(style)
            if (!sayiyor) s(d, "nKisa").takeIf { it.isNotEmpty() }?.let { b.setShortCriticalText(it) }
            // Notification.Builder#setRequestPromotedOngoing is API 36.1; the extra is what it sets.
            b.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
        } else {
            b.setStyle(Notification.BigTextStyle().bigText(metin))
            if (toplam > 0 && mod != "bitti") b.setProgress(toplam * 100, (ilerleme * 100).toInt(), false)
        }
        return b.build()
    }
}
