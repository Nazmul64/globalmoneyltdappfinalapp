package com.globalmoneyltd.globalmoneyltd

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.*
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "ad_timer_overlay"
        private const val TAG = "AdTimerOverlay"
        private const val OVERLAY_PERMISSION_REQUEST = 1001
    }

    // UI Components
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var timerTextView: TextView? = null

    // Timer Control
    private val handler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null
    private var countdownSeconds = 0
    private var originalDuration = 0
    private var timerStartTime: Long = 0
    private var isTimerRunning = false

    // Timer Type
    private var isBreakTimer = false

    // Flutter Communication
    private var methodChannel: MethodChannel? = null

    // Permission
    private var permissionGranted = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        suppressStartAppConsentDialog()
        super.onCreate(savedInstanceState)
        suppressStartAppConsentDialog()
    }

    private fun suppressStartAppConsentDialog() {
        try {
            // 1. Pre-seed SharedPreferences for StartApp SDK to indicate consent is already handled
            val prefNames = arrayOf(
                "com.startapp.sdk.adsbase",
                "com.startapp.sdk",
                "com.startapp.sdk.ads.banner",
                packageName + "_preferences",
                "startapp_sdk",
                "StartAppSDK"
            )
            val now = System.currentTimeMillis()
            for (prefName in prefNames) {
                try {
                    val prefs = getSharedPreferences(prefName, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("USER_CONSENT_PERSONALIZED_ADS_SERVING", true)
                        .putLong("USER_CONSENT_TIMESTAMP", now)
                        .putBoolean("startapp_consent", true)
                        .putBoolean("startapp_consent_pas", true)
                        .putLong("startapp_consent_timestamp", now)
                        .putString("consent_type", "pas")
                        .putLong("consent_timestamp", now)
                        .putInt("consent_result", 1)
                        .putBoolean("disable_consent_dialog", true)
                        .putBoolean("consent_shown", true)
                        .putBoolean("consent_dialog_shown", true)
                        .putBoolean("com.startapp.sdk.CONSENT_SHOWN", true)
                        .putBoolean("com.startapp.sdk.PAS_CONSENT", true)
                        .putBoolean("com.startapp.sdk.GDPR_CONSENT", true)
                        .putBoolean("com.startapp.sdk.CCPA_CONSENT", true)
                        .putLong("com.startapp.sdk.CONSENT_TIMESTAMP", now)
                        .apply()
                } catch (_: Throwable) {}
            }

            // 2. Invoke all StartAppSDK consent methods via reflection
            val sdkClass = Class.forName("com.startapp.sdk.adsbase.StartAppSDK")
            for (method in sdkClass.methods) {
                if (method.name == "setUserConsent") {
                    try {
                        val types = method.parameterTypes
                        when (types.size) {
                            4 -> {
                                if (types[1] == String::class.java && types[2] == Long::class.javaPrimitiveType && types[3] == Boolean::class.javaPrimitiveType) {
                                    method.invoke(null, this, "pas", now, true)
                                } else if (types[1] == String::class.java && types[2] == Boolean::class.javaPrimitiveType && types[3] == Long::class.javaPrimitiveType) {
                                    method.invoke(null, this, "pas", true, now)
                                }
                            }
                            3 -> {
                                if (types[1] == Boolean::class.javaPrimitiveType && types[2] == Long::class.javaPrimitiveType) {
                                    method.invoke(null, this, true, now)
                                }
                            }
                        }
                    } catch (_: Throwable) {}
                }
            }

            try {
                val methodDisableDialog = sdkClass.getMethod("disableConsentDialog")
                methodDisableDialog.invoke(null)
            } catch (_: Throwable) {}

            try {
                val methodEnableReturn = sdkClass.getMethod("enableReturnAds", Boolean::class.javaPrimitiveType)
                methodEnableReturn.invoke(null, false)
            } catch (_: Throwable) {}

            try {
                val adClass = Class.forName("com.startapp.sdk.adsbase.StartAppAd")
                val methodDisableSplash = adClass.getMethod("disableSplash")
                methodDisableSplash.invoke(null)
            } catch (_: Throwable) {}

            try {
                val initMethod = sdkClass.getMethod("init", Context::class.java, String::class.java, Boolean::class.javaPrimitiveType)
                initMethod.invoke(null, this, "209922521", false)
            } catch (_: Throwable) {}
        } catch (e: Throwable) {
            Log.d(TAG, "StartApp consent suppression info: ${e.message}")
        }
    }

    // ==================== FLUTTER SETUP ====================
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Check overlay permission (only cache status, do NOT auto-prompt or auto-redirect on app startup)
        permissionGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }

        // Setup Method Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Ad Timer শুরু
                "startAdTimer" -> {
                    val seconds = call.argument<Int>("adTimerSeconds") ?: 0
                    Log.d(TAG, "📺 Ad Timer Request: ${seconds}s")

                    if (seconds <= 0) {
                        Log.e(TAG, "❌ Invalid timer duration: $seconds")
                        result.error("INVALID", "Invalid timer duration", null)
                    } else {
                        if (checkOverlayPermission()) {
                            showTimerOverlay(seconds, isBreak = false)
                            result.success(true)
                        } else {
                            Log.w(TAG, "⚠️ Overlay permission not granted")
                            requestOverlayPermission()
                            result.error("NO_PERMISSION", "Overlay permission required", null)
                        }
                    }
                }

                // Break Timer শুরু
                "startBreakTimer" -> {
                    val seconds = call.argument<Int>("breakSeconds") ?: 0
                    Log.d(TAG, "⏱️ Break Timer Request: ${seconds}s (${seconds/60}m)")

                    if (seconds <= 0) {
                        Log.e(TAG, "❌ Invalid break duration: $seconds")
                        result.error("INVALID", "Invalid break duration", null)
                    } else {
                        if (checkOverlayPermission()) {
                            showTimerOverlay(seconds, isBreak = true)
                            result.success(true)
                        } else {
                            Log.w(TAG, "⚠️ Overlay permission not granted")
                            requestOverlayPermission()
                            result.error("NO_PERMISSION", "Overlay permission required", null)
                        }
                    }
                }

                // সব Overlay hide করো
                "hideAllOverlays" -> {
                    Log.d(TAG, "🔴 Hide all overlays request")
                    hideAllOverlays()
                    result.success(true)
                }

                else -> {
                    Log.w(TAG, "⚠️ Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        Log.d(TAG, "✅ Flutter Engine configured successfully")
    }

    // ==================== PERMISSION HANDLING ====================
    private fun checkOverlayPermission(): Boolean {
        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
        permissionGranted = canDraw

        if (!canDraw) {
            Log.w(TAG, "⚠️ Overlay permission not granted")
        }

        return canDraw
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.d(TAG, "📋 Requesting overlay permission...")
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to request overlay permission: ${e.message}", e)
                runOnUiThread {
                    Toast.makeText(
                        this,
                        "⚠️ Overlay permission settings not supported on this device.",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST) {
            if (checkOverlayPermission()) {
                Log.d(TAG, "✅ Overlay permission granted!")
                Toast.makeText(
                    this,
                    "✅ Permission granted! You can now watch ads.",
                    Toast.LENGTH_SHORT
                ).show()
            } else {
                Log.e(TAG, "❌ Overlay permission denied!")
                Toast.makeText(
                    this,
                    "❌ Permission denied. Timer won't work.",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    // ==================== OVERLAY SETUP ====================
    private fun getOverlayType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun createOverlayParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            getOverlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 80 // Top থেকে 80px নিচে
            dimAmount = 0.7f // Background dim করো
        }
    }

    // ==================== TIMER OVERLAY ====================
    private fun showTimerOverlay(seconds: Int, isBreak: Boolean) {
        if (!checkOverlayPermission()) {
            Log.e(TAG, "❌ Cannot show overlay - permission not granted")
            Toast.makeText(this, "Please enable overlay permission", Toast.LENGTH_SHORT).show()
            return
        }

        // পুরানো overlay clear করো
        hideAllOverlays()

        // Timer setup
        countdownSeconds = seconds
        originalDuration = seconds
        timerStartTime = System.currentTimeMillis()
        isBreakTimer = isBreak

        val timerType = if (isBreak) "Break Timer" else "Ad Timer"
        val formattedTime = if (seconds >= 60) "${seconds/60}m ${seconds%60}s" else "${seconds}s"

        Log.d(TAG, "🎬 Starting $timerType: $formattedTime")

        runOnUiThread {
            try {
                val inflater = LayoutInflater.from(this)
                overlayView = inflater.inflate(R.layout.timer_overlay, null)
                timerTextView = overlayView?.findViewById(R.id.timerText)

                // Initial state: শুধু timer দেখাও
                overlayView?.findViewById<View>(R.id.successContainer)?.visibility = View.GONE
                overlayView?.findViewById<View>(R.id.timerContainer)?.visibility = View.VISIBLE

                // Timer text set করো
                val prefix = if (isBreak) "⏱️ Break Time" else "📺 Watching Ad"
                updateTimerText(prefix)

                // Return to App Button Click Handlers
                overlayView?.findViewById<View>(R.id.btnBackToApp)?.setOnClickListener {
                    Log.d(TAG, "🔙 Back to App clicked from overlay")
                    returnToApp()
                }

                overlayView?.findViewById<View>(R.id.btnSuccessBackToApp)?.setOnClickListener {
                    Log.d(TAG, "🔙 Return to App clicked from success overlay")
                    returnToApp()
                }

                // Overlay show করো
                windowManager?.addView(overlayView, createOverlayParams())

                Log.d(TAG, "✅ Overlay displayed successfully")

                // Countdown শুরু করো
                startCountdown {
                    runOnUiThread {
                        Log.d(TAG, "⏰ Timer completed!")

                        // Timer complete - success animation দেখাও
                        showSuccessAnimation()

                        // 2.5 seconds পর overlay hide + Flutter notify
                        handler.postDelayed({
                            hideAllOverlays()

                            // Flutter কে notify করো
                            if (isBreak) {
                                channelInvoke("onBreakComplete")
                                Log.d(TAG, "✅ Break timer complete - Flutter notified")
                            } else {
                                channelInvoke("onTimerComplete")
                                Log.d(TAG, "✅ Ad timer complete - Flutter notified")
                            }
                        }, 2500)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error showing overlay: ${e.message}", e)
                Toast.makeText(this, "Failed to show timer overlay", Toast.LENGTH_SHORT).show()
            }
        }
    }

    // ==================== COUNTDOWN LOGIC ====================
    private fun startCountdown(onComplete: () -> Unit) {
        stopCountdown()
        isTimerRunning = true

        Log.d(TAG, "⏳ Countdown started: ${originalDuration}s")

        timerRunnable = object : Runnable {
            override fun run() {
                if (!isTimerRunning) {
                    Log.d(TAG, "⏸️ Countdown stopped")
                    return
                }

                // Elapsed time calculate করো
                val elapsed = (System.currentTimeMillis() - timerStartTime) / 1000
                countdownSeconds = (originalDuration - elapsed.toInt()).coerceAtLeast(0)

                if (countdownSeconds > 0) {
                    // Timer text update করো
                    val prefix = if (isBreakTimer) "⏱️ Break Time" else "📺 Watching Ad"
                    updateTimerText(prefix)

                    // Log every 10 seconds or at final 5 seconds
                    if (countdownSeconds % 10 == 0 || countdownSeconds <= 5) {
                        Log.d(TAG, "⏱️ ${if (isBreakTimer) "Break" else "Ad"} timer: ${countdownSeconds}s remaining")
                    }

                    // 1 second পর আবার run করো
                    handler.postDelayed(this, 1000)
                } else {
                    // Timer complete
                    isTimerRunning = false
                    Log.d(TAG, "✅ Countdown finished!")
                    onComplete()
                }
            }
        }

        handler.post(timerRunnable!!)
    }

    private fun stopCountdown() {
        if (isTimerRunning) {
            Log.d(TAG, "🛑 Stopping countdown...")
        }
        isTimerRunning = false
        timerRunnable?.let { handler.removeCallbacks(it) }
        timerRunnable = null
    }

    private fun updateTimerText(prefix: String = "Time remaining") {
        runOnUiThread {
            try {
                val formattedTime = if (countdownSeconds >= 60) {
                    val minutes = countdownSeconds / 60
                    val seconds = countdownSeconds % 60
                    "$prefix: ${minutes}m ${seconds}s"
                } else {
                    "$prefix: ${countdownSeconds}s"
                }

                timerTextView?.text = formattedTime
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error updating timer text: ${e.message}", e)
            }
        }
    }

    // ==================== SUCCESS ANIMATION ====================
    private fun showSuccessAnimation() {
        try {
            Log.d(TAG, "🎉 Showing success animation")

            overlayView?.findViewById<View>(R.id.timerContainer)?.visibility = View.GONE
            overlayView?.findViewById<View>(R.id.successContainer)?.apply {
                visibility = View.VISIBLE
                scaleX = 0.3f
                scaleY = 0.3f
                alpha = 0f
                animate()
                    .scaleX(1.0f)
                    .scaleY(1.0f)
                    .alpha(1.0f)
                    .setDuration(400)
                    .start()
            }

            Log.d(TAG, "✅ Success animation displayed")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing success animation: ${e.message}", e)
        }
    }

    // ==================== OVERLAY CLEANUP ====================
    private fun hideAllOverlays() {
        Log.d(TAG, "🧹 Cleaning up overlays...")

        stopCountdown()

        overlayView?.let { view ->
            runOnUiThread {
                try {
                    if (view.parent != null) {
                        windowManager?.removeViewImmediate(view)
                        Log.d(TAG, "✅ Overlay removed successfully")
                    } else {
                        Log.d(TAG, "ℹ️ Overlay already removed")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error removing overlay: ${e.message}", e)
                }
            }
        }

        overlayView = null
        timerTextView = null
    }

    // ==================== FLUTTER COMMUNICATION ====================
    private fun channelInvoke(method: String) {
        handler.post {
            try {
                methodChannel?.invokeMethod(method, null)
                Log.d(TAG, "📤 Flutter channel invoked: $method")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error invoking Flutter channel: ${e.message}", e)
            }
        }
    }

    private fun returnToApp() {
        try {
            val intent = Intent(this@MainActivity, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)
            Log.d(TAG, "🚀 Returned to MainActivity")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to return to app: ${e.message}", e)
        }
    }

    // ==================== LIFECYCLE ====================
    override fun onDestroy() {
        Log.d(TAG, "🔴 MainActivity destroying...")
        hideAllOverlays()
        super.onDestroy()
        Log.d(TAG, "✅ MainActivity destroyed")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "⏸️ MainActivity paused")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "▶️ MainActivity resumed")

        // Check if permission was granted while app was in background
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val wasGranted = permissionGranted
            val isGranted = checkOverlayPermission()

            if (!wasGranted && isGranted) {
                Log.d(TAG, "✅ Overlay permission granted (detected on resume)")
                Toast.makeText(
                    this,
                    "✅ Overlay permission granted!",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        Log.d(TAG, "🟢 MainActivity started")
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "🟡 MainActivity stopped")
    }
}