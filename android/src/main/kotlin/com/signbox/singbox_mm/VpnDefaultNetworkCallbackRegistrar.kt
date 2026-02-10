package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.util.Log

internal object VpnDefaultNetworkCallbackRegistrar {
    fun register(
        connectivity: ConnectivityManager,
        callback: ConnectivityManager.NetworkCallback,
        mainHandler: Handler,
        logTag: String,
    ): Boolean {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()

        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                connectivity.registerBestMatchingNetworkCallback(
                    request,
                    callback,
                    mainHandler,
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                connectivity.registerNetworkCallback(request, callback, mainHandler)
            } else {
                @Suppress("DEPRECATION")
                connectivity.registerNetworkCallback(request, callback)
            }
            true
        }.onFailure {
            Log.w(logTag, "Unable to register default network callback", it)
        }.getOrDefault(false)
    }

    fun unregister(
        connectivity: ConnectivityManager,
        callback: ConnectivityManager.NetworkCallback,
        logTag: String,
    ) {
        runCatching {
            connectivity.unregisterNetworkCallback(callback)
        }.onFailure {
            Log.w(logTag, "Unable to unregister default network callback", it)
        }
    }
}
