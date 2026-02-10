package com.signbox.singbox_mm

import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.PlatformInterface

internal data class VpnCoreStartOutcome(
    val preparedConfig: VpnPreparedConfig,
    val runtime: VpnCoreRuntime,
)

internal object VpnCoreSessionOrchestrator {
    fun prepareConfigOrThrow(
        configPath: String?,
        privateDnsHost: String?,
        defaultProfileLabel: String,
        logTag: String,
    ): VpnPreparedConfig {
        val preparedResult = VpnCoreLifecycleCoordinator.prepareConfig(
            configPath = configPath,
            privateDnsHost = privateDnsHost,
            defaultProfileLabel = defaultProfileLabel,
            logTag = logTag,
        )
        if (!preparedResult.error.isNullOrBlank()) {
            throw IllegalStateException(preparedResult.error)
        }
        return preparedResult.config
            ?: throw IllegalStateException("Failed to prepare config")
    }

    fun startPreparedRuntime(
        preparedConfig: VpnPreparedConfig,
        commandPort: Int,
        platformInterface: PlatformInterface,
        commandHandler: CommandServerHandler,
        onConnecting: () -> Unit,
    ): VpnCoreStartOutcome {
        val runtime = VpnCoreLifecycleCoordinator.createRuntime(
            configContent = preparedConfig.configContent,
            platformInterface = platformInterface,
            commandHandler = commandHandler,
            commandPort = commandPort,
        )
        onConnecting()
        VpnCoreLifecycleCoordinator.startRuntimeService(runtime.boxService)
        return VpnCoreStartOutcome(
            preparedConfig = preparedConfig,
            runtime = runtime,
        )
    }

    fun stopRuntimeAndTraffic(
        boxService: BoxService?,
        commandServer: CommandServer?,
        tunFileDescriptor: ParcelFileDescriptor?,
        trafficMonitor: NotificationTrafficMonitor,
        lastPublishedState: String,
        lastPublishedError: String?,
        persistSnapshot: (String, String?) -> Unit,
    ) {
        VpnCoreLifecycleCoordinator.stopRuntime(
            boxService = boxService,
            commandServer = commandServer,
            tunFileDescriptor = tunFileDescriptor,
        )
        VpnTrafficSessionCoordinator.clear(
            monitor = trafficMonitor,
            lastPublishedState = lastPublishedState,
            lastPublishedError = lastPublishedError,
            persistSnapshot = persistSnapshot,
        )
    }
}
