package com.signbox.singbox_mm

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

internal class PluginMethodDispatcher(
    private val methodNames: MethodNames,
    private val handlers: Handlers,
) {
    internal data class MethodNames(
        val initialize: String,
        val requestPermission: String,
        val requestNotificationPermission: String,
        val setConfig: String,
        val startVpn: String,
        val stopVpn: String,
        val restartVpn: String,
        val getState: String,
        val getStateDetails: String,
        val getStats: String,
        val getLastError: String,
        val getVersion: String,
        val pingServer: String,
        val syncRuntime: String,
    )

    internal data class Handlers(
        val initialize: (Any?, Result) -> Unit,
        val requestPermission: (Result) -> Unit,
        val requestNotificationPermission: (Result) -> Unit,
        val setConfig: (Any?, Result) -> Unit,
        val startVpn: (Result) -> Unit,
        val stopVpn: (Result) -> Unit,
        val restartVpn: (Result) -> Unit,
        val getState: (Result) -> Unit,
        val getStateDetails: (Result) -> Unit,
        val getStats: (Result) -> Unit,
        val getLastError: (Result) -> Unit,
        val getVersion: (Result) -> Unit,
        val pingServer: (Any?, Result) -> Unit,
        val syncRuntime: (Result) -> Unit,
    )

    fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            methodNames.initialize -> handlers.initialize(call.arguments, result)
            methodNames.requestPermission -> handlers.requestPermission(result)
            methodNames.requestNotificationPermission ->
                handlers.requestNotificationPermission(result)
            methodNames.setConfig -> handlers.setConfig(call.arguments, result)
            methodNames.startVpn -> handlers.startVpn(result)
            methodNames.stopVpn -> handlers.stopVpn(result)
            methodNames.restartVpn -> handlers.restartVpn(result)
            methodNames.getState -> handlers.getState(result)
            methodNames.getStateDetails -> handlers.getStateDetails(result)
            methodNames.getStats -> handlers.getStats(result)
            methodNames.getLastError -> handlers.getLastError(result)
            methodNames.getVersion -> handlers.getVersion(result)
            methodNames.pingServer -> handlers.pingServer(call.arguments, result)
            methodNames.syncRuntime -> handlers.syncRuntime(result)
            else -> result.notImplemented()
        }
    }
}
