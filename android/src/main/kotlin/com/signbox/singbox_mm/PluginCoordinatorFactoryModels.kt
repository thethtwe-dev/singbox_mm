package com.signbox.singbox_mm

import android.content.Context
import android.net.ConnectivityManager
import android.os.Handler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ExecutorService

internal data class PluginChannelNames(
    val method: String,
    val state: String,
    val stats: String,
)

internal data class PluginRuntimeDefaults(
    val configFileName: String,
    val statsEmitIntervalMs: Long,
    val networkValidationGraceMs: Long,
)

internal data class PluginStateConfig(
    val action: String,
    val extraStateKey: String,
    val extraErrorKey: String,
    val disconnected: String,
    val preparing: String,
    val connecting: String,
    val connected: String,
    val disconnecting: String,
    val error: String,
)

internal data class PluginCoordinatorFactoryArgs(
    val context: Context,
    val connectivity: ConnectivityManager,
    val executor: ExecutorService,
    val mainHandler: Handler,
    val activityResultListener: PluginRegistry.ActivityResultListener,
    val requestPermissionsResultListener: PluginRegistry.RequestPermissionsResultListener,
    val readUidTxBytes: () -> Long,
    val readUidRxBytes: () -> Long,
    val updateConnectionState: (String, String?) -> Unit,
    val emitState: () -> Unit,
    val emitStats: () -> Unit,
    val refreshDerivedStateDetail: () -> Unit,
    val syncStateFromPersistedRuntime: (Boolean) -> Boolean,
    val postSuccess: (Result, Any?) -> Unit,
    val postError: (Result, String, String) -> Unit,
    val requestVpnPermission: (Result) -> Unit,
    val requestNotificationPermission: (Result) -> Unit,
    val methodNames: PluginMethodDispatcher.MethodNames,
    val channelNames: PluginChannelNames,
    val runtimeDefaults: PluginRuntimeDefaults,
    val stateConfig: PluginStateConfig,
)
