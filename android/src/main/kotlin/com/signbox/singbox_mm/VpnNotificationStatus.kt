package com.signbox.singbox_mm

internal object VpnNotificationStatus {
    const val STARTING = "Starting"
    const val RESTARTING = "Restarting"
    const val RESTORING = "Restoring"
    const val PREPARING = "Preparing"
    const val CONNECTING = "Connecting"
    const val CONNECTED = "Connected"
    const val DISCONNECTED = "Disconnected"
    const val ERROR = "Error"
    private const val UNKNOWN_ERROR_DETAIL = "Unknown error"

    fun forRuntimeState(
        state: String,
        error: String?,
        connectedDetail: String?,
    ): Pair<String, String?> {
        return when (state) {
            PluginStates.PREPARING -> PREPARING to null
            PluginStates.CONNECTING -> CONNECTING to null
            PluginStates.CONNECTED -> CONNECTED to connectedDetail
            PluginStates.DISCONNECTED -> DISCONNECTED to null
            PluginStates.ERROR -> ERROR to
                (error?.takeIf { it.isNotBlank() } ?: UNKNOWN_ERROR_DETAIL)
            else -> state to error
        }
    }
}
