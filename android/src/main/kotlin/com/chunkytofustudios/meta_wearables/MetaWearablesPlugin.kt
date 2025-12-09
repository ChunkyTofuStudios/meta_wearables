package com.chunkytofustudios.meta_wearables

import android.app.Activity
import android.content.Context
import androidx.activity.result.ActivityResultLauncher
import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.types.PhotoData
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.types.Permission as SdkPermission
import com.meta.wearable.dat.core.types.PermissionStatus as SdkPermissionStatus
import com.meta.wearable.dat.core.types.RegistrationState
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.nio.ByteBuffer
import kotlin.coroutines.resume

/** MetaWearablesPlugin */
class MetaWearablesPlugin : FlutterPlugin, ActivityAware {
    private var activity: Activity? = null
    private var context: Context? = null
    private var hostApi: MetaWearablesHostApiImpl? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val flutterApi = WearablesFlutterApi(binding.binaryMessenger)
        hostApi = MetaWearablesHostApiImpl(binding.applicationContext, flutterApi)
        WearablesHostApi.setUp(binding.binaryMessenger, hostApi)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        WearablesHostApi.setUp(binding.binaryMessenger, null)
        hostApi?.dispose()
        hostApi = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        hostApi?.setActivity(binding.activity, binding)
    }

    override fun onDetachedFromActivity() {
        activity = null
        hostApi?.clearActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}

private class MetaWearablesHostApiImpl(
    private val appContext: Context,
    private val flutterApi: WearablesFlutterApi,
) : WearablesHostApi {
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var registrationJob: Job? = null
    private var streamStateJob: Job? = null
    private var videoJob: Job? = null
    private var currentStream: StreamSession? = null
    private var permissionLauncher: ActivityResultLauncher<Permission>? = null
    private var permissionContinuation: (SdkPermissionStatus) -> Unit = {}

    fun setActivity(activity: Activity, binding: ActivityPluginBinding) {
        // DAT exposes a RequestPermissionContract; wrap via ActivityResultContracts to keep control
        permissionLauncher =
            activity.registerForActivityResult(Wearables.RequestPermissionContract()) { status ->
                permissionContinuation(status)
            }
    }

    fun clearActivity() {
        permissionLauncher = null
        permissionContinuation = {}
    }

    fun dispose() {
        scope.cancel()
        currentStream?.close()
    }

    override fun initialize() {
        Wearables.initialize(appContext)
        registrationJob?.cancel()
        registrationJob =
            scope.launch {
                Wearables.registrationState.collectLatest { state ->
                    flutterApi.onRegistrationStateChanged(
                        state.toPigeonUpdate()
                    )
                }
            }
    }

    override fun checkPermission(
        permission: com.chunkytofustudios.meta_wearables.meta_wearables.Permission,
        callback: (Result<PermissionResult>) -> Unit
    ) {
        scope.launch {
            try {
                val status = Wearables.checkPermissionStatus(permission.toSdk())
                callback(Result.success(status.toPigeonResult()))
            } catch (t: Throwable) {
                callback(Result.failure(t))
                flutterApi.onError(ErrorInfo("permission", t.message ?: "Unknown error"))
            }
        }
    }

    override fun requestPermission(
        permission: com.chunkytofustudios.meta_wearables.meta_wearables.Permission,
        callback: (Result<PermissionResult>) -> Unit
    ) {
        val launcher = permissionLauncher
        if (launcher == null) {
            callback(
                Result.failure(
                    FlutterError("no-activity", "Activity not attached; cannot request permission.", null)
                )
            )
            return
        }
        scope.launch {
            val status =
                suspendCancellableCoroutine { cont ->
                    permissionContinuation = { result ->
                        if (cont.isActive) cont.resume(result)
                    }
                    launcher.launch(permission.toSdk())
                    cont.invokeOnCancellation { permissionContinuation = {} }
                }
            callback(Result.success(status.toPigeonResult()))
        }
    }

    override fun getRegistrationState(callback: (Result<RegistrationUpdate>) -> Unit) {
        scope.launch {
            try {
                val state = Wearables.registrationState.first()
                callback(Result.success(state.toPigeonUpdate()))
            } catch (t: Throwable) {
                callback(Result.failure(t))
            }
        }
    }

    override fun startRegistration(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                Wearables.startRegistration(appContext)
                callback(Result.success(Unit))
            } catch (t: Throwable) {
                callback(Result.failure(t))
                flutterApi.onError(ErrorInfo("registration", t.message ?: "Unknown error"))
            }
        }
    }

    override fun startUnregistration(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                Wearables.startUnregistration(appContext)
                callback(Result.success(Unit))
            } catch (t: Throwable) {
                callback(Result.failure(t))
                flutterApi.onError(ErrorInfo("unregistration", t.message ?: "Unknown error"))
            }
        }
    }

    override fun startStream(config: StreamConfig, callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                stopStreamInternal()
                val streamConfig =
                    StreamConfiguration(
                        videoQuality = config.quality.toSdk(),
                        config.frameRate
                    )
                currentStream =
                    Wearables.startStreamSession(
                        appContext,
                        AutoDeviceSelector(),
                        streamConfig
                    )
                currentStream?.let { session ->
                    streamStateJob =
                        launch {
                            session.state.collectLatest { state ->
                                flutterApi.onStreamStateChanged(state.toPigeon())
                                if (state == StreamSessionState.STOPPED) {
                                    stopStreamInternal()
                                }
                            }
                        }
                    videoJob =
                        launch {
                            session.videoStream.collectLatest { frame ->
                                flutterApi.onVideoFrame(frame.toPigeon())
                            }
                        }
                }
                callback(Result.success(Unit))
            } catch (t: Throwable) {
                flutterApi.onError(ErrorInfo("startStream", t.message ?: "Unknown error"))
                callback(Result.failure(t))
            }
        }
    }

    override fun stopStream() {
        stopStreamInternal()
    }

    override fun capturePhoto() {
        scope.launch {
            try {
                currentStream?.capturePhoto()?.onSuccess { photo ->
                    flutterApi.onPhotoCaptured(photo.toPigeon())
                }?.onFailure {
                    flutterApi.onError(ErrorInfo("capturePhoto", it.message ?: "Unknown error"))
                }
            } catch (t: Throwable) {
                flutterApi.onError(ErrorInfo("capturePhoto", t.message ?: "Unknown error"))
            }
        }
    }

    private fun stopStreamInternal() {
        videoJob?.cancel()
        streamStateJob?.cancel()
        currentStream?.close()
        currentStream = null
        flutterApi.onStreamStateChanged(StreamState.STOPPED)
    }
}

private fun SdkPermissionStatus.toPigeonResult(): PermissionResult =
    when (this) {
        SdkPermissionStatus.Granted -> PermissionResult(status = PermissionStatus.GRANTED)
        SdkPermissionStatus.Denied -> PermissionResult(status = PermissionStatus.DENIED)
        is SdkPermissionStatus.Error -> PermissionResult(
            status = PermissionStatus.ERROR,
            message = this.error.description
        )
    }

private fun com.chunkytofustudios.meta_wearables.meta_wearables.Permission.toSdk(): SdkPermission =
    when (this) {
        com.chunkytofustudios.meta_wearables.meta_wearables.Permission.CAMERA -> SdkPermission.CAMERA
    }

private fun RegistrationState.toPigeonUpdate(): RegistrationUpdate =
    when (this) {
        is RegistrationState.Available -> RegistrationUpdate(
            state = RegistrationStatePigeon.AVAILABLE,
            errorCode = error?.name,
            description = error?.description
        )
        is RegistrationState.Unavailable -> RegistrationUpdate(
            state = RegistrationStatePigeon.UNAVAILABLE,
            errorCode = error?.name,
            description = error?.description
        )
        is RegistrationState.Registering -> RegistrationUpdate(
            state = RegistrationStatePigeon.REGISTERING,
            errorCode = error?.name,
            description = error?.description
        )
        is RegistrationState.Registered -> RegistrationUpdate(
            state = RegistrationStatePigeon.REGISTERED,
            errorCode = error?.name,
            description = error?.description
        )
        is RegistrationState.Unregistering -> RegistrationUpdate(
            state = RegistrationStatePigeon.UNREGISTERING,
            errorCode = error?.name,
            description = error?.description
        )
    }

private fun StreamSessionState.toPigeon(): StreamState =
    when (this) {
        StreamSessionState.STARTING -> StreamState.STARTING
        StreamSessionState.STARTED -> StreamState.STARTED
        StreamSessionState.STREAMING -> StreamState.STREAMING
        StreamSessionState.STOPPING -> StreamState.STOPPING
        StreamSessionState.STOPPED -> StreamState.STOPPED
        StreamSessionState.CLOSED -> StreamState.CLOSED
    }

private fun VideoQualityPigeon.toSdk(): VideoQuality =
    when (this) {
        VideoQualityPigeon.LOW -> VideoQuality.LOW
        VideoQualityPigeon.MEDIUM -> VideoQuality.MEDIUM
        VideoQualityPigeon.HIGH -> VideoQuality.HIGH
    }

private fun VideoFrame.toPigeon(): VideoFrameData {
    val buffer: ByteBuffer = this.buffer
    val data = ByteArray(buffer.remaining())
    val position = buffer.position()
    buffer.get(data)
    buffer.position(position)
    return VideoFrameData(data = data, width = width, height = height)
}

private fun PhotoData.toPigeon(): PhotoDataPigeon =
    when (this) {
        is PhotoData.Bitmap -> {
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, stream)
            PhotoDataPigeon(data = stream.toByteArray(), format = "jpeg")
        }
        is PhotoData.HEIC -> {
            val byteArray = ByteArray(data.remaining())
            data.get(byteArray)
            PhotoDataPigeon(data = byteArray, format = "heic")
        }
    }

// Pigeon generated enums are in the same package; use aliases for clarity
private typealias RegistrationStatePigeon = com.chunkytofustudios.meta_wearables.meta_wearables.RegistrationState
private typealias VideoQualityPigeon = com.chunkytofustudios.meta_wearables.meta_wearables.VideoQuality
