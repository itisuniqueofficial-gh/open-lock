package com.itisuniqueofficial.openlock

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FlutterFragmentActivity is required by local_auth (biometric prompt). Hosts
 * the enforcement MethodChannel that bridges the Flutter app to the native
 * app-lock layer.
 */
class MainActivity : FlutterFragmentActivity() {

    private var enforcementPlugin: EnforcementPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Keep sensitive in-app content (PIN entry, locked-app list, intruder
        // photos, security settings) out of screenshots and the Recents
        // preview. This mirrors the FLAG_SECURE already set on LockActivity.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        enforcementPlugin = EnforcementPlugin(this).also {
            it.register(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onDestroy() {
        enforcementPlugin?.dispose()
        enforcementPlugin = null
        super.onDestroy()
    }
}
