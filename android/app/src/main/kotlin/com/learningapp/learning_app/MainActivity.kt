package com.learningapp.learning_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private data class DocumentExport(
        val bytes: ByteArray, val result: MethodChannel.Result, val isCertificate: Boolean
    )
    private val certificates = CertificateDocuments(this)
    private var pendingExport: DocumentExport? = null
    private val documentRequest = 3147
    private val notificationRequest = 3150
    private data class PendingReminder(val hour: Int, val minute: Int, val result: MethodChannel.Result)
    private var pendingReminder: PendingReminder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "skillverse/build").setMethodCallHandler { call, result ->
            if (call.method != "info") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(packageName, 0)
                @Suppress("DEPRECATION")
                val code = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                result.success(mapOf("version" to (info.versionName ?: "Unavailable"), "build" to code.toString()))
            } catch (_: Exception) {
                result.error("build_info", "Build information is unavailable.", null)
            }
        }
        MethodChannel(messenger, "skillverse/certificates").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "savePdf" -> saveDocument(
                        call.argument("bytes"), call.argument("filename"), "application/pdf",
                        result, isCertificate = true
                    )
                    "renderPdf" -> certificates.render(call.argument("bytes"), call.argument("uri")) {
                        it.fold(
                            onSuccess = { png -> result.success(png) },
                            onFailure = { error -> result.error("render_pdf", error.message, null) }
                        )
                    }
                    "sharePdf" -> {
                        certificates.share(requireNotNull(call.argument<String>("uri")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("certificate_pdf", error.message, null)
            }
        }
        MethodChannel(messenger, "skillverse/lesson_files").setMethodCallHandler { call, result ->
            if (call.method == "saveText") {
                val filename = call.argument<String>("filename")
                val extension = filename?.substringAfterLast('.', "")
                val mimeType = extension?.let { MimeTypeMap.getSingleton().getMimeTypeFromExtension(it) }
                    ?: "application/octet-stream"
                saveDocument(call.argument("bytes"), filename, mimeType, result)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(messenger, "skillverse/reminders").setMethodCallHandler { call, result ->
            when (call.method) {
                "get" -> result.success(LearningReminders.state(this))
                "set" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    val hour = call.argument<Int>("hour")
                    val minute = call.argument<Int>("minute")
                    if (enabled == null || hour == null || minute == null ||
                        hour !in 0..23 || minute !in 0..59) {
                        result.error("invalid_reminder", "A valid time and reminder setting are required.", null)
                    } else if (pendingReminder != null) {
                        result.error("reminder_busy", "Finish the notification permission prompt first.", null)
                    } else if (enabled && LearningReminders.requiresPermission(this)) {
                        pendingReminder = PendingReminder(hour, minute, result)
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequest)
                    } else {
                        updateReminder(enabled, hour, minute, result)
                    }
                }
                else -> result.notImplemented()
            }
        }

    }

    private fun updateReminder(enabled: Boolean, hour: Int, minute: Int, result: MethodChannel.Result) {
        try {
            result.success(LearningReminders.update(this, enabled, hour, minute))
        } catch (error: Exception) {
            result.error("reminder_failed", error.message, null)
        }
    }

    @Deprecated("Used by the FlutterActivity notification permission callback")
    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationRequest) return
        val request = pendingReminder ?: return
        pendingReminder = null
        updateReminder(!LearningReminders.requiresPermission(this), request.hour, request.minute, request.result)
    }

    private fun saveDocument(
        bytes: ByteArray?,
        filename: String?,
        mimeType: String,
        result: MethodChannel.Result,
        isCertificate: Boolean = false
    ) {
        if (pendingExport != null) {
            result.error("export_active", "Finish the current save dialog first.", null)
            return
        }
        if (bytes == null || filename.isNullOrBlank()) {
            result.error("invalid_document", "Document bytes and filename are required.", null)
            return
        }
        pendingExport = DocumentExport(bytes, result, isCertificate)
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, filename)
            }
            startActivityForResult(intent, documentRequest)
        } catch (error: Exception) {
            pendingExport = null
            result.error("save_unavailable", error.message, null)
        }
    }

    @Deprecated("Used by the FlutterActivity document-save callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != documentRequest) return
        val export = pendingExport ?: return
        pendingExport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            export.result.success(null)
            return
        }
        try {
            val output = contentResolver.openOutputStream(uri, "w")
                ?: error("The selected location could not be opened.")
            output.use { it.write(export.bytes) }
            if (export.isCertificate) certificates.recordExport(uri)
            export.result.success(uri.toString())
        } catch (error: Exception) {
            export.result.error("save_failed", error.message, null)
        }
    }
}
