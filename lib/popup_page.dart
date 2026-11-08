import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'downloads.dart';

/// A page opened from the main page (new tab, window.open, outside link).
/// It lives inside the app: Back or the close button returns to the main page.
/// A link that turns out to be a download starts the download and closes itself.
class PopupPage extends StatefulWidget {
  const PopupPage({super.key, required this.settings, required this.url});
  final AppSettings settings;
  final WebUri url;

  @override
  State<PopupPage> createState() => _PopupPageState();
}

class _PopupPageState extends State<PopupPage> {
  InAppWebViewController? _web;
  int _progress = 0;
  String _title = '';
  bool _shown = false; // a real page has been shown

  AppSettings get _s => widget.settings;

  void _toast(String t) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));
  }

  Future<void> _download(InAppWebViewController c, DownloadStartRequest r) async {
    if (!_s.downloads) {
      _toast('Downloads are turned off in this app.');
      if (!_shown && mounted) Navigator.of(context).maybePop();
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
      if (!mounted) return;
      final closing = !_shown;
      if (closing) Navigator.of(context).pop(name);
      else _toast('Downloading $name');
    } catch (_) {
      _toast('This file could not be downloaded.');
      if (!_shown && mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final c = _web;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _s.backgroundColor,
        appBar: AppBar(
          toolbarHeight: 48,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          title: Text(_title.isEmpty ? (widget.url.host) : _title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3))
              : null,
        ),
        body: SafeArea(
          top: false,
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: widget.url, headers: _s.headers),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: _s.javascript,
              useShouldOverrideUrlLoading: true,
              useOnDownloadStart: true,
              javaScriptCanOpenWindowsAutomatically: true,
              supportMultipleWindows: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              useWideViewPort: true,
              userAgent: _s.userAgent.isEmpty ? null : _s.userAgent,
            ),
            onWebViewCreated: (c) => _web = c,
            onProgressChanged: (c, p) {
              if (mounted) setState(() => _progress = p);
            },
            onLoadStop: (c, url) async {
              _shown = true;
              final t = await c.getTitle();
              if (mounted && t != null && t.isNotEmpty) setState(() => _title = t);
            },
            onTitleChanged: (c, t) {
              if (mounted && t != null && t.isNotEmpty) setState(() => _title = t);
            },
            shouldOverrideUrlLoading: (c, action) async {
              final u = action.request.url;
              final uri = u == null ? null : Uri.tryParse(u.toString());
              if (uri == null) return NavigationActionPolicy.ALLOW;
              final web = uri.scheme == 'http' || uri.scheme == 'https';
              if (!web && uri.scheme != 'about' && uri.scheme != 'data' && uri.scheme != 'blob' &&
                  uri.scheme != 'javascript' && uri.scheme != 'file') {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onCreateWindow: (c, action) async {
              final u = action.request.url;
              if (u != null && u.toString().isNotEmpty && u.toString() != 'about:blank') {
                await c.loadUrl(urlRequest: URLRequest(url: u));
              }
              return true;
            },
            onDownloadStartRequest: _download,
            onPrintRequest: (c, url, job) async => true,
          ),
        ),
      ),
    );
  }
}
