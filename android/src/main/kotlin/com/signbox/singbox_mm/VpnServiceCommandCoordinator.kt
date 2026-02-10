package com.signbox.singbox_mm

internal class VpnServiceCommandCoordinator(
    private val readCurrentConfigPath: () -> String?,
    private val readPersistedConfigPath: () -> String?,
    private val hasRunningCore: () -> Boolean,
    private val readConnectedDetail: () -> String?,
    private val actionStop: String,
    private val actionRestart: String,
    private val actionStart: String,
    private val statusStarting: String,
    private val statusRestarting: String,
    private val statusRestoring: String,
    private val statusConnected: String,
    private val startNotSticky: Int,
    private val startRedeliverIntent: Int,
    private val showForeground: (status: String, detail: String?) -> Unit,
    private val scheduleStop: () -> Unit,
    private val scheduleRestart: (String?) -> Unit,
    private val scheduleStart: (String?) -> Unit,
    private val stopSelf: () -> Unit,
) {
    fun onStartCommand(intentAction: String?, intentConfigPath: String?): Int {
        return VpnStartCommandRouter.route(
            intentAction = intentAction,
            intentConfigPath = intentConfigPath,
            currentConfigPath = readCurrentConfigPath(),
            persistedConfigPath = readPersistedConfigPath(),
            hasRunningCore = hasRunningCore(),
            connectedDetail = readConnectedDetail(),
            actionStop = actionStop,
            actionRestart = actionRestart,
            actionStart = actionStart,
            statusStarting = statusStarting,
            statusRestarting = statusRestarting,
            statusRestoring = statusRestoring,
            statusConnected = statusConnected,
            startNotSticky = startNotSticky,
            startRedeliverIntent = startRedeliverIntent,
            showForeground = showForeground,
            scheduleStop = scheduleStop,
            scheduleRestart = scheduleRestart,
            scheduleStart = scheduleStart,
            stopSelf = stopSelf,
        )
    }
}
