package app.presyomlang.personal

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private class PendingExport(val result: MethodChannel.Result, val bytes: ByteArray) {
        var writing = false
    }

    private val exportExecutor = Executors.newSingleThreadExecutor()
    private var pendingExport: PendingExport? = null
    private var exportChannel: MethodChannel? = null
    private var locationChannel: MethodChannel? = null
    private var location: AndroidLocation? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        exportChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.presyomlang/export_writer",
        ).also { channel -> channel.setMethodCallHandler(::handleExportCall) }
        location = AndroidLocation(this)
        locationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.presyomlang/location",
        ).also { channel -> channel.setMethodCallHandler { call, result ->
            location?.handle(call, result)
                ?: result.error("unavailable", "Location is unavailable. Enter it manually.", null)
        } }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (location?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onStart() {
        super.onStart()
        location?.onStart()
    }

    override fun onStop() {
        location?.onStop()
        super.onStop()
    }

    private fun handleExportCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveExport") {
            result.notImplemented()
            return
        }
        if (pendingExport != null) {
            result.error("export_busy", "An export is already in progress.", null)
            return
        }
        val arguments = call.arguments as? Map<*, *>
        val name = arguments?.get("fileName") as? String
        val mimeType = arguments?.get("mimeType") as? String
        val bytes = arguments?.get("bytes") as? ByteArray
        if (name.isNullOrBlank() || name.length > 200 ||
            name.any { it == '/' || it == '\\' || it.code < 32 } ||
            mimeType !in listOf("application/json", "text/csv") || bytes == null
        ) {
            result.error("invalid_export", "The export request is invalid.", null)
            return
        }
        val request = PendingExport(result, bytes)
        pendingExport = request
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, name)
            }
            startActivityForResult(intent, EXPORT_REQUEST_CODE)
        } catch (_: Exception) {
            finishExportError(request, "export_picker_failed")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != EXPORT_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val request = pendingExport ?: return
        if (request.writing) return
        if (resultCode == Activity.RESULT_CANCELED) {
            pendingExport = null
            request.result.success(null)
            return
        }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finishExportError(request, "export_destination_missing")
            return
        }
        request.writing = true
        try {
            exportExecutor.execute {
                try {
                    CheckedExportWriter.write(request.bytes) {
                        contentResolver.openOutputStream(uri, "wt")
                    }
                    runOnUiThread {
                        if (pendingExport === request) {
                            pendingExport = null
                            request.result.success(true)
                        }
                    }
                } catch (_: Exception) {
                    // Never send a provider URI, exception text, or export data
                    // to Flutter logs or the UI. Complete permission/I/O failures.
                    runOnUiThread { finishExportError(request, "export_write_failed") }
                }
            }
        } catch (_: Exception) {
            finishExportError(request, "export_write_failed")
        }
    }

    private fun finishExportError(request: PendingExport, code: String) {
        if (pendingExport !== request) return
        pendingExport = null
        request.result.error(code, "The export could not be completed.", null)
    }

    override fun onDestroy() {
        location?.onDestroy()
        locationChannel?.setMethodCallHandler(null)
        pendingExport?.let { finishExportError(it, "export_activity_closed") }
        exportChannel?.setMethodCallHandler(null)
        exportExecutor.shutdown()
        super.onDestroy()
    }

    private companion object {
        const val EXPORT_REQUEST_CODE = 0x504D
    }
}
