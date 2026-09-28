package com.itisuniqueofficial.openlock

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.pm.ServiceInfo
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Usage Access enforcement source. This service exists only when the user
 * selected Usage Access; Accessibility mode has no polling service and no
 * Open Lock foreground notification.
 *
 * UsageStatsManager has no foreground-change callback, so this is a deliberately
 * slow, deduplicated poll (one query per second, from the last query boundary).
 * It is not a Flutter process and never starts a Dart isolate.
 */
class OpenLockMonitorService : Service() {
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var store: ConfigStore
    private val handler = Handler(Looper.getMainLooper())
    private var lastQueryAt = 0L
    private var lastForeground: Pair<String, String?>? = null
    private val started = AtomicBoolean(false)

    private val poller = object : Runnable {
        override fun run() {
            if (!started.get()) return
            try {
                if (!isUsageAccessGranted(this@OpenLockMonitorService) ||
                    !Settings.canDrawOverlays(this@OpenLockMonitorService) ||
                    store.enforcementMethod() != LockEnforcementManager.METHOD_USAGE
                ) {
                    stopSelf()
                    return
                }
                pollForeground()
            } catch (_: Exception) {
                // A transient UsageStats/OEM error should not kill the service.
            }
            if (started.get()) handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = ConfigStore(this)
        usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        LockEnforcementManager.onUsageStarted(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (store.enforcementMethod() != LockEnforcementManager.METHOD_USAGE ||
            store.pinHash() == null ||
            !store.hasEnforcementWork() ||
            !isUsageAccessGranted(this) ||
            !Settings.canDrawOverlays(this)
        ) {
            stopSelfResult(startId)
            return START_NOT_STICKY
        }

        try {
            startAsForeground()
        } catch (_: Exception) {
            stopSelfResult(startId)
            return START_NOT_STICKY
        }

        started.set(true)
        isRunning = true
        lastQueryAt = 0L
        handler.removeCallbacks(poller)
        handler.post(poller)
        return START_STICKY
    }

    override fun onDestroy() {
        started.set(false)
        isRunning = false
        handler.removeCallbacks(poller)
        LockEnforcementManager.onUsageStopped()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun pollForeground() {
        val now = System.currentTimeMillis()
        val begin = if (lastQueryAt == 0L) now - INITIAL_LOOKBACK_MS else lastQueryAt
        val events = usageStatsManager.queryEvents(begin, now + 1L)
        val event = UsageEvents.Event()
        var newest: Pair<String, String?>? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            ) {
                val pkg = event.packageName?.takeIf { it.isNotBlank() } ?: continue
                newest = pkg to event.className
            }
        }
        lastQueryAt = now
        if (newest != null) lastForeground = newest
        lastForeground?.let { (pkg, cls) ->
            LockEnforcementManager.onForegroundPackage(
                method = LockEnforcementManager.METHOD_USAGE,
                packageName = pkg,
                className = cls,
            )
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Usage Access protection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Required while Usage Access enforcement is selected."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = openIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Open Lock is protecting your apps")
            .setContentText("Usage Access enforcement is enabled.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
    }

    companion object {
        @Volatile
        var isRunning: Boolean = false
            private set

        private const val CHANNEL_ID = "openlock_monitor"
        private const val NOTIFICATION_ID = 4711
        private const val POLL_INTERVAL_MS = 1_000L
        private const val INITIAL_LOOKBACK_MS = 10_000L

        fun hasUsageAccess(context: Context): Boolean = isUsageAccessGranted(context)

        fun startIfNeeded(context: Context) {
            val appContext = context.applicationContext
            val store = ConfigStore(appContext)
            if (store.enforcementMethod() != LockEnforcementManager.METHOD_USAGE ||
                store.pinHash() == null ||
                !store.hasEnforcementWork() ||
                !isUsageAccessGranted(appContext) ||
                !Settings.canDrawOverlays(appContext)
            ) return

            val intent = Intent(appContext, OpenLockMonitorService::class.java)
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appContext.startForegroundService(intent)
                } else {
                    appContext.startService(intent)
                }
            }
        }

        private fun isUsageAccessGranted(context: Context): Boolean {
            return try {
                val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        android.os.Process.myUid(),
                        context.packageName,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        android.os.Process.myUid(),
                        context.packageName,
                    )
                }
                mode == AppOpsManager.MODE_ALLOWED
            } catch (_: Exception) {
                false
            }
        }
    }
}
