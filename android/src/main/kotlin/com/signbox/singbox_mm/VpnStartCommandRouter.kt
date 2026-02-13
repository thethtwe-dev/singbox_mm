package com.signbox.singbox_mm

internal object VpnStartCommandRouter {
    fun route(
        intentAction: String?,
        intentConfigPath: String?,
        currentConfigPath: String?,
        persistedRuntimeState: PersistedRuntimeState?,
        hasRunningCore: Boolean,
        connectedDetail: String?,
        actionStop: String,
        actionRestart: String,
        actionStart: String,
        statePreparing: String,
        stateConnecting: String,
        stateConnected: String,
        stateDisconnected: String,
        stoppedByUserError: String,
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

                val recoveredConfigPath = currentConfigPath ?: persistedRuntimeState?.configPath
                if (
                    !recoveredConfigPath.isNullOrBlank() &&
                    shouldRestorePersistedSession(
                        snapshot = persistedRuntimeState,
                        statePreparing = statePreparing,
                        stateConnecting = stateConnecting,
                        stateConnected = stateConnected,
                        stateDisconnected = stateDisconnected,
                        stoppedByUserError = stoppedByUserError,
                    )
                ) {
                    showForeground(statusRestoring, null)
                    scheduleStart(recoveredConfigPath)
                    return startRedeliverIntent
                }

                stopSelf()
                return startNotSticky
            }
        }
    }

    private fun shouldRestorePersistedSession(
        snapshot: PersistedRuntimeState?,
        statePreparing: String,
        stateConnecting: String,
        stateConnected: String,
        stateDisconnected: String,
        stoppedByUserError: String,
    ): Boolean {
        if (snapshot == null) {
            return true
        }

        if (snapshot.error == stoppedByUserError) {
            return false
        }

        if (snapshot.state == stateDisconnected) {
            return false
        }

        return snapshot.state == statePreparing ||
            snapshot.state == stateConnecting ||
            snapshot.state == stateConnected
    }
}
