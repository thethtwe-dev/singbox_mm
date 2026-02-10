package com.signbox.singbox_mm

internal object PluginFactoryDefaults {
    val methodNames =
        PluginMethodDispatcher.MethodNames(
            initialize = PluginMethods.INITIALIZE,
            requestPermission = PluginMethods.REQUEST_VPN_PERMISSION,
            requestNotificationPermission = PluginMethods.REQUEST_NOTIFICATION_PERMISSION,
            setConfig = PluginMethods.SET_CONFIG,
            startVpn = PluginMethods.START_VPN,
            stopVpn = PluginMethods.STOP_VPN,
            restartVpn = PluginMethods.RESTART_VPN,
            getState = PluginMethods.GET_STATE,
            getStateDetails = PluginMethods.GET_STATE_DETAILS,
            getStats = PluginMethods.GET_STATS,
            getLastError = PluginMethods.GET_LAST_ERROR,
            getVersion = PluginMethods.GET_SINGBOX_VERSION,
            pingServer = PluginMethods.PING_SERVER,
            syncRuntime = PluginMethods.SYNC_RUNTIME_STATE,
        )

    val channelNames =
        PluginChannelNames(
            method = PluginChannels.METHOD,
            state = PluginChannels.STATE,
            stats = PluginChannels.STATS,
        )

    val runtimeDefaults =
        PluginRuntimeDefaults(
            configFileName = PluginDefaults.CONFIG_FILE_NAME,
            statsEmitIntervalMs = PluginDefaults.STATS_EMIT_INTERVAL_MS,
            networkValidationGraceMs = PluginDefaults.NETWORK_VALIDATION_GRACE_MS,
        )

    val stateConfig =
        PluginStateConfig(
            action = SignboxLibboxServiceContract.ACTION_STATE_UPDATE,
            extraStateKey = SignboxLibboxServiceContract.EXTRA_STATE,
            extraErrorKey = SignboxLibboxServiceContract.EXTRA_ERROR,
            disconnected = PluginStates.DISCONNECTED,
            preparing = PluginStates.PREPARING,
            connecting = PluginStates.CONNECTING,
            connected = PluginStates.CONNECTED,
            disconnecting = PluginStates.DISCONNECTING,
            error = PluginStates.ERROR,
        )
}
