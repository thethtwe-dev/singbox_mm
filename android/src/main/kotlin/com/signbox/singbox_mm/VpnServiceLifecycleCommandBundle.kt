package com.signbox.singbox_mm

import java.util.concurrent.ExecutorService

internal class VpnServiceLifecycleCommandBundle(
    private val runtimeSession: VpnCoreRuntimeSession,
    private val notificationRuntime: VpnServiceNotificationRuntime,
    private val actionScheduler: VpnServiceActionScheduler,
    private val coreServiceCoordinator: VpnCoreServiceCoordinator,
    private val liveNotificationTicker: VpnLiveNotificationTicker,
    private val defaultInterfaceMonitorController: VpnDefaultInterfaceMonitorController,
    private val worker: ExecutorService,
    private val runtimeStateBridge: VpnServiceRuntimeStateBridge,
    private val trafficMonitor: NotificationTrafficMonitor,
    private val readPersistedRuntimeState: () -> PersistedRuntimeState?,
    private val stopForegroundFlag: Int,
    private val startNotSticky: Int,
    private val startRedeliverIntent: Int,
    private val showForeground: (String, String?) -> Unit,
    private val stopForeground: (Int) -> Unit,
    private val stopSelf: () -> Unit,
) {
    private val commandCoordinator by lazy {
        VpnServiceCommandCoordinator(
            readCurrentConfigPath = { runtimeSession.configPath },
            readPersistedRuntimeState = readPersistedRuntimeState,
            hasRunningCore = { runtimeSession.boxService != null },
            readConnectedDetail = { runtimeSession.coreNotificationDetail },
            actionStop = SignboxLibboxServiceContract.ACTION_STOP,
            actionRestart = SignboxLibboxServiceContract.ACTION_RESTART,
            actionStart = SignboxLibboxServiceContract.ACTION_START,
            statePreparing = SignboxLibboxServiceContract.STATE_PREPARING,
            stateConnecting = SignboxLibboxServiceContract.STATE_CONNECTING,
            stateConnected = SignboxLibboxServiceContract.STATE_CONNECTED,
            stateDisconnected = SignboxLibboxServiceContract.STATE_DISCONNECTED,
            stoppedByUserError = SignboxLibboxServiceContract.ERROR_STOPPED_BY_USER,
            statusStarting = VpnNotificationStatus.STARTING,
            statusRestarting = VpnNotificationStatus.RESTARTING,
            statusRestoring = VpnNotificationStatus.RESTORING,
            statusConnected = VpnNotificationStatus.CONNECTED,
            startNotSticky = startNotSticky,
            startRedeliverIntent = startRedeliverIntent,
            showForeground = showForeground,
            scheduleStop = { actionScheduler.scheduleStop() },
            scheduleRestart = { configPath -> actionScheduler.scheduleRestart(configPath) },
            scheduleStart = { configPath -> actionScheduler.scheduleStart(configPath) },
            stopSelf = stopSelf,
        )
    }

    private val lifecycleCoordinator by lazy {
        VpnServiceLifecycleCoordinator(
            liveNotificationTicker = liveNotificationTicker,
            defaultInterfaceMonitorController = defaultInterfaceMonitorController,
            coreServiceCoordinator = coreServiceCoordinator,
            worker = worker,
            stopForeground = stopForeground,
            stopForegroundFlag = stopForegroundFlag,
            stopSelf = stopSelf,
        )
    }

    private val startupCoordinator by lazy {
        VpnServiceStartupCoordinator(
            runtimeStateBridge = runtimeStateBridge,
            runtimeSession = runtimeSession,
            trafficMonitor = trafficMonitor,
            notificationRuntime = notificationRuntime,
        )
    }

    fun onCreateBootstrap() {
        startupCoordinator.onCreateBootstrap()
    }

    fun onDestroyBeforeSuper() {
        lifecycleCoordinator.onDestroyBeforeSuper()
    }

    fun onRevoke() {
        lifecycleCoordinator.onRevoke()
    }

    fun onStartCommand(
        intentAction: String?,
        intentConfigPath: String?,
    ): Int {
        return commandCoordinator.onStartCommand(
            intentAction = intentAction,
            intentConfigPath = intentConfigPath,
        )
    }
}
