package com.signbox.singbox_mm

import android.content.pm.PackageManager
import android.net.ConnectivityManager
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.WIFIState

internal class VpnPlatformServiceBridge(
    private val connectivity: ConnectivityManager,
    private val packageManager: PackageManager,
    private val defaultInterfaceMonitorController: VpnDefaultInterfaceMonitorController,
) {
    fun useProcFS(): Boolean {
        return VpnPlatformInterfaceDelegate.useProcFS()
    }

    fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): Int {
        return VpnPlatformInterfaceDelegate.findConnectionOwner(
            connectivity = connectivity,
            ipProtocol = ipProtocol,
            sourceAddress = sourceAddress,
            sourcePort = sourcePort,
            destinationAddress = destinationAddress,
            destinationPort = destinationPort,
        )
    }

    fun packageNameByUid(uid: Int): String {
        return VpnPlatformInterfaceDelegate.packageNameByUid(packageManager, uid)
    }

    fun uidByPackageName(packageName: String): Int {
        return VpnPlatformInterfaceDelegate.uidByPackageName(packageManager, packageName)
    }

    fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        defaultInterfaceMonitorController.startDefaultInterfaceMonitor(listener)
    }

    fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        defaultInterfaceMonitorController.closeDefaultInterfaceMonitor(listener)
    }

    fun getInterfaces(): NetworkInterfaceIterator {
        return VpnInterfaceSnapshotProvider.collect(connectivity)
    }

    fun underNetworkExtension(): Boolean {
        return VpnPlatformInterfaceDelegate.underNetworkExtension()
    }

    fun includeAllNetworks(): Boolean {
        return VpnPlatformInterfaceDelegate.includeAllNetworks()
    }

    fun clearDNSCache() {
        // Not used.
    }

    fun readWIFIState(): WIFIState? {
        return VpnPlatformInterfaceDelegate.readWIFIState()
    }

    fun localDNSTransport(): LocalDNSTransport? {
        return VpnPlatformInterfaceDelegate.localDNSTransport()
    }

    fun systemCertificates(): StringIterator {
        return VpnSystemCertificateProvider.readAsIterator()
    }

    fun getSystemProxyStatus(): SystemProxyStatus {
        return VpnPlatformInterfaceDelegate.defaultSystemProxyStatus()
    }

    fun setSystemProxyEnabled(isEnabled: Boolean) {
        // Not supported in this integration yet.
    }
}
