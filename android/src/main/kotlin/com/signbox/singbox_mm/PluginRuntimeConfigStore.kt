package com.signbox.singbox_mm

import android.content.Context
import java.io.File

internal class PluginRuntimeConfigStore(
    private val context: Context,
    private val defaultConfigFileName: String,
    private val defaultStatsEmitIntervalMs: Long,
) {
    private data class RuntimeConfig(
        val workingDirectory: File,
        val binaryPath: String,
        val logLevel: String,
        val verbose: Boolean,
        val statsEmitIntervalMs: Long,
    )

    @Volatile
    private var runtimeConfig: RuntimeConfig? = null

    @Volatile
    private var configFile: File? = null

    @Synchronized
    fun initialize(arguments: Map<String, Any?>) {
        val requestedWorkingDir = arguments["workingDirectory"] as? String
        val requestedBinaryPath = arguments["binaryPath"] as? String
        val logLevel = arguments["logLevel"] as? String ?: "info"
        val verbose = arguments["enableVerboseLogs"] as? Boolean ?: false
        val statsEmitIntervalMs =
            ((arguments["statsEmitIntervalMs"] as? Number)?.toLong()
                ?: defaultStatsEmitIntervalMs)
                .coerceIn(250L, 10_000L)

        val workingDirectory = if (!requestedWorkingDir.isNullOrBlank()) {
            File(requestedWorkingDir)
        } else {
            File(context.filesDir, "singbox")
        }

        if (!workingDirectory.exists() && !workingDirectory.mkdirs()) {
            throw IllegalStateException("Unable to create working directory")
        }

        val binaryPath = requestedBinaryPath ?: "libbox"
        runtimeConfig = RuntimeConfig(
            workingDirectory = workingDirectory,
            binaryPath = binaryPath,
            logLevel = logLevel,
            verbose = verbose,
            statsEmitIntervalMs = statsEmitIntervalMs,
        )
        configFile = File(workingDirectory, defaultConfigFileName)
    }

    @Synchronized
    private fun ensureRuntimeConfig(): RuntimeConfig {
        runtimeConfig?.let { return it }

        val workingDirectory = File(context.filesDir, "singbox")
        if (!workingDirectory.exists()) {
            workingDirectory.mkdirs()
        }

        val config = RuntimeConfig(
            workingDirectory = workingDirectory,
            binaryPath = "libbox",
            logLevel = "info",
            verbose = false,
            statsEmitIntervalMs = defaultStatsEmitIntervalMs,
        )

        runtimeConfig = config
        configFile = File(workingDirectory, defaultConfigFileName)
        return config
    }

    @Synchronized
    fun writeConfig(configContent: String) {
        val runtime = ensureRuntimeConfig()
        val file = configFile ?: File(runtime.workingDirectory, defaultConfigFileName)
        configFile = file
        file.writeText(configContent)
    }

    @Synchronized
    fun resolveConfigFile(): File {
        val runtime = ensureRuntimeConfig()
        val file = configFile ?: File(runtime.workingDirectory, defaultConfigFileName)
        configFile = file
        return file
    }

    @Synchronized
    fun currentStatsEmitIntervalMs(): Long {
        return runtimeConfig?.statsEmitIntervalMs ?: defaultStatsEmitIntervalMs
    }
}
