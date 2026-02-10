package com.signbox.singbox_mm

import android.content.pm.PackageManager
import android.net.VpnService
import android.util.Log

internal object VpnPackageAccessController {
    fun addAllowedPackage(
        builder: VpnService.Builder,
        packageName: String,
        hostPackageName: String,
        logTag: String,
    ) {
        if (packageName == hostPackageName) {
            return
        }
        runCatching {
            builder.addAllowedApplication(packageName)
        }.onFailure {
            if (it !is PackageManager.NameNotFoundException) {
                Log.w(logTag, "Unable to add allowed package '$packageName'", it)
            }
        }
    }

    fun addDisallowedPackage(
        builder: VpnService.Builder,
        packageName: String,
        logTag: String,
    ) {
        runCatching {
            builder.addDisallowedApplication(packageName)
        }.onFailure {
            if (it !is PackageManager.NameNotFoundException) {
                Log.w(logTag, "Unable to add disallowed package '$packageName'", it)
            }
        }
    }
}
