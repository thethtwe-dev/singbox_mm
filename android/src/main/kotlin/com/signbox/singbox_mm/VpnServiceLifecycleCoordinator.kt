package com.signbox.singbox_mm

import java.util.concurrent.ExecutorService

internal class VpnServiceLifecycleCoordinator(
    private val liveNotificationTicker: VpnLiveNotificationTicker,
    private val defaultInterfaceMonitorController: VpnDefaultInterfaceMonitorController,
    private val coreServiceCoordinator: VpnCoreServiceCoordinator,
    private val worker: ExecutorService,
    private val stopForeground: (Int) -> Unit,
    private val stopForegroundFlag: Int,
    private val stopSelf: () -> Unit,
) {
    fun onDestroyBeforeSuper() {
        liveNotificationTicker.stop()
        defaultInterfaceMonitorController.shutdown()
        coreServiceCoordinator.stop(emitDisconnected = false)
        worker.shutdownNow()
    }

    fun onRevoke() {
        coreServiceCoordinator.stop(emitDisconnected = true)
        stopForeground(stopForegroundFlag)
        stopSelf()
    }
}
