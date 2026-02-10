package com.signbox.singbox_mm

internal object VpnStartCommandRouter {
    fun route(
        intentAction: String?,
        intentConfigPath: String?,
        currentConfigPath: String?,
        persistedConfigPath: String?,
        hasRunningCore: Boolean,
        connectedDetail: String?,
        actionStop: String,
        actionRestart: String,
        actionStart: String,
        statusStarting: String,
        statusRestarting: String,
        statusRestoring: String,
        statusConnected: String,
        startNotSticky: Int,
        startRedeliverIntent: Int,
        showForeground: (status: String, detail: String?) -> Unit,
        scheduleStop: () -> Unit,
        scheduleRestart: (String?) -> Unit,
        scheduleStart: (String?) -> Unit,
        stopSelf: () -> Unit,
    ): Int {
        when (intentAction) {
            actionStop -> {
                scheduleStop()
                return startNotSticky
            }

            actionRestart -> {
                showForeground(statusRestarting, null)
                val configPath = intentConfigPath ?: currentConfigPath
                scheduleRestart(configPath)
                return startRedeliverIntent
            }

            actionStart -> {
                showForeground(statusStarting, null)
                scheduleStart(intentConfigPath)
                return startRedeliverIntent
            }

            else -> {
                if (hasRunningCore) {
                    showForeground(statusConnected, connectedDetail)
                    return startRedeliverIntent
                }

                val recoveredConfigPath = currentConfigPath ?: persistedConfigPath
                if (!recoveredConfigPath.isNullOrBlank()) {
                    showForeground(statusRestoring, null)
                    scheduleStart(recoveredConfigPath)
                    return startRedeliverIntent
                }

                stopSelf()
                return startNotSticky
            }
        }
    }
}
