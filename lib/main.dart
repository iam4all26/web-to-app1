import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> config = {};
  try {
    config = jsonDecode(await rootBundle.loadString('app_config.json')) as Map<String, dynamic>;
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: WebPage(config: config),
    );
  }
}

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.config});
  final Map<String, dynamic> config;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;
  late final Uri _home;

  bool get _bar => widget.config['show_loading_bar'] != false;
  bool get _stay => widget.config['open_other_sites_in_app'] != false;

  @override
  void initState() {
    super.initState();
    _home = Uri.parse((widget.config['url'] ?? 'https://example.com').toString());
    _controller = WebViewController()
      ..setJavaScriptMode(widget.config['javascript'] == false ? JavaScriptMode.disabled : JavaScriptMode.unrestricted)
      ..setBackgroundColor(_color(widget.config['background_color']?.toString()))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _failed = false),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _failed = true);
        },
        onNavigationRequest: (r) {
          if (!_stay && Uri.parse(r.url).host != _home.host) return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(_home);
    _controller.enableZoom(widget.config['allow_zoom'] == true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _color(widget.config['background_color']?.toString()),
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _controller),
            if (_bar && _progress < 100 && !_failed) LinearProgressIndicator(value: _progress / 100, minHeight: 3),
            if (_failed)
              Container(
                color: Theme.of(context).colorScheme.surface,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 56),
                  const SizedBox(height: 12),
                  const Text('Could not load the page.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Check your internet connection.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() => _failed = false);
                      _controller.loadRequest(_home);
                    },
                    child: const Text('Try again'),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
