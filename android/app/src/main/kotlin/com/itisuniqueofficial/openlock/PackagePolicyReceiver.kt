package com.itisuniqueofficial.openlock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Keeps the native auto-lock set independent of Flutter and of the monitor
 * service. Package broadcasts are delivered after process death as long as the
 * user has not force-stopped the app, which is an Android-enforced boundary.
 */
class PackagePolicyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val packageName = intent.data?.schemeSpecificPart ?: return
        if (packageName == context.packageName) return

        val store = ConfigStore(context)
        when (intent.action) {
            Intent.ACTION_PACKAGE_ADDED -> {
                if (!intent.getBooleanExtra(Intent.EXTRA_REPLACING, false) &&
                    store.lockNewApps() &&
                    store.pinHash() != null
                ) {
                    store.addAutoLocked(packageName)
                    if (store.enforcementMethod() == LockEnforcementManager.METHOD_USAGE) {
                        OpenLockMonitorService.startIfNeeded(context)
                    }
                }
            }
            Intent.ACTION_PACKAGE_REMOVED -> {
                if (!intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) {
                    store.removeAutoLocked(packageName)
                }
            }
        }
    }
}
