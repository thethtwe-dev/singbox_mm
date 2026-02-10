package com.signbox.singbox_mm

import android.net.VpnService
import android.os.ParcelFileDescriptor
import io.nekohasekai.libbox.TunOptions

internal object VpnTunSessionManager {
    fun openTun(
        createBuilder: () -> VpnService.Builder,
        options: TunOptions,
        privateDnsHost: String?,
        privateDnsBootstrapDnsServer: String,
        hostPackageName: String,
        logTag: String,
        previousTunFileDescriptor: ParcelFileDescriptor?,
    ): ParcelFileDescriptor {
        val builder = createBuilder()
            .setSession("singbox-mm")
            .setMtu(options.mtu)

        VpnTunBuilderConfigurator.configure(
            builder = builder,
            options = options,
            privateDnsHost = privateDnsHost,
            privateDnsBootstrapDnsServer = privateDnsBootstrapDnsServer,
            hostPackageName = hostPackageName,
            addAllowedPackage = { packageName ->
                VpnPackageAccessController.addAllowedPackage(
                    builder = builder,
                    packageName = packageName,
                    hostPackageName = hostPackageName,
                    logTag = logTag,
                )
            },
            addDisallowedPackage = { packageName ->
                VpnPackageAccessController.addDisallowedPackage(
                    builder = builder,
                    packageName = packageName,
                    logTag = logTag,
                )
            },
        )

        val established = builder.establish()
            ?: throw IllegalStateException("Unable to establish TUN interface")

        runCatching {
            previousTunFileDescriptor?.close()
        }
        return established
    }
}
