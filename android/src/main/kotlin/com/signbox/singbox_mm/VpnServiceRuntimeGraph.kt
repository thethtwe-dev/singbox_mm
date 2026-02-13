package com.signbox.singbox_mm

import android.content.Context
import android.net.ConnectivityManager
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal class VpnServiceRuntimeGraph(
    private val service: SignboxLibboxVpnService,
) {
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val connectivity by lazy {
        service.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    private val resolvePrivateDnsHost: () -> String? = {
        VpnPrivateDnsHostResolver.resolve(service, connectivity)
    }
    private val mainHandler by lazy {
        Handler(Looper.getMainLooper())
    }
    private val notificationTrafficMonitor by lazy {
        NotificationTrafficMonitor(
            readUidTxBytes = { VpnTrafficStatsReader.readUidTxBytes(service.applicationInfo.uid) },
            readUidRxBytes = { VpnTrafficStatsReader.readUidRxBytes(service.applicationInfo.uid) },
        )
    }

    private val coreRuntimeSession = VpnCoreRuntimeSession()

    private val platformGraph by lazy {
        VpnServicePlatformGraph(
            service = service,
            connectivity = connectivity,
            mainHandler = mainHandler,
            runtimeSession = coreRuntimeSession,
            resolvePrivateDnsHost = resolvePrivateDnsHost,
        )
    }

    private val notificationGraph by lazy {
        VpnServiceNotificationGraph(
            service = service,
            runtimeSession = coreRuntimeSession,
            trafficMonitor = notificationTrafficMonitor,
            mainHandler = mainHandler,
        )
    }

    private val notificationRuntime by lazy {
        notificationGraph.notificationRuntime
    }

    private val liveNotificationTicker by lazy {
        notificationGraph.liveNotificationTicker
    }

    private val controlGraph by lazy {
        VpnServiceControlGraph(
            service = service,
            worker = worker,
            runtimeSession = coreRuntimeSession,
            notificationRuntime = notificationRuntime,
            liveNotificationTicker = liveNotificationTicker,
            trafficMonitor = notificationTrafficMonitor,
            platformGraph = platformGraph,
            resolvePrivateDnsHost = resolvePrivateDnsHost,
        )
    }

    fun onCreate() {
        controlGraph.onCreate()
    }

    fun onDestroyBeforeSuper() {
        controlGraph.onDestroyBeforeSuper()
    }

    fun onRevoke() {
        controlGraph.onRevoke()
    }

    fun onStartCommand(
        intentAction: String?,
        intentConfigPath: String?,
    ): Int {
        return controlGraph.onStartCommand(
            intentAction = intentAction,
            intentConfigPath = intentConfigPath,
        )
    }
}
