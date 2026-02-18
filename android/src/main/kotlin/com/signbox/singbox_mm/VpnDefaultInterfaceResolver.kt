package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.Network
import java.net.NetworkInterface

internal object VpnDefaultInterfaceResolver {
    fun resolveInterfaceName(
        connectivity: ConnectivityManager,
        network: Network,
    ): String? {
        val interfaceName = connectivity.getLinkProperties(network)?.interfaceName
        if (interfaceName.isNullOrBlank()) {
            return null
        }
        if (VpnUpstreamNetworkResolver.isVirtualVpnInterface(interfaceName)) {
            return null
        }
        return interfaceName
    }

    fun resolveInterfaceIndex(interfaceName: String): Int {
        // Never block the callback thread; callback churn will re-notify soon.
        return runCatching {
            NetworkInterface.getByName(interfaceName)?.index ?: -1
        }.getOrDefault(-1)
    }
}
