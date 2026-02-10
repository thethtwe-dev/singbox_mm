package com.signbox.singbox_mm

import io.nekohasekai.libbox.TunOptions

internal class VpnTunControlBridge(
    private val hasVpnPermission: () -> Boolean,
    private val protectFd: (Int) -> Unit,
    private val tunServiceAdapter: VpnTunServiceAdapter,
) {
    fun usePlatformAutoDetectInterfaceControl(): Boolean {
        return true
    }

    fun autoDetectInterfaceControl(fd: Int) {
        protectFd(fd)
    }

    fun openTun(options: TunOptions): Int {
        if (!hasVpnPermission()) {
            throw IllegalStateException("VPN permission is not granted")
        }
        return tunServiceAdapter.openTun(options)
    }
}
