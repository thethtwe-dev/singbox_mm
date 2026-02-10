package com.signbox.singbox_mm

import android.content.Context

internal object VpnNotificationIconResolver {
    fun resolve(context: Context): Int {
        val bundledStatusIcon = runCatching {
            R.drawable.ic_stat_singbox_mm
        }.getOrDefault(0)
        if (bundledStatusIcon != 0) {
            return bundledStatusIcon
        }

        val appIcon = context.applicationInfo.icon
        if (appIcon != 0) {
            return appIcon
        }
        return android.R.drawable.stat_sys_warning
    }
}
