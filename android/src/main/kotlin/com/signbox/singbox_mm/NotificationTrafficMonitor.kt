package com.signbox.singbox_mm

internal data class NotificationTrafficSnapshot(
    val uplinkBytes: Long,
    val downlinkBytes: Long,
    val uplinkRateBytesPerSecond: Long,
    val downlinkRateBytesPerSecond: Long,
    val durationMs: Long,
)

internal class NotificationTrafficMonitor(
    private val readUidTxBytes: () -> Long,
    private val readUidRxBytes: () -> Long,
) {
    @Volatile
    var connectedSinceMillis: Long? = null
        private set

    @Volatile
    var uplinkBytesBase: Long = 0L
        private set

    @Volatile
    var downlinkBytesBase: Long = 0L
        private set

    @Volatile
    private var lastSampleAtMillis: Long = 0L

    @Volatile
    private var lastSampleUplinkBytes: Long = 0L

    @Volatile
    private var lastSampleDownlinkBytes: Long = 0L

    @Volatile
    private var lastUplinkRateBytesPerSecond: Long = 0L

    @Volatile
    private var lastDownlinkRateBytesPerSecond: Long = 0L

    @Synchronized
    fun startSession(nowMillis: Long = System.currentTimeMillis()) {
        connectedSinceMillis = nowMillis
        uplinkBytesBase = readUidTxBytes().coerceAtLeast(0L)
        downlinkBytesBase = readUidRxBytes().coerceAtLeast(0L)
        lastSampleAtMillis = nowMillis
        lastSampleUplinkBytes = 0L
        lastSampleDownlinkBytes = 0L
        lastUplinkRateBytesPerSecond = 0L
        lastDownlinkRateBytesPerSecond = 0L
    }

    @Synchronized
    fun restoreSession(
        connectedAtMillis: Long?,
        uplinkBase: Long,
        downlinkBase: Long,
    ) {
        if (connectedAtMillis == null) {
            clearSession()
            return
        }
        connectedSinceMillis = connectedAtMillis
        uplinkBytesBase = uplinkBase.coerceAtLeast(0L)
        downlinkBytesBase = downlinkBase.coerceAtLeast(0L)
        lastSampleAtMillis = 0L
        lastSampleUplinkBytes = 0L
        lastSampleDownlinkBytes = 0L
        lastUplinkRateBytesPerSecond = 0L
        lastDownlinkRateBytesPerSecond = 0L
    }

    @Synchronized
    fun clearSession() {
        connectedSinceMillis = null
        uplinkBytesBase = 0L
        downlinkBytesBase = 0L
        lastSampleAtMillis = 0L
        lastSampleUplinkBytes = 0L
        lastSampleDownlinkBytes = 0L
        lastUplinkRateBytesPerSecond = 0L
        lastDownlinkRateBytesPerSecond = 0L
    }

    @Synchronized
    fun captureSnapshot(nowMillis: Long = System.currentTimeMillis()): NotificationTrafficSnapshot? {
        val connectedAt = connectedSinceMillis ?: return null
        val uplinkBytes = (readUidTxBytes() - uplinkBytesBase).coerceAtLeast(0L)
        val downlinkBytes = (readUidRxBytes() - downlinkBytesBase).coerceAtLeast(0L)

        val elapsedSinceLastSampleMs = (nowMillis - lastSampleAtMillis).coerceAtLeast(0L)
        if (elapsedSinceLastSampleMs >= 250L) {
            val uplinkDelta = (uplinkBytes - lastSampleUplinkBytes).coerceAtLeast(0L)
            val downlinkDelta = (downlinkBytes - lastSampleDownlinkBytes).coerceAtLeast(0L)
            val divisor = elapsedSinceLastSampleMs.coerceAtLeast(1L)
            lastUplinkRateBytesPerSecond = (uplinkDelta * 1000L) / divisor
            lastDownlinkRateBytesPerSecond = (downlinkDelta * 1000L) / divisor
            lastSampleAtMillis = nowMillis
            lastSampleUplinkBytes = uplinkBytes
            lastSampleDownlinkBytes = downlinkBytes
        } else if (lastSampleAtMillis <= 0L) {
            lastSampleAtMillis = nowMillis
            lastSampleUplinkBytes = uplinkBytes
            lastSampleDownlinkBytes = downlinkBytes
        }

        return NotificationTrafficSnapshot(
            uplinkBytes = uplinkBytes,
            downlinkBytes = downlinkBytes,
            uplinkRateBytesPerSecond = lastUplinkRateBytesPerSecond,
            downlinkRateBytesPerSecond = lastDownlinkRateBytesPerSecond,
            durationMs = (nowMillis - connectedAt).coerceAtLeast(0L),
        )
    }
}
