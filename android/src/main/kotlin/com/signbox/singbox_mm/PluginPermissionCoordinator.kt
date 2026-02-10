package com.signbox.singbox_mm

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import io.flutter.plugin.common.MethodChannel.Result

internal class PluginPermissionCoordinator(
    private val context: Context,
    private val onVpnPermissionDenied: () -> Unit,
) {
    @Volatile
    private var activity: Activity? = null

    @Volatile
    private var pendingVpnPermissionResult: Result? = null

    @Volatile
    private var pendingNotificationPermissionResult: Result? = null

    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachActivity() {
        activity = null
    }

    fun requestVpnPermission(result: Result) {
        val intent = VpnService.prepare(context)
        if (intent == null) {
            result.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "NO_ACTIVITY",
                "An Activity is required to request VPN permission",
                null,
            )
            return
        }

        if (pendingVpnPermissionResult != null) {
            result.error("PERMISSION_PENDING", "VPN permission request is already in progress", null)
            return
        }

        pendingVpnPermissionResult = result
        currentActivity.startActivityForResult(intent, REQUEST_VPN_PERMISSION)
    }

    fun requestNotificationPermission(result: Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "NO_ACTIVITY",
                "An Activity is required to request notification permission",
                null,
            )
            return
        }

        if (pendingNotificationPermissionResult != null) {
            result.error(
                "PERMISSION_PENDING",
                "Notification permission request is already in progress",
                null,
            )
            return
        }

        pendingNotificationPermissionResult = result
        currentActivity.requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION,
        )
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_VPN_PERMISSION) {
            return false
        }

        val granted = resultCode == Activity.RESULT_OK || VpnService.prepare(context) == null
        pendingVpnPermissionResult?.success(granted)
        pendingVpnPermissionResult = null

        if (!granted) {
            onVpnPermissionDenied()
        }

        return true
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) {
            return false
        }

        val granted =
            grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingNotificationPermissionResult?.success(granted)
        pendingNotificationPermissionResult = null
        return true
    }

    companion object {
        private const val REQUEST_VPN_PERMISSION = 0x7B0
        private const val REQUEST_NOTIFICATION_PERMISSION = 0x7B1
    }
}
