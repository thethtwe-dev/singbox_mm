package com.signbox.singbox_mm

internal class PluginStatsTracker(
    private val readUidTxBytes: () -> Long,
    private val readUidRxBytes: () -> Long,
) {
    @Volatile
    var connectedAtMillis: Long? = null
        private set

    @Volatile
    var uplinkBytesBase: Long = 0L
        private set

    @Volatile
    var downlinkBytesBase: Long = 0L
        private set

    @Volatile
    private var lastStatsSampleAtMillis: Long = 0L

    @Volatile
    private var lastStatsUploadedBytes: Long = 0L

    @Volatile
    private var lastStatsDownloadedBytes: Long = 0L

    @Volatile
    private var lastUploadSpeedBytesPerSecond: Long = 0L

    @Volatile
    private var lastDownloadSpeedBytesPerSecond: Long = 0L

    @Synchronized
    fun prepareForStart(nowMillis: Long = System.currentTimeMillis()) {
        connectedAtMillis = null
        uplinkBytesBase = readUidTxBytes().coerceAtLeast(0L)
        downlinkBytesBase = readUidRxBytes().coerceAtLeast(0L)
        resetSampling(nowMillis = nowMillis)
    }

    @Synchronized
    fun onConnectedState(nowMillis: Long = System.currentTimeMillis()) {
        if (connectedAtMillis == null) {
            connectedAtMillis = nowMillis
            uplinkBytesBase = readUidTxBytes().coerceAtLeast(0L)
            downlinkBytesBase = readUidRxBytes().coerceAtLeast(0L)
            resetSampling(nowMillis = nowMillis)
        }
    }

    @Synchronized
    fun onDisconnectedState(nowMillis: Long = System.currentTimeMillis()) {
        connectedAtMillis = null
        resetSampling(nowMillis = nowMillis)
    }

    @Synchronized
    fun applyPersistedSnapshot(
        snapshot: PersistedRuntimeState,
        disconnectedState: String,
        errorState: String,
        nowMillis: Long = System.currentTimeMillis(),
    ) {
        if (snapshot.connectedAtMillis != null) {
            connectedAtMillis = snapshot.connectedAtMillis
            uplinkBytesBase = snapshot.uplinkBytesBase.coerceAtLeast(0L)
            downlinkBytesBase = snapshot.downlinkBytesBase.coerceAtLeast(0L)
            resetSampling(
                totalUploaded = (readUidTxBytes() - uplinkBytesBase).coerceAtLeast(0L),
                totalDownloaded = (readUidRxBytes() - downlinkBytesBase).coerceAtLeast(0L),
                nowMillis = nowMillis,
            )
            return
        }

        if (snapshot.state == disconnectedState || snapshot.state == errorState) {
            connectedAtMillis = null
            uplinkBytesBase = snapshot.uplinkBytesBase.coerceAtLeast(0L)
            downlinkBytesBase = snapshot.downlinkBytesBase.coerceAtLeast(0L)
            resetSampling(nowMillis = nowMillis)
        }
    }

    @Synchronized
    fun buildStatsMap(
        connectionState: String,
        connectedState: String,
        nowMillis: Long = System.currentTimeMillis(),
    ): Map<String, Any?> {
        val currentTx = readUidTxBytes().coerceAtLeast(0L)
        val currentRx = readUidRxBytes().coerceAtLeast(0L)
        val totalUploaded = (currentTx - uplinkBytesBase).coerceAtLeast(0L)
        val totalDownloaded = (currentRx - downlinkBytesBase).coerceAtLeast(0L)
        val isConnected = connectionState == connectedState

        if (!isConnected) {
            lastUploadSpeedBytesPerSecond = 0L
            lastDownloadSpeedBytesPerSecond = 0L
            lastStatsSampleAtMillis = nowMillis
            lastStatsUploadedBytes = totalUploaded
            lastStatsDownloadedBytes = totalDownloaded
        } else if (lastStatsSampleAtMillis <= 0L) {
            resetSampling(totalUploaded, totalDownloaded, nowMillis = nowMillis)
        } else {
            val elapsedMs = (nowMillis - lastStatsSampleAtMillis).coerceAtLeast(0L)
            if (elapsedMs >= 250L) {
                val uploadDelta = (totalUploaded - lastStatsUploadedBytes).coerceAtLeast(0L)
                val downloadDelta = (totalDownloaded - lastStatsDownloadedBytes).coerceAtLeast(0L)
                val divisor = elapsedMs.coerceAtLeast(1L)
                lastUploadSpeedBytesPerSecond = (uploadDelta * 1000L) / divisor
                lastDownloadSpeedBytesPerSecond = (downloadDelta * 1000L) / divisor
                lastStatsSampleAtMillis = nowMillis
                lastStatsUploadedBytes = totalUploaded
                lastStatsDownloadedBytes = totalDownloaded
            }
        }

        return mapOf(
            "totalUploaded" to totalUploaded,
            "totalDownloaded" to totalDownloaded,
            "uploadSpeed" to lastUploadSpeedBytesPerSecond,
            "downloadSpeed" to lastDownloadSpeedBytesPerSecond,
            "uplinkBytes" to totalUploaded,
            "downlinkBytes" to totalDownloaded,
            "activeConnections" to if (isConnected) 1 else 0,
            "connectedAt" to connectedAtMillis,
            "updatedAt" to nowMillis,
        )
    }

    @Synchronized
    private fun resetSampling(
        totalUploaded: Long = 0L,
        totalDownloaded: Long = 0L,
        nowMillis: Long = System.currentTimeMillis(),
    ) {
        lastStatsSampleAtMillis = nowMillis
        lastStatsUploadedBytes = totalUploaded.coerceAtLeast(0L)
        lastStatsDownloadedBytes = totalDownloaded.coerceAtLeast(0L)
        lastUploadSpeedBytesPerSecond = 0L
        lastDownloadSpeedBytesPerSecond = 0L
    }
}
