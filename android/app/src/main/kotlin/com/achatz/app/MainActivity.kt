package com.achatz.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.achatz.app/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getFreeDiskSpace") {
                try {
                    val freeBytes = filesDir.usableSpace
                    result.success(freeBytes)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Disk space unavailable", e.message)
                }
            } else if (call.method == "getTotalDiskSpace") {
                try {
                    val totalBytes = filesDir.totalSpace
                    result.success(totalBytes)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Total disk space unavailable", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
