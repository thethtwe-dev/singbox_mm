package com.signbox.singbox_mm

import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.PlatformInterface
import java.io.File

internal object VpnServiceReloader {
    fun reload(
        commandServer: CommandServer,
        oldService: BoxService,
        host: PlatformInterface,
        configPath: String,
    ): BoxService {
        val content = File(configPath).readText()
        val nextService = Libbox.newService(content, host)
        nextService.start()
        if (nextService.needWIFIState()) {
            runCatching {
                nextService.updateWIFIState()
            }
        }
        commandServer.setService(nextService)
        runCatching {
            oldService.close()
        }
        return nextService
    }
}
