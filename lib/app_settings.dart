import 'dart:ui' show Color;

/// How links that leave the main page are handled.
enum ExternalLinks { yes, no, auto }

/// Everything in app_config.json, with safe defaults for missing keys.
class AppSettings {
  AppSettings(Map<String, dynamic> j)
      : url = (j['url'] ?? 'https://example.com').toString(),
        javascript = j['javascript'] != false,
        backgroundColor = _color(j['background_color']?.toString()),
        externalLinks = _links(j),
        newWindowInApp = (j['new_window_mode'] ?? 'in_app').toString().trim().toLowerCase() != 'chrome',
        downloads = _bool(j['enable_downloads'], true),
        print = _bool(j['enable_print'], false),
        share = _bool(j['enable_share'], false),
        adaptWidth = _bool(j['adapt_width'], false),
        zoom = _bool(j['allow_zoom'], false),
        orientation = (j['screen_orientation'] ?? 'auto').toString().toLowerCase(),
        pullToRefresh = _bool(j['pull_to_refresh'], true),
        loader = _bool(j['show_loader'] ?? j['show_loading_bar'], true),
        updateAlways = _bool(j['update_always'], false),
        allowOffline = _bool(j['allow_offline'], true),
        offlineMessage = (j['offline_message'] ?? '').toString().trim(),
        userAgent = (j['user_agent'] ?? '').toString().trim(),
        headers = _headers(j['custom_headers']);

  final String url;
  final bool javascript;
  final Color backgroundColor;
  final ExternalLinks externalLinks;
  /// true: new windows and outside links open in a page inside the app. false: Chrome Custom Tab.
  final bool newWindowInApp;
  final bool downloads;
  final bool print;
  final bool share;
  final bool adaptWidth;
  final bool zoom;
  final String orientation; // auto | portrait | landscape
  final bool pullToRefresh;
  final bool loader;
  final bool updateAlways;
  final bool allowOffline;
  final String offlineMessage;
  final String userAgent;
  final Map<String, String> headers;

  static const _fileExt = {
    'pdf', 'zip', 'rar', '7z', 'apk', 'aab', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'csv', 'mp3', 'wav', 'm4a', 'mp4', 'mkv', 'avi', 'mov', 'epub', 'exe', 'dmg', 'iso', 'tar', 'gz',
  };

  /// True when the link points straight at a file that should be downloaded, not shown.
  static bool looksLikeFile(Uri u) {
    final path = u.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return _fileExt.contains(path.substring(dot + 1));
  }

  /// True when [url] belongs to the configured website (same host or a subdomain).
  bool isInternal(Uri u) {
    final home = _bare(Uri.tryParse(url)?.host ?? '');
    final host = _bare(u.host);
    if (home.isEmpty) return true;
    return host == home || host.endsWith('.$home');
  }

  static String _bare(String h) {
    final x = h.toLowerCase();
    return x.startsWith('www.') ? x.substring(4) : x;
  }

  static bool _bool(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'yes' || s == 'true') return true;
      if (s == 'no' || s == 'false') return false;
    }
    return fallback;
  }

  static ExternalLinks _links(Map<String, dynamic> j) {
    final v = j['open_links_externally'];
    if (v is bool) return v ? ExternalLinks.yes : ExternalLinks.no;
    final s = v?.toString().trim().toLowerCase();
    if (s == 'yes' || s == 'true') return ExternalLinks.yes;
    if (s == 'no' || s == 'false') return ExternalLinks.no;
    if (s == 'auto') return ExternalLinks.auto;
    // Old configs only had open_other_sites_in_app.
    if (j['open_other_sites_in_app'] == false) return ExternalLinks.yes;
    return ExternalLinks.auto;
  }

  static Map<String, String> _headers(dynamic v) {
    final out = <String, String>{};
    if (v is Map) {
      v.forEach((k, val) {
        final key = k.toString().trim();
        if (key.isNotEmpty && val != null) out[key] = val.toString();
      });
    }
    return out;
  }

  static Color _color(String? hex) {
    final h = (hex ?? '#FFFFFF').replaceAll('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return Color(v ?? 0xFFFFFFFF);
  }
}
