package com.signbox.singbox_mm

import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.OverrideOptions
import java.io.File

internal object VpnServiceReloader {
    fun reload(
        commandServer: CommandServer,
        configPath: String,
    ) {
        val content = File(configPath).readText()
        commandServer.startOrReloadService(content, OverrideOptions())
    }
}
