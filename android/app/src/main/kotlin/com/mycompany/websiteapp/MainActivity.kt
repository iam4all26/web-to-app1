package com.mycompany.websiteapp

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.webkit.URLUtil
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "website_to_app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "enqueue") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val url = args["url"]?.toString().orEmpty()
                    val parsed = Uri.parse(url)
                    if (parsed.scheme != "http" && parsed.scheme != "https") {
                        result.error("INVALID_URL", "Only HTTP and HTTPS downloads are supported.", null)
                        return@setMethodCallHandler
                    }

                    val request = DownloadManager.Request(parsed)
                    val suppliedName = args["fileName"]?.toString().orEmpty()
                    val fileName = URLUtil.guessFileName(
                        url,
                        null,
                        args["mimeType"]?.toString()
                    ).let { if (suppliedName.isNotBlank()) suppliedName else it }
                        .replace(Regex("[\\\\/:*?\"<>|]"), "_")

                    request.setTitle(fileName)
                    request.setDescription("Downloading file")
                    request.setMimeType(args["mimeType"]?.toString() ?: "application/octet-stream")
                    request.setNotificationVisibility(
                        DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                    )
                    request.setDestinationInExternalPublicDir(
                        Environment.DIRECTORY_DOWNLOADS,
                        fileName
                    )
                    request.setAllowedOverMetered(true)
                    request.setAllowedOverRoaming(true)

                    val cookie = args["cookie"]?.toString().orEmpty()
                    if (cookie.isNotBlank()) request.addRequestHeader("Cookie", cookie)

                    val userAgent = args["userAgent"]?.toString().orEmpty()
                    if (userAgent.isNotBlank()) request.addRequestHeader("User-Agent", userAgent)

                    val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    val downloadId = manager.enqueue(request)
                    result.success(downloadId)
                } catch (exception: Exception) {
                    result.error("DOWNLOAD_FAILED", exception.message, null)
                }
            }
    }
}
