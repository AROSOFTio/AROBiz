package com.example.arosoft

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var exportResult: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val exportRequest = 7315

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crown_docs/export").setMethodCallHandler { call, result ->
            if (call.method != "savePdf") { result.notImplemented(); return@setMethodCallHandler }
            if (exportResult != null) { result.error("busy", "An export is already open.", null); return@setMethodCallHandler }
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty()) { result.error("invalid", "No PDF to save.", null); return@setMethodCallHandler }
            exportBytes = bytes
            exportResult = result
            try {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/pdf"
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "document.pdf")
                }
                startActivityForResult(intent, exportRequest)
            } catch (e: Exception) {
                exportBytes = null
                exportResult = null
                result.error("export", "No file picker is available.", null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = exportResult ?: return
        val bytes = exportBytes
        exportResult = null
        exportBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) { result.success(false); return }
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri, "w") ?: throw IllegalStateException("Cannot open selected file")
                stream.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("export", "Could not write the selected PDF file.", null) }
            }
        }.start()
    }
}
