package com.signbox.singbox_mm

import java.util.concurrent.ExecutorService
import java.util.concurrent.atomic.AtomicBoolean

internal class VpnServiceActionScheduler(
    private val worker: ExecutorService,
    private val stopCoreUserInitiated: () -> Unit,
    private val stopCore: (Boolean) -> Unit,
    private val startCore: (String?) -> Unit,
    private val publishError: (String) -> Unit,
    private val stopForeground: (Int) -> Unit,
    private val stopForegroundFlag: Int,
    private val stopSelf: () -> Unit,
) {
    private val stopRequested = AtomicBoolean(false)

    fun scheduleStop() {
        stopRequested.set(true)
        VpnServiceActionExecutor.scheduleStop(
            worker = worker,
            isStopRequested = { stopRequested.get() },
            stopCoreUserInitiated = stopCoreUserInitiated,
            stopForeground = stopForeground,
            stopForegroundFlag = stopForegroundFlag,
            stopSelf = stopSelf,
        )
    }

    fun scheduleRestart(configPath: String?) {
        stopRequested.set(false)
        VpnServiceActionExecutor.scheduleRestart(
            worker = worker,
            configPath = configPath,
            isStopRequested = { stopRequested.get() },
            publishError = publishError,
            stopCore = stopCore,
            startCore = startCore,
        )
    }

    fun scheduleStart(configPath: String?) {
        stopRequested.set(false)
        VpnServiceActionExecutor.scheduleStart(
            worker = worker,
            configPath = configPath,
            isStopRequested = { stopRequested.get() },
            startCore = startCore,
        )
    }
}
