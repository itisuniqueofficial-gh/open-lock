package com.itisuniqueofficial.openlock

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * Event-driven enforcement source. It observes only window-state changes and
 * never requests window contents, gestures, or unrelated accessibility data.
 */
class OpenLockAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        LockEnforcementManager.onAccessibilityConnected(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString()?.takeIf { it.isNotBlank() }
            ?: return
        LockEnforcementManager.onForegroundPackage(
            method = LockEnforcementManager.METHOD_ACCESSIBILITY,
            packageName = packageName,
            className = event.className?.toString(),
        )
    }

    override fun onInterrupt() {
        // Android is asking the service to stop processing. No work is queued.
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        LockEnforcementManager.onAccessibilityDisconnected()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        LockEnforcementManager.onAccessibilityDisconnected()
        super.onDestroy()
    }
}
