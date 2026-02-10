package com.signbox.singbox_mm

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

internal object VpnNotificationPendingIntents {
    fun createLaunchPendingIntent(
        context: Context,
        packageName: String,
        requestCode: Int,
    ): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            requestCode,
            launchIntent,
            pendingIntentFlags(updateCurrent = true),
        )
    }

    fun createServicePendingIntent(
        context: Context,
        serviceClass: Class<*>,
        action: String,
        requestCode: Int,
        includeConfig: Boolean,
        configPath: String?,
        configPathExtraKey: String,
    ): PendingIntent {
        val intent = Intent(context, serviceClass).apply {
            this.action = action
            if (includeConfig && !configPath.isNullOrBlank()) {
                putExtra(configPathExtraKey, configPath)
            }
        }
        return PendingIntent.getService(
            context,
            requestCode,
            intent,
            pendingIntentFlags(updateCurrent = true),
        )
    }

    private fun pendingIntentFlags(updateCurrent: Boolean): Int {
        var flags = if (updateCurrent) PendingIntent.FLAG_UPDATE_CURRENT else 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
