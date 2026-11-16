package com.filmytell.ott

import android.app.UiModeManager
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import android.view.OrientationEventListener
import android.view.WindowManager
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val antiPiracyChannel = "com.filmytell.ott/anti_piracy"
    private val installReferrerChannel = "com.filmytell.ott/install_referrer"
    private val orientationChannel = "com.filmytell.ott/orientation"
    private var uprightListener: OrientationEventListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Phones open in portrait (never sideways at launch); rotation is
        // handed back to the system once the phone is held upright. TV and
        // large screens keep their default orientation.
        if (savedInstanceState == null && isPhoneSized()) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            releasePortraitWhenUpright()
        }
        super.onCreate(savedInstanceState)

        // Keep the screen awake during playback-heavy sessions.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onDestroy() {
        uprightListener?.disable()
        uprightListener = null
        super.onDestroy()
    }

    /** A phone: not a TV / leanback device and smallest width < 600dp. */
    private fun isPhoneSized(): Boolean {
        val uiMode = getSystemService(UI_MODE_SERVICE) as? UiModeManager
        val isTv = uiMode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        return !isTv && resources.configuration.smallestScreenWidthDp < 600
    }

    /**
     * Keeps the current portrait request until the device is physically
     * upright, then returns rotation to the system (auto-rotate setting).
     * Does nothing if something else (e.g. the full-screen player) changed
     * the requested orientation meanwhile. Non-phones are released at once.
     */
    private fun releasePortraitWhenUpright() {
        uprightListener?.disable()
        uprightListener = null
        if (!isPhoneSized()) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            return
        }
        val listener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(degrees: Int) {
                if (degrees == ORIENTATION_UNKNOWN) return
                if (degrees <= 30 || degrees >= 330) {
                    disable()
                    if (uprightListener === this) uprightListener = null
                    if (requestedOrientation == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    }
                }
            }
        }
        if (listener.canDetectOrientation()) {
            uprightListener = listener
            listener.enable()
        } else if (requestedOrientation == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) {
            // No sensor: nothing to wait for.
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            orientationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "releasePortraitWhenUpright" -> {
                    releasePortraitWhenUpright()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            installReferrerChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallReferrer" -> fetchInstallReferrer(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            antiPiracyChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureScreen" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disableSecureScreen" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "deviceIntegrity" -> {
                    result.success(
                        mapOf(
                            "rooted" to isRootedDevice(),
                            "jailbroken" to false,
                            "emulator" to isEmulator(),
                            "screenCaptured" to false
                        )
                    )
                }
                "deviceIdentity" -> {
                    result.success(
                        mapOf(
                            "deviceName" to "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}".trim(),
                            "osVersion" to "Android ${android.os.Build.VERSION.RELEASE}"
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isRootedDevice(): Boolean {
        val buildTags = android.os.Build.TAGS ?: ""
        if (buildTags.contains("test-keys")) return true

        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )

        return rootPaths.any { File(it).exists() }
    }

    private fun isEmulator(): Boolean {
        val fingerprint = android.os.Build.FINGERPRINT.lowercase()
        val model = android.os.Build.MODEL.lowercase()
        val product = android.os.Build.PRODUCT.lowercase()
        return fingerprint.startsWith("generic") ||
            fingerprint.contains("emulator") ||
            model.contains("google_sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk built for") ||
            product.contains("sdk") ||
            product.contains("emulator")
    }

    private fun fetchInstallReferrer(result: MethodChannel.Result) {
        try {
            val referrerClient = InstallReferrerClient.newBuilder(this).build()
            referrerClient.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                val response: ReferrerDetails = referrerClient.installReferrer
                                val referrerUrl = response.installReferrer
                                referrerClient.endConnection()
                                runOnUiThread {
                                    result.success(referrerUrl)
                                }
                            } catch (e: Exception) {
                                try { referrerClient.endConnection() } catch (_: Exception) {}
                                runOnUiThread {
                                    result.success(null)
                                }
                            }
                        }
                        else -> {
                            try { referrerClient.endConnection() } catch (_: Exception) {}
                            runOnUiThread {
                                result.success(null)
                            }
                        }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    // Disconnected - no further action needed
                }
            })
        } catch (e: Exception) {
            result.success(null)
        }
    }
}
