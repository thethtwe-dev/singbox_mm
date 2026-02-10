package com.signbox.singbox_mm

import java.io.File

internal data class VpnConfigLoadResult(
    val configPath: String? = null,
    val configContent: String? = null,
    val error: String? = null,
)

internal object VpnConfigContentLoader {
    fun load(
        configPath: String?,
        privateDnsHost: String?,
        logTag: String,
    ): VpnConfigLoadResult {
        if (configPath.isNullOrBlank()) {
            return VpnConfigLoadResult(error = "Missing config path")
        }

        val configFile = File(configPath)
        if (!configFile.exists()) {
            return VpnConfigLoadResult(error = "Config file not found at $configPath")
        }

        val rawConfigContent = runCatching {
            configFile.readText()
        }.getOrElse {
            return VpnConfigLoadResult(error = it.message ?: "Unable to read config file")
        }

        val configContent = if (privateDnsHost == null) {
            rawConfigContent
        } else {
            VpnPrivateDnsCompatibilityPatcher.apply(
                rawConfigContent = rawConfigContent,
                privateDnsHost = privateDnsHost,
                logTag = logTag,
            )
        }

        return VpnConfigLoadResult(
            configPath = configPath,
            configContent = configContent,
        )
    }
}
