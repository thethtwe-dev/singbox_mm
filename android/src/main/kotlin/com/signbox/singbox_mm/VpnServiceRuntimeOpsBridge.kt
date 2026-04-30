package com.signbox.singbox_mm

import io.nekohasekai.libbox.Notification as CoreNotification
import io.nekohasekai.libbox.PlatformInterface

internal class VpnServiceRuntimeOpsBridge(
    private val runtimeSession: VpnCoreRuntimeSession,
    private val notificationRuntime: VpnServiceNotificationRuntime,
    private val runtimeStateBridge: VpnServiceRuntimeStateBridge,
    private val host: PlatformInterface,
    private val stateError: String,
    private val logTag: String,
    private val scheduleStop: () -> Unit,
) {
    fun sendNotification(notification: CoreNotification) {
        val detail = VpnServiceActionExecutor.resolveNotificationDetail(notification)
        runtimeSession.coreNotificationDetail = detail
        notificationRuntime.notify(status = VpnNotificationStatus.CONNECTED, detail = detail)
    }

    fun serviceReload() {
        VpnServiceActionExecutor.reloadService(
            commandServer = runtimeSession.commandServer,
            configPath = runtimeSession.configPath,
            onSuccess = {
                // Success
            },
            onFailure = { message ->
                runtimeStateBridge.publish(stateError, "Reload failed: $message")
            },
        )
    }

    fun serviceStop() {
        scheduleStop()
    }

    fun writeLog(message: String) {
        VpnServiceActionExecutor.writeLog(logTag, message)
    }
}
