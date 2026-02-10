package com.signbox.singbox_mm

import android.content.Context
import android.net.VpnService

internal class PluginVpnServiceController(
    private val context: Context,
    private val runtimeConfigStore: PluginRuntimeConfigStore,
    private val statsTracker: PluginStatsTracker,
    private val updateConnectionState: (String, String?) -> Unit,
    private val preparingState: String,
    private val disconnectingState: String,
    private val startService: (Context, String) -> Unit,
    private val stopService: (Context) -> Unit,
) {
    fun startVpn(): String? {
        if (VpnService.prepare(context) != null) {
            return "VPN permission is required. Call requestVpnPermission() first."
        }

        val config = runtimeConfigStore.resolveConfigFile()
        if (!config.exists() || config.length() <= 2) {
            return "No sing-box config found. Call setConfig() with a valid config JSON first."
        }

        return try {
            statsTracker.prepareForStart()
            updateConnectionState(preparingState, null)
            startService(context, config.absolutePath)
            null
        } catch (error: Throwable) {
            error.message ?: "Unable to start VPN service"
        }
    }

    fun stopVpn(): String? {
        return try {
            updateConnectionState(disconnectingState, null)
            stopService(context)
            null
        } catch (error: Throwable) {
            error.message ?: "Unable to stop VPN service"
        }
    }
}
