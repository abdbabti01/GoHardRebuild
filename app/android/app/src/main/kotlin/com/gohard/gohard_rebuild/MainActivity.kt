package com.gohard.gohard_rebuild

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.time.Instant

class MainActivity : FlutterActivity() {
    private val scope = MainScope()
    private var motionResult: MethodChannel.Result? = null
    private var dailyResult: MethodChannel.Result? = null

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
        // Steps (docs/RUN_WALK.md › Steps): the phone's step counter during a recording, and Health Connect's daily total.
        // Nothing is estimated here and nothing leaves the phone.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gohard/steps").setMethodCallHandler { call, result ->
            when (call.method) {
                "access" -> result.success(motionAccess())
                "request" -> requestMotion(result)
                "dailyAccess" -> scope.launch { result.success(dailyAccess()) }
                "dailyRequest" -> requestDaily(result)
                "daily" -> scope.launch { result.success(daily(call.argument<Number>("from")!!.toLong(), call.argument<Number>("to")!!.toLong())) }
                "vibrate" -> { vibrate(); result.success(null) }
                "openSettings" -> { openSettings(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "gohard/steps/live").setStreamHandler(StepStream(this))
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private val prefs get() = getSharedPreferences("gohard.steps", Context.MODE_PRIVATE)

    // ---------------------------------------------------------------- motion (the step counter)

    private fun motionAccess(): String {
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        if (sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) == null) return "unavailable"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return "allowed" // no runtime permission before Android 10
        if (checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED) return "allowed"
        val asked = prefs.getBoolean("motionAsked", false)
        return if (asked && !shouldShowRequestPermissionRationale(Manifest.permission.ACTIVITY_RECOGNITION)) "blocked" else "notAllowed"
    }

    private fun requestMotion(result: MethodChannel.Result) {
        val now = motionAccess()
        if (now != "notAllowed" || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return result.success(now)
        motionResult?.success(now)
        motionResult = result
        prefs.edit().putBoolean("motionAsked", true).apply()
        requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQ_MOTION)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_MOTION) {
            motionResult?.success(motionAccess())
            motionResult = null
        }
    }

    // ---------------------------------------------------------------- daily total (Health Connect, steps only)

    private val stepsRead = HealthPermission.getReadPermission(StepsRecord::class)

    private suspend fun dailyAccess(): String {
        if (HealthConnectClient.getSdkStatus(this) != HealthConnectClient.SDK_AVAILABLE) return "unavailable"
        return try {
            val granted = HealthConnectClient.getOrCreate(this).permissionController.getGrantedPermissions()
            when {
                granted.contains(stepsRead) -> "allowed"
                prefs.getInt("dailyDenied", 0) >= 2 -> "blocked" // Health Connect stops asking after two refusals
                else -> "notAllowed"
            }
        } catch (e: Exception) {
            "unavailable"
        }
    }

    private fun requestDaily(result: MethodChannel.Result) {
        scope.launch {
            val now = dailyAccess()
            if (now != "notAllowed") return@launch result.success(now)
            dailyResult?.success(now)
            dailyResult = result
            val contract = PermissionController.createRequestPermissionResultContract()
            @Suppress("DEPRECATION")
            startActivityForResult(contract.createIntent(this@MainActivity, setOf(stepsRead)), REQ_DAILY)
        }
    }

    // FlutterActivity is not a ComponentActivity, so the result comes here rather than through registerForActivityResult.
    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_DAILY) return
        val granted = PermissionController.createRequestPermissionResultContract().parseResult(resultCode, data).contains(stepsRead)
        if (!granted) prefs.edit().putInt("dailyDenied", prefs.getInt("dailyDenied", 0) + 1).apply()
        scope.launch {
            dailyResult?.success(dailyAccess())
            dailyResult = null
        }
    }

    /** Health Connect's own total for the range: it resolves overlapping sources (phone, watch, apps), so nothing is added. */
    private suspend fun daily(from: Long, to: Long): Map<String, Any>? = try {
        val r = HealthConnectClient.getOrCreate(this).aggregate(
            AggregateRequest(setOf(StepsRecord.COUNT_TOTAL), TimeRangeFilter.between(Instant.ofEpochMilli(from), Instant.ofEpochMilli(to))))
        val total = r[StepsRecord.COUNT_TOTAL]
        mapOf("steps" to (total ?: 0L), "recorded" to (total != null))
    } catch (e: Exception) {
        null
    }

    // ---------------------------------------------------------------- vibration and settings

    private fun vibrate() {
        val v: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (v.hasVibrator()) v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 180, 120, 180), -1))
    }

    private fun openSettings() {
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    companion object {
        private const val REQ_MOTION = 7301
        private const val REQ_DAILY = 7302
    }
}

/** The step counter's readings while listened to: {c: steps since the phone started, t: when they were counted (UTC ms)}. */
private class StepStream(private val context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private val sm get() = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return events.error("UNAVAILABLE", "No step counter", null)
        sink = events
        // A reading carries the time of the steps, also when the phone delivers them late in a batch.
        if (!sm.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)) events.error("UNAVAILABLE", "Step counter refused", null)
    }

    override fun onCancel(arguments: Any?) {
        sm.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val wall = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1_000_000
        sink?.success(mapOf("c" to event.values[0].toLong(), "t" to wall))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
