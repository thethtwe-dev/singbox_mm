package com.signbox.singbox_mm

internal object PluginChannels {
    const val METHOD = "singbox_mm/methods"
    const val STATE = "singbox_mm/state"
    const val STATS = "singbox_mm/stats"
}

internal object PluginMethods {
    const val INITIALIZE = "initialize"
    const val REQUEST_VPN_PERMISSION = "requestVpnPermission"
    const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
    const val SET_CONFIG = "setConfig"
    const val START_VPN = "startVpn"
    const val STOP_VPN = "stopVpn"
    const val RESTART_VPN = "restartVpn"
    const val GET_STATE = "getState"
    const val GET_STATE_DETAILS = "getStateDetails"
    const val GET_STATS = "getStats"
    const val GET_LAST_ERROR = "getLastError"
    const val GET_SINGBOX_VERSION = "getSingboxVersion"
    const val PING_SERVER = "pingServer"
    const val SYNC_RUNTIME_STATE = "syncRuntimeState"
}

internal object PluginStates {
    const val DISCONNECTED = "disconnected"
    const val PREPARING = "preparing"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
    const val DISCONNECTING = "disconnecting"
    const val ERROR = "error"
}

internal object PluginDefaults {
    const val CONFIG_FILE_NAME = "active-config.json"
    const val STATS_EMIT_INTERVAL_MS = 1000L
    const val NETWORK_VALIDATION_GRACE_MS = 12_000L
}
