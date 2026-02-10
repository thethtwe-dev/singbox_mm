package com.signbox.singbox_mm

import android.content.Context

internal data class VpnRuntimeSnapshotWritePayload(
    val state: String,
    val error: String?,
    val connectedAtMillis: Long?,
    val uplinkBytesBase: Long,
    val downlinkBytesBase: Long,
    val configPath: String?,
)

internal object VpnRuntimeSnapshotStore {
    fun read(context: Context): PersistedRuntimeState? {
        val entry = RuntimeStateStore.read(context) ?: return null
        return PersistedRuntimeState(
            state = entry.state,
            error = entry.error,
            connectedAtMillis = entry.connectedAtMillis,
            uplinkBytesBase = entry.uplinkBytesBase,
            downlinkBytesBase = entry.downlinkBytesBase,
            configPath = entry.configPath,
            updatedAtMillis = entry.updatedAtMillis,
        )
    }

    fun write(
        context: Context,
        payload: VpnRuntimeSnapshotWritePayload,
    ) {
        RuntimeStateStore.write(
            context = context,
            state = payload.state,
            error = payload.error,
            connectedAtMillis = payload.connectedAtMillis,
            uplinkBytesBase = payload.uplinkBytesBase,
            downlinkBytesBase = payload.downlinkBytesBase,
            configPath = payload.configPath,
        )
    }
}
