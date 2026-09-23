package com.itisuniqueofficial.openlock

import android.util.Base64
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * Verifies an entered PIN against the verifier the Flutter app pushed down.
 *
 * This mirrors the Dart [PinHasher] exactly (PBKDF2-HMAC-SHA256, 256-bit,
 * standard Base64 of the derived key) so the on-top lock screen can validate
 * the PIN entirely offline — no Flutter engine, no round-trip.
 */
object PinVerifier {

    fun verify(pin: String, saltB64: String, expectedHashB64: String, iterations: Int): Boolean {
        return try {
            val salt = Base64.decode(saltB64, Base64.DEFAULT)
            val spec = PBEKeySpec(pin.toCharArray(), salt, iterations, 256)
            val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
            val hash = factory.generateSecret(spec).encoded
            val actual = Base64.encodeToString(hash, Base64.NO_WRAP)
            constantTimeEquals(actual, expectedHashB64)
        } catch (e: Exception) {
            false
        }
    }

    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var diff = 0
        for (i in a.indices) diff = diff or (a[i].code xor b[i].code)
        return diff == 0
    }
}
