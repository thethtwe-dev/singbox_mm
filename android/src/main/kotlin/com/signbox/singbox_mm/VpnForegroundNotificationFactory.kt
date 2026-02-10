package com.signbox.singbox_mm

import android.app.Notification
import android.app.Service
import android.content.Context
import android.os.Build

internal object VpnForegroundNotificationFactory {
    fun build(
        context: Context,
        channelId: String,
        status: String,
        detail: String?,
        profileLabel: String?,
        defaultProfileLabel: String,
        currentConfigPath: String?,
        connectedSinceMillis: Long?,
        appPackageName: String,
        serviceClass: Class<out Service>,
        openAppRequestCode: Int,
        stopRequestCode: Int,
        restartRequestCode: Int,
        stopAction: String,
        restartAction: String,
        configPathExtraKey: String,
        smallIcon: Int,
        captureTrafficSnapshot: () -> NotificationTrafficSnapshot?,
    ): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context)
        }

        val title = VpnNotificationTextFormatter.buildTitle(
            profileLabel = profileLabel,
            defaultLabel = defaultProfileLabel,
        )
        val trafficSnapshot = if (VpnNotificationTextFormatter.isConnectedStatus(status)) {
            captureTrafficSnapshot()
        } else {
            null
        }
        val content = VpnNotificationTextFormatter.buildContent(
            status = status,
            detail = detail,
            trafficSnapshot = trafficSnapshot,
        )

        builder
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(smallIcon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(
                VpnNotificationPendingIntents.createLaunchPendingIntent(
                    context = context,
                    packageName = appPackageName,
                    requestCode = openAppRequestCode,
                ),
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                VpnNotificationPendingIntents.createServicePendingIntent(
                    context = context,
                    serviceClass = serviceClass,
                    action = stopAction,
                    requestCode = stopRequestCode,
                    includeConfig = false,
                    configPath = currentConfigPath,
                    configPathExtraKey = configPathExtraKey,
                ),
            )

        if (trafficSnapshot != null) {
            if (!detail.isNullOrBlank()) {
                builder.setStyle(Notification.BigTextStyle().bigText(detail))
            }
            connectedSinceMillis?.let { connectedAt ->
                builder
                    .setWhen(connectedAt)
                    .setShowWhen(true)
                    .setUsesChronometer(true)
            }
        }

        if (!currentConfigPath.isNullOrBlank()) {
            builder.addAction(
                android.R.drawable.ic_popup_sync,
                "Restart",
                VpnNotificationPendingIntents.createServicePendingIntent(
                    context = context,
                    serviceClass = serviceClass,
                    action = restartAction,
                    requestCode = restartRequestCode,
                    includeConfig = true,
                    configPath = currentConfigPath,
                    configPathExtraKey = configPathExtraKey,
                ),
            )
        }

        return builder.build()
    }
}
