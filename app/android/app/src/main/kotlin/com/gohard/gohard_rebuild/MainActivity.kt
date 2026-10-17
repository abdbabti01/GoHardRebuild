package com.gohard.gohard_rebuild

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Whether this build has a Google Maps key (docs/RUN_WALK.md › Map). Without one the app draws the route itself.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gohard/maps").setMethodCallHandler { _, result ->
            val key = try {
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData?.getString("com.google.android.geo.API_KEY")
            } catch (e: Exception) {
                null
            }
            result.success(!key.isNullOrBlank())
        }
    }
}
