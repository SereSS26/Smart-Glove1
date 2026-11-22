package ro.manusa.manusa_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * „Trimite către Mănușa” din alte aplicații (Notițe, WhatsApp, Keep, Galerie):
 * textul sau poza rețetei ajunge în aplicație pe canalul `ro.manusa/share`.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ro.manusa/share").also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
        pending = read(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val item = read(intent) ?: return
        val ch = channel
        if (ch == null) pending = item else ch.invokeMethod("shared", item)
    }

    private fun read(intent: Intent?): Map<String, String>? {
        if (intent?.action != Intent.ACTION_SEND) return null
        val type = intent.type ?: return null
        if (type.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
            return mapOf("text" to text)
        }
        if (type.startsWith("image/")) {
            val uri: Uri = (if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }) ?: return null
            return try {
                val out = File(cacheDir, "reteta_${System.currentTimeMillis()}.jpg")
                contentResolver.openInputStream(uri)?.use { input -> out.outputStream().use { input.copyTo(it) } } ?: return null
                mapOf("image" to out.absolutePath)
            } catch (e: Exception) {
                null
            }
        }
        return null
    }
}
