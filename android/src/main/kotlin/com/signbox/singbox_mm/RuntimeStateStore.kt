package com.signbox.singbox_mm

import android.content.Context

internal data class RuntimeStateStoreEntry(
    val state: String,
    val error: String?,
    val connectedAtMillis: Long?,
    val uplinkBytesBase: Long,
    val downlinkBytesBase: Long,
    val configPath: String?,
    val updatedAtMillis: Long,
)

internal object RuntimeStateStore {
    private const val PREFS_NAME = "signbox_mm_runtime"
    private const val PREF_LAST_STATE = "state"
    private const val PREF_LAST_ERROR = "error"
    private const val PREF_UPDATED_AT = "updatedAt"
    private const val PREF_CONNECTED_AT = "connectedAt"
    private const val PREF_UPLINK_BASE = "uplinkBase"
    private const val PREF_DOWNLINK_BASE = "downlinkBase"
    private const val PREF_CONFIG_PATH = "configPath"

    fun read(context: Context): RuntimeStateStoreEntry? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val state = prefs.getString(PREF_LAST_STATE, null) ?: return null
        val connectedAt = if (prefs.contains(PREF_CONNECTED_AT)) {
            prefs.getLong(PREF_CONNECTED_AT, 0L).takeIf { it > 0L }
        } else {
            null
        }
        return RuntimeStateStoreEntry(
            state = state,
            error = prefs.getString(PREF_LAST_ERROR, null),
            connectedAtMillis = connectedAt,
            uplinkBytesBase = prefs.getLong(PREF_UPLINK_BASE, 0L).coerceAtLeast(0L),
            downlinkBytesBase = prefs.getLong(PREF_DOWNLINK_BASE, 0L).coerceAtLeast(0L),
            configPath = prefs.getString(PREF_CONFIG_PATH, null),
            updatedAtMillis = prefs.getLong(PREF_UPDATED_AT, 0L),
        )
    }

    fun write(
        context: Context,
        state: String,
        error: String?,
        connectedAtMillis: Long?,
        uplinkBytesBase: Long,
        downlinkBytesBase: Long,
        configPath: String?,
        updatedAtMillis: Long = System.currentTimeMillis(),
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
            .putString(PREF_LAST_STATE, state)
            .putLong(PREF_UPDATED_AT, updatedAtMillis)
            .putLong(PREF_UPLINK_BASE, uplinkBytesBase.coerceAtLeast(0L))
            .putLong(PREF_DOWNLINK_BASE, downlinkBytesBase.coerceAtLeast(0L))

        if (error.isNullOrBlank()) {
            editor.remove(PREF_LAST_ERROR)
        } else {
            editor.putString(PREF_LAST_ERROR, error)
        }

        if (connectedAtMillis == null) {
            editor.remove(PREF_CONNECTED_AT)
        } else {
            editor.putLong(PREF_CONNECTED_AT, connectedAtMillis)
        }

        if (configPath.isNullOrBlank()) {
            editor.remove(PREF_CONFIG_PATH)
        } else {
            editor.putString(PREF_CONFIG_PATH, configPath)
        }
        editor.apply()
    }
}
