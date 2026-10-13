package com.groovy.music

import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import android.view.Surface
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

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

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
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
                    // 1. Force the high-refresh modeId
                    params.preferredDisplayModeId = maxMode.modeId
                    // 2. Set official public preferredRefreshRate (API 23+)
                    params.preferredRefreshRate = maxMode.refreshRate
                    window.attributes = params

                    // 3. Android 11+ (API 30+) View/Surface frame rate:
                    // Prevents SurfaceFlinger and OEM power managers (Transsion XOS, MIUI, OneUI)
                    // from throttling back to 60Hz during idle or animations
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        window.decorView.post {
                            try {
                                val setFrameRateMethod = window.decorView.javaClass.methods.firstOrNull {
                                    it.name == "setFrameRate" && it.parameterTypes.size >= 2
                                }
                                if (setFrameRateMethod != null) {
                                    if (setFrameRateMethod.parameterTypes.size == 2) {
                                        setFrameRateMethod.invoke(window.decorView, maxMode.refreshRate, 0)
                                    } else if (setFrameRateMethod.parameterTypes.size == 3) {
                                        setFrameRateMethod.invoke(window.decorView, maxMode.refreshRate, 0, 0)
                                    }
                                }
                            } catch (_: Exception) {}
                        }
                    }
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
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val py = Python.getInstance()
                    val helper = py.getModule("ytdlp_helper")
                    helper.callAttr("warmup")
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.groovy.music/display").setMethodCallHandler { call, result ->
            when (call.method) {
                "setHighRefreshRate" -> {
                    runOnUiThread {
                        setHighRefreshRate()
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.groovy.music/downloads").setMethodCallHandler { call, result ->
            CoroutineScope(Dispatchers.IO).launch {
                when (call.method) {
                    "saveToPublicDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName") ?: "song.mp3"
                        val subfolder = call.argument<String>("subfolder") ?: "Groovy"
                        val title = call.argument<String>("title") ?: ""
                        val artist = call.argument<String>("artist") ?: ""
                        val album = call.argument<String>("album") ?: ""

                        if (sourcePath.isNullOrEmpty()) {
                            withContext(Dispatchers.Main) { result.error("INVALID_PATH", "Source path is empty", null) }
                            return@launch
                        }
                        val srcFile = File(sourcePath)
                        if (!srcFile.exists()) {
                            withContext(Dispatchers.Main) { result.error("NOT_FOUND", "Source file does not exist", null) }
                            return@launch
                        }

                        try {
                            var savedPath = ""
                            // 1. Try direct copy to Download/subfolder first
                            try {
                                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                                val targetDir = if (subfolder.isEmpty()) downloadsDir else File(downloadsDir, subfolder)
                                if (!targetDir.exists()) {
                                    targetDir.mkdirs()
                                }
                                val destFile = File(targetDir, fileName)
                                srcFile.copyTo(destFile, overwrite = true)
                                savedPath = destFile.absolutePath

                                MediaScannerConnection.scanFile(
                                    applicationContext,
                                    arrayOf(destFile.absolutePath),
                                    arrayOf("audio/mpeg"),
                                    null
                                )
                            } catch (_: Exception) {
                                savedPath = ""
                            }

                            // 2. If direct write didn't succeed, use MediaStore (Android 10+)
                            if (savedPath.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val relativePath = if (subfolder.isEmpty()) {
                                    Environment.DIRECTORY_DOWNLOADS + "/Groovy"
                                } else if (subfolder.startsWith(Environment.DIRECTORY_DOWNLOADS)) {
                                    subfolder
                                } else {
                                    Environment.DIRECTORY_DOWNLOADS + "/" + subfolder
                                }

                                val contentValues = ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                    put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                                    if (title.isNotEmpty()) put(MediaStore.Audio.Media.TITLE, title)
                                    if (artist.isNotEmpty()) put(MediaStore.Audio.Media.ARTIST, artist)
                                    if (album.isNotEmpty()) put(MediaStore.Audio.Media.ALBUM, album)
                                }

                                val resolver = applicationContext.contentResolver
                                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                                    ?: resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, contentValues)

                                if (uri != null) {
                                    resolver.openOutputStream(uri)?.use { out ->
                                        srcFile.inputStream().use { input ->
                                            input.copyTo(out)
                                        }
                                    }
                                    contentValues.clear()
                                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                    resolver.update(uri, contentValues, null, null)
                                    savedPath = uri.toString()
                                } else {
                                    throw Exception("Failed to create MediaStore entry for $fileName")
                                }
                            }

                            if (savedPath.isEmpty()) {
                                throw Exception("Could not save $fileName to public downloads")
                            }

                            withContext(Dispatchers.Main) { result.success(savedPath) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("SAVE_FAILED", e.message, e.stackTraceToString())
                            }
                        }
                    }
                    "getDownloadsPath" -> {
                        try {
                            val path = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath + "/Groovy"
                            withContext(Dispatchers.Main) { result.success(path) }
                        } catch (_: Exception) {
                            withContext(Dispatchers.Main) { result.success("/storage/emulated/0/Download/Groovy") }
                        }
                    }
                    else -> withContext(Dispatchers.Main) { result.notImplemented() }
                }
            }
        }
    }
}
