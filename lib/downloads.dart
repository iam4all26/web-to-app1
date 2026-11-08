import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kgit_downloader/kgit_downloader.dart';

import 'app_settings.dart';

/// Hands a file to Android's DownloadManager with the page's cookies, so
/// downloads that need a login keep working. Returns the file name used.
/// Throws when Android refuses the download.
Future<String> startDownload(
  AppSettings s, {
  required WebUri url,
  String? fileName,
  String? mimeType,
  String? contentDisposition,
  String? userAgent,
  String? referer,
}) async {
  String cookie = '';
  try {
    final cookies = await CookieManager.instance().getCookies(url: url);
    cookie = cookies.map((e) => '${e.name}=${e.value}').join('; ');
  } catch (_) {}
  return KgitDownloader.enqueue(
    url: url.toString(),
    fileName: fileName,
    mimeType: mimeType,
    contentDisposition: contentDisposition,
    userAgent: (userAgent != null && userAgent.isNotEmpty) ? userAgent : s.userAgent,
    cookie: cookie,
    referer: referer,
    headers: s.headers,
  );
}
