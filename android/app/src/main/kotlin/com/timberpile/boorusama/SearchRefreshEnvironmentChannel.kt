package com.timberpile.boorusama

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class SearchRefreshEnvironmentChannel(private val context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val method = MethodChannel(messenger, "boorusama/search_refresh_environment")
    private val events = EventChannel(messenger, "boorusama/search_refresh_environment/events")
    private var sink: EventChannel.EventSink? = null
    private val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    private val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
    private var receiverRegistered = false
    private var networkRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) = emit()
    }
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = emit()
        override fun onLost(network: Network) = emit()
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = emit()
    }

    init {
        method.setMethodCallHandler { call, result ->
            if (call.method == "snapshot") result.success(snapshot()) else result.notImplemented()
        }
        events.setStreamHandler(this)
    }

    private fun snapshot(): Map<String, Any> = try {
        buildMap {
            power?.let { put("batterySaver", it.isPowerSaveMode) }
            connectivity?.let { manager ->
                val network = manager.activeNetwork
                if (network == null) {
                    put("transport", "none")
                } else {
                    manager.getNetworkCapabilities(network)?.let { capabilities ->
                        val transports = listOfNotNull(
                            "wifi".takeIf { capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) },
                            "ethernet".takeIf { capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) },
                            "mobile".takeIf { capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) }
                        )
                        put("transport", transports.singleOrNull() ?: "unknown")
                        put("metered", !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED))
                    }
                }
            }
        }
    } catch (_: SecurityException) { emptyMap() }

    private fun emit() {
        val value = snapshot()
        Handler(Looper.getMainLooper()).post { sink?.success(value) }
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        if (!receiverRegistered) {
            try {
                val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
                if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                else context.registerReceiver(receiver, filter)
                receiverRegistered = true
                connectivity?.registerDefaultNetworkCallback(callback)
                networkRegistered = connectivity != null
            } catch (_: SecurityException) {
                eventSink.success(emptyMap<String, Boolean>())
                return
            }
        }
        emit()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        if (receiverRegistered) {
            context.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        if (networkRegistered) {
            connectivity?.unregisterNetworkCallback(callback)
            networkRegistered = false
        }
    }

    fun close() {
        onCancel(null)
        method.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
