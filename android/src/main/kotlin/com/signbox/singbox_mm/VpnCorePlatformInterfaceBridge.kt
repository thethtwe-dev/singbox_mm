package com.signbox.singbox_mm

import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification as CoreNotification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState

internal class VpnCorePlatformInterfaceBridge(
    private val tunControlBridge: VpnTunControlBridge,
    private val platformServiceBridge: VpnPlatformServiceBridge,
    private val sendCoreNotification: (CoreNotification) -> Unit,
    private val writeCoreLog: (String) -> Unit,
) : PlatformInterface {
    override fun usePlatformAutoDetectInterfaceControl(): Boolean {
        return tunControlBridge.usePlatformAutoDetectInterfaceControl()
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        tunControlBridge.autoDetectInterfaceControl(fd)
    }

    override fun openTun(options: TunOptions): Int {
        return tunControlBridge.openTun(options)
    }

    override fun useProcFS(): Boolean {
        return platformServiceBridge.useProcFS()
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): Int {
        return platformServiceBridge.findConnectionOwner(
            ipProtocol = ipProtocol,
            sourceAddress = sourceAddress,
            sourcePort = sourcePort,
            destinationAddress = destinationAddress,
            destinationPort = destinationPort,
        )
    }

    override fun packageNameByUid(uid: Int): String {
        return platformServiceBridge.packageNameByUid(uid)
    }

    override fun uidByPackageName(packageName: String): Int {
        return platformServiceBridge.uidByPackageName(packageName)
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        platformServiceBridge.startDefaultInterfaceMonitor(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        platformServiceBridge.closeDefaultInterfaceMonitor(listener)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        return platformServiceBridge.getInterfaces()
    }

    override fun underNetworkExtension(): Boolean {
        return platformServiceBridge.underNetworkExtension()
    }

    override fun includeAllNetworks(): Boolean {
        return platformServiceBridge.includeAllNetworks()
    }

    override fun clearDNSCache() {
        platformServiceBridge.clearDNSCache()
    }

    override fun readWIFIState(): WIFIState? {
        return platformServiceBridge.readWIFIState()
    }

    override fun localDNSTransport(): LocalDNSTransport? {
        return platformServiceBridge.localDNSTransport()
    }

    override fun systemCertificates(): StringIterator {
        return platformServiceBridge.systemCertificates()
    }

    override fun sendNotification(notification: CoreNotification) {
        sendCoreNotification(notification)
    }

    override fun writeLog(message: String) {
        writeCoreLog(message)
    }
}
