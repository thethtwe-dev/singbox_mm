package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build

internal object VpnUpstreamNetworkResolver {
    fun resolve(
        connectivity: ConnectivityManager,
        preferredNetwork: Network?,
        excluded: Network? = null,
    ): Network? {
        val preferred = preferredNetwork
        if (preferred != null && scoreNetwork(connectivity, preferred, excluded) >= 0) {
            return preferred
        }

        var bestNetwork: Network? = null
        var bestScore = -1
        val allNetworks = runCatching { connectivity.allNetworks }.getOrDefault(emptyArray())
        for (network in allNetworks) {
            val score = scoreNetwork(connectivity, network, excluded)
            if (score > bestScore) {
                bestScore = score
                bestNetwork = network
            }
        }
        if (bestNetwork != null) {
            return bestNetwork
        }

        val active = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivity.activeNetwork
        } else {
            null
        }
        if (active != null && scoreNetwork(connectivity, active, excluded) >= 0) {
            return active
        }

        return null
    }

    fun isVirtualVpnInterface(interfaceName: String): Boolean {
        return interfaceName.startsWith("tun", ignoreCase = true) ||
            interfaceName.startsWith("ppp", ignoreCase = true) ||
            interfaceName.startsWith("ipsec", ignoreCase = true)
    }

    private fun scoreNetwork(
        connectivity: ConnectivityManager,
        network: Network,
        excluded: Network?,
    ): Int {
        val capabilities = connectivity.getNetworkCapabilities(network) ?: return -1
        if (excluded != null && network == excluded) {
            return -1
        }
        if (!isUsableNetwork(capabilities) || capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
            return -1
        }
        var score = 0
        if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
            score += 6
        }
        if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            score += 3
        }
        if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) {
            score += 1
        }
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            score += 2
        }
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
            score += 2
        }
        if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
            score += 2
        }
        if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING)) {
            score += 1
        }
        return score
    }

    fun isUsableNetwork(capabilities: NetworkCapabilities): Boolean {
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return false
        }
        if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)) {
            return false
        }
        return true
    }
}
