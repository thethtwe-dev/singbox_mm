package com.signbox.singbox_mm

import android.content.Context

internal class VpnServiceRuntimeStateBridge(
    private val context: Context,
    initialState: String,
    private val actionStateUpdate: String,
    private val packageName: String,
    private val stateExtraKey: String,
    private val errorExtraKey: String,
    private val updateNotificationForState: (String, String?) -> Unit,
    private val readConnectedSinceMillis: () -> Long?,
    private val readUplinkBytesBase: () -> Long,
    private val readDownlinkBytesBase: () -> Long,
    private val readConfigPath: () -> String?,
) {
    private val runtimeStateSession = VpnRuntimeStateSession(initialState = initialState)

    val state: String
        get() = runtimeStateSession.state

    val error: String?
        get() = runtimeStateSession.error

    fun publish(state: String, error: String?) {
        runtimeStateSession.publish(
            context = context,
            state = state,
            error = error,
            actionStateUpdate = actionStateUpdate,
            packageName = packageName,
            stateExtraKey = stateExtraKey,
            errorExtraKey = errorExtraKey,
            persistSnapshot = { _, _ ->
                persistSnapshot()
            },
            updateNotificationForState = updateNotificationForState,
        )
    }

    fun restoreSnapshot(
        applySnapshot: (PersistedRuntimeState) -> Unit,
    ) {
        val snapshot = runtimeStateSession.restoreSnapshot(context) ?: return
        applySnapshot(snapshot)
    }

    fun persistSnapshot() {
        runtimeStateSession.persistSnapshot(
            context = context,
            connectedAtMillis = readConnectedSinceMillis(),
            uplinkBytesBase = readUplinkBytesBase(),
            downlinkBytesBase = readDownlinkBytesBase(),
            configPath = readConfigPath(),
        )
    }
}
