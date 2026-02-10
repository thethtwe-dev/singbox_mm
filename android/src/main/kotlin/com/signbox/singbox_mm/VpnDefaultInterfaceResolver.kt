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

    fun resolveInterfaceIndex(
        interfaceName: String,
        attempts: Int = 10,
        retryDelayMillis: Long = 100L,
    ): Int {
        var interfaceIndex = -1
        for (attempt in 0 until attempts) {
            interfaceIndex = runCatching {
                NetworkInterface.getByName(interfaceName)?.index ?: -1
            }.getOrDefault(-1)
            if (interfaceIndex > 0) {
                return interfaceIndex
            }
            if (attempt < attempts - 1) {
                Thread.sleep(retryDelayMillis)
            }
        }
        return -1
    }
}
