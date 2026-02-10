package com.signbox.singbox_mm

import android.os.Handler

internal class VpnLiveNotificationTicker(
    private val handler: Handler,
    private val intervalMillis: Long,
    private val shouldTick: () -> Boolean,
    private val onTick: () -> Unit,
) {
    @Volatile
    private var started = false

    private val ticker = object : Runnable {
        override fun run() {
            if (!started) {
                return
            }
            if (!shouldTick()) {
                started = false
                return
            }
            onTick()
            if (started) {
                handler.postDelayed(this, intervalMillis)
            }
        }
    }

    fun start() {
        if (started) {
            return
        }
        started = true
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }

    fun stop() {
        started = false
        handler.removeCallbacks(ticker)
    }
}
