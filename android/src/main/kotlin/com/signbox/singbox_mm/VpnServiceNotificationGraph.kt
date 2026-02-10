package com.signbox.singbox_mm

import android.os.Handler

internal class VpnServiceNotificationGraph(
    private val service: SignboxLibboxVpnService,
    private val runtimeSession: VpnCoreRuntimeSession,
    private val trafficMonitor: NotificationTrafficMonitor,
    private val mainHandler: Handler,
) {
    val notificationRuntime by lazy {
        VpnServiceNotificationRuntime(
            context = service,
            channelId = SignboxLibboxServiceContract.NOTIFICATION_CHANNEL_ID,
            channelName = SignboxLibboxServiceContract.NOTIFICATION_CHANNEL_NAME,
            notificationId = SignboxLibboxServiceContract.NOTIFICATION_ID,
            defaultProfileLabel = SignboxLibboxServiceContract.DEFAULT_PROFILE_LABEL,
            appPackageName = service.packageName,
            serviceClass = SignboxLibboxVpnService::class.java,
            openAppRequestCode = SignboxLibboxServiceContract.REQUEST_OPEN_APP_ACTION,
            stopRequestCode = SignboxLibboxServiceContract.REQUEST_STOP_ACTION,
            restartRequestCode = SignboxLibboxServiceContract.REQUEST_RESTART_ACTION,
            stopAction = SignboxLibboxServiceContract.ACTION_STOP,
            restartAction = SignboxLibboxServiceContract.ACTION_RESTART,
            configPathExtraKey = SignboxLibboxServiceContract.EXTRA_CONFIG_PATH,
            resolveSmallIcon = { VpnNotificationIconResolver.resolve(service) },
            readProfileLabel = { runtimeSession.profileLabel },
            readConfigPath = { runtimeSession.configPath },
            readConnectedSinceMillis = { trafficMonitor.connectedSinceMillis },
            captureTrafficSnapshot = {
                VpnTrafficSessionCoordinator.captureSnapshot(trafficMonitor)
            },
            readConnectedDetail = { runtimeSession.coreNotificationDetail },
        )
    }

    val liveNotificationTicker by lazy {
        VpnLiveNotificationTicker(
            handler = mainHandler,
            intervalMillis = SignboxLibboxServiceContract.NOTIFICATION_STATS_INTERVAL_MS,
            shouldTick = {
                VpnNotificationRuntimeCoordinator.shouldKeepLiveTicker(
                    boxService = runtimeSession.boxService,
                    connectedSinceMillis = trafficMonitor.connectedSinceMillis,
                )
            },
            onTick = {
                notificationRuntime.notify(
                    status = VpnNotificationStatus.CONNECTED,
                    detail = runtimeSession.coreNotificationDetail,
                )
            },
        )
    }
}
