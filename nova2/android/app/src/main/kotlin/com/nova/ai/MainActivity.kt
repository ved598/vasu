package com.nova.ai

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.nova.ai/automation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "openApp" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        val intent = packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }

                    "openUrl" -> {
                        val url = call.argument<String>("url") ?: ""
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "openSettings" -> {
                        val screen = call.argument<String>("screen") ?: "main"
                        val action = when (screen) {
                            "wifi"          -> Settings.ACTION_WIFI_SETTINGS
                            "bluetooth"     -> Settings.ACTION_BLUETOOTH_SETTINGS
                            "sound"         -> Settings.ACTION_SOUND_SETTINGS
                            "display"       -> Settings.ACTION_DISPLAY_SETTINGS
                            "location"      -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
                            "battery"       -> Settings.ACTION_BATTERY_SAVER_SETTINGS
                            else            -> Settings.ACTION_SETTINGS
                        }
                        val intent = Intent(action)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }

                    "getInstalledApps" -> {
                        val apps = packageManager
                            .getInstalledApplications(0)
                            .filter { packageManager.getLaunchIntentForPackage(it.packageName) != null }
                            .map { mapOf(
                                "name"    to packageManager.getApplicationLabel(it).toString(),
                                "package" to it.packageName
                            )}
                            .sortedBy { it["name"] }
                        result.success(apps)
                    }

                    "isAccessibilityEnabled" -> {
                        val enabled = try {
                            Settings.Secure.getInt(contentResolver,
                                Settings.Secure.ACCESSIBILITY_ENABLED) == 1
                        } catch (e: Exception) { false }
                        result.success(enabled)
                    }

                    "requestAccessibility" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
