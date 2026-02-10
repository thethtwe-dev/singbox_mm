package com.signbox.singbox_mm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.nekohasekai.libbox.BoxService

internal object VpnNotificationRuntimeCoordinator {
    fun ensureChannel(
        context: Context,
        channelId: String,
        channelName: String,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    fun notify(
        context: Context,
        notificationId: Int,
        notification: Notification,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
    }

    fun statusForState(
        state: String,
        error: String?,
        connectedDetail: String?,
    ): Pair<String, String?> {
        return VpnNotificationStatus.forRuntimeState(
            state = state,
            error = error,
            connectedDetail = connectedDetail,
        )
    }

    fun shouldKeepLiveTicker(
        boxService: BoxService?,
        connectedSinceMillis: Long?,
    ): Boolean {
        return boxService != null && connectedSinceMillis != null
    }
}
