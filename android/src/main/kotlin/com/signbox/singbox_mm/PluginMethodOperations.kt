package com.signbox.singbox_mm

import io.flutter.plugin.common.MethodChannel.Result
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ExecutorService

internal class PluginMethodOperations(
    private val executor: ExecutorService,
    private val postSuccess: (Result, Any?) -> Unit,
    private val postError: (Result, String, String) -> Unit,
    private val updateConnectionState: (String, String?) -> Unit,
    private val errorState: String,
    private val startVpnInternal: () -> String?,
    private val stopVpnInternal: () -> String?,
    private val versionProvider: () -> String?,
) {
    fun startVpn(result: Result) {
        executor.execute {
            val failure = startVpnInternal()
            if (failure == null) {
                postSuccess(result, null)
            } else {
                updateConnectionState(errorState, failure)
                postError(result, "START_FAILED", failure)
            }
        }
    }

    fun stopVpn(result: Result) {
        executor.execute {
            val failure = stopVpnInternal()
            if (failure == null) {
                postSuccess(result, null)
            } else {
                updateConnectionState(errorState, failure)
                postError(result, "STOP_FAILED", failure)
            }
        }
    }

    fun restartVpn(result: Result) {
        executor.execute {
            val stopFailure = stopVpnInternal()
            if (stopFailure != null) {
                updateConnectionState(errorState, stopFailure)
                postError(result, "STOP_FAILED", stopFailure)
                return@execute
            }

            val startFailure = startVpnInternal()
            if (startFailure != null) {
                updateConnectionState(errorState, startFailure)
                postError(result, "START_FAILED", startFailure)
                return@execute
            }

            postSuccess(result, null)
        }
    }

    fun getSingboxVersion(result: Result) {
        executor.execute {
            val version = runCatching {
                versionProvider()
            }.getOrNull()
            postSuccess(result, version)
        }
    }

    fun pingServer(arguments: Any?, result: Result) {
        executor.execute {
            try {
                @Suppress("UNCHECKED_CAST")
                val args = arguments as? Map<String, Any?> ?: emptyMap()
                val host = args["host"] as? String
                val port = (args["port"] as? Number)?.toInt()
                val timeoutMs = ((args["timeoutMs"] as? Number)?.toInt() ?: DEFAULT_TIMEOUT_MS)
                    .coerceAtLeast(1)
                if (host.isNullOrBlank() || port == null || port <= 0) {
                    postSuccess(
                        result,
                        mapOf(
                            "ok" to false,
                            "error" to "Invalid host or port",
                        ),
                    )
                    return@execute
                }

                val startedAt = System.nanoTime()
                val pingResult = runCatching {
                    Socket().use { socket ->
                        socket.connect(InetSocketAddress(host, port), timeoutMs)
                    }
                    val latencyMs = ((System.nanoTime() - startedAt) / 1_000_000L).toInt()
                    mapOf(
                        "ok" to true,
                        "latencyMs" to latencyMs,
                    )
                }.getOrElse { error ->
                    mapOf(
                        "ok" to false,
                        "error" to (error.message ?: "Connection failed"),
                    )
                }

                postSuccess(result, pingResult)
            } catch (error: Throwable) {
                postSuccess(
                    result,
                    mapOf(
                        "ok" to false,
                        "error" to (error.message ?: "Ping failed"),
                    ),
                )
            }
        }
    }

    companion object {
        private const val DEFAULT_TIMEOUT_MS = 3000
    }
}
