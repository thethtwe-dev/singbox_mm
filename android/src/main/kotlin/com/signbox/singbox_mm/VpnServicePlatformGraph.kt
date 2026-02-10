package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import io.nekohasekai.libbox.Notification as CoreNotification

internal class VpnServicePlatformGraph(
    private val service: SignboxLibboxVpnService,
    private val connectivity: ConnectivityManager,
    private val mainHandler: Handler,
    private val runtimeSession: VpnCoreRuntimeSession,
    private val resolvePrivateDnsHost: () -> String?,
) {
    val defaultInterfaceMonitorController by lazy {
        VpnDefaultInterfaceMonitorController(
            connectivity = connectivity,
            mainHandler = mainHandler,
            logTag = SignboxLibboxServiceContract.LOG_TAG,
            canSetUnderlyingNetworks = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP,
            applyUnderlyingNetworks = { networks ->
                service.setUnderlyingNetworks(networks)
            },
        )
    }

    val platformServiceBridge by lazy {
        VpnPlatformServiceBridge(
            connectivity = connectivity,
            packageManager = service.packageManager,
            defaultInterfaceMonitorController = defaultInterfaceMonitorController,
        )
    }

    private val tunServiceAdapter by lazy {
        VpnTunServiceAdapter(
            createBuilder = { service.Builder() },
            resolvePrivateDnsHost = resolvePrivateDnsHost,
            privateDnsBootstrapDnsServer = SignboxLibboxServiceContract.PRIVATE_DNS_BOOTSTRAP_DNS_SERVER,
            hostPackageName = service.packageName,
            logTag = SignboxLibboxServiceContract.LOG_TAG,
            readPreviousTunFileDescriptor = { runtimeSession.tunFileDescriptor },
            persistTunFileDescriptor = { tunFileDescriptor ->
                runtimeSession.tunFileDescriptor = tunFileDescriptor
            },
        )
    }

    private val tunControlBridge by lazy {
        VpnTunControlBridge(
            hasVpnPermission = { VpnService.prepare(service) == null },
            protectFd = { fd -> service.protect(fd) },
            tunServiceAdapter = tunServiceAdapter,
        )
    }

    fun createPlatformInterfaceBridge(
        sendCoreNotification: (CoreNotification) -> Unit,
        writeCoreLog: (String) -> Unit,
    ): VpnCorePlatformInterfaceBridge {
        return VpnCorePlatformInterfaceBridge(
            tunControlBridge = tunControlBridge,
            platformServiceBridge = platformServiceBridge,
            sendCoreNotification = sendCoreNotification,
            writeCoreLog = writeCoreLog,
        )
    }

    fun createCommandHandlerBridge(
        serviceReload: () -> Unit,
        postServiceClose: () -> Unit,
    ): VpnCoreCommandHandlerBridge {
        return VpnCoreCommandHandlerBridge(
            readSystemProxyStatus = { platformServiceBridge.getSystemProxyStatus() },
            applySystemProxyEnabled = { isEnabled ->
                platformServiceBridge.setSystemProxyEnabled(isEnabled)
            },
            serviceReload = serviceReload,
            postServiceClose = postServiceClose,
        )
    }
}
