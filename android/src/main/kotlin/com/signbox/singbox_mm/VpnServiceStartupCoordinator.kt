package com.signbox.singbox_mm

internal class VpnServiceStartupCoordinator(
    private val runtimeStateBridge: VpnServiceRuntimeStateBridge,
    private val runtimeSession: VpnCoreRuntimeSession,
    private val trafficMonitor: NotificationTrafficMonitor,
    private val notificationRuntime: VpnServiceNotificationRuntime,
) {
    fun onCreateBootstrap() {
        runtimeStateBridge.restoreSnapshot { snapshot ->
            runtimeSession.configPath = snapshot.configPath ?: runtimeSession.configPath
            trafficMonitor.restoreSession(
                connectedAtMillis = snapshot.connectedAtMillis,
                uplinkBase = snapshot.uplinkBytesBase,
                downlinkBase = snapshot.downlinkBytesBase,
            )
        }
        notificationRuntime.ensureChannel()
    }
}
