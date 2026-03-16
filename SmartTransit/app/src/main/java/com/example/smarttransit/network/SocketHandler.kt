package com.example.smarttransit.network

import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import okhttp3.OkHttpClient
import io.socket.client.IO
import io.socket.client.Socket
import java.net.URISyntaxException
import java.util.UUID

object SocketHandler {
    private const val TAG = "SocketHandler"
    
    var currentSocket by mutableStateOf<Socket?>(null)
        private set
    var isConnected by mutableStateOf(false)
        private set
        
    private var mCurrentUrl: String? = null
    private const val PREFS_NAME = "socket_prefs"
    private const val KEY_URL = "server_url"
    private const val KEY_DEVICE_ID = "device_id"
    
    // Default URL - public tunnel so real/remote devices work out-of-box.
    // Emulator can still use this, or you can switch to http://10.0.2.2:3000 in settings.
    private const val DEFAULT_URL = "http://192.168.0.182:3000"

    private val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            // Engine.IO long-poll requests can legitimately stay open for a long time.
            // A short OkHttp read timeout causes disconnect/reconnect loops.
            .readTimeout(0, java.util.concurrent.TimeUnit.SECONDS)
            .writeTimeout(0, java.util.concurrent.TimeUnit.SECONDS)
            .addInterceptor { chain ->
                val request = chain.request().newBuilder()
                    .header("Bypass-Tunnel-Reminder", "true")
                    .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                    .header("Connection", "keep-alive")
                    .build()
                chain.proceed(request)
            }
            .build()
    }

    @Synchronized
    fun init(context: Context, url: String? = null) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedUrl = prefs.getString(KEY_URL, DEFAULT_URL) ?: DEFAULT_URL
        val targetUrl = (url ?: savedUrl).trim()
        
        initWithUrl(context, targetUrl)
    }

    private fun initWithUrl(context: Context, targetUrl: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val deviceId = prefs.getString(KEY_DEVICE_ID, null) ?: UUID.randomUUID().toString().take(8).also {
            prefs.edit().putString(KEY_DEVICE_ID, it).apply()
        }

        // Don't re-init if same URL and already connected
        if (currentSocket != null && mCurrentUrl == targetUrl && currentSocket?.connected() == true) {
            return
        }

        prefs.edit().putString(KEY_URL, targetUrl).apply()
        mCurrentUrl = targetUrl
        isConnected = false

        Log.d(TAG, "Initializing socket [$deviceId] -> $targetUrl")
        
        currentSocket?.disconnect()
        currentSocket?.off()

        try {
            val options = IO.Options().apply {
                callFactory = okHttpClient
                webSocketFactory = okHttpClient
                // Keep query stable to avoid churn/reconnect loops through tunnels
                query = "deviceId=$deviceId"
                
                // Crucial for some reverse proxies/tunnels
                extraHeaders = mapOf("Bypass-Tunnel-Reminder" to listOf("true"))
                
                // Allow a single shared Manager per URL; forceNew can cause flapping
                forceNew = false
                multiplex = true
                reconnection = true
                reconnectionAttempts = Int.MAX_VALUE
                reconnectionDelay = 1000
                reconnectionDelayMax = 5000
                randomizationFactor = 0.3
                timeout = 60000

                // Localtunnel/reverse proxies can be flaky with WebSocket upgrades.
                // Polling-only is significantly more stable across networks.
                transports = arrayOf("polling")
                upgrade = false
            }

            val socket = IO.socket(targetUrl, options)
            
            socket.on(Socket.EVENT_CONNECT) { 
                Log.i(TAG, "===> CONNECTED to $targetUrl")
                isConnected = true 
            }
            socket.on(Socket.EVENT_DISCONNECT) { 
                Log.w(TAG, "===> DISCONNECTED")
                isConnected = false 
            }
            socket.on(Socket.EVENT_CONNECT_ERROR) { args ->
                val err = if (args.isNotEmpty()) args[0].toString() else "Unknown"
                Log.e(TAG, "===> CONNECT ERROR [$targetUrl]: $err")
                isConnected = false
            }

            socket.connect()
            currentSocket = socket

        } catch (e: Exception) {
            Log.e(TAG, "Socket Initialization Failed", e)
        }
    }

    fun getCurrentUrl(): String = mCurrentUrl ?: DEFAULT_URL

    fun establishConnection() {
        if (currentSocket?.connected() == false) {
            Log.d(TAG, "Explicitly connecting socket...")
            currentSocket?.connect()
        }
    }
}
