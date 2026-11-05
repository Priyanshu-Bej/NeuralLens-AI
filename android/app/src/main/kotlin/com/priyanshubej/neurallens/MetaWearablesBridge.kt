package com.priyanshubej.neurallens

import android.Manifest
import androidx.activity.ComponentActivity
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.session.DeviceSession
import com.meta.wearable.dat.core.session.DeviceSessionState
import com.meta.wearable.dat.core.types.Device
import com.meta.wearable.dat.core.types.DeviceCompatibility
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.DeviceSessionError
import com.meta.wearable.dat.core.types.DonState
import com.meta.wearable.dat.core.types.HingeState
import com.meta.wearable.dat.core.types.LinkState
import com.meta.wearable.dat.core.types.RegistrationState
import com.meta.wearable.dat.core.types.WearablesError
import com.meta.wearable.dat.display.Display
import com.meta.wearable.dat.display.addDisplay
import com.meta.wearable.dat.display.removeDisplay
import com.meta.wearable.dat.display.types.DisplayState
import com.meta.wearable.dat.display.views.FlexBoxBackground
import com.meta.wearable.dat.display.views.TextColor
import com.meta.wearable.dat.display.views.TextStyle
import com.meta.wearable.dat.inputs.Inputs
import com.meta.wearable.dat.inputs.addInputs
import com.meta.wearable.dat.inputs.removeInputs
import com.meta.wearable.dat.inputs.types.CapturePressType
import com.meta.wearable.dat.inputs.types.InputEvent
import com.meta.wearable.dat.inputs.types.InputSource
import com.meta.wearable.dat.inputs.types.InputsConfiguration
import com.meta.wearable.dat.inputs.types.InputsError
import com.meta.wearable.dat.inputs.types.InputsState
import com.meta.wearable.dat.inputs.types.NavDirection
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Flutter bridge to the Meta Wearables Device Access Toolkit (DAT 1.0.0).
 *
 * Only APIs present in the published SDK and its official samples are used:
 * registration, a display-capable device session, Camera and Display capabilities,
 * and the experimental Inputs capability. State sent to Dart always reflects what
 * the SDK reports; nothing here simulates a connection.
 */
class MetaWearablesBridge(
    private val activity: ComponentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val displayMutex = Mutex()
    private val methods = MethodChannel(messenger, "neurallens/wearables")
    private val stateEvents = EventChannel(messenger, "neurallens/wearables/state")
    private val inputEvents = EventChannel(messenger, "neurallens/wearables/inputs")

    private var stateSink: EventChannel.EventSink? = null
    private var inputSink: EventChannel.EventSink? = null

    private val questionCamera = MetaQuestionCamera(activity, messenger, scope) { session }
    private var questionMode = false
    private val inputJobs = mutableListOf<Job>()

    private var initialized = false
    private var registration: RegistrationState = RegistrationState.UNAVAILABLE
    private var session: DeviceSession? = null
    private var sessionState: DeviceSessionState? = null
    private var sessionJobs = mutableListOf<Job>()
    private var display: Display? = null
    private var displayReady = false
    private var inputs: Inputs? = null
    private var inputsAvailability = "unknown"
    private var connecting = false
    private var errorMessage: String? = null

    /** Most specific session error seen during the current connection attempt. */
    private var sessionError: DeviceSessionError? = null

    /** Whether the current attempt ever reached STARTED. */
    private var sessionStarted = false

    /**
     * Collects session errors. Kept alive after the session stops: the SDK can
     * report the specific reason (e.g. an update is required) just after it
     * has already ended the session.
     */
    private var errorJob: Job? = null

    /** Device picking and the link wait before a session exists. */
    private var connectJob: Job? = null

    /** Glasses targeted by the current attempt. */
    private var target: DeviceIdentifier? = null
    private var retriesLeft = 0

    /**
     * The SDK left Developer Mode or the glasses could not launch the app;
     * Dart offers "Repair connection" ([repairRegistration]).
     */
    private var needsRepair = false

    /** Repair step 2: register exactly once after unregistration completes. */
    private var reRegisterAfterUnregister = false
    private var deviceName: String? = null

    /** Action waiting on the runtime Bluetooth permission. */
    private var pendingAfterPermission: (() -> Unit)? = null

    init {
        methods.setMethodCallHandler(this)
        stateEvents.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stateSink = events
                    emitState()
                }

                override fun onCancel(arguments: Any?) {
                    stateSink = null
                }
            },
        )
        inputEvents.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    inputSink = events
                }

                override fun onCancel(arguments: Any?) {
                    inputSink = null
                }
            },
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                // Avoid a permission prompt at launch: initialize now only if
                // Bluetooth access was granted earlier.
                if (hasBluetoothPermission()) initializeSdk() else emitState()
                result.success(null)
            }
            "register" -> {
                withSdk { startRegistrationOnce() }
                result.success(null)
            }
            "repair" -> {
                withSdk { repairRegistration() }
                result.success(null)
            }
            "unregister" -> {
                withSdk {
                    stopSession()
                    Wearables.startUnregistration(activity)
                }
                result.success(null)
            }
            "connect" -> {
                withSdk { startSession() }
                result.success(null)
            }
            "disconnect" -> {
                stopSession()
                result.success(null)
            }
            "setQuestionMode" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                if (questionMode != enabled) {
                    questionMode = enabled
                    if (!enabled) questionCamera.cancel()
                    session?.let {
                        detachInputs(it)
                        if (sessionState == DeviceSessionState.STARTED) attachInputs(it)
                    }
                }
                result.success(null)
            }
            "startCameraPreview" -> {
                if (questionMode) questionCamera.startPreview(result)
                else result.error("camera_inactive", "Open Question Lens before using the camera.", null)
            }
            "stopCameraPreview" -> {
                questionCamera.cancel()
                result.success(null)
            }
            "capturePhoto" -> {
                if (questionMode) questionCamera.capture(call.argument<Double>("zoom") ?: 1.0, result)
                else result.error("camera_inactive", "Open Question Lens before capturing.", null)
            }
            "showCue" -> showCue(call, result)
            "clearDisplay" -> clearDisplay(result)
            else -> result.notImplemented()
        }
    }

    // ---- Permissions & SDK init --------------------------------------------

    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            emptyArray() // BLUETOOTH is a normal (install-time) permission before Android 12.
        }

    private fun hasBluetoothPermission(): Boolean =
        requiredPermissions().all {
            activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }

    private fun withSdk(action: () -> Unit) {
        if (!hasBluetoothPermission()) {
            pendingAfterPermission = action
            activity.requestPermissions(requiredPermissions(), PERMISSION_REQUEST)
            return
        }
        if (initializeSdk()) action()
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        val action = pendingAfterPermission
        pendingAfterPermission = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            if (initializeSdk()) action?.invoke()
        } else {
            errorMessage = "Bluetooth permission is required to connect to glasses."
            emitState()
        }
    }

    /** Returns true when the SDK is ready. */
    private fun initializeSdk(): Boolean {
        if (initialized) return true
        var ok = false
        Wearables.initialize(activity.applicationContext)
            .onSuccess { ok = true }
            .onFailure { error, _ ->
                if (error == WearablesError.ALREADY_INITIALIZED) {
                    ok = true // e.g. the Activity was recreated.
                } else {
                    errorMessage = "Meta Wearables SDK unavailable: ${error.description}"
                }
            }
        if (!ok) {
            emitState()
            return false
        }
        initialized = true
        errorMessage = null
        scope.launch {
            Wearables.registrationState.collect {
                registration = it
                if (reRegisterAfterUnregister && it == RegistrationState.AVAILABLE) {
                    reRegisterAfterUnregister = false
                    Wearables.startRegistration(activity)
                }
                emitState()
            }
        }
        scope.launch {
            Wearables.registrationErrorStream.collect { error ->
                errorMessage = error.description
                emitState()
            }
        }
        emitState()
        return true
    }

    // ---- Registration --------------------------------------------------------

    /**
     * Calling startRegistration() while already registered can silently drop
     * the SDK out of Developer Mode, after which the glasses refuse every
     * session (facebook/meta-wearables-dat-android#192).
     */
    private fun startRegistrationOnce() {
        if (Wearables.registrationState.value == RegistrationState.REGISTERED) {
            emitState()
            return
        }
        Wearables.startRegistration(activity)
    }

    /** Meta's documented recovery: unregister fully, then register exactly once. */
    private fun repairRegistration() {
        stopSession()
        needsRepair = false
        errorMessage = null
        if (Wearables.registrationState.value == RegistrationState.REGISTERED) {
            reRegisterAfterUnregister = true
            Wearables.startUnregistration(activity)
        } else {
            Wearables.startRegistration(activity)
        }
        emitState()
    }

    /** True when the manifest carries Developer Mode credentials ("0" or empty). */
    private fun manifestUsesDevMode(): Boolean {
        val metaData =
            activity.packageManager
                .getApplicationInfo(activity.packageName, PackageManager.GET_META_DATA)
                .metaData
        val appId = metaData?.get(APPLICATION_ID_KEY)?.toString().orEmpty()
        return appId.isEmpty() || appId == "0" || appId == "0.0"
    }

    // ---- Session -------------------------------------------------------------

    private fun startSession() {
        if (registration != RegistrationState.REGISTERED) {
            errorMessage = "Register with the Meta AI app before connecting."
            emitState()
            return
        }
        if (session != null || connectJob?.isActive == true) return
        errorMessage = null
        sessionError = null
        sessionStarted = false
        errorJob?.cancel()
        retriesLeft = MAX_RETRIES
        connecting = true
        emitState()
        connectJob = scope.launch { connectToGlasses() }
    }

    private suspend fun connectToGlasses() {
        val id = pickGlasses()
        if (id == null) {
            fail(
                "No Meta Ray-Ban Display glasses found. Pair them in the Meta AI app, " +
                    "then try again.",
            )
            return
        }
        target = id
        // Glasses that were idle take a moment to link up with the phone.
        withTimeoutOrNull(LINK_TIMEOUT_MS) {
            Wearables.devicesMetadata[id]?.first { it.linkState == LinkState.CONNECTED }
        }
        val device = metadata(id)
        logDevice("before session", device)
        val devModeBuild = manifestUsesDevMode()
        Log.i(
            TAG,
            "isDevMode=${Wearables.isDevMode} devModeBuild=$devModeBuild " +
                "registration=${Wearables.registrationState.value}",
        )
        if (devModeBuild && !Wearables.isDevMode) {
            needsRepair = true
            fail(REPAIR_MESSAGE)
            return
        }
        readinessProblem(device)?.let {
            fail(it)
            return
        }
        openSession(id)
    }

    /** Paired display glasses, preferring ones that are connected and worn. */
    private suspend fun pickGlasses(): DeviceIdentifier? {
        // The device list can lag briefly after the SDK initializes.
        val ids =
            withTimeoutOrNull(DEVICE_LIST_TIMEOUT_MS) {
                Wearables.devices.first { it.isNotEmpty() }
            } ?: return null
        return ids
            .filter { metadata(it)?.isDisplayCapable() != false }
            .minByOrNull { rank(metadata(it)) }
    }

    private fun rank(device: Device?): Int =
        when {
            device == null -> 4
            device.linkState == LinkState.CONNECTED && device.donState == DonState.DONNED -> 0
            device.linkState == LinkState.CONNECTED -> 1
            device.compatibility == DeviceCompatibility.COMPATIBLE -> 2
            else -> 3
        }

    private fun metadata(id: DeviceIdentifier): Device? = Wearables.devicesMetadata[id]?.value

    /** Problems that make a session attempt pointless; null to go ahead. */
    private fun readinessProblem(device: Device?): String? =
        when {
            device == null -> null
            device.compatibility == DeviceCompatibility.DEVICE_UPDATE_REQUIRED ->
                "Your glasses need an update first. In the Meta AI app, open App Connections, " +
                    "install the update, then connect again."
            device.compatibility == DeviceCompatibility.SDK_UPDATE_REQUIRED ->
                "This version of NeuralLens is too old for your glasses. Install the latest version."
            device.hingeState == HingeState.CLOSED -> "Unfold your glasses, then connect again."
            else -> null
        }

    private fun openSession(id: DeviceIdentifier) {
        errorJob?.cancel()
        Wearables.createSession(SpecificDeviceSelector(id))
            .fold(
                onSuccess = { newSession ->
                    session = newSession
                    errorJob = scope.launch { newSession.errors.collect(::onSessionError) }
                    sessionJobs += scope.launch {
                        newSession.deviceInfo.collect { device ->
                            deviceName = device.name.ifBlank { null }
                            emitState()
                        }
                    }
                    sessionJobs += scope.launch {
                        newSession.state.collect { state ->
                            sessionState = state
                            when (state) {
                                DeviceSessionState.STARTED -> {
                                    sessionStarted = true
                                    needsRepair = false
                                    connecting = false
                                    errorMessage = null
                                    logDevice("session started", metadata(id))
                                    attachDisplay(newSession)
                                    attachInputs(newSession)
                                }
                                DeviceSessionState.STOPPED -> onSessionStopped(id)
                                else -> Unit
                            }
                            emitState()
                        }
                    }
                    newSession.start()
                },
                onFailure = { error, _ ->
                    fail((error as? DeviceSessionError)?.let(::describe) ?: error.description)
                },
            )
    }

    private fun onSessionStopped(id: DeviceIdentifier) {
        val refusedAtStart = !sessionStarted
        releaseSession()
        if (!refusedAtStart) return
        logDevice("session refused (${sessionError ?: "no reason given"})", metadata(id))
        // Glasses that just woke up can refuse the first session; try once more.
        if (retriesLeft > 0 && isTransient(sessionError)) {
            retriesLeft--
            connecting = true
            errorMessage = null
            connectJob = scope.launch {
                delay(RETRY_DELAY_MS)
                if (session == null) openSession(id)
            }
            return
        }
        if (sessionError == null) errorMessage = explainRefusal(metadata(id))
    }

    private fun isTransient(error: DeviceSessionError?): Boolean =
        error == null ||
            error == DeviceSessionError.NO_ELIGIBLE_DEVICE ||
            error == DeviceSessionError.DEVICE_DISCONNECTED ||
            error == DeviceSessionError.UNEXPECTED_ERROR

    /** Why the glasses most likely refused a session, from their reported state. */
    private fun explainRefusal(device: Device?): String =
        when {
            device == null ->
                "NeuralLens can't see your glasses. Open the Meta AI app, check they're connected, " +
                    "then try again."
            device.linkState != LinkState.CONNECTED ->
                "Your glasses aren't connected to this phone right now. Open the Meta AI app, wait " +
                    "until they show as connected, then try again."
            device.hingeState == HingeState.CLOSED -> "Unfold your glasses, then connect again."
            device.donState == DonState.DOFFED -> "Put your glasses on, then connect again."
            else ->
                "The glasses didn't accept the session. Close anything open on the glasses display, " +
                    "wait a few seconds, then try again. If it keeps happening, restart the glasses."
        }

    private fun fail(message: String) {
        connecting = false
        errorMessage = message
        emitState()
    }

    /** Device state for `adb logcat -s NeuralLensGlasses`. */
    private fun logDevice(event: String, device: Device?) {
        Log.i(
            TAG,
            if (device == null) {
                "$event: no metadata for target"
            } else {
                "$event: link=${device.linkState} don=${device.donState} hinge=${device.hingeState} " +
                    "compat=${device.compatibility} display=${device.isDisplayCapable()} " +
                    "battery=${device.batteryLevel} firmware=${device.firmwareInfo}"
            },
        )
    }

    private fun onSessionError(error: DeviceSessionError) {
        // Nonblocking compatibility warning; the session continues normally.
        if (error == DeviceSessionError.DWA_OUT_OF_STU_RANGE) return
        // The glasses usually report the real reason first and then end the
        // session; keep the reason rather than the generic follow-up.
        val generic =
            error == DeviceSessionError.SESSION_ENDED_BY_DEVICE ||
                error == DeviceSessionError.DEVICE_DISCONNECTED
        if (generic && sessionError != null) return
        if (!generic) sessionError = error
        errorMessage = describe(error)
        emitState()
    }

    /** Turns session errors into a next step the user can take. */
    private fun describe(error: DeviceSessionError): String =
        when (error) {
            // Despite the name, the SDK also reports this when the glasses could
            // not launch the app for the session (see #192); repair fixes that.
            DeviceSessionError.DAT_APP_ON_THE_GLASSES_UPDATE_REQUIRED -> {
                needsRepair = true
                REPAIR_MESSAGE
            }
            DeviceSessionError.INSUFFICIENT_SDK_VERSION ->
                "This version of NeuralLens is too old for your glasses. Install the latest version."
            DeviceSessionError.NO_ELIGIBLE_DEVICE ->
                "No Meta Ray-Ban Display glasses found. Make sure they're on, unfolded, nearby " +
                    "and paired in the Meta AI app."
            DeviceSessionError.THERMAL_CRITICAL, DeviceSessionError.THERMAL_EMERGENCY ->
                "Your glasses are too warm. Let them cool down, then connect again."
            DeviceSessionError.BATTERY_CRITICAL, DeviceSessionError.PEAK_POWER_SHUTDOWN ->
                "Your glasses' battery is too low. Charge them, then connect again."
            DeviceSessionError.SESSION_ENDED_BY_DEVICE ->
                if (sessionStarted) {
                    "The glasses ended the session. Make sure they're worn and unfolded, then connect again."
                } else {
                    explainRefusal(target?.let(::metadata))
                }
            else -> error.description
        }

    private fun attachDisplay(session: DeviceSession) {
        if (display != null) return
        session.addDisplay()
            .onSuccess { newDisplay ->
                display = newDisplay
                sessionJobs += scope.launch {
                    newDisplay.state.collect { state ->
                        displayReady = state == DisplayState.STARTED
                        emitState()
                    }
                }
            }
            .onFailure { error, _ ->
                errorMessage = "Display unavailable: ${error.description}"
                emitState()
            }
    }

    private fun attachInputs(session: DeviceSession) {
        if (inputs != null) return
        session.addInputs(
            InputsConfiguration(
                sources = buildSet {
                    add(InputSource.NEURAL_BAND)
                    add(InputSource.CAPTOUCH)
                    if (questionMode) add(InputSource.CAPTURE_BUTTON)
                },
                consumeBack = true,
            ),
        )
            .onSuccess { newInputs ->
                inputs = newInputs
                inputJobs += scope.launch {
                    newInputs.state.collect { state ->
                        if (state == InputsState.ACTIVE) inputsAvailability = "available"
                        emitState()
                    }
                }
                inputJobs += scope.launch {
                    newInputs.errors.collect { error ->
                        if (error == null) return@collect
                        inputsAvailability =
                            if (error == InputsError.PERMISSION_DENIED) "denied" else "unavailable"
                        emitState()
                    }
                }
                inputJobs += scope.launch { newInputs.events.collect(::onInputEvent) }
            }
            .onFailure { _, _ ->
                inputsAvailability = "unavailable"
                emitState()
            }
    }

    private fun detachInputs(current: DeviceSession) {
        inputJobs.forEach { it.cancel() }
        inputJobs.clear()
        if (inputs != null) current.removeInputs()
        inputs = null
        inputsAvailability = "unknown"
    }

    private fun onInputEvent(event: InputEvent) {
        val mapped =
            when (event) {
                is InputEvent.Nav ->
                    when (event.direction) {
                        NavDirection.RIGHT, NavDirection.DOWN -> "next"
                        NavDirection.LEFT, NavDirection.UP -> "previous"
                    }
                is InputEvent.Select -> "select"
                is InputEvent.Back -> "back"
                is InputEvent.Capture ->
                    if (questionMode && event.pressType == CapturePressType.SHORT_PRESS) "capture" else null
                else -> null // Button / Drag are unused.
            }
        if (mapped != null) inputSink?.success(mapped)
    }

    private fun stopSession() {
        // A user-initiated stop: errors from the old session no longer matter.
        errorJob?.cancel()
        if (connectJob?.isActive == true) {
            connectJob?.cancel()
            connecting = false
            emitState()
        }
        val current = session ?: return
        detachInputs(current)
        if (display != null) current.removeDisplay()
        current.stop()
        releaseSession()
        emitState()
    }

    private fun releaseSession() {
        questionCamera.cancel()
        inputJobs.forEach { it.cancel() }
        inputJobs.clear()
        sessionJobs.forEach { it.cancel() }
        sessionJobs.clear()
        session = null
        sessionState = null
        display = null
        displayReady = false
        inputs = null
        inputsAvailability = "unknown"
        connecting = false
        deviceName = null
    }

    // ---- Display content -----------------------------------------------------

    private fun showCue(call: MethodCall, result: MethodChannel.Result) {
        val target = display
        if (target == null || !displayReady) {
            result.success(false)
            return
        }
        val heading = call.argument<String>("heading").orEmpty()
        val lines = call.argument<List<String>>("lines").orEmpty()
        val next = call.argument<String>("next")
        val position = call.argument<Int>("position") ?: 0
        val total = call.argument<Int>("total") ?: 0
        val paused = call.argument<Boolean>("paused") ?: false

        scope.launch {
            // Serialize replacements and clears: a slow answer send must finish
            // before the next capture clears the old answer.
            val shown = withTimeoutOrNull(10_000L) {
                displayMutex.withLock {
                    if (display !== target || !displayReady) return@withLock false
                    target.sendContent {
                        flexBox(gap = 8, padding = 24, background = FlexBoxBackground.NONE) {
                            text(heading.uppercase(), style = TextStyle.META, color = TextColor.SECONDARY)
                            lines.forEach { text(it, style = TextStyle.HEADING) }
                            if (!next.isNullOrBlank()) {
                                text(next, style = TextStyle.BODY, color = TextColor.SECONDARY)
                            }
                            text(
                                "$position / $total" + if (paused) "  ·  Paused" else "",
                                style = TextStyle.META,
                                color = TextColor.SECONDARY,
                            )
                        }
                    }.fold(
                        onSuccess = { true },
                        onFailure = { error, _ ->
                            errorMessage = "Display update failed: ${error.description}"
                            emitState()
                            false
                        },
                    )
                }
            } ?: false
            result.success(shown)
        }
    }

    private fun clearDisplay(result: MethodChannel.Result) {
        scope.launch {
            val cleared = withTimeoutOrNull(10_000L) {
                displayMutex.withLock { display?.clearDisplay() }
                true
            } ?: false
            if (cleared) result.success(null)
            else result.error("display_timeout", "The glasses display did not respond. Try again.", null)
        }
    }

    // ---- State to Dart -------------------------------------------------------

    private fun emitState() {
        val status =
            when {
                !initialized && errorMessage != null -> "error"
                !initialized -> "unregistered"
                registration == RegistrationState.REGISTERING ||
                    registration == RegistrationState.UNREGISTERING -> "registering"
                registration != RegistrationState.REGISTERED -> "unregistered"
                session == null && connecting -> "connecting"
                session == null && errorMessage != null -> "error"
                session == null -> "disconnected"
                sessionState == DeviceSessionState.STARTED -> "connected"
                sessionState == DeviceSessionState.STOPPING ||
                    sessionState == DeviceSessionState.STOPPED -> "disconnected"
                else -> "connecting" // IDLE, STARTING, PAUSED
            }
        val message =
            errorMessage
                ?: if (sessionState == DeviceSessionState.PAUSED) "Session paused by the glasses." else null
        stateSink?.success(
            mapOf(
                "status" to status,
                "deviceName" to if (status == "connected") deviceName else null,
                "displayAvailable" to (status == "connected" && displayReady),
                "inputs" to inputsAvailability,
                "message" to message,
                "needsRepair" to needsRepair,
            ),
        )
    }

    fun dispose() {
        questionCamera.dispose()
        stopSession()
        scope.cancel()
        methods.setMethodCallHandler(null)
        stateEvents.setStreamHandler(null)
        inputEvents.setStreamHandler(null)
    }

    private companion object {
        const val PERMISSION_REQUEST = 4207
        const val TAG = "NeuralLensGlasses"
        const val APPLICATION_ID_KEY = "com.meta.wearable.mwdat.APPLICATION_ID"
        const val REPAIR_MESSAGE =
            "The glasses couldn't start NeuralLens. Tap Repair connection, approve NeuralLens " +
                "in Meta AI, then fully close and reopen NeuralLens before connecting again."
        const val DEVICE_LIST_TIMEOUT_MS = 3_000L
        const val LINK_TIMEOUT_MS = 15_000L
        const val RETRY_DELAY_MS = 2_500L
        const val MAX_RETRIES = 1
    }
}
