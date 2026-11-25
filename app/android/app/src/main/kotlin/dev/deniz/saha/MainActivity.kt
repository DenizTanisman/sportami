package dev.deniz.saha

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val kanal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "saha/ada")
        Ada.kanal = kanal
        kanal.setMethodCallHandler { call, result ->
            when (call.method) {
                "izin" -> result.success(Ada.izinVar(this))
                "izinIste" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    } catch (_: Exception) {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                    }
                    result.success(null)
                }
                "goster" -> {
                    Ada.durum = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    result.success(Ada.goster(applicationContext))
                }
                "guncelle" -> {
                    Ada.durum = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    Ada.yenile()
                    result.success(true)
                }
                "gizle" -> {
                    Ada.gizle()
                    result.success(null)
                }
                "kareler" -> {
                    val a = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    Ada.kareKaydet(a["id"] as String, (a["ms"] as Number).toInt(), a["kareler"] as List<ByteArray>)
                    result.success(null)
                }
                "arkayaAl" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        // The Dart side lives with this activity: without it the island could not log anything.
        Ada.gizle()
        Ada.kanal = null
        super.onDestroy()
    }
}
