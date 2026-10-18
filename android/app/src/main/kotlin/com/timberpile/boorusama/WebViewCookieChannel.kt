package com.timberpile.boorusama

import android.net.Uri
import android.webkit.CookieManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the cookies the Android WebView would send to a URL.
 *
 * CookieManager only exposes them as a Cookie request header, so each cookie
 * is restricted to this request's host/path and transport. Unknown HttpOnly
 * attributes are treated as restricted rather than silently relaxed.
 */
class WebViewCookieChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url: String? = call.argument("url")
                    val uri = url?.let { Uri.parse(it) }
                    val host = uri?.host
                    val isHttp = uri?.scheme.equals("http", ignoreCase = true) ||
                        uri?.scheme.equals("https", ignoreCase = true)
                    if (url == null || host.isNullOrEmpty() || !isHttp) {
                        result.error("INVALID_ARGUMENTS", "Invalid arguments for getCookies", null)
                    } else {
                        result.success(cookies(url, host))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cookies(url: String, host: String): List<Map<String, Any>> {
        val uri = Uri.parse(url)
        val header = CookieManager.getInstance().getCookie(url) ?: return emptyList()
        return header.split(";").mapNotNull { part ->
            val separator = part.indexOf('=')
            if (separator <= 0) return@mapNotNull null
            mapOf(
                "name" to part.substring(0, separator).trim(),
                "value" to part.substring(separator + 1).trim(),
                "domain" to host,
                "path" to (uri.path?.takeIf { it.isNotEmpty() } ?: "/"),
                "secure" to uri.scheme.equals("https", ignoreCase = true),
                "httpOnly" to true,
            )
        }
    }

    companion object {
        private const val CHANNEL_NAME = "webview_cookies"
    }
}
