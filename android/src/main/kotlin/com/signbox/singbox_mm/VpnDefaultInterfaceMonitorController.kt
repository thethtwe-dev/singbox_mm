package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import io.nekohasekai.libbox.InterfaceUpdateListener

internal class VpnDefaultInterfaceMonitorController(
    private val connectivity: ConnectivityManager,
    private val mainHandler: Handler,
    private val logTag: String,
    private val canSetUnderlyingNetworks: Boolean,
    private val applyUnderlyingNetworks: (Array<Network>?) -> Unit,
) {
    @Volatile
    private var defaultInterfaceListener: InterfaceUpdateListener? = null

    @Volatile
    private var defaultNetworkCallbackRegistered = false

    @Volatile
    private var upstreamNetwork: Network? = null

    private val defaultNetworkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            upstreamNetwork = network
            notifyDefaultInterface()
        }

        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            if (
                networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ||
                    !VpnUpstreamNetworkResolver.isUsableNetwork(networkCapabilities)
            ) {
                if (upstreamNetwork == network) {
                    upstreamNetwork = resolveUpstreamNetwork(excluded = network)
                }
            } else {
                upstreamNetwork = network
            }
            notifyDefaultInterface()
        }

        override fun onBlockedStatusChanged(network: Network, blocked: Boolean) {
            if (blocked) {
                if (upstreamNetwork == network) {
                    upstreamNetwork = resolveUpstreamNetwork(excluded = network)
                }
            } else if (upstreamNetwork == null) {
                upstreamNetwork = network
            }
            notifyDefaultInterface()
        }

        override fun onUnavailable() {
            upstreamNetwork = resolveUpstreamNetwork()
            notifyDefaultInterface()
        }

        override fun onLost(network: Network) {
            if (upstreamNetwork == network) {
                upstreamNetwork = resolveUpstreamNetwork(excluded = network)
            }
            notifyDefaultInterface()
        }
    }

    fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        defaultInterfaceListener = listener
        registerDefaultNetworkCallbackIfNeeded()
        notifyDefaultInterface()
    }

    fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        if (defaultInterfaceListener == listener) {
            defaultInterfaceListener = null
        }
        unregisterDefaultNetworkCallbackIfNeeded()
    }

    fun shutdown() {
        unregisterDefaultNetworkCallbackIfNeeded()
    }

    private fun notifyDefaultInterface() {
        VpnDefaultInterfaceNotifier.notify(
            listener = defaultInterfaceListener,
            connectivity = connectivity,
            resolveUpstreamNetwork = { resolveUpstreamNetwork() },
            canSetUnderlyingNetworks = canSetUnderlyingNetworks,
            applyUnderlyingNetworks = applyUnderlyingNetworks,
        )
    }

    private fun resolveUpstreamNetwork(excluded: Network? = null): Network? {
        return VpnUpstreamNetworkResolver.resolve(
            connectivity = connectivity,
            preferredNetwork = upstreamNetwork,
            excluded = excluded,
        )
    }

    private fun registerDefaultNetworkCallbackIfNeeded() {
        if (defaultNetworkCallbackRegistered) {
            return
        }
        defaultNetworkCallbackRegistered = VpnDefaultNetworkCallbackRegistrar.register(
            connectivity = connectivity,
            callback = defaultNetworkCallback,
            mainHandler = mainHandler,
            logTag = logTag,
        )
    }

    private fun unregisterDefaultNetworkCallbackIfNeeded() {
        if (!defaultNetworkCallbackRegistered) {
            return
        }
        VpnDefaultNetworkCallbackRegistrar.unregister(
            connectivity = connectivity,
            callback = defaultNetworkCallback,
            logTag = logTag,
        )
        defaultNetworkCallbackRegistered = false
        upstreamNetwork = null
    }
}
