package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.os.Build

internal object VpnPrivateDnsHostResolver {
    fun resolve(connectivity: ConnectivityManager): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return null
        }

        val allNetworks = runCatching { connectivity.allNetworks }.getOrDefault(emptyArray())
        for (network in allNetworks) {
            val host = connectivity
                .getLinkProperties(network)
                ?.privateDnsServerName
                ?.trim()
                .orEmpty()
            if (host.isNotEmpty()) {
                return host
            }
        }

        val active = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivity.activeNetwork
        } else {
            null
        }
        val activeHost = active?.let { network ->
            connectivity
                .getLinkProperties(network)
                ?.privateDnsServerName
                ?.trim()
                .orEmpty()
        }.orEmpty()
        return activeHost.takeIf { it.isNotEmpty() }
    }
}
