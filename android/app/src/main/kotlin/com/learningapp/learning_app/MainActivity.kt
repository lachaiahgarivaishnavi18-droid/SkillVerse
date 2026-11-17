package com.learningapp.learning_app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingExport: MethodChannel.Result? = null
    private var pendingPdf: ByteArray? = null
    private val certificateRequest = 3147

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "skillverse/certificates")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingExport != null) {
                    result.error("export_active", "Finish the current save dialog first.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || filename == null) {
                    result.error("invalid_pdf", "PDF bytes and filename are required.", null)
                    return@setMethodCallHandler
                }
                pendingPdf = bytes
                pendingExport = result
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    startActivityForResult(intent, certificateRequest)
                } catch (error: Exception) {
                    pendingPdf = null
                    pendingExport = null
                    result.error("save_unavailable", error.message, null)
                }
            }
    }

    @Deprecated("Used by the FlutterActivity document-save callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != certificateRequest) return
        val result = pendingExport ?: return
        val bytes = pendingPdf
        pendingExport = null
        pendingPdf = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            checkNotNull(bytes) { "Certificate data is no longer available." }
            val output = contentResolver.openOutputStream(uri, "w")
                ?: error("The selected location could not be opened.")
            output.use { it.write(bytes) }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("save_failed", error.message, null)
        }
    }
}
