import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Best-effort WebView pre-warm for faster navigation and cookie/session reuse.
///
/// This does **not** log the user in; it just initializes the WebView engine
/// and loads the Frontline domain early so subsequent job opens are faster.
class FrontlineWebViewWarmup {
  static final FrontlineWebViewWarmup _instance = FrontlineWebViewWarmup._internal();
  factory FrontlineWebViewWarmup() => _instance;
  FrontlineWebViewWarmup._internal();

  WebViewController? _controller;
  bool _started = false;

  Future<void> prewarm() async {
    if (_started) return;
    _started = true;

    // webview_flutter on web can behave differently; keep this best-effort.
    try {
      _controller ??= WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (_) {},
          ),
        );

      // Kick off a lightweight page load to warm the engine + domain cookies.
      // We do not await completion; we just start it.
      unawaited(_controller!.loadRequest(Uri.parse('https://absencesub.frontlineeducation.com/')));
    } catch (e) {
      // Never block app startup.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[FrontlineWebViewWarmup] prewarm failed: $e');
      }
    }
  }
}

