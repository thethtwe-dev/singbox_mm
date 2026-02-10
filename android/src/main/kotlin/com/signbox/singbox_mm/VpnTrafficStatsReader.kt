package com.signbox.singbox_mm

import android.net.TrafficStats

internal object VpnTrafficStatsReader {
    fun readUidTxBytes(uid: Int): Long {
        val value = TrafficStats.getUidTxBytes(uid)
        return if (value >= 0L) value else 0L
    }

    fun readUidRxBytes(uid: Int): Long {
        val value = TrafficStats.getUidRxBytes(uid)
        return if (value >= 0L) value else 0L
    }
}
