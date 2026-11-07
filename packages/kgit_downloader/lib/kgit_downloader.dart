import 'package:flutter/services.dart';

/// Saves a file with Android's own DownloadManager.
///
/// The file lands in the public Downloads folder and the system shows the
/// normal download notification. There is no download screen inside the app.
class KgitDownloader {
  static const MethodChannel _channel = MethodChannel('kgit_downloader');

  /// Returns the file name that was used. Throws a [PlatformException] when
  /// Android refuses the download (the caller can then hand the link to Chrome).
  static Future<String> enqueue({
    required String url,
    String? fileName,
    String? mimeType,
    String? contentDisposition,
    String? userAgent,
    String? cookie,
    String? referer,
    Map<String, String>? headers,
  }) async {
    final name = await _channel.invokeMethod<String>('enqueue', <String, dynamic>{
      'url': url,
      'fileName': fileName ?? '',
      'mimeType': mimeType ?? '',
      'contentDisposition': contentDisposition ?? '',
      'userAgent': userAgent ?? '',
      'cookie': cookie ?? '',
      'referer': referer ?? '',
      'headers': headers ?? <String, String>{},
    });
    return name ?? (fileName ?? 'download');
  }
}
