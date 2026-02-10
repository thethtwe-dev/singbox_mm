package com.signbox.singbox_mm

import io.nekohasekai.libbox.Libbox

internal data class PluginCoordinatorBundle(
    val channelBindingCoordinator: PluginChannelBindingCoordinator,
    val eventEmitter: PluginEventEmitterCoordinator,
    val streamHandlerCoordinator: PluginStreamHandlerCoordinator,
    val callbackRegistration: PluginCallbackRegistrationCoordinator,
    val permissionCoordinator: PluginPermissionCoordinator,
    val activityBindingCoordinator: PluginActivityBindingCoordinator,
    val methodOperations: PluginMethodOperations,
    val methodDispatcher: PluginMethodDispatcher,
    val statsTracker: PluginStatsTracker,
    val networkDiagnostics: PluginNetworkDiagnosticsTracker,
    val stateCoordinator: PluginConnectionStateCoordinator,
    val stateQueryOperations: PluginStateQueryOperations,
)

internal class PluginCoordinatorFactory(
    private val args: PluginCoordinatorFactoryArgs,
) {
    fun build(): PluginCoordinatorBundle {
        val runtimeConfigStore = createRuntimeConfigStore()
        val configOperations = createConfigOperations(runtimeConfigStore)
        val channelBindingCoordinator = createChannelBindingCoordinator()
        val eventEmitter = createEventEmitter(runtimeConfigStore)
        val streamHandlerCoordinator = createStreamHandlerCoordinator(eventEmitter)
        val statsTracker = createStatsTracker()
        val networkDiagnostics = createNetworkDiagnostics()
        val stateCoordinator = createStateCoordinator(networkDiagnostics)
        val stateQueryOperations = createStateQueryOperations(
            stateCoordinator = stateCoordinator,
            networkDiagnostics = networkDiagnostics,
            statsTracker = statsTracker,
        )
        val networkEventCoordinator = createNetworkEventCoordinator(
            stateCoordinator = stateCoordinator,
            networkDiagnostics = networkDiagnostics,
            statsTracker = statsTracker,
        )
        val vpnServiceController = createVpnServiceController(runtimeConfigStore, statsTracker)
        val methodOperations = createMethodOperations(vpnServiceController)
        val methodDispatcher = createMethodDispatcher(
            methodOperations = methodOperations,
            stateQueryOperations = stateQueryOperations,
            configOperations = configOperations,
        )
        val permissionCoordinator = createPermissionCoordinator()
        val activityBindingCoordinator = createActivityBindingCoordinator(permissionCoordinator)
        val callbackRegistration = createCallbackRegistration(networkEventCoordinator)

        return PluginCoordinatorBundle(
            channelBindingCoordinator = channelBindingCoordinator,
            eventEmitter = eventEmitter,
            streamHandlerCoordinator = streamHandlerCoordinator,
            callbackRegistration = callbackRegistration,
            permissionCoordinator = permissionCoordinator,
            activityBindingCoordinator = activityBindingCoordinator,
            methodOperations = methodOperations,
            methodDispatcher = methodDispatcher,
            statsTracker = statsTracker,
            networkDiagnostics = networkDiagnostics,
            stateCoordinator = stateCoordinator,
            stateQueryOperations = stateQueryOperations,
        )
    }

    private fun createRuntimeConfigStore(): PluginRuntimeConfigStore {
        return PluginRuntimeConfigStore(
            context = args.context,
            defaultConfigFileName = args.runtimeDefaults.configFileName,
            defaultStatsEmitIntervalMs = args.runtimeDefaults.statsEmitIntervalMs,
        )
    }

    private fun createConfigOperations(
        runtimeConfigStore: PluginRuntimeConfigStore,
    ): PluginConfigOperations {
        return PluginConfigOperations(
            executor = args.executor,
            runtimeConfigStore = runtimeConfigStore,
            postSuccess = args.postSuccess,
            postError = args.postError,
        )
    }

    private fun createChannelBindingCoordinator(): PluginChannelBindingCoordinator {
        return PluginChannelBindingCoordinator(
            methodChannelName = args.channelNames.method,
            stateChannelName = args.channelNames.state,
            statsChannelName = args.channelNames.stats,
        )
    }

    private fun createEventEmitter(
        runtimeConfigStore: PluginRuntimeConfigStore,
    ): PluginEventEmitterCoordinator {
        return PluginEventEmitterCoordinator(
            mainHandler = args.mainHandler,
            statsEmitIntervalMsProvider = { runtimeConfigStore.currentStatsEmitIntervalMs() },
        )
    }

    private fun createStreamHandlerCoordinator(
        eventEmitter: PluginEventEmitterCoordinator,
    ): PluginStreamHandlerCoordinator {
        return PluginStreamHandlerCoordinator(
            eventEmitter = eventEmitter,
            syncStateFromPersistedRuntime = args.syncStateFromPersistedRuntime,
            emitState = args.emitState,
            emitStats = args.emitStats,
        )
    }

    private fun createStatsTracker(): PluginStatsTracker {
        return PluginStatsTracker(
            readUidTxBytes = args.readUidTxBytes,
            readUidRxBytes = args.readUidRxBytes,
        )
    }

    private fun createNetworkDiagnostics(): PluginNetworkDiagnosticsTracker {
        return PluginNetworkDiagnosticsTracker(
            connectivityProvider = { args.connectivity },
            networkValidationGraceMs = args.runtimeDefaults.networkValidationGraceMs,
        )
    }

    private fun createStateCoordinator(
        networkDiagnostics: PluginNetworkDiagnosticsTracker,
    ): PluginConnectionStateCoordinator {
        return PluginConnectionStateCoordinator(
            disconnectedState = args.stateConfig.disconnected,
            connectingState = args.stateConfig.connecting,
            connectedState = args.stateConfig.connected,
            errorState = args.stateConfig.error,
            onConnectedOrConnecting = {
                networkDiagnostics.refreshFromSystem()
            },
            onDisconnectedOrError = {
                networkDiagnostics.clear()
            },
            onRefreshDerivedStateDetail = { state, error ->
                networkDiagnostics.refreshDerivedStateDetail(
                    connectionState = state,
                    lastError = error,
                    connectedState = args.stateConfig.connected,
                    errorState = args.stateConfig.error,
                )
            },
            onEmitStateAndStats = {
                args.emitState()
                args.emitStats()
            },
        )
    }

    private fun createStateQueryOperations(
        stateCoordinator: PluginConnectionStateCoordinator,
        networkDiagnostics: PluginNetworkDiagnosticsTracker,
        statsTracker: PluginStatsTracker,
    ): PluginStateQueryOperations {
        return PluginStateQueryOperations(
            executor = args.executor,
            syncStateFromPersistedRuntime = args.syncStateFromPersistedRuntime,
            emitState = args.emitState,
            emitStats = args.emitStats,
            postSuccess = args.postSuccess,
            currentStateProvider = { stateCoordinator.currentState },
            currentErrorProvider = { stateCoordinator.currentError },
            stateSnapshotProvider = { stateCoordinator.snapshot() },
            diagnosticsSnapshotProvider = { networkDiagnostics.snapshot() },
            refreshNetworkDiagnostics = { networkDiagnostics.refreshFromSystem() },
            refreshDerivedStateDetail = args.refreshDerivedStateDetail,
            statsPayloadProvider = { state ->
                statsTracker.buildStatsMap(
                    connectionState = state,
                    connectedState = args.stateConfig.connected,
                )
            },
            connectedState = args.stateConfig.connected,
            connectingState = args.stateConfig.connecting,
        )
    }

    private fun createNetworkEventCoordinator(
        stateCoordinator: PluginConnectionStateCoordinator,
        networkDiagnostics: PluginNetworkDiagnosticsTracker,
        statsTracker: PluginStatsTracker,
    ): PluginNetworkEventCoordinator {
        return PluginNetworkEventCoordinator(
            stateAction = args.stateConfig.action,
            stateExtraStateKey = args.stateConfig.extraStateKey,
            stateExtraErrorKey = args.stateConfig.extraErrorKey,
            connectedState = args.stateConfig.connected,
            connectingState = args.stateConfig.connecting,
            disconnectedState = args.stateConfig.disconnected,
            errorState = args.stateConfig.error,
            onConnectedState = {
                statsTracker.onConnectedState()
            },
            onDisconnectedOrErrorState = {
                statsTracker.onDisconnectedState()
            },
            updateConnectionState = args.updateConnectionState,
            refreshNetworkDiagnostics = { networkDiagnostics.refreshFromSystem() },
            clearNetworkDiagnostics = { networkDiagnostics.clear() },
            refreshDerivedStateDetail = args.refreshDerivedStateDetail,
            emitState = args.emitState,
            currentStateProvider = { stateCoordinator.currentState },
        )
    }

    private fun createVpnServiceController(
        runtimeConfigStore: PluginRuntimeConfigStore,
        statsTracker: PluginStatsTracker,
    ): PluginVpnServiceController {
        return PluginVpnServiceController(
            context = args.context,
            runtimeConfigStore = runtimeConfigStore,
            statsTracker = statsTracker,
            updateConnectionState = args.updateConnectionState,
            preparingState = args.stateConfig.preparing,
            disconnectingState = args.stateConfig.disconnecting,
            startService = { serviceContext, configPath ->
                SignboxLibboxServiceContract.start(serviceContext, configPath)
            },
            stopService = { serviceContext ->
                SignboxLibboxServiceContract.stop(serviceContext)
            },
        )
    }

    private fun createMethodOperations(
        vpnServiceController: PluginVpnServiceController,
    ): PluginMethodOperations {
        return PluginMethodOperations(
            executor = args.executor,
            postSuccess = args.postSuccess,
            postError = args.postError,
            updateConnectionState = args.updateConnectionState,
            errorState = args.stateConfig.error,
            startVpnInternal = { vpnServiceController.startVpn() },
            stopVpnInternal = { vpnServiceController.stopVpn() },
            versionProvider = { Libbox.version() },
        )
    }

    private fun createMethodDispatcher(
        methodOperations: PluginMethodOperations,
        stateQueryOperations: PluginStateQueryOperations,
        configOperations: PluginConfigOperations,
    ): PluginMethodDispatcher {
        return PluginMethodDispatcher(
            methodNames = args.methodNames,
            handlers = PluginMethodHandlersFactory.create(
                args = args,
                methodOperations = methodOperations,
                stateQueryOperations = stateQueryOperations,
                configOperations = configOperations,
            ),
        )
    }

    private fun createPermissionCoordinator(): PluginPermissionCoordinator {
        return PluginPermissionCoordinator(
            context = args.context,
            onVpnPermissionDenied = {
                args.updateConnectionState(args.stateConfig.disconnected, "VPN permission denied by user")
            },
        )
    }

    private fun createActivityBindingCoordinator(
        permissionCoordinator: PluginPermissionCoordinator,
    ): PluginActivityBindingCoordinator {
        return PluginActivityBindingCoordinator(
            permissionCoordinator = permissionCoordinator,
            activityResultListener = args.activityResultListener,
            requestPermissionsResultListener = args.requestPermissionsResultListener,
        )
    }

    private fun createCallbackRegistration(
        networkEventCoordinator: PluginNetworkEventCoordinator,
    ): PluginCallbackRegistrationCoordinator {
        return PluginCallbackRegistrationCoordinator(
            context = args.context,
            connectivity = args.connectivity,
            mainHandler = args.mainHandler,
            stateReceiver = networkEventCoordinator.stateReceiver,
            stateAction = args.stateConfig.action,
            vpnNetworkCallback = networkEventCoordinator.vpnNetworkCallback,
            upstreamNetworkCallback = networkEventCoordinator.upstreamNetworkCallback,
        )
    }
}
