package com.signbox.singbox_mm

import android.content.Intent
import android.net.VpnService

class SignboxLibboxVpnService : VpnService() {
    private val runtimeGraph by lazy {
        VpnServiceRuntimeGraph(
            service = this,
        )
    }

    override fun onCreate() {
        super.onCreate()
        runtimeGraph.onCreate()
    }

    override fun onDestroy() {
        runtimeGraph.onDestroyBeforeSuper()
        super.onDestroy()
    }

    override fun onRevoke() {
        runtimeGraph.onRevoke()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return runtimeGraph.onStartCommand(
            intentAction = intent?.action,
            intentConfigPath = intent?.getStringExtra(SignboxLibboxServiceContract.EXTRA_CONFIG_PATH),
        )
    }
}
