package com.signbox.singbox_mm

import android.content.Context
import android.content.Intent

internal object VpnStateUpdateBroadcaster {
    fun send(
        context: Context,
        action: String,
        packageName: String,
        stateExtraKey: String,
        errorExtraKey: String,
        state: String,
        error: String?,
    ) {
        val intent = Intent(action)
            .setPackage(packageName)
            .putExtra(stateExtraKey, state)
            .putExtra(errorExtraKey, error)
        context.sendBroadcast(intent)
    }
}
