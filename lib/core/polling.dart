import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

final pollingRoutes = RouteObserver<ModalRoute<dynamic>>();

/// One request at a time, with bounded backoff. Mutations never use this scheduler.
class AdaptivePoller {
  AdaptivePoller({required this.interval, required this.fetch});
  final Duration interval;
  final Future<bool> Function() fetch;
  Timer? _timer;
  bool _active = false, _busy = false, _disposed = false;
  int _failures = 0;
  bool get active => _active && !_disposed;

  void setActive(bool value) {
    if (_disposed || value == _active) return;
    _active = value;
    _timer?.cancel();
    _timer = null;
    if (value && !_busy) unawaited(_run());
  }

  Future<void> _run() async {
    if (!active || _busy) return;
    _busy = true;
    try {
      _failures = await fetch() ? 0 : math.min(_failures + 1, 5);
    } catch (_) {
      _failures = math.min(_failures + 1, 5);
    } finally {
      _busy = false;
      if (active) {
        final seconds = math.min(interval.inSeconds * (1 << _failures), 120);
        _timer = Timer(Duration(seconds: seconds), _run);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _active = false;
    _timer?.cancel();
  }
}

class RoutePolling with WidgetsBindingObserver, RouteAware {
  RoutePolling({
    required Duration interval,
    required Future<bool> Function() fetch,
  }) : poller = AdaptivePoller(interval: interval, fetch: fetch) {
    WidgetsBinding.instance.addObserver(this);
  }
  final AdaptivePoller poller;
  ModalRoute<dynamic>? _route;
  bool _disposed = false;
  void attach(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == _route) return;
    pollingRoutes.unsubscribe(this);
    _route = route;
    if (route != null) pollingRoutes.subscribe(this, route);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (_disposed) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    poller.setActive(
      _route?.isCurrent == true &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed),
    );
  }

  @override
  void didPush() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  @override
  void didPopNext() => _update();
  @override
  void didPushNext() => poller.setActive(false);
  @override
  void didPop() => poller.setActive(false);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _update();
  void dispose() {
    _disposed = true;
    pollingRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    poller.dispose();
  }
}
