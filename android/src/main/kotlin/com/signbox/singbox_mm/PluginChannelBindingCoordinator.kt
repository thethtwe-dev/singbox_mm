package com.signbox.singbox_mm

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

internal class PluginChannelBindingCoordinator(
    private val methodChannelName: String,
    private val stateChannelName: String,
    private val statsChannelName: String,
) {
    data class BindingSet(
        val methodChannel: MethodChannel,
        val stateChannel: EventChannel,
        val statsChannel: EventChannel,
    )

    fun attach(
        binaryMessenger: BinaryMessenger,
        methodCallHandler: MethodCallHandler,
        stateStreamHandler: EventChannel.StreamHandler,
        statsStreamHandler: EventChannel.StreamHandler,
    ): BindingSet {
        val methodChannel = MethodChannel(binaryMessenger, methodChannelName)
        val stateChannel = EventChannel(binaryMessenger, stateChannelName)
        val statsChannel = EventChannel(binaryMessenger, statsChannelName)

        methodChannel.setMethodCallHandler(methodCallHandler)
        stateChannel.setStreamHandler(stateStreamHandler)
        statsChannel.setStreamHandler(statsStreamHandler)

        return BindingSet(
            methodChannel = methodChannel,
            stateChannel = stateChannel,
            statsChannel = statsChannel,
        )
    }

    fun detach(bindingSet: BindingSet?) {
        if (bindingSet == null) {
            return
        }
        bindingSet.methodChannel.setMethodCallHandler(null)
        bindingSet.stateChannel.setStreamHandler(null)
        bindingSet.statsChannel.setStreamHandler(null)
    }
}
