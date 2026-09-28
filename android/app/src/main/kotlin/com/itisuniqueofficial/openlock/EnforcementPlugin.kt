package com.itisuniqueofficial.openlock

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * The Flutter configuration bridge. It reports live Android state and writes a
 * validated native projection; it does not run enforcement itself.
 */
class EnforcementPlugin(private val activity: Activity) :
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private val store = ConfigStore(activity)

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushConfig" -> {
                val config = call.argument<String>("config")
                if (config == null) {
                    result.error("invalid_config", "Missing native configuration", null)
                    return
                }
                runCatching {
                    store.saveConfig(config)
                    LockEnforcementManager.initialize(activity)
                    if (store.enforcementMethod() == LockEnforcementManager.METHOD_USAGE) {
                        OpenLockMonitorService.startIfNeeded(activity)
                    } else {
                        activity.stopService(Intent(activity, OpenLockMonitorService::class.java))
                        LockSession.clearAll()
                    }
                }.onSuccess { result.success(null) }
                    .onFailure { error ->
                        result.error(
                            "config_not_saved",
                            "Native enforcement configuration was not accepted",
                            error.message,
                        )
                    }
            }
            "getInstalledApps" -> result.success(installedApps())
            "getPermissionStates" -> result.success(permissionStates())
            "requestUsageAccess" -> {
                launch(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                result.success(null)
            }
            "requestAccessibilityService" -> {
                launch(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(null)
            }
            "requestOverlayPermission" -> {
                launch(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                )
                result.success(null)
            }
            "requestBatteryExemption" -> {
                launch(
                    Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                )
                result.success(null)
            }
            "requestNotificationPermission" -> {
                requestNotifications()
                result.success(null)
            }
            "isServiceRunning" -> result.success(selectedSourceRunning())
            "startService" -> {
                OpenLockMonitorService.startIfNeeded(activity)
                result.success(null)
            }
            "stopService" -> {
                activity.stopService(Intent(activity, OpenLockMonitorService::class.java))
                LockSession.clearAll()
                result.success(null)
            }
            "isDeviceAdminActive" -> result.success(isDeviceAdminActive())
            "requestDeviceAdmin" -> {
                requestDeviceAdmin()
                result.success(null)
            }
            "deactivateDeviceAdmin" -> {
                deactivateDeviceAdmin()
                result.success(null)
            }
            "getAutoLockedPackages" -> result.success(store.autoLockedPackages().toList())
            "removeAutoLocked" -> {
                call.argument<String>("packageName")?.let(store::removeAutoLocked)
                result.success(null)
            }
            "getIntruderRecords" -> result.success(store.intruderRecords())
            "deleteIntruderRecord" -> {
                call.argument<String>("id")?.let(store::deleteIntruder)
                result.success(null)
            }
            "clearIntruderRecords" -> {
                store.clearIntruders()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun installedApps(): List<Map<String, Any?>> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()
        for (info in resolveInfos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == activity.packageName || !seen.add(pkg)) continue
            val label = info.loadLabel(pm)?.toString() ?: pkg
            val icon = runCatching { drawableToBase64(info.loadIcon(pm)) }.getOrNull()
            apps.add(mapOf("packageName" to pkg, "label" to label, "icon" to icon))
        }
        apps.sortWith(compareBy { (it["label"] as? String)?.lowercase() ?: "" })
        return apps
    }

    private fun drawableToBase64(drawable: Drawable?): String? {
        if (drawable == null) return null
        val size = ICON_SIZE_PX
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also { bitmap ->
                val canvas = Canvas(bitmap)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return android.util.Base64.encodeToString(stream.toByteArray(), android.util.Base64.NO_WRAP)
    }

    private fun permissionStates(): Map<String, Any?> {
        val selected = store.enforcementMethod()
        return mapOf(
            "usageAccess" to hasUsageAccess(),
            "accessibilityService" to hasAccessibilityService(),
            "overlay" to Settings.canDrawOverlays(activity),
            "notifications" to NotificationManagerCompat.from(activity).areNotificationsEnabled(),
            "batteryExempt" to isBatteryExempt(),
            "enforcementMethod" to selected,
            "serviceRunning" to if (selected == LockEnforcementManager.METHOD_ACCESSIBILITY) {
                hasAccessibilityService()
            } else {
                OpenLockMonitorService.isRunning
            },
        )
    }

    private fun selectedSourceRunning(): Boolean {
        return if (store.enforcementMethod() == LockEnforcementManager.METHOD_ACCESSIBILITY) {
            hasAccessibilityService()
        } else {
            OpenLockMonitorService.isRunning
        }
    }

    private fun hasUsageAccess(): Boolean = OpenLockMonitorService.hasUsageAccess(activity)

    private fun hasAccessibilityService(): Boolean {
        return try {
            val manager =
                activity.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabled = manager.getEnabledAccessibilityServiceList(
                android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
            )
            enabled.any { info ->
                info.resolveInfo?.serviceInfo?.packageName == activity.packageName &&
                    info.resolveInfo?.serviceInfo?.name ==
                    OpenLockAccessibilityService::class.java.name
            } || Settings.Secure.getString(
                activity.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            )?.split(':')?.any { value ->
                ComponentName.unflattenFromString(value)?.className ==
                    OpenLockAccessibilityService::class.java.name
            } == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isBatteryExempt(): Boolean {
        return try {
            val power = activity.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            power.isIgnoringBatteryOptimizations(activity.packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQ_NOTIFICATIONS,
            )
        } else {
            launch(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
            )
        }
    }

    private fun adminComponent(): ComponentName =
        ComponentName(activity, OpenLockDeviceAdminReceiver::class.java)

    private fun devicePolicyManager(): DevicePolicyManager =
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun isDeviceAdminActive(): Boolean =
        runCatching { devicePolicyManager().isAdminActive(adminComponent()) }.getOrDefault(false)

    private fun requestDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Open Lock uses device administrator access only to block itself from being uninstalled while protection is on. It never manages, locks, or wipes your device.",
            )
        }
        launch(intent)
    }

    private fun deactivateDeviceAdmin() {
        runCatching { devicePolicyManager().removeActiveAdmin(adminComponent()) }
    }

    private fun launch(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { activity.startActivity(intent) }
    }

    companion object {
        private const val CHANNEL = "openlock/enforcement"
        private const val ICON_SIZE_PX = 96
        private const val REQ_NOTIFICATIONS = 9021
    }
}
