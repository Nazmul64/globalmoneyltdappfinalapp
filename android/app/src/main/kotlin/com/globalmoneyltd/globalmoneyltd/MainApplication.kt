package com.globalmoneyltd.globalmoneyltd

import android.app.Application
import android.content.Context
import android.util.Log
import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {

    companion object {
        private const val TAG = "GlobalMoneyApp"
        private const val STARTAPP_APP_ID = "209922521"
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        preseedConsentPreferences(base)
    }

    override fun onCreate() {
        super.onCreate()
        preseedConsentPreferences(this)
        suppressStartAppSdkConsent(this)
    }

    private fun preseedConsentPreferences(context: Context) {
        try {
            val prefNames = arrayOf(
                "com.startapp.sdk.adsbase",
                "com.startapp.sdk",
                "com.startapp.sdk.ads.banner",
                "${context.packageName}_preferences",
                "startapp_sdk",
                "StartAppSDK"
            )
            val now = System.currentTimeMillis()

            for (prefName in prefNames) {
                try {
                    val prefs = context.getSharedPreferences(prefName, Context.MODE_PRIVATE)
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
        } catch (e: Throwable) {
            Log.d(TAG, "Consent preseed note: ${e.message}")
        }
    }

    private fun suppressStartAppSdkConsent(context: Context) {
        try {
            val sdkClass = Class.forName("com.startapp.sdk.adsbase.StartAppSDK")

            // Try all variations of setUserConsent
            for (method in sdkClass.methods) {
                if (method.name == "setUserConsent") {
                    try {
                        val types = method.parameterTypes
                        when (types.size) {
                            4 -> {
                                if (types[1] == String::class.java && types[2] == Long::class.javaPrimitiveType && types[3] == Boolean::class.javaPrimitiveType) {
                                    method.invoke(null, context, "pas", System.currentTimeMillis(), true)
                                } else if (types[1] == String::class.java && types[2] == Boolean::class.javaPrimitiveType && types[3] == Long::class.javaPrimitiveType) {
                                    method.invoke(null, context, "pas", true, System.currentTimeMillis())
                                }
                            }
                            3 -> {
                                if (types[1] == Boolean::class.javaPrimitiveType && types[2] == Long::class.javaPrimitiveType) {
                                    method.invoke(null, context, true, System.currentTimeMillis())
                                }
                            }
                        }
                    } catch (_: Throwable) {}
                }
            }

            // Disable Consent Dialog
            try {
                val methodDisableDialog = sdkClass.getMethod("disableConsentDialog")
                methodDisableDialog.invoke(null)
            } catch (_: Throwable) {}

            // Disable Return Ads
            try {
                val methodEnableReturn = sdkClass.getMethod("enableReturnAds", Boolean::class.javaPrimitiveType)
                methodEnableReturn.invoke(null, false)
            } catch (_: Throwable) {}

            // Disable Splash Ads
            try {
                val adClass = Class.forName("com.startapp.sdk.adsbase.StartAppAd")
                val methodDisableSplash = adClass.getMethod("disableSplash")
                methodDisableSplash.invoke(null)
            } catch (_: Throwable) {}

            // Try explicit init with returnAds = false
            try {
                val initMethod = sdkClass.getMethod("init", Context::class.java, String::class.java, Boolean::class.javaPrimitiveType)
                initMethod.invoke(null, context, STARTAPP_APP_ID, false)
            } catch (_: Throwable) {}

            Log.d(TAG, "StartApp SDK consent suppressed successfully in Application")
        } catch (e: Throwable) {
            Log.d(TAG, "StartApp suppression note: ${e.message}")
        }
    }
}
