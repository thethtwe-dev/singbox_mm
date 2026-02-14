package com.signbox.singbox_mm

import java.util.Locale

internal object VpnNotificationTextFormatter {
    private val units = arrayOf("B", "KB", "MB", "GB", "TB", "PB")

    fun buildTitle(profileLabel: String?, defaultLabel: String): String {
        return profileLabel?.takeIf { it.isNotBlank() } ?: defaultLabel
    }

    fun buildContent(
        status: String,
        detail: String?,
        trafficSnapshot: NotificationTrafficSnapshot?,
    ): String {
        return if (trafficSnapshot == null) {
            if (detail.isNullOrBlank()) status else "$status • $detail"
        } else {
            "↑ ${formatBytes(trafficSnapshot.uplinkRateBytesPerSecond)}/s • " +
                "↓ ${formatBytes(trafficSnapshot.downlinkRateBytesPerSecond)}/s"
        }
    }

    fun isConnectedStatus(status: String): Boolean {
        return status.equals(VpnNotificationStatus.CONNECTED, ignoreCase = true)
    }

    private fun formatBytes(bytes: Long): String {
        var value = bytes.coerceAtLeast(0L).toDouble()
        var index = 0
        while (value >= 1024.0 && index < units.lastIndex) {
            value /= 1024.0
            index++
        }
        return if (index == 0) {
            "${value.toLong()} ${units[index]}"
        } else {
            String.format(Locale.US, "%.2f %s", value, units[index])
        }
    }
}
