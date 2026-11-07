import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const MethodChannel _downloadsChannel = MethodChannel('website_to_app/downloads');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> config = {};
  try {
    config = jsonDecode(await rootBundle.loadString('app_config.json'))
        as Map<String, dynamic>;
  } catch (_) {}
  runApp(WebApp(config: config));
}

Color _color(String? hex) {
  final h = (hex ?? '#FFFFFF').replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return Color(v ?? 0xFFFFFFFF);
}

class WebApp extends StatelessWidget {
  const WebApp({super.key, required this.config});
  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: _color(config['background_color']?.toString()),
      ),
      home: WebPage(config: config),
    );
  }
}

class _BrowserTab {
  _BrowserTab({
    required this.id,
    required this.url,
    this.windowId,
    this.title = 'New tab',
  });

  final int id;
  final int? windowId;
  String url;
  String title;
  InAppWebViewController? controller;
  int progress = 0;
  bool failed = false;
}

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.config});
  final Map<String, dynamic> config;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final Uri _home;
  final List<_BrowserTab> _tabs = [];
  int _activeIndex = 0;
  int _nextId = 0;
  bool _showTabs = false;

  bool get _showProgress => widget.config['show_loading_bar'] != false;
  bool get _stayInApp => widget.config['open_other_sites_in_app'] != false;
  bool get _javascript => widget.config['javascript'] != false;
  bool get _allowZoom => widget.config['allow_zoom'] == true;
  _BrowserTab get _activeTab => _tabs[_activeIndex];

  @override
  void initState() {
    super.initState();
    _home = Uri.parse(
      (widget.config['url'] ?? 'https://example.com').toString(),
    );
    _tabs.add(_BrowserTab(id: _nextId++, url: _home.toString(), title: 'Home'));
  }

  Future<void> _newTab({String? url, int? windowId}) async {
    setState(() {
      _tabs.add(_BrowserTab(
        id: _nextId++,
        url: url ?? _home.toString(),
        windowId: windowId,
      ));
      _activeIndex = _tabs.length - 1;
      _showTabs = false;
    });
  }

  Future<void> _closeTab(int index) async {
    if (_tabs.length == 1) {
      final tab = _tabs.first;
      await tab.controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_home.toString())),
      );
      if (!mounted) return;
      setState(() {
        tab.url = _home.toString();
        tab.title = 'Home';
        tab.failed = false;
        tab.progress = 0;
        _activeIndex = 0;
        _showTabs = false;
      });
      return;
    }
    setState(() {
      _tabs.removeAt(index);
      if (_activeIndex > index) {
        _activeIndex--;
      } else if (_activeIndex == index) {
        _activeIndex = (index - 1).clamp(0, _tabs.length - 1);
      }
      _showTabs = false;
    });
  }

  Future<bool> _handleBack() async {
    if (_showTabs) {
      setState(() => _showTabs = false);
      return true;
    }
    final controller = _activeTab.controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return true;
    }
    if (_tabs.length > 1) {
      await _closeTab(_activeIndex);
      return true;
    }
    return false;
  }

  Future<void> _startDownload(dynamic request) async {
    final url = request.url.toString();
    final tab = _activeTab;
    try {
      await _downloadsChannel.invokeMethod('enqueue', {
        'url': url,
        'fileName': request.suggestedFilename ?? '',
        'mimeType': request.mimeType ?? 'application/octet-stream',
        'userAgent': await tab.controller?.evaluateJavascript(
          source: 'navigator.userAgent',
        ),
        'cookie': await CookieManager.instance().getCookies(
          url: WebUri(url),
        ).then((cookies) => cookies
            .map((cookie) => '${cookie.name}=${cookie.value}')
            .join('; ')),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download started. Check your device notifications or Downloads.'),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start download: ${error.message ?? error.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This download is not supported on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = _activeTab;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _handleBack() && mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _browserBar(tab),
              Expanded(
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _activeIndex,
                      children: _tabs.map(_buildTab).toList(),
                    ),
                    if (_showTabs) _tabOverview(),
                  ],
                ),
              ),
              _bottomBar(tab),
            ],
          ),
        ),
      ),
    );
  }

  Widget _browserBar(_BrowserTab tab) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Home',
              onPressed: () => tab.controller?.loadUrl(
                urlRequest: URLRequest(url: WebUri(_home.toString())),
              ),
              icon: const Icon(Icons.home_outlined),
            ),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        tab.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Reload',
                      onPressed: () => tab.controller?.reload(),
                      icon: const Icon(Icons.refresh, size: 19),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'New tab',
              onPressed: () => _newTab(),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: 'Tabs',
              onPressed: () => setState(() => _showTabs = !_showTabs),
              icon: _TabCountIcon(count: _tabs.length),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(_BrowserTab tab) {
    return Stack(
      children: [
        InAppWebView(
          key: ValueKey('webview-${tab.id}'),
          windowId: tab.windowId,
          initialUrlRequest: tab.windowId == null
              ? URLRequest(url: WebUri(tab.url))
              : null,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: _javascript,
            supportMultipleWindows: true,
            javaScriptCanOpenWindowsAutomatically: true,
            useOnDownloadStart: true,
            allowsBackForwardNavigationGestures: true,
            builtInZoomControls: _allowZoom,
            displayZoomControls: false,
            thirdPartyCookiesEnabled: true,
          ),
          onWebViewCreated: (controller) => tab.controller = controller,
          onTitleChanged: (controller, title) {
            if (!mounted) return;
            setState(() => tab.title = title ?? tab.title);
          },
          onUpdateVisitedHistory: (controller, url, isReload) {
            if (!mounted || url == null) return;
            setState(() => tab.url = url.toString());
          },
          onProgressChanged: (controller, progress) {
            if (!mounted) return;
            setState(() => tab.progress = progress);
          },
          onLoadStart: (controller, url) {
            if (!mounted) return;
            setState(() => tab.failed = false);
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame == true && mounted) {
              setState(() => tab.failed = true);
            }
          },
          onDownloadStartRequest: (controller, request) {
            _startDownload(request);
          },
          shouldOverrideUrlLoading: (controller, action) async {
            final uri = action.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;
            if (!_stayInApp && uri.host.isNotEmpty && uri.host != _home.host) {
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onCreateWindow: (controller, action) async {
            await _newTab(
              url: action.request.url?.toString(),
              windowId: action.windowId,
            );
            return true;
          },
        ),
        if (_showProgress && tab.progress < 100 && !tab.failed)
          LinearProgressIndicator(value: tab.progress / 100, minHeight: 2),
        if (tab.failed)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 52),
                      const SizedBox(height: 12),
                      const Text('Could not load the page.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() => tab.failed = false);
                          tab.controller?.reload();
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabOverview() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Tabs (${_tabs.length})',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'New tab',
                  onPressed: () => _newTab(),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Close tab overview',
                  onPressed: () => setState(() => _showTabs = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.18,
              ),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final item = _tabs[index];
                final selected = index == _activeIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() {
                    _activeIndex = index;
                    _showTabs = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language, size: 18),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _closeTab(index),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          item.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(_BrowserTab tab) {
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () async {
                if (await tab.controller?.canGoBack() ?? false) {
                  await tab.controller?.goBack();
                }
              },
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: 'Forward',
              onPressed: () async {
                if (await tab.controller?.canGoForward() ?? false) {
                  await tab.controller?.goForward();
                }
              },
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              tooltip: 'New tab',
              onPressed: () => _newTab(),
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              tooltip: 'Close current tab',
              onPressed: () => _closeTab(_activeIndex),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCountIcon extends StatelessWidget {
  const _TabCountIcon({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.crop_square, size: 27),
          Text('$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
