package com.learningapp.learning_app

import android.content.ClipData
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.ByteArrayOutputStream
import java.io.File

internal class CertificateDocuments(private val activity: MainActivity) {
    private val exported = mutableSetOf<Uri>()
    private val maxBytes = 10 * 1024 * 1024

    fun recordExport(uri: Uri) {
        exported.add(uri)
    }

    private fun savedUri(value: String): Uri {
        val uri = Uri.parse(value)
        require(uri in exported) { "Save this certificate before opening or sharing it." }
        return uri
    }

    fun share(value: String) {
        val uri = savedUri(value)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(activity.contentResolver, "Skillverse certificate", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(intent, "Share certificate PDF"))
    }

    fun render(bytes: ByteArray?, value: String?, callback: (Result<ByteArray>) -> Unit) {
        val uri = value?.let { savedUri(it) }
        require((bytes != null) xor (uri != null)) { "Choose a PDF to preview." }
        require(bytes == null || bytes.size <= maxBytes) { "The PDF is too large to preview." }
        Thread {
            val rendered = runCatching {
                val temporary = File.createTempFile("skillverse_certificate_", ".pdf", activity.cacheDir)
                try {
                    if (bytes != null) {
                        temporary.writeBytes(bytes)
                    } else {
                        val input = activity.contentResolver.openInputStream(checkNotNull(uri))
                            ?: error("The exported PDF could not be read.")
                        input.use { source ->
                            temporary.outputStream().use { target ->
                                val buffer = ByteArray(8192)
                                var size = 0
                                while (true) {
                                    val count = source.read(buffer)
                                    if (count == -1) break
                                    size += count
                                    require(size <= maxBytes) { "The exported PDF is too large to preview." }
                                    target.write(buffer, 0, count)
                                }
                            }
                        }
                    }
                    renderPage(temporary)
                } finally {
                    temporary.delete()
                }
            }
            activity.runOnUiThread { callback(rendered) }
        }.start()
    }

    private fun renderPage(file: File): ByteArray {
        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try {
            PdfRenderer(descriptor)
        } catch (error: Exception) {
            descriptor.close()
            throw error
        }
        return renderer.use {
            check(it.pageCount == 1) { "A course certificate must contain one page." }
            it.openPage(0).use { page ->
                val scale = 1400.0 / maxOf(page.width, page.height)
                val bitmap = Bitmap.createBitmap(
                    maxOf(1, (page.width * scale).toInt()),
                    maxOf(1, (page.height * scale).toInt()),
                    Bitmap.Config.ARGB_8888
                )
                try {
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    ByteArrayOutputStream().use { output ->
                        check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
                        output.toByteArray()
                    }
                } finally {
                    bitmap.recycle()
                }
            }
        }
    }
}
