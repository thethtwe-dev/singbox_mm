package com.signbox.singbox_mm

internal class PluginConnectionStateCoordinator(
    private val disconnectedState: String,
    private val connectingState: String,
    private val connectedState: String,
    private val errorState: String,
    private val onConnectedOrConnecting: () -> Unit,
    private val onDisconnectedOrError: () -> Unit,
    private val onRefreshDerivedStateDetail: (String, String?) -> Unit,
    private val onEmitStateAndStats: () -> Unit,
    private val nowMillisProvider: () -> Long = { System.currentTimeMillis() },
) {
    data class Snapshot(
        val state: String,
        val lastError: String?,
        val updatedAtMillis: Long,
    )

    @Volatile
    private var connectionState: String = disconnectedState

    @Volatile
    private var lastError: String? = null

    @Volatile
    private var connectionStateUpdatedAtMillis: Long = 0L

    @Synchronized
    fun snapshot(): Snapshot {
        return Snapshot(
            state = connectionState,
            lastError = lastError,
            updatedAtMillis = connectionStateUpdatedAtMillis,
        )
    }

    val currentState: String
        get() = connectionState

    val currentError: String?
        get() = lastError

    @Synchronized
    fun updateConnectionState(
        newState: String,
        error: String?,
    ) {
        connectionState = newState
        connectionStateUpdatedAtMillis = nowMillisProvider()
        if (!error.isNullOrBlank()) {
            lastError = error
        } else if (newState != errorState) {
            lastError = null
        }
        if (newState == connectedState || newState == connectingState) {
            onConnectedOrConnecting()
        }
        if (newState == disconnectedState || newState == errorState) {
            onDisconnectedOrError()
        }
        onRefreshDerivedStateDetail(connectionState, lastError)
        onEmitStateAndStats()
    }

    @Synchronized
    fun syncStateFromPersistedRuntime(
        snapshot: PersistedRuntimeState,
        forceEmit: Boolean,
        statsTracker: PluginStatsTracker,
    ): Boolean {
        if (
            snapshot.updatedAtMillis > 0L &&
                snapshot.updatedAtMillis < connectionStateUpdatedAtMillis &&
                connectionState != disconnectedState
        ) {
            return false
        }

        val previousState = connectionState
        val previousError = lastError
        val previousConnectedAt = statsTracker.connectedAtMillis
        val previousUplinkBase = statsTracker.uplinkBytesBase
        val previousDownlinkBase = statsTracker.downlinkBytesBase

        statsTracker.applyPersistedSnapshot(
            snapshot = snapshot,
            disconnectedState = disconnectedState,
            errorState = errorState,
        )

        val changed =
            previousState != snapshot.state ||
                previousError != snapshot.error ||
                previousConnectedAt != statsTracker.connectedAtMillis ||
                previousUplinkBase != statsTracker.uplinkBytesBase ||
                previousDownlinkBase != statsTracker.downlinkBytesBase

        if (changed || forceEmit) {
            updateConnectionState(snapshot.state, snapshot.error)
            return true
        }

        return false
    }
}
