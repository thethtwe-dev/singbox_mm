package com.signbox.singbox_mm

import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.WIFIState
import java.net.InetSocketAddress

internal object VpnPlatformInterfaceDelegate {
    fun useProcFS(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }

    fun findConnectionOwner(
        connectivity: ConnectivityManager,
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Connection owner lookup requires Android 10+")
        }

        val uid = connectivity.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort),
        )

        if (uid == Process.INVALID_UID) {
            throw IllegalStateException("Connection owner is not available")
        }
        return uid
    }

    fun packageNameByUid(
        packageManager: PackageManager,
        uid: Int,
    ): String {
        return packageManager.getPackagesForUid(uid)?.firstOrNull() ?: ""
    }

    fun uidByPackageName(
        packageManager: PackageManager,
        packageName: String,
    ): Int {
        val appInfo = packageManager.getApplicationInfo(packageName, 0)
        return appInfo.uid
    }

    fun underNetworkExtension(): Boolean {
        return false
    }

    fun includeAllNetworks(): Boolean {
        return false
    }

    fun readWIFIState(): WIFIState? {
        return null
    }

    fun localDNSTransport(): LocalDNSTransport? {
        return null
    }

    fun defaultSystemProxyStatus(): SystemProxyStatus {
        return SystemProxyStatus().apply {
            available = false
            enabled = false
        }
    }
}
