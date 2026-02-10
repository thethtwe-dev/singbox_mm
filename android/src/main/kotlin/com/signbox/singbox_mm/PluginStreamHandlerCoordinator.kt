package com.signbox.singbox_mm

import io.flutter.plugin.common.EventChannel

internal class PluginStreamHandlerCoordinator(
    private val eventEmitter: PluginEventEmitterCoordinator,
    private val syncStateFromPersistedRuntime: (Boolean) -> Boolean,
    private val emitState: () -> Unit,
    private val emitStats: () -> Unit,
) {
    val statsStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventEmitter.onStatsListen(events) {
                emitStats()
            }
            syncStateFromPersistedRuntime(false)
            emitStats()
        }

        override fun onCancel(arguments: Any?) {
            eventEmitter.onStatsCancel()
        }
    }

    fun onStateListen(events: EventChannel.EventSink?) {
        eventEmitter.onStateListen(events)
        syncStateFromPersistedRuntime(false)
        emitState()
    }

    fun onStateCancel() {
        eventEmitter.onStateCancel()
    }
}
