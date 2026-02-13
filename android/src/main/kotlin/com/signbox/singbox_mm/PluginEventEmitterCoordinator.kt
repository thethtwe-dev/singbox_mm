package com.signbox.singbox_mm

import android.os.Handler
import io.flutter.plugin.common.EventChannel

internal class PluginEventEmitterCoordinator(
    private val mainHandler: Handler,
    private val statsEmitIntervalMsProvider: () -> Long,
) {
    companion object {
        private const val STATS_HEARTBEAT_MS = 5_000L
    }

    @Volatile
    private var stateSink: EventChannel.EventSink? = null

    @Volatile
    private var statsSink: EventChannel.EventSink? = null

    @Volatile
    private var statsTickCallback: (() -> Unit)? = null

    private var lastStatsSignature: String? = null
    private var lastStatsEmitAtMs: Long = 0L

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
        resetStatsDedup()
        startStatsEmitter()
    }

    fun onStatsCancel() {
        statsSink = null
        statsTickCallback = null
        resetStatsDedup()
        stopStatsEmitter()
    }

    fun emitState(payload: Any?) {
        mainHandler.post {
            stateSink?.success(payload)
        }
    }

    fun emitStats(payload: Any?) {
        mainHandler.post {
            val sink = statsSink ?: return@post
            if (!shouldEmitStatsPayload(payload)) {
                return@post
            }
            sink.success(payload)
        }
    }

    fun shutdown() {
        stateSink = null
        statsSink = null
        statsTickCallback = null
        resetStatsDedup()
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

    private fun shouldEmitStatsPayload(payload: Any?): Boolean {
        val now = System.currentTimeMillis()
        val signature = buildStatsSignature(payload)
        val elapsed = now - lastStatsEmitAtMs
        val changed = signature != lastStatsSignature
        val heartbeatDue = elapsed >= STATS_HEARTBEAT_MS
        if (changed || heartbeatDue || lastStatsEmitAtMs <= 0L) {
            lastStatsSignature = signature
            lastStatsEmitAtMs = now
            return true
        }
        return false
    }

    private fun buildStatsSignature(payload: Any?): String {
        if (payload !is Map<*, *>) {
            return payload?.toString() ?: "null"
        }

        fun readLong(vararg keys: String): Long {
            for (key in keys) {
                val value = payload[key]
                when (value) {
                    is Number -> return value.toLong()
                    is String -> value.toLongOrNull()?.let { return it }
                }
            }
            return -1L
        }

        val totalUploaded = readLong("totalUploaded", "uplinkBytes")
        val totalDownloaded = readLong("totalDownloaded", "downlinkBytes")
        val uploadSpeed = readLong("uploadSpeed")
        val downloadSpeed = readLong("downloadSpeed")
        val activeConnections = readLong("activeConnections")
        val connectedAt = payload["connectedAt"]?.toString() ?: "null"
        return listOf(
            totalUploaded.toString(),
            totalDownloaded.toString(),
            uploadSpeed.toString(),
            downloadSpeed.toString(),
            activeConnections.toString(),
            connectedAt,
        ).joinToString("|")
    }

    private fun resetStatsDedup() {
        lastStatsSignature = null
        lastStatsEmitAtMs = 0L
    }
}
