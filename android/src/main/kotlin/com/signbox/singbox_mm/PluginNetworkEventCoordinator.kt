package com.signbox.singbox_mm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities

internal class PluginNetworkEventCoordinator(
    private val stateAction: String,
    private val stateExtraStateKey: String,
    private val stateExtraErrorKey: String,
    private val connectedState: String,
    private val connectingState: String,
    private val disconnectedState: String,
    private val errorState: String,
    private val onConnectedState: () -> Unit,
    private val onDisconnectedOrErrorState: () -> Unit,
    private val updateConnectionState: (String, String?) -> Unit,
    private val refreshNetworkDiagnostics: () -> Boolean,
    private val clearNetworkDiagnostics: () -> Unit,
    private val refreshDerivedStateDetail: () -> Unit,
    private val emitState: () -> Unit,
    private val currentStateProvider: () -> String,
) {
    val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != stateAction) {
                return
            }

            val state = intent.getStringExtra(stateExtraStateKey)
            val error = intent.getStringExtra(stateExtraErrorKey)
            if (state.isNullOrBlank()) {
                return
            }

            if (state == connectedState) {
                onConnectedState()
            }

            if (state == disconnectedState || state == errorState) {
                onDisconnectedOrErrorState()
            }

            updateConnectionState(state, error)
        }
    }

    val vpnNetworkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            refreshNetworkAndEmit()
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) {
            refreshNetworkAndEmit()
        }

        override fun onLost(network: Network) {
            if (!refreshNetworkDiagnostics()) {
                clearNetworkDiagnostics()
            }
            refreshDerivedStateDetail()
            emitState()
        }

        override fun onUnavailable() {
            if (!refreshNetworkDiagnostics()) {
                clearNetworkDiagnostics()
            }
            refreshDerivedStateDetail()
            emitState()
        }
    }

    val upstreamNetworkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            refreshForActiveTunnel()
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) {
            refreshForActiveTunnel()
        }

        override fun onLost(network: Network) {
            refreshForActiveTunnel()
        }

        override fun onBlockedStatusChanged(network: Network, blocked: Boolean) {
            refreshForActiveTunnel()
        }
    }

    private fun refreshForActiveTunnel() {
        val state = currentStateProvider()
        if (state == connectedState || state == connectingState) {
            refreshNetworkAndEmit()
        }
    }

    private fun refreshNetworkAndEmit() {
        refreshNetworkDiagnostics()
        refreshDerivedStateDetail()
        emitState()
    }
}
