package com.signbox.singbox_mm

import android.util.Log
import java.net.Inet6Address
import java.net.InetAddress
import org.json.JSONArray
import org.json.JSONObject

internal object VpnPrivateDnsCompatibilityPatcher {
    private const val PRIVATE_DNS_BOOTSTRAP_TAG = "dns-private-bootstrap"
    private const val PRIVATE_DNS_BOOTSTRAP_ADDRESS = "1.1.1.1"
    private const val DNS_OUTBOUND_TAG = "dns-out"
    private const val DIRECT_OUTBOUND_TAG = "direct"
    private const val SYNTHETIC_DNS_GATEWAY_V4 = "172.19.0.2/32"
    private const val SYNTHETIC_DNS_GATEWAY_V6 = "fdfe:dcba:9876::2/128"

    fun apply(
        rawConfigContent: String,
        privateDnsHost: String,
        logTag: String,
    ): String {
        return runCatching {
            val root = JSONObject(rawConfigContent)

            val dns = root.optJSONObject("dns") ?: JSONObject().also {
                root.put("dns", it)
            }
            val dnsServers = dns.optJSONArray("servers") ?: JSONArray().also {
                dns.put("servers", it)
            }
            if (!containsDnsServerTag(dnsServers, PRIVATE_DNS_BOOTSTRAP_TAG)) {
                dnsServers.put(
                    JSONObject()
                        .put("tag", PRIVATE_DNS_BOOTSTRAP_TAG)
                        .put("address", PRIVATE_DNS_BOOTSTRAP_ADDRESS)
                        .put("detour", DIRECT_OUTBOUND_TAG)
                        .put("strategy", "prefer_ipv4"),
                )
            }
            val dnsRules = dns.optJSONArray("rules") ?: JSONArray().also {
                dns.put("rules", it)
            }
            if (!containsDnsRuleForHost(dnsRules, privateDnsHost)) {
                prependObject(
                    dnsRules,
                    JSONObject()
                        .put("domain_suffix", JSONArray().put(privateDnsHost))
                        .put("server", PRIVATE_DNS_BOOTSTRAP_TAG),
                )
            }

            val route = root.optJSONObject("route") ?: JSONObject().also {
                root.put("route", it)
            }
            val routeRules = route.optJSONArray("rules") ?: JSONArray().also {
                route.put("rules", it)
            }
            removeGlobalDnsOutRule(routeRules, 853, "tcp")
            if (!containsGlobalDnsOutRule(routeRules, 53, "udp")) {
                routeRules.put(
                    JSONObject()
                        .put("port", 53)
                        .put("network", "udp")
                        .put("outbound", DNS_OUTBOUND_TAG),
                )
            }
            if (!containsGlobalDnsOutRule(routeRules, 53, "tcp")) {
                routeRules.put(
                    JSONObject()
                        .put("port", 53)
                        .put("network", "tcp")
                        .put("outbound", DNS_OUTBOUND_TAG),
                )
            }
            if (!containsDnsOutSyntheticGatewayRule(routeRules, 53)) {
                routeRules.put(
                    JSONObject()
                        .put("ip_cidr", JSONArray().put(SYNTHETIC_DNS_GATEWAY_V4).put(SYNTHETIC_DNS_GATEWAY_V6))
                        .put("port", 53)
                        .put("outbound", DNS_OUTBOUND_TAG),
                )
            }
            if (!containsDnsOutSyntheticGatewayRule(routeRules, 853)) {
                routeRules.put(
                    JSONObject()
                        .put("ip_cidr", JSONArray().put(SYNTHETIC_DNS_GATEWAY_V4).put(SYNTHETIC_DNS_GATEWAY_V6))
                        .put("port", 853)
                        .put("outbound", DNS_OUTBOUND_TAG),
                )
            }
            if (!containsDirectRouteRuleForHost(routeRules, privateDnsHost)) {
                prependObject(
                    routeRules,
                    JSONObject()
                        .put("domain_suffix", JSONArray().put(privateDnsHost))
                        .put("port", 853)
                        .put("network", "tcp")
                        .put("outbound", DIRECT_OUTBOUND_TAG),
                )
            }
            val privateDnsCidrs = resolveHostCidrs(privateDnsHost)
            for (cidr in privateDnsCidrs) {
                if (containsDirectRouteRuleForIp(routeRules, cidr, 853)) {
                    continue
                }
                prependObject(
                    routeRules,
                    JSONObject()
                        .put("ip_cidr", JSONArray().put(cidr))
                        .put("port", 853)
                        .put("network", "tcp")
                        .put("outbound", DIRECT_OUTBOUND_TAG),
                )
            }

            Log.i(
                logTag,
                "Applied strict Private DNS compatibility for host=$privateDnsHost " +
                    "(resolvedAddresses=${privateDnsCidrs.size})",
            )
            root.toString()
        }.getOrElse { error ->
            Log.w(
                logTag,
                "Unable to patch config for strict Private DNS host=$privateDnsHost",
                error,
            )
            rawConfigContent
        }
    }

    private fun containsDnsServerTag(servers: JSONArray, tag: String): Boolean {
        for (index in 0 until servers.length()) {
            val item = servers.optJSONObject(index) ?: continue
            if (item.optString("tag").equals(tag, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun containsDnsRuleForHost(rules: JSONArray, host: String): Boolean {
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index) ?: continue
            if (jsonArrayContainsHost(item.optJSONArray("domain"), host)) {
                return true
            }
            if (jsonArrayContainsHost(item.optJSONArray("domain_suffix"), host)) {
                return true
            }
        }
        return false
    }

    private fun containsDnsOutSyntheticGatewayRule(rules: JSONArray, port: Int): Boolean {
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index) ?: continue
            if (!item.optString("outbound").equals(DNS_OUTBOUND_TAG, ignoreCase = true)) {
                continue
            }
            if (item.optInt("port", -1) != port) {
                continue
            }
            val cidr = item.optJSONArray("ip_cidr")
            if (cidr != null && jsonArrayContainsHost(cidr, SYNTHETIC_DNS_GATEWAY_V4)) {
                return true
            }
        }
        return false
    }

    private fun containsGlobalDnsOutRule(
        rules: JSONArray,
        port: Int,
        network: String,
    ): Boolean {
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index) ?: continue
            if (!item.optString("outbound").equals(DNS_OUTBOUND_TAG, ignoreCase = true)) {
                continue
            }
            if (item.optInt("port", -1) != port) {
                continue
            }
            val configuredNetwork = item.optString("network").trim().lowercase()
            if (configuredNetwork.isNotBlank() && configuredNetwork != network) {
                continue
            }
            val cidr = item.optJSONArray("ip_cidr")
            if (cidr == null || cidr.length() == 0) {
                return true
            }
        }
        return false
    }

    private fun removeGlobalDnsOutRule(
        rules: JSONArray,
        port: Int,
        network: String,
    ) {
        val retained = ArrayList<Any?>(rules.length())
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index)
            if (item == null) {
                retained.add(rules.opt(index))
                continue
            }

            if (!item.optString("outbound").equals(DNS_OUTBOUND_TAG, ignoreCase = true)) {
                retained.add(item)
                continue
            }
            if (item.optInt("port", -1) != port) {
                retained.add(item)
                continue
            }
            val configuredNetwork = item.optString("network").trim().lowercase()
            if (configuredNetwork.isNotBlank() && configuredNetwork != network) {
                retained.add(item)
                continue
            }
            val cidr = item.optJSONArray("ip_cidr")
            if (cidr != null && cidr.length() > 0) {
                retained.add(item)
            }
        }

        while (rules.length() > 0) {
            rules.remove(0)
        }
        for (item in retained) {
            rules.put(item)
        }
    }

    private fun containsDirectRouteRuleForHost(rules: JSONArray, host: String): Boolean {
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index) ?: continue
            if (!item.optString("outbound").equals(DIRECT_OUTBOUND_TAG, ignoreCase = true)) {
                continue
            }
            if (jsonArrayContainsHost(item.optJSONArray("domain"), host)) {
                return true
            }
            if (jsonArrayContainsHost(item.optJSONArray("domain_suffix"), host)) {
                return true
            }
        }
        return false
    }

    private fun containsDirectRouteRuleForIp(
        rules: JSONArray,
        cidr: String,
        port: Int,
    ): Boolean {
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index) ?: continue
            if (!item.optString("outbound").equals(DIRECT_OUTBOUND_TAG, ignoreCase = true)) {
                continue
            }
            if (item.optInt("port", -1) != port) {
                continue
            }
            if (jsonArrayContainsHost(item.optJSONArray("ip_cidr"), cidr)) {
                return true
            }
        }
        return false
    }

    private fun resolveHostCidrs(host: String): List<String> {
        return runCatching {
            InetAddress.getAllByName(host)
                .mapNotNull { address ->
                    val hostAddress = address.hostAddress ?: return@mapNotNull null
                    val normalized = normalizeIp(hostAddress)
                    if (address is Inet6Address) {
                        "$normalized/128"
                    } else {
                        "$normalized/32"
                    }
                }
                .distinct()
        }.getOrElse { emptyList() }
    }

    private fun normalizeIp(value: String): String {
        val zoneSeparator = value.indexOf('%')
        if (zoneSeparator > 0) {
            return value.substring(0, zoneSeparator)
        }
        return value
    }

    private fun jsonArrayContainsHost(values: JSONArray?, host: String): Boolean {
        if (values == null) {
            return false
        }
        for (index in 0 until values.length()) {
            val value = values.optString(index)
            if (value.equals(host, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun prependObject(
        array: JSONArray,
        value: JSONObject,
    ) {
        val snapshot = ArrayList<Any?>(array.length())
        for (index in 0 until array.length()) {
            snapshot.add(array.opt(index))
        }
        array.put(0, value)
        for (index in snapshot.indices) {
            array.put(index + 1, snapshot[index])
        }
    }
}
