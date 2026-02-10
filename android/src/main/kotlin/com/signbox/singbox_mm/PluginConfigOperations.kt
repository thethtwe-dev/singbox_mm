package com.signbox.singbox_mm

import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService

internal class PluginConfigOperations(
    private val executor: ExecutorService,
    private val runtimeConfigStore: PluginRuntimeConfigStore,
    private val postSuccess: (Result, Any?) -> Unit,
    private val postError: (Result, String, String) -> Unit,
) {
    fun initialize(arguments: Any?, result: Result) {
        executor.execute {
            try {
                @Suppress("UNCHECKED_CAST")
                val args = arguments as? Map<String, Any?> ?: emptyMap()
                runtimeConfigStore.initialize(args)
                postSuccess(result, null)
            } catch (error: Throwable) {
                postError(result, "INIT_FAILED", error.message ?: "Initialization failed")
            }
        }
    }

    fun setConfig(arguments: Any?, result: Result) {
        executor.execute {
            try {
                @Suppress("UNCHECKED_CAST")
                val args = arguments as? Map<String, Any?> ?: emptyMap()
                val config = args["config"] as? String
                if (config.isNullOrBlank()) {
                    postError(result, "INVALID_CONFIG", "Missing config payload")
                    return@execute
                }

                runtimeConfigStore.writeConfig(config)
                postSuccess(result, null)
            } catch (error: Throwable) {
                postError(result, "CONFIG_WRITE_FAILED", error.message ?: "Could not write config")
            }
        }
    }
}
