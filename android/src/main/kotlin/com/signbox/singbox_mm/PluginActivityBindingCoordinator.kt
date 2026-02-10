package com.signbox.singbox_mm

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

internal class PluginActivityBindingCoordinator(
    private val permissionCoordinator: PluginPermissionCoordinator,
    private val activityResultListener: PluginRegistry.ActivityResultListener,
    private val requestPermissionsResultListener: PluginRegistry.RequestPermissionsResultListener,
) {
    @Volatile
    private var activityBinding: ActivityPluginBinding? = null

    fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
        permissionCoordinator.attachActivity(binding.activity)
        binding.addActivityResultListener(activityResultListener)
        binding.addRequestPermissionsResultListener(requestPermissionsResultListener)
    }

    fun detach() {
        val binding = activityBinding ?: return
        binding.removeActivityResultListener(activityResultListener)
        binding.removeRequestPermissionsResultListener(requestPermissionsResultListener)
        permissionCoordinator.detachActivity()
        activityBinding = null
    }
}
