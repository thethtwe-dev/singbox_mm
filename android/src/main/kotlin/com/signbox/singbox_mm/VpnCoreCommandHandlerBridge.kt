package com.signbox.singbox_mm

import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.SystemProxyStatus

internal class VpnCoreCommandHandlerBridge(
    private val readSystemProxyStatus: () -> SystemProxyStatus,
    private val applySystemProxyEnabled: (Boolean) -> Unit,
    private val serviceReload: () -> Unit,
    private val postServiceClose: () -> Unit,
) : CommandServerHandler {
    override fun getSystemProxyStatus(): SystemProxyStatus {
        return readSystemProxyStatus()
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
        applySystemProxyEnabled(isEnabled)
    }

    override fun serviceReload() {
        serviceReload.invoke()
    }

    override fun postServiceClose() {
        postServiceClose.invoke()
    }
}
