package dev.deniz.saha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between the Dart side (lib/ada.dart) and the island drawn over other apps.
 * Dart decides what the island says; this side only draws it and passes taps back.
 */
object Ada {
    var kanal: MethodChannel? = null
    var durum: Map<*, *> = emptyMap<Any, Any>()
    var servis: AdaServis? = null

    /** Whether the island should be up. The service checks it once it has started. */
    var istenen = false

    private val kareBaytlari = LinkedHashMap<String, Pair<Int, List<ByteArray>>>()
    private var cozulen: Pair<String, Pair<Int, List<Bitmap>>>? = null

    fun izinVar(c: Context) = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(c)

    fun goster(c: Context): Boolean {
        if (!izinVar(c)) return false
        istenen = true
        val s = servis
        if (s != null) {
            s.yenile()
            return true
        }
        val i = Intent(c, AdaServis::class.java)
        return try {
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
            true
        } catch (_: Exception) {
            istenen = false
            false
        }
    }

    fun yenile() {
        servis?.yenile()
    }

    /** Never stops the service before it has called startForeground; it stops itself instead. */
    fun gizle() {
        istenen = false
        servis?.stopSelf()
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
}

/** Foreground service that keeps the island (and the app's process) alive while training. */
class AdaServis : Service() {
    private var gorunum: AdaGorunum? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Ada.servis = this
        onPlanaAl()
        if (!Ada.istenen || !Ada.izinVar(this)) {
            stopSelf()
            return
        }
        try {
            gorunum = AdaGorunum(this, getSystemService(WINDOW_SERVICE) as WindowManager).also {
                it.ekle()
                it.yenile(Ada.durum)
            }
        } catch (_: Exception) {
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Ada.istenen) stopSelf() else yenile()
        return START_NOT_STICKY
    }

    fun yenile() {
        gorunum?.yenile(Ada.durum)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
    }

    override fun onDestroy() {
        gorunum?.kaldir()
        gorunum = null
        if (Ada.servis === this) Ada.servis = null
        super.onDestroy()
    }

    private fun onPlanaAl() {
        val L = Ada.durum["L"] as? Map<*, *>
        val baslik = L?.get("bildirim") as? String ?: applicationInfo.loadLabel(packageManager).toString()
        val alt = L?.get("bildirimAlt") as? String ?: ""
        val ac = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n: Notification = if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(KANAL) == null) {
                nm.createNotificationChannel(NotificationChannel(KANAL, baslik, NotificationManager.IMPORTANCE_MIN).apply {
                    setShowBadge(false)
                })
            }
            Notification.Builder(this, KANAL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }.setSmallIcon(applicationInfo.icon)
            .setContentTitle(baslik)
            .setContentText(alt)
            .setContentIntent(ac)
            .setOngoing(true)
            .build()
        startForeground(1, n)
    }

    companion object {
        const val KANAL = "ada"
    }
}
