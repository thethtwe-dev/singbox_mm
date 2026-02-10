package com.signbox.singbox_mm

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build

internal class PluginNetworkDiagnosticsTracker(
    private val connectivityProvider: () -> ConnectivityManager,
    private val networkValidationGraceMs: Long,
    private val nowMillisProvider: () -> Long = { System.currentTimeMillis() },
) {
    data class Snapshot(
        val networkValidated: Boolean?,
        val hasInternetCapability: Boolean?,
        val privateDnsActive: Boolean?,
        val privateDnsServerName: String?,
        val activeInterface: String?,
        val underlyingTransports: List<String>,
        val detailCode: String?,
        val detailMessage: String?,
    )

    @Volatile
    private var networkValidated: Boolean? = null

    @Volatile
    private var hasInternetCapability: Boolean? = null

    @Volatile
    private var privateDnsActive: Boolean? = null

    @Volatile
    private var privateDnsServerName: String? = null

    @Volatile
    private var activeInterface: String? = null

    @Volatile
    private var underlyingTransports: List<String> = emptyList()

    @Volatile
    private var validationGraceActive: Boolean = false

    @Volatile
    private var validationGraceDeadlineMillis: Long = 0L

    @Volatile
    private var handoverSignalDeadlineMillis: Long = 0L

    @Volatile
    private var lastUnderlyingTransportSignature: String? = null

    @Volatile
    private var detailCode: String? = null

    @Volatile
    private var detailMessage: String? = null

    @Synchronized
    fun snapshot(): Snapshot {
        return Snapshot(
            networkValidated = networkValidated,
            hasInternetCapability = hasInternetCapability,
            privateDnsActive = privateDnsActive,
            privateDnsServerName = privateDnsServerName,
            activeInterface = activeInterface,
            underlyingTransports = underlyingTransports,
            detailCode = detailCode,
            detailMessage = detailMessage,
        )
    }

    @Synchronized
    fun clear() {
        networkValidated = null
        hasInternetCapability = null
        privateDnsActive = null
        privateDnsServerName = null
        activeInterface = null
        underlyingTransports = emptyList()
        validationGraceActive = false
        validationGraceDeadlineMillis = 0L
        handoverSignalDeadlineMillis = 0L
        lastUnderlyingTransportSignature = null
    }

    @Synchronized
    fun refreshFromSystem(): Boolean {
        val connectivity = connectivityProvider()
        val networks = runCatching { connectivity.allNetworks }.getOrDefault(emptyArray())

        data class Candidate(
            val network: Network,
            val score: Int,
        )

        var best: Candidate? = null
        for (network in networks) {
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                continue
            }

            val linkProperties = connectivity.getLinkProperties(network)
            var score = 0

            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
                score += 4
            }
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                score += 2
            }
            if (linkProperties?.interfaceName?.startsWith("tun") == true) {
                score += 1
            }

            if (best == null || score > best.score) {
                best = Candidate(network = network, score = score)
            }
        }

        val selected = best?.network ?: return false
        refreshForNetwork(connectivity = connectivity, network = selected)
        return true
    }

    @Synchronized
    fun refreshDerivedStateDetail(
        connectionState: String,
        lastError: String?,
        connectedState: String,
        errorState: String,
    ) {
        if (connectionState == errorState && !lastError.isNullOrBlank()) {
            detailCode = "ERROR"
            detailMessage = lastError
            return
        }
        if (connectionState != connectedState) {
            detailCode = null
            detailMessage = null
            return
        }
        if (validationGraceActive) {
            detailCode = "NETWORK_HANDOVER"
            detailMessage =
                "Upstream network transition detected; preserving validation during grace period."
            return
        }
        val now = nowMillisProvider()
        if (now <= handoverSignalDeadlineMillis) {
            detailCode = "NETWORK_HANDOVER"
            detailMessage = "Upstream network transition detected."
            return
        }
        if (hasInternetCapability == false) {
            detailCode = "NO_INTERNET_CAPABILITY"
            detailMessage = "VPN network lacks NET_CAPABILITY_INTERNET."
            return
        }
        if (networkValidated == false) {
            val privateDnsName = privateDnsServerName
            if (privateDnsActive == true && !privateDnsName.isNullOrBlank()) {
                detailCode = "PRIVATE_DNS_BROKEN"
                detailMessage =
                    "VPN network is unvalidated while strict Private DNS is active ($privateDnsName)."
            } else {
                detailCode = "NETWORK_UNVALIDATED"
                detailMessage = "VPN network is connected but not validated by Android."
            }
            return
        }
        detailCode = "OK"
        detailMessage = "VPN network validated."
    }

    private fun refreshForNetwork(
        connectivity: ConnectivityManager,
        network: Network,
    ) {
        val capabilities = connectivity.getNetworkCapabilities(network)
        val linkProperties = connectivity.getLinkProperties(network)
        val now = nowMillisProvider()
        val rawValidated = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        val hasInternet = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

        hasInternetCapability = hasInternet
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            privateDnsActive = linkProperties?.isPrivateDnsActive
            privateDnsServerName = linkProperties?.privateDnsServerName
        } else {
            privateDnsActive = null
            privateDnsServerName = null
        }
        activeInterface = linkProperties?.interfaceName
        underlyingTransports = resolveUnderlyingTransportLabels(connectivity)
        val currentSignature = underlyingTransports.joinToString(",")
        if (
            !lastUnderlyingTransportSignature.isNullOrBlank() &&
                currentSignature != lastUnderlyingTransportSignature
        ) {
            validationGraceDeadlineMillis = now + networkValidationGraceMs
            handoverSignalDeadlineMillis = now + networkValidationGraceMs
        }
        lastUnderlyingTransportSignature = currentSignature

        when (rawValidated) {
            true -> {
                networkValidated = true
                validationGraceActive = false
                validationGraceDeadlineMillis = now + networkValidationGraceMs
            }

            false -> {
                val withinGrace = hasInternet == true && now <= validationGraceDeadlineMillis
                validationGraceActive = withinGrace
                networkValidated = if (withinGrace) true else false
            }

            null -> {
                networkValidated = null
                validationGraceActive = false
            }
        }
    }

    private fun resolveUnderlyingTransportLabels(
        connectivity: ConnectivityManager,
    ): List<String> {
        val labels = linkedSetOf<String>()
        val networks = runCatching { connectivity.allNetworks }.getOrDefault(emptyArray())
        for (network in networks) {
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                continue
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                continue
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                labels.add("wifi")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                labels.add("cellular")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                labels.add("ethernet")
            }
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) {
                labels.add("bluetooth")
            }
            if (labels.isEmpty()) {
                labels.add("other")
            }
        }
        return labels.toList()
    }
}
