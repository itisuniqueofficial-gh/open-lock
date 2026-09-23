package com.itisuniqueofficial.openlock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Restarts the monitor service after a reboot or app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val store = ConfigStore(context)
        val hasWork = store.lockedPackages().isNotEmpty() ||
            store.schedules().length() > 0 ||
            store.autoLockedPackages().isNotEmpty()
        if (store.pinHash() == null || !hasWork) return

        val serviceIntent = Intent(context, OpenLockMonitorService::class.java)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
