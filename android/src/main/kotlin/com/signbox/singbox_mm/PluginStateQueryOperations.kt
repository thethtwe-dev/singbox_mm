package com.signbox.singbox_mm

import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService

internal class PluginStateQueryOperations(
    private val executor: ExecutorService,
    private val syncStateFromPersistedRuntime: (Boolean) -> Boolean,
    private val emitState: () -> Unit,
    private val emitStats: () -> Unit,
    private val postSuccess: (Result, Any?) -> Unit,
    private val currentStateProvider: () -> String,
    private val currentErrorProvider: () -> String?,
    private val stateSnapshotProvider: () -> PluginConnectionStateCoordinator.Snapshot,
    private val diagnosticsSnapshotProvider: () -> PluginNetworkDiagnosticsTracker.Snapshot,
    private val refreshNetworkDiagnostics: () -> Unit,
    private val refreshDerivedStateDetail: () -> Unit,
    private val statsPayloadProvider: (String) -> Map<String, Any?>,
    private val connectedState: String,
    private val connectingState: String,
) {
    fun getState(result: Result) {
        syncStateFromPersistedRuntime(false)
        result.success(currentStateProvider())
    }

    fun getStateDetails(result: Result) {
        syncStateFromPersistedRuntime(false)
        val state = currentStateProvider()
        if (state == connectedState || state == connectingState) {
            refreshNetworkDiagnostics()
        }
        refreshDerivedStateDetail()
        result.success(buildStateMap())
    }

    fun getStats(result: Result) {
        syncStateFromPersistedRuntime(false)
        val state = currentStateProvider()
        result.success(statsPayloadProvider(state))
    }

    fun getLastError(result: Result) {
        result.success(currentErrorProvider())
    }

    fun syncRuntimeState(result: Result) {
        executor.execute {
            val applied = syncStateFromPersistedRuntime(true)
            if (!applied) {
                emitState()
            }
            emitStats()
            postSuccess(result, null)
        }
    }

    fun buildStateMap(): Map<String, Any?> {
        val stateSnapshot = stateSnapshotProvider()
        val diagnostics = diagnosticsSnapshotProvider()
        return mapOf(
            "state" to stateSnapshot.state,
            "timestamp" to System.currentTimeMillis(),
            "lastError" to stateSnapshot.lastError,
            "detailCode" to diagnostics.detailCode,
            "detailMessage" to diagnostics.detailMessage,
            "networkValidated" to diagnostics.networkValidated,
            "hasInternetCapability" to diagnostics.hasInternetCapability,
            "privateDnsActive" to diagnostics.privateDnsActive,
            "privateDnsServerName" to diagnostics.privateDnsServerName,
            "activeInterface" to diagnostics.activeInterface,
            "underlyingTransports" to diagnostics.underlyingTransports,
        )
    }
}
