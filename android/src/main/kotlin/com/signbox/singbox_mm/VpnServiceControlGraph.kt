package com.signbox.singbox_mm

import android.net.VpnService
import java.util.concurrent.ExecutorService

internal class VpnServiceControlGraph(
    private val service: SignboxLibboxVpnService,
    private val worker: ExecutorService,
    private val runtimeSession: VpnCoreRuntimeSession,
    private val notificationRuntime: VpnServiceNotificationRuntime,
    private val liveNotificationTicker: VpnLiveNotificationTicker,
    private val trafficMonitor: NotificationTrafficMonitor,
    private val platformGraph: VpnServicePlatformGraph,
    private val resolvePrivateDnsHost: () -> String?,
) {
    private val runtimeStateBridge by lazy {
        VpnServiceRuntimeStateBridge(
            context = service,
            initialState = SignboxLibboxServiceContract.STATE_DISCONNECTED,
            actionStateUpdate = SignboxLibboxServiceContract.ACTION_STATE_UPDATE,
            packageName = service.packageName,
            stateExtraKey = SignboxLibboxServiceContract.EXTRA_STATE,
            errorExtraKey = SignboxLibboxServiceContract.EXTRA_ERROR,
            updateNotificationForState = { state, error ->
                notificationRuntime.notifyForState(state, error)
            },
            readConnectedSinceMillis = { trafficMonitor.connectedSinceMillis },
            readUplinkBytesBase = { trafficMonitor.uplinkBytesBase },
            readDownlinkBytesBase = { trafficMonitor.downlinkBytesBase },
            readConfigPath = { runtimeSession.configPath },
        )
    }

    private val actionScheduler: VpnServiceActionScheduler by lazy {
        VpnServiceActionScheduler(
            worker = worker,
            stopCore = { emitDisconnected -> coreServiceCoordinator.stop(emitDisconnected) },
            startCore = { configPath -> coreServiceCoordinator.start(configPath) },
            publishError = { message ->
                runtimeStateBridge.publish(SignboxLibboxServiceContract.STATE_ERROR, message)
            },
            stopForeground = { stopForegroundFlag ->
                service.stopForeground(stopForegroundFlag)
            },
            stopForegroundFlag = VpnService.STOP_FOREGROUND_REMOVE,
            stopSelf = { service.stopSelf() },
        )
    }

    private val runtimeOpsBridge: VpnServiceRuntimeOpsBridge by lazy {
        VpnServiceRuntimeOpsBridge(
            runtimeSession = runtimeSession,
            notificationRuntime = notificationRuntime,
            runtimeStateBridge = runtimeStateBridge,
            host = platformInterfaceBridge,
            stateError = SignboxLibboxServiceContract.STATE_ERROR,
            logTag = SignboxLibboxServiceContract.LOG_TAG,
            scheduleStop = { actionScheduler.scheduleStop() },
        )
    }

    private val platformInterfaceBridge: VpnCorePlatformInterfaceBridge by lazy {
        platformGraph.createPlatformInterfaceBridge(
            sendCoreNotification = { notification ->
                runtimeOpsBridge.sendNotification(notification)
            },
            writeCoreLog = { message ->
                runtimeOpsBridge.writeLog(message)
            },
        )
    }

    private val commandHandlerBridge: VpnCoreCommandHandlerBridge by lazy {
        platformGraph.createCommandHandlerBridge(
            serviceReload = {
                runtimeOpsBridge.serviceReload()
            },
            postServiceClose = {
                runtimeOpsBridge.postServiceClose()
            },
        )
    }

    private val coreServiceCoordinator by lazy {
        VpnCoreServiceCoordinator(
            context = service,
            platformInterface = platformInterfaceBridge,
            commandHandler = commandHandlerBridge,
            runtimeSession = runtimeSession,
            runtimeStateBridge = runtimeStateBridge,
            notificationRuntime = notificationRuntime,
            trafficMonitor = trafficMonitor,
            liveNotificationTicker = liveNotificationTicker,
            readPrivateDnsHost = resolvePrivateDnsHost,
            logTag = SignboxLibboxServiceContract.LOG_TAG,
            defaultProfileLabel = SignboxLibboxServiceContract.DEFAULT_PROFILE_LABEL,
            commandPort = SignboxLibboxServiceContract.CORE_COMMAND_PORT,
            statePreparing = SignboxLibboxServiceContract.STATE_PREPARING,
            stateConnecting = SignboxLibboxServiceContract.STATE_CONNECTING,
            stateConnected = SignboxLibboxServiceContract.STATE_CONNECTED,
            stateDisconnected = SignboxLibboxServiceContract.STATE_DISCONNECTED,
            stateError = SignboxLibboxServiceContract.STATE_ERROR,
        )
    }

    private val lifecycleCommandBundle by lazy {
        VpnServiceLifecycleCommandBundle(
            runtimeSession = runtimeSession,
            notificationRuntime = notificationRuntime,
            actionScheduler = actionScheduler,
            coreServiceCoordinator = coreServiceCoordinator,
            liveNotificationTicker = liveNotificationTicker,
            defaultInterfaceMonitorController = platformGraph.defaultInterfaceMonitorController,
            worker = worker,
            runtimeStateBridge = runtimeStateBridge,
            trafficMonitor = trafficMonitor,
            readPersistedConfigPath = {
                SignboxLibboxServiceContract.readPersistedRuntimeState(service)?.configPath
            },
            stopForegroundFlag = VpnService.STOP_FOREGROUND_REMOVE,
            startNotSticky = VpnService.START_NOT_STICKY,
            startRedeliverIntent = VpnService.START_REDELIVER_INTENT,
            showForeground = { status, detail ->
                service.startForeground(
                    SignboxLibboxServiceContract.NOTIFICATION_ID,
                    notificationRuntime.buildNotification(status = status, detail = detail),
                )
            },
            stopForeground = { stopForegroundFlag ->
                service.stopForeground(stopForegroundFlag)
            },
            stopSelf = { service.stopSelf() },
        )
    }

    fun onCreate() {
        lifecycleCommandBundle.onCreateBootstrap()
    }

    fun onDestroyBeforeSuper() {
        lifecycleCommandBundle.onDestroyBeforeSuper()
    }

    fun onRevoke() {
        lifecycleCommandBundle.onRevoke()
    }

    fun onStartCommand(
        intentAction: String?,
        intentConfigPath: String?,
    ): Int {
        return lifecycleCommandBundle.onStartCommand(
            intentAction = intentAction,
            intentConfigPath = intentConfigPath,
        )
    }
}
