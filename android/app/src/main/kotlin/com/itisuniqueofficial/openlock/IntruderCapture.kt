package com.itisuniqueofficial.openlock

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Best-effort silent front-camera capture for the intruder log. Uses Camera2
 * with an [ImageReader] and no preview surface. If the camera is unavailable or
 * the permission has not been granted, the event is still recorded — just
 * without a photo. Photos are written to app-private storage and never leave
 * the device.
 *
 * NOTE: silent no-preview capture is device-dependent and cannot be validated
 * without physical hardware; failures degrade gracefully to a photo-less entry.
 */
object IntruderCapture {

    fun record(context: Context, store: ConfigStore, packageName: String, attemptPhoto: Boolean) {
        val recorded = AtomicBoolean(false)
        fun finish(photoPath: String?) {
            if (recorded.compareAndSet(false, true)) {
                store.addIntruder(packageName, System.currentTimeMillis(), photoPath)
                notifyIntruder(context.applicationContext, photoPath != null)
            }
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED

        if (!attemptPhoto || !hasPermission) {
            finish(null)
            return
        }

        try {
            capture(context.applicationContext) { path -> finish(path) }
        } catch (e: Exception) {
            finish(null)
        }
    }

    private const val channelId = "openlock_intruder"

    // Posts a heads-up that a failed-unlock attempt was recorded. The photo
    // (if any) stays on-device; the notification only signals it happened.
    private fun notifyIntruder(context: Context, hasPhoto: Boolean) {
        val nm = context.getSystemService(NotificationManager::class.java)
            ?: return
        nm.createNotificationChannel(
            NotificationChannel(
                channelId,
                "Intruder alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
        val pi = launch?.let {
            android.app.PendingIntent.getActivity(
                context,
                0,
                it,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification = Notification.Builder(context, channelId)
            .setContentTitle("Failed unlock attempt")
            .setContentText(
                if (hasPhoto) {
                    "A photo was captured. Tap to view the intruder log."
                } else {
                    "Someone missed the unlock. Tap to view the intruder log."
                },
            )
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setAutoCancel(true)
            .apply { if (pi != null) setContentIntent(pi) }
            .build()
        nm.notify(5711, notification)
    }

    private fun capture(context: Context, onDone: (String?) -> Unit) {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = frontCameraId(manager) ?: run {
            onDone(null)
            return
        }

        val thread = HandlerThread("openlock-intruder").apply { start() }
        val handler = Handler(thread.looper)
        val done = AtomicBoolean(false)
        val reader = ImageReader.newInstance(480, 640, ImageFormat.JPEG, 1)

        fun cleanup(camera: CameraDevice?, session: CameraCaptureSession?, path: String?) {
            if (!done.compareAndSet(false, true)) return
            runCatching { session?.close() }
            runCatching { camera?.close() }
            runCatching { reader.close() }
            runCatching { thread.quitSafely() }
            onDone(path)
        }

        reader.setOnImageAvailableListener({ r ->
            val image = runCatching { r.acquireLatestImage() }.getOrNull()
            var savedPath: String? = null
            if (image != null) {
                try {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    val dir = File(context.filesDir, "intruders").apply { mkdirs() }
                    val file = File(dir, "intruder_${System.currentTimeMillis()}.jpg")
                    file.writeBytes(bytes)
                    savedPath = file.absolutePath
                } catch (_: Exception) {
                    // fall through with null path
                } finally {
                    runCatching { image.close() }
                }
            }
            cleanup(null, null, savedPath)
        }, handler)

        try {
            // SecurityException is impossible here — we checked the permission.
            @Suppress("MissingPermission")
            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    try {
                        val surfaces = listOf(reader.surface)
                        @Suppress("DEPRECATION")
                        camera.createCaptureSession(
                            surfaces,
                            object : CameraCaptureSession.StateCallback() {
                                override fun onConfigured(session: CameraCaptureSession) {
                                    try {
                                        val request = camera.createCaptureRequest(
                                            CameraDevice.TEMPLATE_STILL_CAPTURE,
                                        ).apply { addTarget(reader.surface) }
                                        session.capture(request.build(), null, handler)
                                    } catch (e: Exception) {
                                        cleanup(camera, session, null)
                                    }
                                }

                                override fun onConfigureFailed(session: CameraCaptureSession) {
                                    cleanup(camera, session, null)
                                }
                            },
                            handler,
                        )
                    } catch (e: Exception) {
                        cleanup(camera, null, null)
                    }
                }

                override fun onDisconnected(camera: CameraDevice) = cleanup(camera, null, null)

                override fun onError(camera: CameraDevice, error: Int) =
                    cleanup(camera, null, null)
            }, handler)
        } catch (e: Exception) {
            cleanup(null, null, null)
        }

        // Safety timeout so we always record something even if the camera hangs.
        handler.postDelayed({ cleanup(null, null, null) }, CAPTURE_TIMEOUT_MS)
    }

    private fun frontCameraId(manager: CameraManager): String? {
        return try {
            manager.cameraIdList.firstOrNull { id ->
                manager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_FRONT
            }
        } catch (e: Exception) {
            null
        }
    }

    private const val CAPTURE_TIMEOUT_MS = 4_000L
}
