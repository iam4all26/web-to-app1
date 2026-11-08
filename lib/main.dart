import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'downloads.dart';
import 'popup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> config = {};
  try {
    config = jsonDecode(await rootBundle.loadString('app_config.json')) as Map<String, dynamic>;
  } catch (_) {}
  final settings = AppSettings(config);
  switch (settings.orientation) {
    case 'portrait':
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      break;
    case 'landscape':
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      break;
    default:
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
  runApp(WebApp(settings: settings));
}

class WebApp extends StatelessWidget {
  const WebApp({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: WebPage(settings: settings),
    );
  }
}

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  InAppWebViewController? _web;
  PullToRefreshController? _pull;
  late final InAppWebViewSettings _viewSettings;
  late final WebUri _home;
  int _progress = 0;
  bool _failed = false;
  bool _cacheTried = false;

  AppSettings get _s => widget.settings;

  CacheMode get _normalCache => _s.updateAlways ? CacheMode.LOAD_NO_CACHE : CacheMode.LOAD_DEFAULT;

  @override
  void initState() {
    super.initState();
    _home = WebUri(_s.url);
    _viewSettings = InAppWebViewSettings(
      javaScriptEnabled: _s.javascript,
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      // new-window requests (target="_blank", window.open) reach onCreateWindow
      javaScriptCanOpenWindowsAutomatically: true,
      supportMultipleWindows: _s.externalLinks != ExternalLinks.no,
      supportZoom: _s.zoom,
      builtInZoomControls: _s.zoom,
      displayZoomControls: false,
      useWideViewPort: true,
      loadWithOverviewMode: _s.adaptWidth,
      cacheMode: _normalCache,
      transparentBackground: false,
      mediaPlaybackRequiresUserGesture: false,
      userAgent: _s.userAgent.isEmpty ? null : _s.userAgent,
    );
    if (_s.pullToRefresh) {
      _pull = PullToRefreshController(
        settings: PullToRefreshSettings(enabled: true),
        onRefresh: () async {
          await _web?.reload();
        },
      );
    }
  }

  // ---- links -------------------------------------------------------------

  /// Opens a page without leaving the app (a page on top of the main one;
  /// Back or the close button returns), or in a Chrome Custom Tab when
  /// "new_window_mode" is "chrome". A link to a plain file is downloaded instead.
  Future<void> _openExternal(Uri uri) async {
    if (_s.downloads && AppSettings.looksLikeFile(uri)) {
      await _downloadUrl(uri);
      return;
    }
    if (_s.newWindowInApp && mounted) {
      final r = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => PopupPage(settings: _s, url: WebUri.uri(uri))),
      );
      if (r != null && r.isNotEmpty) _toast('Downloading $r');
      return;
    }
    await _openChrome(uri);
  }

  Future<void> _openChrome(Uri uri) async {
    try {
      await ChromeSafariBrowser().open(
        url: WebUri.uri(uri),
        settings: ChromeSafariBrowserSettings(showTitle: true),
      );
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  /// Downloads a direct file link without opening any page.
  Future<void> _downloadUrl(Uri uri) async {
    try {
      final page = await _web?.getUrl();
      final name = await startDownload(_s, url: WebUri.uri(uri), referer: page?.toString());
      _toast('Downloading $name');
    } catch (_) {
      await _openChrome(uri);
    }
  }

  /// tel:, mailto:, intent:, whatsapp: and similar go to the app that owns them.
  Future<void> _openApp(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static bool _isWeb(Uri u) => u.scheme == 'http' || u.scheme == 'https';
  static bool _isInline(Uri u) =>
      u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob' || u.scheme == 'file' || u.scheme == 'javascript';

  // ---- downloads ---------------------------------------------------------

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  Future<void> _download(InAppWebViewController c, DownloadStartRequest r) async {
    if (!_s.downloads) {
      _toast('Downloads are turned off in this app.');
      return;
    }
    final uri = Uri.tryParse(r.url.toString());
    if (uri == null || !_isWeb(uri)) {
      _toast('This kind of file cannot be downloaded.');
      return;
    }
    try {
      final page = await c.getUrl();
      final name = await startDownload(
        _s,
        url: r.url,
        fileName: r.suggestedFilename,
        mimeType: r.mimeType,
        contentDisposition: r.contentDisposition,
        userAgent: r.userAgent,
        referer: page?.toString(),
      );
      _toast('Downloading $name');
    } catch (_) {
      // Android refused it (old phone without storage access, for example):
      // let Chrome handle the download.
      await _openChrome(uri);
    }
  }

  // ---- page actions ------------------------------------------------------

  Future<void> _printPage() async {
    try {
      await _web?.printCurrentPage();
    } catch (_) {
      _toast('Printing is not available on this phone.');
    }
  }

  Future<void> _sharePage() async {
    final u = await _web?.getUrl();
    await Share.share((u ?? _home).toString());
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_s.share)
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share this page'),
              onTap: () {
                Navigator.pop(ctx);
                _sharePage();
              },
            ),
          if (_s.print)
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print this page'),
              onTap: () {
                Navigator.pop(ctx);
                _printPage();
              },
            ),
        ]),
      ),
    );
  }

  // ---- loading and errors ------------------------------------------------

  Future<void> _useCache(bool on) async {
    _viewSettings.cacheMode = on ? CacheMode.LOAD_CACHE_ONLY : _normalCache;
    await _web?.setSettings(settings: _viewSettings);
  }

  Future<void> _fixViewport(InAppWebViewController c) async {
    await c.evaluateJavascript(source: '''
      (function () {
        var v = 'width=device-width, initial-scale=1';
        var m = document.querySelector('meta[name=viewport]');
        if (m) { m.setAttribute('content', v); }
        else { m = document.createElement('meta'); m.name = 'viewport'; m.content = v; document.head.appendChild(m); }
      })();
    ''');
  }

  Future<void> _reloadHome() async {
    setState(() => _failed = false);
    _cacheTried = false;
    await _useCache(false);
    await _web?.loadUrl(urlRequest: URLRequest(url: _home, headers: _s.headers));
  }

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final showMenu = _s.print || _s.share;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final c = _web;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _s.backgroundColor,
        body: SafeArea(
          child: Stack(children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: _home, headers: _s.headers),
              initialSettings: _viewSettings,
              pullToRefreshController: _pull,
              onWebViewCreated: (c) => _web = c,
              onProgressChanged: (c, p) {
                if (mounted) setState(() => _progress = p);
              },
              onLoadStart: (c, url) {
                if (_failed && mounted) setState(() => _failed = false);
              },
              onLoadStop: (c, url) async {
                _pull?.endRefreshing();
                if (_cacheTried) {
                  // the cached copy is showing; go back to the normal mode for the next page
                  _cacheTried = false;
                  await _useCache(false);
                }
                if (_s.adaptWidth) await _fixViewport(c);
              },
              onReceivedError: (c, request, error) async {
                if (request.isForMainFrame == false) return;
                if (error.description.contains('ERR_ABORTED')) return;
                _pull?.endRefreshing();
                if (_s.allowOffline && !_s.updateAlways && !_cacheTried) {
                  _cacheTried = true;
                  await _useCache(true);
                  await c.loadUrl(urlRequest: URLRequest(url: request.url));
                  return;
                }
                if (_cacheTried) {
                  _cacheTried = false;
                  await _useCache(false);
                }
                if (mounted) setState(() => _failed = true);
              },
              shouldOverrideUrlLoading: (c, action) async {
                final uri = Uri.tryParse(action.request.url?.toString() ?? '');
                if (uri == null || !action.isForMainFrame) return NavigationActionPolicy.ALLOW;
                if (_isInline(uri)) return NavigationActionPolicy.ALLOW;
                if (!_isWeb(uri)) {
                  await _openApp(uri);
                  return NavigationActionPolicy.CANCEL;
                }
                if (_s.downloads && AppSettings.looksLikeFile(uri)) {
                  await _downloadUrl(uri);
                  return NavigationActionPolicy.CANCEL;
                }
                if (_s.externalLinks == ExternalLinks.yes && !_s.isInternal(uri)) {
                  await _openExternal(uri);
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (c, action) async {
                final u = action.request.url;
                final uri = u == null ? null : Uri.tryParse(u.toString());
                if (uri == null || uri.toString().isEmpty || uri.scheme == 'about') {
                  return false; // an empty pop-up: nothing to open
                }
                if (!_isWeb(uri)) {
                  await _openApp(uri);
                  return true;
                }
                if (_s.externalLinks == ExternalLinks.no) {
                  await c.loadUrl(urlRequest: URLRequest(url: u));
                } else {
                  await _openExternal(uri);
                }
                return true;
              },
              onDownloadStartRequest: _download,
              onPrintRequest: (c, url, job) async {
                if (_s.print) {
                  await _printPage();
                }
                return true; // we handled it (or print is off)
              },
            ),
            if (_s.loader && _progress < 100 && !_failed)
              LinearProgressIndicator(value: _progress / 100, minHeight: 3),
            if (showMenu)
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white),
                    tooltip: 'More',
                    onPressed: _showMenu,
                  ),
                ),
              ),
            if (_failed)
              Container(
                color: Theme.of(context).colorScheme.surface,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    _s.offlineMessage.isEmpty ? 'Could not load the page.' : _s.offlineMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_s.offlineMessage.isEmpty) ...[
                    const SizedBox(height: 4),
                    const Text('Check your internet connection.'),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _reloadHome, child: const Text('Try again')),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
