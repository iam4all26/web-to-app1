package com.kgit.downloader;

import android.app.DownloadManager;
import android.content.Context;
import android.net.Uri;
import android.os.Environment;
import android.webkit.URLUtil;

import androidx.annotation.NonNull;

import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** Hands a download to Android's DownloadManager. */
public class KgitDownloaderPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "kgit_downloader");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        context = null;
    }

    private static String str(MethodCall call, String key) {
        String v = call.argument(key);
        return v == null ? "" : v;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (!"enqueue".equals(call.method)) {
            result.notImplemented();
            return;
        }
        try {
            String url = str(call, "url");
            String mime = str(call, "mimeType");
            String disposition = str(call, "contentDisposition");
            String userAgent = str(call, "userAgent");
            String cookie = str(call, "cookie");
            String referer = str(call, "referer");
            String name = str(call, "fileName");

            if (name.isEmpty()) {
                name = URLUtil.guessFileName(url, disposition.isEmpty() ? null : disposition,
                        mime.isEmpty() ? null : mime);
            }
            name = name.replaceAll("[\\\\/:*?\"<>|]", "_");
            if (name.isEmpty()) {
                name = "download";
            }

            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            if (!mime.isEmpty()) {
                request.setMimeType(mime);
            }
            if (!userAgent.isEmpty()) {
                request.addRequestHeader("User-Agent", userAgent);
            }
            if (!cookie.isEmpty()) {
                request.addRequestHeader("Cookie", cookie);
            }
            if (!referer.isEmpty()) {
                request.addRequestHeader("Referer", referer);
            }
            Map<String, String> headers = call.argument("headers");
            if (headers != null) {
                for (Map.Entry<String, String> e : headers.entrySet()) {
                    if (e.getKey() != null && e.getValue() != null) {
                        request.addRequestHeader(e.getKey(), e.getValue());
                    }
                }
            }
            request.setTitle(name);
            request.setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.allowScanningByMediaScanner();
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name);

            DownloadManager dm = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
            if (dm == null) {
                result.error("no_download_manager", "DownloadManager is not available.", null);
                return;
            }
            dm.enqueue(request);
            result.success(name);
        } catch (Exception e) {
            result.error("download_failed", String.valueOf(e.getMessage()), null);
        }
    }
}
