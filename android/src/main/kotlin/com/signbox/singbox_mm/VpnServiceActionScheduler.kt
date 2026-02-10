package com.signbox.singbox_mm

import java.util.concurrent.ExecutorService

internal class VpnServiceActionScheduler(
    private val worker: ExecutorService,
    private val stopCore: (Boolean) -> Unit,
    private val startCore: (String?) -> Unit,
    private val publishError: (String) -> Unit,
    private val stopForeground: (Int) -> Unit,
    private val stopForegroundFlag: Int,
    private val stopSelf: () -> Unit,
) {
    fun scheduleStop() {
        VpnServiceActionExecutor.scheduleStop(
            worker = worker,
            stopCore = stopCore,
            stopForeground = stopForeground,
            stopForegroundFlag = stopForegroundFlag,
            stopSelf = stopSelf,
        )
    }

    fun scheduleRestart(configPath: String?) {
        VpnServiceActionExecutor.scheduleRestart(
            worker = worker,
            configPath = configPath,
            publishError = publishError,
            stopCore = stopCore,
            startCore = startCore,
        )
    }

    fun scheduleStart(configPath: String?) {
        VpnServiceActionExecutor.scheduleStart(
            worker = worker,
            configPath = configPath,
            startCore = startCore,
        )
    }
}
