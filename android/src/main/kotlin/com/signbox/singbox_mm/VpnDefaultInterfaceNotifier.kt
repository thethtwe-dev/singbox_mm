package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.Network
import io.nekohasekai.libbox.InterfaceUpdateListener

internal object VpnDefaultInterfaceNotifier {
    fun notify(
        listener: InterfaceUpdateListener?,
        connectivity: ConnectivityManager,
        resolveUpstreamNetwork: () -> Network?,
        canSetUnderlyingNetworks: Boolean,
        applyUnderlyingNetworks: (Array<Network>?) -> Unit,
    ) {
        val targetListener = listener ?: return
        val network = resolveUpstreamNetwork()

        if (network == null) {
            if (canSetUnderlyingNetworks) {
                runCatching { applyUnderlyingNetworks(null) }
            }
            targetListener.updateDefaultInterface("", -1, false, false)
            return
        }

        val interfaceName = VpnDefaultInterfaceResolver.resolveInterfaceName(
            connectivity = connectivity,
            network = network,
        ) ?: run {
            targetListener.updateDefaultInterface("", -1, false, false)
            return
        }

        if (canSetUnderlyingNetworks) {
            runCatching { applyUnderlyingNetworks(arrayOf(network)) }
        }

        val interfaceIndex = VpnDefaultInterfaceResolver.resolveInterfaceIndex(interfaceName)
        if (interfaceIndex <= 0) {
            targetListener.updateDefaultInterface("", -1, false, false)
            return
        }

        targetListener.updateDefaultInterface(interfaceName, interfaceIndex, false, false)
    }
}
