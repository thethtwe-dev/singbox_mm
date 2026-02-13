package com.signbox.singbox_mm

import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer

internal class VpnCoreRuntimeSession {
    @Volatile
    var commandServer: CommandServer? = null

    @Volatile
    var boxService: BoxService? = null

    @Volatile
    var configPath: String? = null

    @Volatile
    var profileLabel: String? = null

    @Volatile
    var tunFileDescriptor: ParcelFileDescriptor? = null

    @Volatile
    var coreNotificationDetail: String? = null

    @Volatile
    private var suppressPostServiceCloseUntilEpochMs: Long = 0L

    fun bindPreparedProfile(profileLabel: String) {
        this.profileLabel = profileLabel
    }

    fun bindStartOutcome(startOutcome: VpnCoreStartOutcome) {
        commandServer = startOutcome.runtime.commandServer
        boxService = startOutcome.runtime.boxService
        configPath = startOutcome.preparedConfig.configPath
        profileLabel = startOutcome.preparedConfig.profileLabel
    }

    fun clearRuntimeHandles() {
        commandServer = null
        boxService = null
        tunFileDescriptor = null
        coreNotificationDetail = null
    }

    fun clearProfileAndConfig() {
        profileLabel = null
        configPath = null
    }

    fun suppressPostServiceCloseFor(durationMs: Long) {
        if (durationMs <= 0L) {
            return
        }
        suppressPostServiceCloseUntilEpochMs =
            System.currentTimeMillis() + durationMs
    }

    fun shouldIgnorePostServiceClose(): Boolean {
        return System.currentTimeMillis() < suppressPostServiceCloseUntilEpochMs
    }
}
