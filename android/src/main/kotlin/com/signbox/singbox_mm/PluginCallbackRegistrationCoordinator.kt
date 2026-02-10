package com.signbox.singbox_mm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler

internal class PluginCallbackRegistrationCoordinator(
    private val context: Context,
    private val connectivity: ConnectivityManager,
    private val mainHandler: Handler,
    private val stateReceiver: BroadcastReceiver,
    private val stateAction: String,
    private val vpnNetworkCallback: ConnectivityManager.NetworkCallback,
    private val upstreamNetworkCallback: ConnectivityManager.NetworkCallback,
) {
    @Volatile
    private var receiverRegistered = false

    @Volatile
    private var vpnNetworkCallbackRegistered = false

    @Volatile
    private var upstreamNetworkCallbackRegistered = false

    fun registerAll() {
        registerStateReceiver()
        registerVpnNetworkCallback()
        registerUpstreamNetworkCallback()
    }

    fun unregisterAll() {
        unregisterStateReceiver()
        unregisterVpnNetworkCallback()
        unregisterUpstreamNetworkCallback()
    }

    private fun registerStateReceiver() {
        if (receiverRegistered) {
            return
        }

        val filter = IntentFilter(stateAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(stateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(stateReceiver, filter)
        }

        receiverRegistered = true
    }

    private fun unregisterStateReceiver() {
        if (!receiverRegistered) {
            return
        }

        runCatching {
            context.unregisterReceiver(stateReceiver)
        }

        receiverRegistered = false
    }

    private fun registerVpnNetworkCallback() {
        if (vpnNetworkCallbackRegistered) {
            return
        }
        runCatching {
            val request = android.net.NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                connectivity.registerNetworkCallback(request, vpnNetworkCallback, mainHandler)
            } else {
                @Suppress("DEPRECATION")
                connectivity.registerNetworkCallback(request, vpnNetworkCallback)
            }
            vpnNetworkCallbackRegistered = true
        }
    }

    private fun unregisterVpnNetworkCallback() {
        if (!vpnNetworkCallbackRegistered) {
            return
        }
        runCatching {
            connectivity.unregisterNetworkCallback(vpnNetworkCallback)
        }
        vpnNetworkCallbackRegistered = false
    }

    private fun registerUpstreamNetworkCallback() {
        if (upstreamNetworkCallbackRegistered) {
            return
        }
        runCatching {
            val request = android.net.NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                connectivity.registerNetworkCallback(request, upstreamNetworkCallback, mainHandler)
            } else {
                @Suppress("DEPRECATION")
                connectivity.registerNetworkCallback(request, upstreamNetworkCallback)
            }
            upstreamNetworkCallbackRegistered = true
        }
    }

    private fun unregisterUpstreamNetworkCallback() {
        if (!upstreamNetworkCallbackRegistered) {
            return
        }
        runCatching {
            connectivity.unregisterNetworkCallback(upstreamNetworkCallback)
        }
        upstreamNetworkCallbackRegistered = false
    }
}
