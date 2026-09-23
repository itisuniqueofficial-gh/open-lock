package com.itisuniqueofficial.openlock

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * The enforcement config the native monitor reads, plus the intruder log,
 * stored in EncryptedSharedPreferences (androidx.security.crypto). The Flutter
 * app is the source of truth and pushes the enforcement subset here via the
 * MethodChannel; the service only ever reads it.
 */
class ConfigStore(context: Context) {

    private val prefs: SharedPreferences = createPrefs(context.applicationContext)

    private fun createPrefs(context: Context): SharedPreferences {
        return try {
            encryptedPrefs(context)
        } catch (first: Exception) {
            // A corrupted keyset (e.g. after a device-to-device restore) is the
            // usual cause. Clear the encrypted store + its keyset and retry once.
            runCatching { context.deleteSharedPreferences(PREFS_NAME) }
            try {
                encryptedPrefs(context)
            } catch (second: Exception) {
                // Fail closed: never persist the PIN verifier / config in
                // plaintext. Fall back to a NON-persistent in-memory store so
                // the app keeps running but writes nothing sensitive to disk.
                // Locks won't survive process death until the keystore recovers
                // — a deliberate confidentiality-over-durability trade-off
                // (documented in PROJECT_SUMMARY.md).
                InMemorySharedPreferences()
            }
        }
    }

    private fun encryptedPrefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun saveConfig(json: String) {
        prefs.edit().putString(KEY_CONFIG, json).apply()
    }

    private fun config(): JSONObject? {
        val raw = prefs.getString(KEY_CONFIG, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    fun hasConfig(): Boolean = config() != null

    fun lockedPackages(): Set<String> {
        val array = config()?.optJSONArray("lockedPackages") ?: return emptySet()
        val set = HashSet<String>(array.length())
        for (i in 0 until array.length()) set.add(array.optString(i))
        return set
    }

    fun schedules(): JSONArray = config()?.optJSONArray("schedules") ?: JSONArray()

    fun relockMode(): String = config()?.optString("relockMode", "immediately") ?: "immediately"

    fun relockTimeoutMinutes(): Int = config()?.optInt("relockTimeoutMinutes", 1) ?: 1

    fun randomizeKeypad(): Boolean = config()?.optBoolean("randomizeKeypad", false) ?: false

    fun intruderCaptureEnabled(): Boolean =
        config()?.optBoolean("intruderCaptureEnabled", false) ?: false

    fun intruderThreshold(): Int = config()?.optInt("intruderThreshold", 3) ?: 3

    fun fakeCoverEnabled(): Boolean = config()?.optBoolean("fakeCoverEnabled", false) ?: false

    fun preventUninstall(): Boolean = config()?.optBoolean("preventUninstall", false) ?: false

    fun biometricEnabled(): Boolean = config()?.optBoolean("biometricEnabled", false) ?: false

    /** Whether newly installed apps should be auto-locked (pushed from Flutter). */
    fun lockNewApps(): Boolean = config()?.optBoolean("lockNewApps", false) ?: false

    // --- Auto-locked packages (native-owned, additive) ----------------------
    // Populated by the monitor's package-install receiver when [lockNewApps] is
    // on. Kept under a separate key so a Flutter config push never clobbers it.

    fun autoLockedPackages(): Set<String> {
        val raw = prefs.getString(KEY_AUTOLOCKED, null) ?: return emptySet()
        return try {
            val arr = JSONArray(raw)
            val set = HashSet<String>(arr.length())
            for (i in 0 until arr.length()) set.add(arr.optString(i))
            set
        } catch (e: Exception) {
            emptySet()
        }
    }

    fun addAutoLocked(packageName: String) {
        val set = HashSet(autoLockedPackages())
        if (!set.add(packageName)) return
        prefs.edit().putString(KEY_AUTOLOCKED, JSONArray(set.toList()).toString()).apply()
    }

    fun removeAutoLocked(packageName: String) {
        val set = HashSet(autoLockedPackages())
        if (!set.remove(packageName)) return
        prefs.edit().putString(KEY_AUTOLOCKED, JSONArray(set.toList()).toString()).apply()
    }

    fun pinHash(): String? = config()?.optString("pinHash")?.ifBlank { null }

    fun pinSalt(): String? = config()?.optString("pinSalt")?.ifBlank { null }

    fun pinIterations(): Int = config()?.optInt("pinIterations", 120000) ?: 120000

    // --- Intruder log -------------------------------------------------------

    private fun intruderArray(): JSONArray {
        val raw = prefs.getString(KEY_INTRUDERS, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    fun addIntruder(packageName: String, timestamp: Long, photoPath: String?) {
        val array = intruderArray()
        val entry = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("package", packageName)
            put("timestamp", timestamp)
            put("photoPath", photoPath ?: JSONObject.NULL)
        }
        array.put(entry)
        prefs.edit().putString(KEY_INTRUDERS, array.toString()).apply()
    }

    fun intruderRecords(): List<Map<String, Any?>> {
        val array = intruderArray()
        val list = ArrayList<Map<String, Any?>>(array.length())
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            list.add(
                mapOf(
                    "id" to obj.optString("id"),
                    "package" to obj.optString("package"),
                    "timestamp" to obj.optLong("timestamp"),
                    "photoPath" to obj.opt("photoPath").let {
                        if (it == JSONObject.NULL) null else it as? String
                    },
                ),
            )
        }
        return list
    }

    fun deleteIntruder(id: String) {
        val array = intruderArray()
        val kept = JSONArray()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            if (obj.optString("id") != id) {
                kept.put(obj)
            } else {
                (obj.opt("photoPath") as? String)?.let { path ->
                    runCatching { java.io.File(path).delete() }
                }
            }
        }
        prefs.edit().putString(KEY_INTRUDERS, kept.toString()).apply()
    }

    fun clearIntruders() {
        val array = intruderArray()
        for (i in 0 until array.length()) {
            (array.optJSONObject(i)?.opt("photoPath") as? String)?.let { path ->
                runCatching { java.io.File(path).delete() }
            }
        }
        prefs.edit().remove(KEY_INTRUDERS).apply()
    }

    companion object {
        private const val PREFS_NAME = "openlock_enforcement"
        private const val KEY_CONFIG = "config"
        private const val KEY_INTRUDERS = "intruders"
        private const val KEY_AUTOLOCKED = "autoLockedPackages"
    }
}

/**
 * Minimal in-memory [SharedPreferences] used only as a fail-closed fallback
 * when the Keystore-backed EncryptedSharedPreferences cannot be created. It
 * persists nothing to disk, so security-critical values (the PIN verifier,
 * locked-app list) are never written in plaintext. Only the methods ConfigStore
 * actually uses are functional; the rest return defaults.
 */
private class InMemorySharedPreferences : SharedPreferences {
    private val map = java.util.concurrent.ConcurrentHashMap<String, String>()

    override fun getString(key: String?, defValue: String?): String? =
        if (key != null && map.containsKey(key)) map[key] else defValue

    override fun getAll(): MutableMap<String, *> = HashMap(map)
    override fun getInt(key: String?, defValue: Int): Int = defValue
    override fun getLong(key: String?, defValue: Long): Long = defValue
    override fun getFloat(key: String?, defValue: Float): Float = defValue
    override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue
    override fun getStringSet(
        key: String?,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? = defValues

    override fun contains(key: String?): Boolean = key != null && map.containsKey(key)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun edit(): SharedPreferences.Editor = InMemoryEditor()

    private inner class InMemoryEditor : SharedPreferences.Editor {
        private val pending = HashMap<String, String?>()
        private var clearFlag = false

        override fun putString(key: String?, value: String?): SharedPreferences.Editor {
            if (key != null) pending[key] = value
            return this
        }

        override fun remove(key: String?): SharedPreferences.Editor {
            if (key != null) pending[key] = null
            return this
        }

        override fun clear(): SharedPreferences.Editor {
            clearFlag = true
            return this
        }

        override fun putStringSet(
            key: String?,
            values: MutableSet<String>?,
        ): SharedPreferences.Editor = this

        override fun putInt(key: String?, value: Int): SharedPreferences.Editor = this
        override fun putLong(key: String?, value: Long): SharedPreferences.Editor = this
        override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = this
        override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = this

        override fun commit(): Boolean {
            apply()
            return true
        }

        override fun apply() {
            if (clearFlag) map.clear()
            for ((k, v) in pending) {
                if (v == null) map.remove(k) else map[k] = v
            }
            pending.clear()
            clearFlag = false
        }
    }
}
