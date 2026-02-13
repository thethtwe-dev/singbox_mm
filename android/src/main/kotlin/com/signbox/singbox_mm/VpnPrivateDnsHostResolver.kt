package com.signbox.singbox_mm

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.provider.Settings

internal object VpnPrivateDnsHostResolver {
    fun resolve(
        context: Context,
        connectivity: ConnectivityManager,
    ): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return null
        }

        resolveFromLinkProperties(connectivity)?.let { return it }
        return resolveFromGlobalSettings(context)
    }

    private fun resolveFromLinkProperties(connectivity: ConnectivityManager): String? {
        val allNetworks = runCatching { connectivity.allNetworks }.getOrDefault(emptyArray())
        for (network in allNetworks) {
            val host = connectivity
                .getLinkProperties(network)
                ?.privateDnsServerName
                ?.trim()
                .orEmpty()
            if (host.isNotEmpty()) {
                return host
            }
        }

        val active = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivity.activeNetwork
        } else {
            null
        }
        val activeHost = active?.let { network ->
            connectivity
                .getLinkProperties(network)
                ?.privateDnsServerName
                ?.trim()
                .orEmpty()
        }.orEmpty()
        return activeHost.takeIf { it.isNotEmpty() }
    }

    private fun resolveFromGlobalSettings(context: Context): String? {
        return runCatching {
            val mode = Settings.Global.getString(context.contentResolver, "private_dns_mode")
                ?.trim()
                ?.lowercase()
                .orEmpty()
            val host = Settings.Global.getString(context.contentResolver, "private_dns_specifier")
                ?.trim()
                .orEmpty()
            if (host.isEmpty()) {
                null
            } else if (mode == "hostname" || mode == "provider_hostname" || mode == "strict") {
                host
            } else {
                null
            }
        }.getOrNull()
    }
}
