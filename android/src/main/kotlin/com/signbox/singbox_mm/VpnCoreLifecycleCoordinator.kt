package com.signbox.singbox_mm

import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.PlatformInterface

internal data class VpnPreparedConfig(
    val configPath: String,
    val configContent: String,
    val profileLabel: String,
)

internal data class VpnPreparedConfigResult(
    val config: VpnPreparedConfig? = null,
    val error: String? = null,
)

internal data class VpnCoreRuntime(
    val commandServer: CommandServer,
    val boxService: BoxService,
)

internal object VpnCoreLifecycleCoordinator {
    fun prepareConfig(
        configPath: String?,
        privateDnsHost: String?,
        defaultProfileLabel: String,
        logTag: String,
    ): VpnPreparedConfigResult {
        val loadedConfig = VpnConfigContentLoader.load(
            configPath = configPath,
            privateDnsHost = privateDnsHost,
            logTag = logTag,
        )
        if (!loadedConfig.error.isNullOrBlank()) {
            return VpnPreparedConfigResult(error = loadedConfig.error)
        }

        val resolvedPath = loadedConfig.configPath
        if (resolvedPath.isNullOrBlank()) {
            return VpnPreparedConfigResult(error = "Missing config path")
        }
        val configContent = loadedConfig.configContent
        if (configContent.isNullOrBlank()) {
            return VpnPreparedConfigResult(error = "Unable to read config file")
        }

        val profileLabel = VpnProfileLabelResolver.resolve(
            configContent = configContent,
            defaultLabel = defaultProfileLabel,
        )
        return VpnPreparedConfigResult(
            config = VpnPreparedConfig(
                configPath = resolvedPath,
                configContent = configContent,
                profileLabel = profileLabel,
            ),
        )
    }

    fun createRuntime(
        configContent: String,
        platformInterface: PlatformInterface,
        commandHandler: CommandServerHandler,
        commandPort: Int,
    ): VpnCoreRuntime {
        val service = Libbox.newService(configContent, platformInterface)
        val server = CommandServer(commandHandler, commandPort)
        server.setService(service)
        server.start()
        return VpnCoreRuntime(commandServer = server, boxService = service)
    }

    fun startRuntimeService(boxService: BoxService) {
        boxService.start()
        if (boxService.needWIFIState()) {
            runCatching {
                boxService.updateWIFIState()
            }
        }
    }

    fun stopRuntime(
        boxService: BoxService?,
        commandServer: CommandServer?,
        tunFileDescriptor: ParcelFileDescriptor?,
    ) {
        runCatching {
            boxService?.close()
        }
        runCatching {
            commandServer?.close()
        }
        runCatching {
            tunFileDescriptor?.close()
        }
    }
}
