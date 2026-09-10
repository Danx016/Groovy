package com.groovy.music

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AudioServiceFragmentActivity() {
    private val CHANNEL = "com.groovy.music/ytdlp"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        setHighRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            setHighRefreshRate()
        }
    }

    /**
     * Intercepts KEYCODE_HEADSETHOOK sent by single-button wired headsets (cable inline button).
     * Android delivers headset button presses as HEADSETHOOK (keyCode 79), NOT as
     * KEYCODE_MEDIA_PLAY_PAUSE (85). audio_service's MediaSession only registers
     * MEDIA_PLAY_PAUSE, so HEADSETHOOK events are silently dropped and the button
     * appears to do nothing.
     *
     * Fix: Translate HEADSETHOOK → broadcast ACTION_MEDIA_BUTTON with
     * KEYCODE_MEDIA_PLAY_PAUSE so audio_service's MediaButtonReceiver processes it
     * through the same click() path (1 tap=play/pause, 2=skip, 3=previous).
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_HEADSETHOOK) {
            try {
                val mediaEvent = KeyEvent(
                    event?.downTime ?: System.currentTimeMillis(),
                    event?.eventTime ?: System.currentTimeMillis(),
                    KeyEvent.ACTION_DOWN,
                    KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                    0
                )
                val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    putExtra(Intent.EXTRA_KEY_EVENT, mediaEvent)
                    component = ComponentName(
                        packageName,
                        "com.ryanheise.audioservice.MediaButtonReceiver"
                    )
                }
                sendBroadcast(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_HEADSETHOOK) {
            // Consumed — we forwarded ACTION_DOWN above; nothing to do on up
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    private fun setHighRefreshRate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    this.display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val modes = currentDisplay?.supportedModes ?: emptyArray()
                val maxMode = modes.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    @Suppress("DEPRECATION")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            params.javaClass.getField("preferredMinDisplayRefreshRate").set(params, maxMode.refreshRate)
                            params.javaClass.getField("preferredMaxDisplayRefreshRate").set(params, maxMode.refreshRate)
                        } catch (_: Exception) {}
                    }
                    window.attributes = params
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            if (!Python.isStarted()) {
                Python.start(AndroidPlatform(this))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val py = Python.getInstance()
                    val helper = py.getModule("ytdlp_helper")
                    when (call.method) {
                        "getStreamUrl" -> {
                            val videoId = call.argument<String>("videoId") ?: ""
                            val url = helper.callAttr("get_stream_url", videoId).toString()
                            withContext(Dispatchers.Main) { result.success(url) }
                        }
                        "search" -> {
                            val query = call.argument<String>("query") ?: ""
                            val limit = call.argument<Int>("limit") ?: 25
                            val json = helper.callAttr("search", query, limit).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "searchDual" -> {
                            val query = call.argument<String>("query") ?: ""
                            val limit = call.argument<Int>("limit") ?: 20
                            val json = helper.callAttr("search_dual", query, limit).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "getVideoInfo" -> {
                            val videoId = call.argument<String>("videoId") ?: ""
                            val json = helper.callAttr("get_video_info", videoId).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "getPlaylist" -> {
                            val playlistId = call.argument<String>("playlistId") ?: ""
                            val limit = call.argument<Int>("limit") ?: 100
                            val json = helper.callAttr("get_playlist", playlistId, limit).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "isAvailable" -> {
                            withContext(Dispatchers.Main) { result.success(true) }
                        }
                        else -> {
                            withContext(Dispatchers.Main) { result.notImplemented() }
                        }
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        result.error("YTDLP_ERROR", e.message, e.stackTraceToString())
                    }
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.groovy.music/app_updater").setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = java.io.File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }
                        // Ensure unknown sources permission is granted on Android 8.0+
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (!packageManager.canRequestPackageInstalls()) {
                                val manageIntent = android.content.Intent(
                                    android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    android.net.Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(manageIntent)
                                result.error(
                                    "NEED_PERMISSION",
                                    "Activa el permiso para instalar aplicaciones desde Groovy y pulsa Actualizar de nuevo.",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                        }

                        val apkUri = androidx.core.content.FileProvider.getUriForFile(
                            this@MainActivity,
                            "${applicationContext.packageName}.fileProvider",
                            file
                        )
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, e.stackTraceToString())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
