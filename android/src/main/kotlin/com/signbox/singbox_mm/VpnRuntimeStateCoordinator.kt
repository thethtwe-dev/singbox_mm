package com.signbox.singbox_mm

import android.content.Context

internal object VpnRuntimeStateCoordinator {
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
        persistSnapshot(state, error)
        updateNotificationForState(state, error)
        VpnStateUpdateBroadcaster.send(
            context = context,
            action = actionStateUpdate,
            packageName = packageName,
            stateExtraKey = stateExtraKey,
            errorExtraKey = errorExtraKey,
            state = state,
            error = error,
        )
    }

    fun restoreSnapshot(
        context: Context,
    ): PersistedRuntimeState? {
        return VpnRuntimeSnapshotStore.read(context)
    }

    fun persistSnapshot(
        context: Context,
        payload: VpnRuntimeSnapshotWritePayload,
    ) {
        VpnRuntimeSnapshotStore.write(
            context = context,
            payload = payload,
        )
    }
}
