package com.signbox.singbox_mm

internal object VpnTrafficSessionCoordinator {
    fun initialize(
        monitor: NotificationTrafficMonitor,
        lastPublishedState: String,
        lastPublishedError: String?,
        persistSnapshot: (String, String?) -> Unit,
    ) {
        monitor.startSession()
        persistSnapshot(lastPublishedState, lastPublishedError)
    }

    fun clear(
        monitor: NotificationTrafficMonitor,
        lastPublishedState: String,
        lastPublishedError: String?,
        persistSnapshot: (String, String?) -> Unit,
    ) {
        monitor.clearSession()
        persistSnapshot(lastPublishedState, lastPublishedError)
    }

    fun captureSnapshot(
        monitor: NotificationTrafficMonitor,
        nowMillis: Long = System.currentTimeMillis(),
    ): NotificationTrafficSnapshot? {
        return monitor.captureSnapshot(nowMillis)
    }
}
