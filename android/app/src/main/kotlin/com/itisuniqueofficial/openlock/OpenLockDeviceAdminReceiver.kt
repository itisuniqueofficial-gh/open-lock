package com.itisuniqueofficial.openlock

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Device administrator for OpenLock's uninstall protection.
 *
 * The receiver itself enforces nothing heavy — being an *active* device admin
 * is what makes Android refuse to uninstall the app until admin is deactivated.
 * OpenLock only ever deactivates it from within the app after a successful
 * PIN/biometric check (see the "Prevent uninstall" toggle), and best-effort
 * guards the OS deactivate-admin screen with the lock overlay. It never locks,
 * wipes, or otherwise manages the device.
 */
class OpenLockDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "Turning this off lets Open Lock be uninstalled. Confirm your PIN in the " +
            "app to keep it protected."
}
