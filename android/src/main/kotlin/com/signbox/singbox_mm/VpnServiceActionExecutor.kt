package com.signbox.singbox_mm

import android.util.Log
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.Notification as CoreNotification
import io.nekohasekai.libbox.PlatformInterface
import java.util.concurrent.ExecutorService

internal object VpnServiceActionExecutor {
    fun scheduleStop(
        worker: ExecutorService,
        stopCore: (Boolean) -> Unit,
        stopForeground: (Int) -> Unit,
        stopForegroundFlag: Int,
        stopSelf: () -> Unit,
    ) {
        worker.execute {
            stopCore(true)
            stopForeground(stopForegroundFlag)
            stopSelf()
        }
    }

    fun scheduleRestart(
        worker: ExecutorService,
        configPath: String?,
        publishError: (String) -> Unit,
        stopCore: (Boolean) -> Unit,
        startCore: (String?) -> Unit,
    ) {
        worker.execute {
            if (configPath.isNullOrBlank()) {
                publishError("Missing config path for restart")
                return@execute
            }
            stopCore(false)
            startCore(configPath)
        }
    }

    fun scheduleStart(
        worker: ExecutorService,
        configPath: String?,
        startCore: (String?) -> Unit,
    ) {
        worker.execute {
            startCore(configPath)
        }
    }

    fun resolveNotificationDetail(notification: CoreNotification): String {
        val title = notification.title
        val body = notification.body
        return if (body.isNullOrBlank()) title else "$title: $body"
    }

    fun reloadService(
        commandServer: CommandServer?,
        oldService: BoxService?,
        configPath: String?,
        host: PlatformInterface,
        onRuntimeUpdated: (BoxService) -> Unit,
        onFailure: (String) -> Unit,
    ) {
        val server = commandServer ?: return
        val service = oldService ?: return
        val path = configPath ?: return
        runCatching {
            VpnServiceReloader.reload(
                commandServer = server,
                oldService = service,
                host = host,
                configPath = path,
            )
        }.onSuccess { nextService ->
            onRuntimeUpdated(nextService)
        }.onFailure {
            onFailure(it.message ?: "unknown error")
        }
    }

    fun writeLog(
        logTag: String,
        message: String,
    ) {
        Log.d(logTag, message)
    }
}
