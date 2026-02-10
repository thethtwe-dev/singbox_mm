package com.signbox.singbox_mm

import io.nekohasekai.libbox.StringIterator
import java.security.KeyStore
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

internal object VpnSystemCertificateProvider {
    @OptIn(ExperimentalEncodingApi::class)
    fun readAsIterator(): StringIterator {
        val certificates = mutableListOf<String>()
        runCatching {
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null, null)
            val aliases = keyStore.aliases()
            while (aliases.hasMoreElements()) {
                val cert = keyStore.getCertificate(aliases.nextElement())
                certificates.add(
                    "-----BEGIN CERTIFICATE-----\n" +
                        Base64.encode(cert.encoded) +
                        "\n-----END CERTIFICATE-----",
                )
            }
        }
        return CertificateStringIterator(certificates)
    }

    private class CertificateStringIterator(private val values: List<String>) : StringIterator {
        private var index = 0

        override fun hasNext(): Boolean {
            return index < values.size
        }

        override fun len(): Int {
            return values.size
        }

        override fun next(): String {
            val current = values[index]
            index++
            return current
        }
    }
}
