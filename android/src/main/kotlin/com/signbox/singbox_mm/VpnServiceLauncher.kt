package com.signbox.singbox_mm

import android.content.Context
import android.content.Intent
import android.os.Build

internal object VpnServiceLauncher {
    fun start(
        context: Context,
        serviceClass: Class<*>,
        startAction: String,
        configPathExtraKey: String,
        configPath: String,
    ) {
        val intent = Intent(context, serviceClass).apply {
            action = startAction
            putExtra(configPathExtraKey, configPath)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    fun stop(
        context: Context,
        serviceClass: Class<*>,
        stopAction: String,
    ) {
        val intent = Intent(context, serviceClass).apply {
            action = stopAction
        }

        runCatching {
            context.startService(intent)
        }.onFailure {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
