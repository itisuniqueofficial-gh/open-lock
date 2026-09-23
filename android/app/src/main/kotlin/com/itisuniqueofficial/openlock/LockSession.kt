package com.itisuniqueofficial.openlock

import java.util.concurrent.ConcurrentHashMap

/**
 * Shared, in-memory session state between [OpenLockMonitorService] and
 * [LockActivity]. Deliberately not persisted: unlocks live only for the
 * current boot/session so a reboot re-locks everything.
 */
object LockSession {
    private val unlockedAt = ConcurrentHashMap<String, Long>()

    fun markUnlocked(packageName: String) {
        unlockedAt[packageName] = System.currentTimeMillis()
    }

    fun unlockedAt(packageName: String): Long = unlockedAt[packageName] ?: 0L

    fun clear(packageName: String) {
        unlockedAt.remove(packageName)
    }

    fun clearAll() = unlockedAt.clear()
}
