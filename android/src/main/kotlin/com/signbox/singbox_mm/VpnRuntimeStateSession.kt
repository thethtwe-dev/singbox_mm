package com.signbox.singbox_mm

import android.content.Context

internal class VpnRuntimeStateSession(
    initialState: String,
    initialError: String? = null,
) {
    @Volatile
    private var lastPublishedState: String = initialState

    @Volatile
    private var lastPublishedError: String? = initialError

    val state: String
        get() = lastPublishedState

    val error: String?
        get() = lastPublishedError

    fun publish(
        context: Context,
        state: String,
        error: String?,
        actionStateUpdate: String,
        packageName: String,
        stateExtraKey: String,
        errorExtraKey: String,
        persistSnapshot: (String, String?) -> Unit,
        updateNotificationForState: (String, String?) -> Unit,
    ) {
        lastPublishedState = state
        lastPublishedError = error
        VpnRuntimeStateCoordinator.publish(
            context = context,
            state = state,
            error = error,
            actionStateUpdate = actionStateUpdate,
            packageName = packageName,
            stateExtraKey = stateExtraKey,
            errorExtraKey = errorExtraKey,
            persistSnapshot = persistSnapshot,
            updateNotificationForState = updateNotificationForState,
        )
    }

    fun restoreSnapshot(context: Context): PersistedRuntimeState? {
        val snapshot = VpnRuntimeStateCoordinator.restoreSnapshot(context) ?: return null
        lastPublishedState = snapshot.state
        lastPublishedError = snapshot.error
        return snapshot
    }

    fun persistSnapshot(
        context: Context,
        connectedAtMillis: Long?,
        uplinkBytesBase: Long,
        downlinkBytesBase: Long,
        configPath: String?,
    ) {
        VpnRuntimeStateCoordinator.persistSnapshot(
            context = context,
            payload = VpnRuntimeSnapshotWritePayload(
                state = lastPublishedState,
                error = lastPublishedError,
                connectedAtMillis = connectedAtMillis,
                uplinkBytesBase = uplinkBytesBase,
                downlinkBytesBase = downlinkBytesBase,
                configPath = configPath,
            ),
        )
    }
}
