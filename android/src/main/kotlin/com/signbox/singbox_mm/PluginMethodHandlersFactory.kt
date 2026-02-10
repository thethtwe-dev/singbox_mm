package com.signbox.singbox_mm

internal object PluginMethodHandlersFactory {
    fun create(
        args: PluginCoordinatorFactoryArgs,
        methodOperations: PluginMethodOperations,
        stateQueryOperations: PluginStateQueryOperations,
        configOperations: PluginConfigOperations,
    ): PluginMethodDispatcher.Handlers {
        return PluginMethodDispatcher.Handlers(
            initialize = { arguments, result ->
                configOperations.initialize(arguments, result)
            },
            requestPermission = args.requestVpnPermission,
            requestNotificationPermission = args.requestNotificationPermission,
            setConfig = { arguments, result ->
                configOperations.setConfig(arguments, result)
            },
            startVpn = { result -> methodOperations.startVpn(result) },
            stopVpn = { result -> methodOperations.stopVpn(result) },
            restartVpn = { result -> methodOperations.restartVpn(result) },
            getState = { result -> stateQueryOperations.getState(result) },
            getStateDetails = { result -> stateQueryOperations.getStateDetails(result) },
            getStats = { result -> stateQueryOperations.getStats(result) },
            getLastError = { result -> stateQueryOperations.getLastError(result) },
            getVersion = { result -> methodOperations.getSingboxVersion(result) },
            pingServer = { arguments, result ->
                methodOperations.pingServer(arguments, result)
            },
            syncRuntime = { result -> stateQueryOperations.syncRuntimeState(result) },
        )
    }
}
