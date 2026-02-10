package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.system.OsConstants
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.StringIterator
import java.net.Inet6Address
import java.net.InterfaceAddress
import java.net.NetworkInterface

internal object VpnInterfaceSnapshotProvider {
    fun collect(connectivity: ConnectivityManager): NetworkInterfaceIterator {
        val interfaces = mutableListOf<LibboxNetworkInterface>()
        val networkByName = mutableMapOf<String, NetworkInterface>()
        val systemInterfaces = runCatching { NetworkInterface.getNetworkInterfaces() }.getOrNull()
        if (systemInterfaces != null) {
            while (systemInterfaces.hasMoreElements()) {
                val item = systemInterfaces.nextElement()
                networkByName[item.name] = item
            }
        }

        val networks = runCatching { connectivity.allNetworks }.getOrDefault(emptyArray())
        for (network in networks) {
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                continue
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                continue
            }

            val linkProperties = connectivity.getLinkProperties(network) ?: continue
            val interfaceName = linkProperties.interfaceName
            if (interfaceName.isNullOrBlank()) {
                continue
            }
            val systemInterface = networkByName[interfaceName] ?: continue

            val boxInterface = LibboxNetworkInterface().apply {
                name = interfaceName
                index = systemInterface.index
                type = when {
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
                        Libbox.InterfaceTypeWIFI
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                        Libbox.InterfaceTypeCellular
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                        Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                flags = interfaceFlags(systemInterface, capabilities)

                runCatching {
                    mtu = systemInterface.mtu
                }
                addresses = ValueStringIterator(
                    systemInterface.interfaceAddresses.mapTo(mutableListOf()) { it.toPrefix() },
                )

                val dnsAddresses = linkProperties.dnsServers.mapNotNull { it.hostAddress }
                dnsServer = ValueStringIterator(dnsAddresses)
            }
            interfaces.add(boxInterface)
        }

        return InterfaceIterator(interfaces)
    }

    private class InterfaceIterator(private val interfaces: List<LibboxNetworkInterface>) :
        NetworkInterfaceIterator {
        private var index = 0

        override fun hasNext(): Boolean {
            return index < interfaces.size
        }

        override fun next(): LibboxNetworkInterface {
            val current = interfaces[index]
            index++
            return current
        }
    }

    private class ValueStringIterator(private val values: List<String>) : StringIterator {
        private var index = 0

        override fun hasNext(): Boolean {
            return index < values.size
        }

        override fun len(): Int {
            return values.size
        }

        override fun next(): String {
            val current = values[index]
            index++
            return current
        }
    }

    private fun InterfaceAddress.toPrefix(): String {
        return if (address is Inet6Address) {
            "${Inet6Address.getByAddress(address.address).hostAddress}/${networkPrefixLength}"
        } else {
            "${address.hostAddress}/${networkPrefixLength}"
        }
    }

    private fun interfaceFlags(
        networkInterface: NetworkInterface,
        capabilities: NetworkCapabilities,
    ): Int {
        var flags = 0
        if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            flags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
        }
        runCatching {
            if (networkInterface.isLoopback) {
                flags = flags or OsConstants.IFF_LOOPBACK
            }
            if (networkInterface.isPointToPoint) {
                flags = flags or OsConstants.IFF_POINTOPOINT
            }
            if (networkInterface.supportsMulticast()) {
                flags = flags or OsConstants.IFF_MULTICAST
            }
        }
        return flags
    }
}
