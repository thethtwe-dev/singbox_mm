package com.signbox.singbox_mm

import android.net.VpnService
import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.TunOptions

internal class VpnTunServiceAdapter(
    private val createBuilder: () -> VpnService.Builder,
    private val resolvePrivateDnsHost: () -> String?,
    private val privateDnsBootstrapDnsServer: String,
    private val hostPackageName: String,
    private val logTag: String,
    private val readPreviousTunFileDescriptor: () -> ParcelFileDescriptor?,
    private val persistTunFileDescriptor: (ParcelFileDescriptor) -> Unit,
) {
    fun openTun(options: TunOptions): Int {
        val established = VpnTunSessionManager.openTun(
            createBuilder = createBuilder,
            options = options,
            privateDnsHost = resolvePrivateDnsHost(),
            privateDnsBootstrapDnsServer = privateDnsBootstrapDnsServer,
            hostPackageName = hostPackageName,
            logTag = logTag,
            previousTunFileDescriptor = readPreviousTunFileDescriptor(),
        )
        persistTunFileDescriptor(established)
        return established.fd
    }
}
