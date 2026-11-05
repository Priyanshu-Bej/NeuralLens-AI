package com.priyanshubej.neurallens

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.exifinterface.media.ExifInterface
import com.meta.wearable.dat.camera.Camera
import com.meta.wearable.dat.camera.addCamera
import com.meta.wearable.dat.camera.types.PhotoData
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamState
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.session.DeviceSession
import com.meta.wearable.dat.core.session.DeviceSessionState
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

/** Local live preview followed by an explicit shutter; frames never go to AI. */
class MetaQuestionCamera(
    activity: ComponentActivity,
    messenger: BinaryMessenger,
    private val scope: CoroutineScope,
    private val currentSession: () -> DeviceSession?,
) {
    private val events = EventChannel(messenger, "neurallens/wearables/camera")
    private var sink: EventChannel.EventSink? = null
    private var camera: Camera? = null
    private var startJob: Job? = null
    private var captureJob: Job? = null
    private val previewJobs = mutableListOf<Job>()
    private var epoch = 0
    private var previewAspect = 0.0
    private var permission: CompletableDeferred<Boolean>? = null
    private val permissionLauncher = activity.activityResultRegistry.register(
        "neurallens-camera-permission", Wearables.RequestPermissionContract(),
    ) { result ->
        result.onSuccess { permission?.complete(it == PermissionStatus.Granted) }
            .onFailure { _, _ -> permission?.complete(false) }
        permission = null
    }

    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
            override fun onCancel(arguments: Any?) { sink = null; cancel() }
        })
    }

    fun startPreview(result: MethodChannel.Result) {
        val session = currentSession()
        if (session == null || session.state.value != DeviceSessionState.STARTED) {
            result.error("disconnected", "Connect your glasses before opening the camera.", null)
            return
        }
        if (camera != null || startJob?.isActive == true) {
            result.error("camera_busy", "Close the current preview before opening another.", null)
            return
        }
        val request = ++epoch
        startJob = scope.launch {
            try {
                withTimeout(60_000L) {
                    requireCameraPermission()
                    withTimeout(15_000L) {
                        session.state.first { it == DeviceSessionState.STARTED }
                    }
                    check(currentSession() === session && request == epoch)
                    val added = session.addCamera(StreamConfiguration(
                        videoQuality = VideoQuality.HIGH, frameRate = 15, compressVideo = false,
                    )).getOrThrow()
                    camera = added
                    val stream = added.stream
                    val firstFrame = CompletableDeferred<Unit>()
                    previewJobs += scope.launch {
                        var lastFrameAt = 0L
                        try {
                            stream.videoStream.collect { frame ->
                                val now = SystemClock.elapsedRealtime()
                                if (now - lastFrameAt < 200 || frame.isCompressed || frame.isCodecConfig) return@collect
                                lastFrameAt = now
                                // Copy before suspending: SDK buffers may be recycled.
                                val buffer = frame.buffer.duplicate()
                                val bytes = ByteArray(buffer.remaining()).also { buffer.get(it) }
                                val jpeg = withContext(Dispatchers.Default) {
                                    previewJpeg(bytes, frame.width, frame.height)
                                }
                                if (request == epoch) {
                                    previewAspect = frame.width.toDouble() / frame.height
                                    sink?.success(mapOf("jpeg" to jpeg, "width" to frame.width, "height" to frame.height))
                                    firstFrame.complete(Unit)
                                }
                            }
                        } catch (error: CancellationException) {
                            throw error
                        } catch (_: Exception) {
                            failPreview(request, "Could not display the camera preview. Reopen the camera.")
                        }
                    }
                    previewJobs += scope.launch {
                        stream.errorStream.collect {
                            failPreview(request, "The glasses camera stopped. Reopen the camera to try again.")
                        }
                    }
                    previewJobs += scope.launch {
                        var wasActive = false
                        stream.state.collect { state ->
                            if (state == StreamState.STREAMING) wasActive = true
                            if (wasActive && state in setOf(StreamState.STOPPED, StreamState.CLOSED, StreamState.PAUSED)) {
                                failPreview(request, "Camera preview interrupted. Reopen the camera.")
                            }
                        }
                    }
                    stream.start().getOrThrow()
                    withTimeout(20_000L) { firstFrame.await() }
                }
                result.success(null)
            } catch (_: TimeoutCancellationException) {
                if (request == epoch) cancel()
                result.error("camera_timeout", "Camera preview timed out. Check your glasses and retry.", null)
            } catch (_: CancellationException) {
                result.error("camera_cancelled", "Camera preview stopped.", null)
            } catch (error: CameraPermissionDenied) {
                if (request == epoch) cancel()
                result.error("camera_permission", error.message, null)
            } catch (_: Exception) {
                if (request == epoch) cancel()
                result.error("camera_failed", "Could not open the camera. Check camera access in Meta AI and retry.", null)
            }
        }
    }

    private fun failPreview(request: Int, message: String) {
        if (request != epoch) return
        sink?.error("preview_stopped", message, null)
        cancel()
    }

    fun capture(zoom: Double, result: MethodChannel.Result) {
        val current = camera
        val aspect = previewAspect
        if (current == null || aspect <= 0 || current.stream.state.value != StreamState.STREAMING) {
            result.error("preview_required", "Open the camera and wait for the preview before capturing.", null)
            return
        }
        if (!zoom.isFinite() || zoom !in 1.0..3.0) {
            result.error("invalid_zoom", "Choose zoom between 1× and 3×.", null)
            return
        }
        if (captureJob?.isActive == true) {
            result.error("camera_busy", "A photo is already being captured.", null)
            return
        }
        val request = epoch
        captureJob = scope.launch {
            try {
                val bytes = withTimeout(30_000L) {
                    val photo = current.stream.capturePhoto().getOrThrow()
                    withContext(Dispatchers.Default) { jpeg(photo, zoom, aspect) }
                }
                result.success(bytes)
            } catch (_: TimeoutCancellationException) {
                result.error("camera_timeout", "Photo capture timed out. Reopen the camera and retry.", null)
            } catch (_: CancellationException) {
                result.error("capture_cancelled", "Photo capture stopped.", null)
            } catch (_: Exception) {
                result.error("capture_failed", "Could not capture a photo. Reopen the camera and retry.", null)
            } finally {
                if (request == epoch) closePreview()
            }
        }
    }

    /** Compact preview JPEGs at <=5 fps keep image conversion off the UI thread. */
    private fun previewJpeg(i420: ByteArray, width: Int, height: Int): ByteArray {
        require(width in 2..4096 && height in 2..4096 && width % 2 == 0 && height % 2 == 0)
        val ySize = width * height
        val chroma = ySize / 4
        require(i420.size == ySize + 2 * chroma)
        val nv21 = ByteArray(i420.size)
        i420.copyInto(nv21, 0, 0, ySize)
        for (i in 0 until chroma) {
            nv21[ySize + 2 * i] = i420[ySize + chroma + i]
            nv21[ySize + 2 * i + 1] = i420[ySize + i]
        }
        return ByteArrayOutputStream().use { output ->
            check(YuvImage(nv21, ImageFormat.NV21, width, height, null)
                .compressToJpeg(Rect(0, 0, width, height), 70, output))
            output.toByteArray()
        }
    }

    private suspend fun requireCameraPermission() {
        val status = Wearables.checkPermissionStatus(Permission.CAMERA).getOrThrow()
        if (status == PermissionStatus.Granted) return
        // Reuse an outstanding system dialog if an earlier capture was cancelled.
        // Its callback must never be mistaken for a new permission request.
        val pending = permission ?: CompletableDeferred<Boolean>().also {
            permission = it
            permissionLauncher.launch(Permission.CAMERA)
        }
        if (!pending.await()) {
            throw CameraPermissionDenied("Camera access was denied. Allow NeuralLens in Meta AI, then retry.")
        }
    }

    private fun closePreview() {
        epoch++
        previewJobs.forEach { it.cancel() }
        previewJobs.clear()
        camera?.close()
        camera = null
        previewAspect = 0.0
    }

    fun cancel() {
        startJob?.cancel()
        captureJob?.cancel()
        closePreview()
    }

    fun dispose() {
        cancel()
        permission?.cancel()
        permission = null
        permissionLauncher.unregister()
        events.setStreamHandler(null)
    }

    private class CameraPermissionDenied(message: String) : Exception(message)

    private fun jpeg(photo: PhotoData, zoom: Double, aspect: Double): ByteArray {
        val bitmap = when (photo) {
            is PhotoData.Bitmap -> photo.bitmap
            is PhotoData.HEIC -> {
                val buffer = photo.data.duplicate().apply { rewind() }
                val bytes = ByteArray(buffer.remaining()).also { buffer.get(it) }
                val decoded = checkNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
                val exif = ByteArrayInputStream(bytes).use { ExifInterface(it) }
                val matrix = Matrix().apply {
                    if (exif.isFlipped) postScale(-1f, 1f)
                    postRotate(exif.rotationDegrees.toFloat())
                }
                if (matrix.isIdentity) decoded else {
                    Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                        .also { if (it !== decoded) decoded.recycle() }
                }
            }
        }
        // Match the preview's aspect ratio and centered digital zoom before upload.
        val crop = QuestionCameraCrop.calculate(bitmap.width, bitmap.height, aspect, zoom)
        val cropped = Bitmap.createBitmap(bitmap, crop.x, crop.y, crop.width, crop.height)
        val scale = minOf(1.0, 2048.0 / maxOf(cropped.width, cropped.height))
        val resized = if (scale < 1) Bitmap.createScaledBitmap(
            cropped, (cropped.width * scale).toInt().coerceAtLeast(1),
            (cropped.height * scale).toInt().coerceAtLeast(1), true,
        ) else cropped
        return try {
            ByteArrayOutputStream().use { output ->
                check(resized.compress(Bitmap.CompressFormat.JPEG, 90, output))
                output.toByteArray().also { check(it.size <= 8 * 1024 * 1024) }
            }
        } finally {
            if (resized !== cropped) resized.recycle()
            if (cropped !== bitmap) cropped.recycle()
            // SDK bitmap ownership stays with the SDK; only recycle our HEIC decode.
            if (photo is PhotoData.HEIC) bitmap.recycle()
        }
    }
}
