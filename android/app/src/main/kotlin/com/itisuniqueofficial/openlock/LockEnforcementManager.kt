package com.itisuniqueofficial.openlock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import java.util.Calendar
import java.util.concurrent.ConcurrentHashMap

/**
 * The single native enforcement state machine. AccessibilityService and the
 * UsageStats fallback both report foreground transitions here; neither owns a
 * second lock policy or an independent activity debounce.
 *
 * Configuration is read from the encrypted native projection, not from a live
 * Flutter isolate. The manager therefore continues to work when the Flutter
 * activity is closed or its process is recreated.
 */
object LockEnforcementManager {
    const val METHOD_ACCESSIBILITY = "accessibility"
    const val METHOD_USAGE = "usageAccess"

    private const val RELAUNCH_GUARD_MS = 1_500L

    private val mutex = Any()
    private val leftAppAt = ConcurrentHashMap<String, Long>()
    private var applicationContext: Context? = null
    private var store: ConfigStore? = null
    private var receiverRegistered = false
    private var lastForegroundPackage: String? = null
    private var screenOffAt: Long = 0L
    private var activeLockPackage: String? = null
    private var lastLaunchAt: Long = 0L
    private var accessibilityConnected = false
    private var usageConnected = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                synchronized(mutex) {
                    screenOffAt = System.currentTimeMillis()
                }
            }
        }
    }

    fun initialize(context: Context) {
        synchronized(mutex) {
            if (applicationContext == null) applicationContext = context.applicationContext
            if (store == null) store = ConfigStore(applicationContext!!)
            if (!receiverRegistered) {
                val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    applicationContext!!.registerReceiver(
                        screenReceiver,
                        filter,
                        Context.RECEIVER_NOT_EXPORTED,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    applicationContext!!.registerReceiver(screenReceiver, filter)
                }
                receiverRegistered = true
            }
        }
    }

    fun onAccessibilityConnected(context: Context) {
        initialize(context)
        synchronized(mutex) { accessibilityConnected = true }
    }

    fun onAccessibilityDisconnected() {
        synchronized(mutex) { accessibilityConnected = false }
    }

    fun onUsageStarted(context: Context) {
        initialize(context)
        synchronized(mutex) { usageConnected = true }
    }

    fun onUsageStopped() {
        synchronized(mutex) { usageConnected = false }
    }

    fun isAccessibilityConnected(): Boolean = synchronized(mutex) { accessibilityConnected }

    fun isUsageConnected(): Boolean = synchronized(mutex) { usageConnected }

    /** Called only by the selected native source. */
    fun onForegroundPackage(
        method: String,
        packageName: String,
        className: String?,
    ) {
        initialize(applicationContext ?: return)
        synchronized(mutex) {
            val localStore = store ?: return
            if (localStore.enforcementMethod() != method) return

            // An event for the lock activity itself must not be interpreted as
            // the protected app leaving the foreground. That transition is
            // what otherwise causes an immediate re-lock after a valid PIN.
            val isLockActivityEvent =
                packageName == applicationContext!!.packageName &&
                    className?.contains(".LockActivity") == true
            if (isLockActivityEvent ||
                (packageName == applicationContext!!.packageName &&
                    activeLockPackage != null)
            ) {
                return
            }

            val now = System.currentTimeMillis()
            val previous = lastForegroundPackage
            if (previous != null && previous != packageName) {
                leftAppAt[previous] = now
            }
            lastForegroundPackage = packageName

            if (packageName == applicationContext!!.packageName) return

            // A lock activity is authoritative. Do not create another one if
            // app-switch events arrive while its PIN/biometric UI is visible.
            activeLockPackage?.let { active ->
                if (!LockActivity.isActive) {
                    activeLockPackage = null
                } else {
                    if (packageName == active &&
                        !LockActivity.isVisible &&
                        !LockActivity.isAuthenticationPromptVisible &&
                        !LockActivity.isFinishingNow
                    ) {
                        bringLockToFront(active)
                    }
                    return
                }
            }

            val locked = HashSet(localStore.lockedPackages())
            locked.addAll(
                LockLogic.scheduledLockedPackages(
                    localStore.schedules(),
                    Calendar.getInstance(),
                ),
            )
            locked.addAll(localStore.autoLockedPackages())
            if (!locked.contains(packageName)) return
            if (localStore.pinHash() == null || localStore.pinSalt() == null) return

            val shouldLock = LockSession.state(packageName) ==
                AuthenticationState.RELOCK_REQUIRED ||
                LockLogic.isLocked(
                    mode = localStore.relockMode(),
                    timeoutMinutes = localStore.relockTimeoutMinutes(),
                    unlockedAt = LockSession.unlockedAt(packageName),
                    leftAppAt = leftAppAt[packageName] ?: 0L,
                    screenOffAt = screenOffAt,
                    now = now,
                )
            if (!shouldLock) return

            if (packageName == activeLockPackage &&
                now - lastLaunchAt < RELAUNCH_GUARD_MS
            ) return
            launchLock(packageName)
        }
    }

    private fun launchLock(packageName: String) {
        val context = applicationContext ?: return
        if (!LockSession.beginAuthentication(packageName)) return
        activeLockPackage = packageName
        lastLaunchAt = System.currentTimeMillis()
        val intent = Intent(context, LockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(LockActivity.EXTRA_PACKAGE, packageName)
        }
        runCatching { context.startActivity(intent) }.onFailure {
            activeLockPackage = null
            LockSession.markRelockRequired(packageName)
        }
    }

    private fun bringLockToFront(packageName: String) {
        val context = applicationContext ?: return
        lastLaunchAt = System.currentTimeMillis()
        val intent = Intent(context, LockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(LockActivity.EXTRA_PACKAGE, packageName)
        }
        runCatching { context.startActivity(intent) }
    }

    fun onLockActivityFinished(packageName: String, authenticated: Boolean) {
        synchronized(mutex) {
            if (activeLockPackage == packageName) activeLockPackage = null
            // Treat the protected app as the most recent foreground owner.
            // LockActivity events are ignored above, while a later MainActivity
            // or Home event correctly records leaving the protected app.
            lastForegroundPackage = packageName
            if (!authenticated) LockSession.markRelockRequired(packageName)
        }
    }

    fun onLockActivityDestroyed(packageName: String, finishing: Boolean) {
        synchronized(mutex) {
            if (activeLockPackage == packageName) activeLockPackage = null
            lastForegroundPackage = packageName
            if (!finishing) LockSession.markRelockRequired(packageName)
        }
    }

    /** True when a selected source is available to enforce the persisted policy. */
    fun selectedSourceAvailable(): Boolean = synchronized(mutex) {
        val selected = store?.enforcementMethod() ?: METHOD_USAGE
        if (selected == METHOD_ACCESSIBILITY) accessibilityConnected else usageConnected
    }
}
