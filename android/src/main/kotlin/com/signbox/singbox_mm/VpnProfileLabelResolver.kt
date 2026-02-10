package com.signbox.singbox_mm

import org.json.JSONObject

internal object VpnProfileLabelResolver {
    private val systemOutboundTypes = setOf("direct", "block", "dns", "dns-out")

    fun resolve(
        configContent: String,
        defaultLabel: String,
    ): String {
        return runCatching {
            val root = JSONObject(configContent)
            val finalTag = root
                .optJSONObject("route")
                ?.optString("final")
                ?.trim()
                .orEmpty()
            if (finalTag.isNotEmpty()) {
                return@runCatching finalTag
            }

            val outbounds = root.optJSONArray("outbounds")
            if (outbounds != null) {
                for (index in 0 until outbounds.length()) {
                    val outbound = outbounds.optJSONObject(index) ?: continue
                    val type = outbound.optString("type").trim().lowercase()
                    val tag = outbound.optString("tag").trim()
                    if (tag.isNotEmpty() && !systemOutboundTypes.contains(type)) {
                        return@runCatching tag
                    }
                }
            }

            defaultLabel
        }.getOrElse {
            defaultLabel
        }
    }
}
