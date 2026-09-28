package com.itisuniqueofficial.openlock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restores the native enforcement projection after boot or an in-place app
 * update. It can start Usage Access's required foreground service, but it can
 * never grant Usage Access or enable Accessibility on the user's behalf.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        val appContext = context.applicationContext
        val store = ConfigStore(appContext)
        LockEnforcementManager.initialize(appContext)

        if (store.enforcementMethod() == LockEnforcementManager.METHOD_USAGE) {
            OpenLockMonitorService.startIfNeeded(appContext)
        }
        // AccessibilityService is intentionally not started programmatically.
        // Android reconnects it when the user has enabled it in system Settings.
    }
}
