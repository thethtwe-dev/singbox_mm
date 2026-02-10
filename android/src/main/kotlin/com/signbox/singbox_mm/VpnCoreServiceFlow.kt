package com.signbox.singbox_mm

import android.content.Context
import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.PlatformInterface

internal data class VpnCoreStartRequest(
    val context: Context,
    val configPath: String?,
    val privateDnsHost: String?,
    val defaultProfileLabel: String,
    val logTag: String,
    val commandPort: Int,
    val platformInterface: PlatformInterface,
    val commandHandler: CommandServerHandler,
    val beforeRuntimeStart: () -> Unit,
    val onPreparing: (String) -> Unit,
    val onConnecting: () -> Unit,
)

internal sealed interface VpnCoreStartResult {
    data class Success(val startOutcome: VpnCoreStartOutcome) : VpnCoreStartResult

    data class Failure(
        val errorMessage: String,
        val cause: Throwable? = null,
        val shouldCleanup: Boolean = false,
    ) : VpnCoreStartResult
}

internal object VpnCoreStartFlow {
    fun execute(request: VpnCoreStartRequest): VpnCoreStartResult {
        val preparedConfig = runCatching {
            VpnCoreSessionOrchestrator.prepareConfigOrThrow(
                configPath = request.configPath,
                privateDnsHost = request.privateDnsHost,
                defaultProfileLabel = request.defaultProfileLabel,
                logTag = request.logTag,
            )
        }.getOrElse {
            return VpnCoreStartResult.Failure(
                errorMessage = it.message ?: "Failed to prepare config",
            )
        }

        return runCatching {
            request.beforeRuntimeStart()
            VpnCoreSetupManager.ensure(request.context)
            request.onPreparing(preparedConfig.profileLabel)

            val startOutcome = VpnCoreSessionOrchestrator.startPreparedRuntime(
                preparedConfig = preparedConfig,
                commandPort = request.commandPort,
                platformInterface = request.platformInterface,
                commandHandler = request.commandHandler,
                onConnecting = request.onConnecting,
            )
            VpnCoreStartResult.Success(startOutcome)
        }.getOrElse {
            VpnCoreStartResult.Failure(
                errorMessage = it.message ?: "Failed to start libbox command server",
                cause = it,
                shouldCleanup = true,
            )
        }
    }
}

internal data class VpnCoreStopRequest(
    val boxService: BoxService?,
    val commandServer: CommandServer?,
    val tunFileDescriptor: ParcelFileDescriptor?,
    val trafficMonitor: NotificationTrafficMonitor,
    val lastPublishedState: String,
    val lastPublishedError: String?,
    val persistSnapshot: (String, String?) -> Unit,
)

internal object VpnCoreStopFlow {
    fun execute(request: VpnCoreStopRequest) {
        VpnCoreSessionOrchestrator.stopRuntimeAndTraffic(
            boxService = request.boxService,
            commandServer = request.commandServer,
            tunFileDescriptor = request.tunFileDescriptor,
            trafficMonitor = request.trafficMonitor,
            lastPublishedState = request.lastPublishedState,
            lastPublishedError = request.lastPublishedError,
            persistSnapshot = request.persistSnapshot,
        )
    }
}
