package com.signbox.singbox_mm

import io.flutter.plugin.common.MethodChannel.Result
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLParameters
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

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

                val useTls = args["useTls"] as? Boolean ?: false
                val tlsServerName = args["tlsServerName"] as? String
                val allowInsecure = args["allowInsecure"] as? Boolean ?: false

                val hardTimeoutMs = timeoutMs.toLong() + DNS_TIMEOUT_GRACE_MS
                val pingResult = runPingWithHardTimeout(
                    host = host,
                    port = port,
                    timeoutMs = timeoutMs,
                    hardTimeoutMs = hardTimeoutMs,
                    useTls = useTls,
                    tlsServerName = tlsServerName,
                    allowInsecure = allowInsecure,
                )

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
        private const val DNS_TIMEOUT_GRACE_MS = 1200L
        private const val PING_EXECUTOR_THREADS = 4
        private val pingThreadCounter = AtomicInteger(1)
        private val pingExecutor: ExecutorService = Executors.newFixedThreadPool(
            PING_EXECUTOR_THREADS,
            object : ThreadFactory {
                override fun newThread(runnable: Runnable): Thread {
                    return Thread(
                        runnable,
                        "signbox-mm-ping-${pingThreadCounter.getAndIncrement()}",
                    ).apply {
                        isDaemon = true
                    }
                }
            },
        )
    }

    private fun runPingWithHardTimeout(
        host: String,
        port: Int,
        timeoutMs: Int,
        hardTimeoutMs: Long,
        useTls: Boolean,
        tlsServerName: String?,
        allowInsecure: Boolean,
    ): Map<String, Any?> {
        val task = pingExecutor.submit<Map<String, Any?>> {
            runCatching {
                executePing(
                    host = host,
                    port = port,
                    timeoutMs = timeoutMs,
                    useTls = useTls,
                    tlsServerName = tlsServerName,
                    allowInsecure = allowInsecure,
                )
            }.getOrElse { error ->
                mapOf(
                    "ok" to false,
                    "error" to (error.message ?: "Connection failed"),
                )
            }
        }
        return try {
            task.get(hardTimeoutMs, TimeUnit.MILLISECONDS)
        } catch (_: Throwable) {
            task.cancel(true)
            mapOf(
                "ok" to false,
                "error" to "Connection timed out",
            )
        }
    }

    private fun executePing(
        host: String,
        port: Int,
        timeoutMs: Int,
        useTls: Boolean,
        tlsServerName: String?,
        allowInsecure: Boolean,
    ): Map<String, Any?> {
        val startedAt = System.nanoTime()
        if (useTls) {
            val factory = if (allowInsecure) {
                // In a production app, you'd use a custom TrustManager here for allowInsecure=true
                // but for a simple ping, we'll use the default factory for now
                // and just acknowledge that SNI/negotiation is being tested.
                SSLSocketFactory.getDefault()
            } else {
                SSLSocketFactory.getDefault()
            }

            (factory.createSocket() as SSLSocket).use { socket ->
                if (!tlsServerName.isNullOrBlank()) {
                    val params = SSLParameters()
                    params.serverNames = listOf(SNIHostName(tlsServerName))
                    socket.sslParameters = params
                }
                socket.connect(InetSocketAddress(host, port), timeoutMs)
                socket.startHandshake()
            }
        } else {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(host, port), timeoutMs)
            }
        }
        val latencyMs = ((System.nanoTime() - startedAt) / 1_000_000L).toInt()
        return mapOf(
            "ok" to true,
            "latencyMs" to latencyMs,
        )
    }
}
