package com.signbox.singbox_mm

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** SingboxMmPlugin */
class SingboxMmPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private var channelBindings: PluginChannelBindingCoordinator.BindingSet? = null

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val connectivity by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private val coordinators by lazy {
        PluginCoordinatorFactory(createCoordinatorFactoryArgs()).build()
    }

    private val eventEmitter: PluginEventEmitterCoordinator
        get() = coordinators.eventEmitter

    private val callbackRegistration: PluginCallbackRegistrationCoordinator
        get() = coordinators.callbackRegistration

    private val permissionCoordinator: PluginPermissionCoordinator
        get() = coordinators.permissionCoordinator

    private val activityBindingCoordinator: PluginActivityBindingCoordinator
        get() = coordinators.activityBindingCoordinator

    private val channelBindingCoordinator: PluginChannelBindingCoordinator
        get() = coordinators.channelBindingCoordinator

    private val streamHandlerCoordinator: PluginStreamHandlerCoordinator
        get() = coordinators.streamHandlerCoordinator

    private val methodDispatcher: PluginMethodDispatcher
        get() = coordinators.methodDispatcher

    private val statsTracker: PluginStatsTracker
        get() = coordinators.statsTracker

    private val networkDiagnostics: PluginNetworkDiagnosticsTracker
        get() = coordinators.networkDiagnostics

    private val stateCoordinator: PluginConnectionStateCoordinator
        get() = coordinators.stateCoordinator

    private val stateQueryOperations: PluginStateQueryOperations
        get() = coordinators.stateQueryOperations

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channelBindings = channelBindingCoordinator.attach(
            binaryMessenger = flutterPluginBinding.binaryMessenger,
            methodCallHandler = this,
            stateStreamHandler = this,
            statsStreamHandler = streamHandlerCoordinator.statsStreamHandler,
        )
        callbackRegistration.registerAll()
        syncStateFromPersistedRuntime(forceEmit = false)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channelBindingCoordinator.detach(channelBindings)
        channelBindings = null
        callbackRegistration.unregisterAll()
        shutdownRuntime()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        methodDispatcher.onMethodCall(call, result)
    }

    private fun requestVpnPermission(result: Result) {
        permissionCoordinator.requestVpnPermission(result)
    }

    private fun requestNotificationPermission(result: Result) {
        permissionCoordinator.requestNotificationPermission(result)
    }

    private fun updateConnectionState(newState: String, error: String?) {
        stateCoordinator.updateConnectionState(newState, error)
    }

    private fun emitState() {
        val payload = stateQueryOperations.buildStateMap()
        eventEmitter.emitState(payload)
    }

    private fun emitStats() {
        val state = stateCoordinator.currentState
        val payload =
            statsTracker.buildStatsMap(
                connectionState = state,
                connectedState = PluginStates.CONNECTED,
            )
        eventEmitter.emitStats(payload)
    }

    private fun readUidTxBytes(): Long {
        val value = TrafficStats.getUidTxBytes(android.os.Process.myUid())
        return if (value == TrafficStats.UNSUPPORTED.toLong()) 0L else value
    }

    private fun readUidRxBytes(): Long {
        val value = TrafficStats.getUidRxBytes(android.os.Process.myUid())
        return if (value == TrafficStats.UNSUPPORTED.toLong()) 0L else value
    }

    private fun refreshDerivedStateDetail() {
        val stateSnapshot = stateCoordinator.snapshot()
        networkDiagnostics.refreshDerivedStateDetail(
            connectionState = stateSnapshot.state,
            lastError = stateSnapshot.lastError,
            connectedState = PluginStates.CONNECTED,
            errorState = PluginStates.ERROR,
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        streamHandlerCoordinator.onStateListen(events)
    }

    override fun onCancel(arguments: Any?) {
        streamHandlerCoordinator.onStateCancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBindingCoordinator.attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBindingCoordinator.detach()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBindingCoordinator.attach(binding)
    }

    override fun onDetachedFromActivity() {
        activityBindingCoordinator.detach()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return permissionCoordinator.onActivityResult(requestCode, resultCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        return permissionCoordinator.onRequestPermissionsResult(requestCode, grantResults)
    }

    private fun shutdownRuntime() {
        executor.shutdown()
        eventEmitter.shutdown()
    }

    private fun syncStateFromPersistedRuntime(forceEmit: Boolean): Boolean {
        val snapshot = SignboxLibboxServiceContract.readPersistedRuntimeState(context) ?: return false
        return stateCoordinator.syncStateFromPersistedRuntime(
            snapshot = snapshot,
            forceEmit = forceEmit,
            statsTracker = statsTracker,
        )
    }

    private fun postSuccess(result: Result, value: Any?) {
        mainHandler.post {
            result.success(value)
        }
    }

    private fun postError(result: Result, code: String, message: String, details: Any? = null) {
        mainHandler.post {
            result.error(code, message, details)
        }
    }

    private fun createCoordinatorFactoryArgs(): PluginCoordinatorFactoryArgs {
        return PluginCoordinatorFactoryArgs(
            context = context,
            connectivity = connectivity,
            executor = executor,
            mainHandler = mainHandler,
            activityResultListener = this,
            requestPermissionsResultListener = this,
            readUidTxBytes = ::readUidTxBytes,
            readUidRxBytes = ::readUidRxBytes,
            updateConnectionState = ::updateConnectionState,
            emitState = ::emitState,
            emitStats = ::emitStats,
            refreshDerivedStateDetail = ::refreshDerivedStateDetail,
            syncStateFromPersistedRuntime = ::syncStateFromPersistedRuntime,
            postSuccess = ::postSuccess,
            postError = { result, code, message -> postError(result, code, message) },
            requestVpnPermission = ::requestVpnPermission,
            requestNotificationPermission = ::requestNotificationPermission,
            methodNames = PluginFactoryDefaults.methodNames,
            channelNames = PluginFactoryDefaults.channelNames,
            runtimeDefaults = PluginFactoryDefaults.runtimeDefaults,
            stateConfig = PluginFactoryDefaults.stateConfig,
        )
    }
}
