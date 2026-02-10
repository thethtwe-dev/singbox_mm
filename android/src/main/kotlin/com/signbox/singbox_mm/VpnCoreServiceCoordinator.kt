package com.signbox.singbox_mm

import android.content.Context
import android.util.Log
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.PlatformInterface

internal class VpnCoreServiceCoordinator(
    private val context: Context,
    private val platformInterface: PlatformInterface,
    private val commandHandler: CommandServerHandler,
    private val runtimeSession: VpnCoreRuntimeSession,
    private val runtimeStateBridge: VpnServiceRuntimeStateBridge,
    private val notificationRuntime: VpnServiceNotificationRuntime,
    private val trafficMonitor: NotificationTrafficMonitor,
    private val liveNotificationTicker: VpnLiveNotificationTicker,
    private val readPrivateDnsHost: () -> String?,
    private val logTag: String,
    private val defaultProfileLabel: String,
    private val commandPort: Int,
    private val statePreparing: String,
    private val stateConnecting: String,
    private val stateConnected: String,
    private val stateDisconnected: String,
    private val stateError: String,
) {
    fun start(configPath: String?) {
        when (
            val result = VpnCoreStartFlow.execute(
                request = VpnCoreStartRequest(
                    context = context,
                    configPath = configPath,
                    privateDnsHost = readPrivateDnsHost(),
                    defaultProfileLabel = defaultProfileLabel,
                    logTag = logTag,
                    commandPort = commandPort,
                    platformInterface = platformInterface,
                    commandHandler = commandHandler,
                    beforeRuntimeStart = {
                        // Avoid multiple core instances when start is triggered repeatedly.
                        stop(emitDisconnected = false)
                    },
                    onPreparing = { profileLabel ->
                        runtimeSession.bindPreparedProfile(profileLabel)
                        runtimeStateBridge.publish(statePreparing, null)
                    },
                    onConnecting = {
                        runtimeStateBridge.publish(stateConnecting, null)
                    },
                ),
            )
        ) {
            is VpnCoreStartResult.Failure -> {
                result.cause?.let { Log.e(logTag, "libbox startup failed", it) }
                if (result.shouldCleanup) {
                    stop(emitDisconnected = false)
                }
                runtimeStateBridge.publish(stateError, result.errorMessage)
            }

            is VpnCoreStartResult.Success -> {
                runtimeSession.bindStartOutcome(result.startOutcome)
                runtimeStateBridge.persistSnapshot()
                VpnTrafficSessionCoordinator.initialize(
                    monitor = trafficMonitor,
                    lastPublishedState = runtimeStateBridge.state,
                    lastPublishedError = runtimeStateBridge.error,
                    persistSnapshot = { _, _ ->
                        runtimeStateBridge.persistSnapshot()
                    },
                )
                liveNotificationTicker.start()
                notificationRuntime.notify(
                    status = VpnNotificationStatus.CONNECTED,
                    detail = runtimeSession.coreNotificationDetail,
                )
                runtimeStateBridge.publish(stateConnected, null)
            }
        }
    }

    fun stop(emitDisconnected: Boolean) {
        liveNotificationTicker.stop()

        VpnCoreStopFlow.execute(
            request = VpnCoreStopRequest(
                boxService = runtimeSession.boxService,
                commandServer = runtimeSession.commandServer,
                tunFileDescriptor = runtimeSession.tunFileDescriptor,
                trafficMonitor = trafficMonitor,
                lastPublishedState = runtimeStateBridge.state,
                lastPublishedError = runtimeStateBridge.error,
                persistSnapshot = { _, _ ->
                    runtimeStateBridge.persistSnapshot()
                },
            ),
        )
        runtimeSession.clearRuntimeHandles()

        if (emitDisconnected) {
            runtimeSession.clearProfileAndConfig()
            runtimeStateBridge.publish(stateDisconnected, null)
        }
    }
}
