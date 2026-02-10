package com.signbox.singbox_mm

import android.os.Handler
import io.flutter.plugin.common.EventChannel

internal class PluginEventEmitterCoordinator(
    private val mainHandler: Handler,
    private val statsEmitIntervalMsProvider: () -> Long,
) {
    @Volatile
    private var stateSink: EventChannel.EventSink? = null

    @Volatile
    private var statsSink: EventChannel.EventSink? = null

    @Volatile
    private var statsTickCallback: (() -> Unit)? = null

    private val statsEmitter = object : Runnable {
        override fun run() {
            statsTickCallback?.invoke()
            if (statsSink != null) {
                val intervalMs = statsEmitIntervalMsProvider()
                mainHandler.postDelayed(this, intervalMs)
            }
        }
    }

    fun onStateListen(events: EventChannel.EventSink?) {
        stateSink = events
    }

    fun onStateCancel() {
        stateSink = null
    }

    fun onStatsListen(
        events: EventChannel.EventSink?,
        onTick: () -> Unit,
    ) {
        statsSink = events
        statsTickCallback = onTick
        startStatsEmitter()
    }

    fun onStatsCancel() {
        statsSink = null
        statsTickCallback = null
        stopStatsEmitter()
    }

    fun emitState(payload: Any?) {
        mainHandler.post {
            stateSink?.success(payload)
        }
    }

    fun emitStats(payload: Any?) {
        mainHandler.post {
            statsSink?.success(payload)
        }
    }

    fun shutdown() {
        stateSink = null
        statsSink = null
        statsTickCallback = null
        stopStatsEmitter()
    }

    private fun startStatsEmitter() {
        mainHandler.removeCallbacks(statsEmitter)
        if (statsSink != null) {
            mainHandler.post(statsEmitter)
        }
    }

    private fun stopStatsEmitter() {
        mainHandler.removeCallbacks(statsEmitter)
    }
}
