package com.signbox.singbox_mm

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

internal object VpnGeoRuleSanitizer {
    private val geoTokenPattern = Regex("""(?i)\b(?:geoip|geosite)(?::|$)""")

    fun apply(
        rawConfigContent: String,
        logTag: String,
    ): String {
        val root = runCatching {
            JSONObject(rawConfigContent)
        }.getOrElse {
            return rawConfigContent
        }

        var removedCount = 0
        removedCount += sanitizeRuleArray(root.optJSONObject("route"), "rules")
        removedCount += sanitizeRuleArray(root.optJSONObject("dns"), "rules")

        if (removedCount > 0) {
            Log.w(logTag, "Removed $removedCount geo-based rule(s); using pure suffix/cidr routing.")
        }

        return root.toString()
    }

    private fun sanitizeRuleArray(
        parent: JSONObject?,
        rulesKey: String,
    ): Int {
        if (parent == null) {
            return 0
        }
        val rules = parent.optJSONArray(rulesKey) ?: return 0

        val sanitized = JSONArray()
        var removedCount = 0
        for (index in 0 until rules.length()) {
            val candidate = rules.opt(index)
            if (candidate is JSONObject && containsGeoReference(candidate)) {
                removedCount++
                continue
            }
            sanitized.put(candidate)
        }

        if (removedCount > 0) {
            parent.put(rulesKey, sanitized)
        }
        return removedCount
    }

    private fun containsGeoReference(value: Any?): Boolean {
        return when (value) {
            null -> false
            is JSONObject -> containsGeoReferenceInObject(value)
            is JSONArray -> containsGeoReferenceInArray(value)
            is String -> geoTokenPattern.containsMatchIn(value)
            else -> false
        }
    }

    private fun containsGeoReferenceInObject(jsonObject: JSONObject): Boolean {
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            if (geoTokenPattern.containsMatchIn(key)) {
                return true
            }
            if (containsGeoReference(jsonObject.opt(key))) {
                return true
            }
        }
        return false
    }

    private fun containsGeoReferenceInArray(jsonArray: JSONArray): Boolean {
        for (index in 0 until jsonArray.length()) {
            if (containsGeoReference(jsonArray.opt(index))) {
                return true
            }
        }
        return false
    }
}
