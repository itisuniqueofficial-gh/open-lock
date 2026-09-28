package com.itisuniqueofficial.openlock

import java.util.concurrent.ConcurrentHashMap

/**
 * Native authentication state shared by the enforcement source and the native
 * lock activity. It is deliberately process-memory only: after process death
 * or reboot no app is considered authenticated.
 */
enum class AuthenticationState {
    LOCKED,
    AUTHENTICATING,
    AUTHENTICATED,
    UNLOCKED,
    RELOCK_REQUIRED,
}

object LockSession {
    private data class Entry(
        var state: AuthenticationState,
        var unlockedAt: Long = 0L,
    )

    private val entries = ConcurrentHashMap<String, Entry>()

    @Synchronized
    fun beginAuthentication(packageName: String): Boolean {
        val entry = entries[packageName]
        if (entry?.state == AuthenticationState.AUTHENTICATING) return false
        entries[packageName] = Entry(AuthenticationState.AUTHENTICATING)
        return true
    }

    @Synchronized
    fun markAuthenticated(packageName: String): Boolean {
        val entry = entries[packageName] ?: return false
        if (entry.state != AuthenticationState.AUTHENTICATING &&
            entry.state != AuthenticationState.AUTHENTICATED
        ) {
            return false
        }
        entry.state = AuthenticationState.AUTHENTICATED
        return true
    }

    @Synchronized
    fun markUnlocked(packageName: String): Boolean {
        val entry = entries[packageName] ?: return false
        if (entry.state != AuthenticationState.AUTHENTICATING &&
            entry.state != AuthenticationState.AUTHENTICATED
        ) {
            return false
        }
        entry.unlockedAt = System.currentTimeMillis()
        entry.state = AuthenticationState.UNLOCKED
        return true
    }

    @Synchronized
    fun markRelockRequired(packageName: String) {
        entries[packageName]?.state = AuthenticationState.RELOCK_REQUIRED
    }

    @Synchronized
    fun unlockedAt(packageName: String): Long = entries[packageName]?.unlockedAt ?: 0L

    @Synchronized
    fun state(packageName: String): AuthenticationState =
        entries[packageName]?.state ?: AuthenticationState.LOCKED

    @Synchronized
    fun clear(packageName: String) {
        entries.remove(packageName)
    }

    @Synchronized
    fun clearAll() = entries.clear()
}
