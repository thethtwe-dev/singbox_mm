package com.signbox.singbox_mm

data class PersistedRuntimeState(
    val state: String,
    val error: String?,
    val connectedAtMillis: Long?,
    val uplinkBytesBase: Long,
    val downlinkBytesBase: Long,
    val configPath: String?,
    val updatedAtMillis: Long,
)
