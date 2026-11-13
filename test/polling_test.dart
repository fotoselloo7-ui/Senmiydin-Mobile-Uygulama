import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/polling.dart';

void main() {
  testWidgets('Polling stops when inactive and refreshes once when resumed', (
    tester,
  ) async {
    var calls = 0;
    final poller = AdaptivePoller(
      interval: const Duration(seconds: 4),
      fetch: () async {
        calls++;
        return true;
      },
    );
    addTearDown(poller.dispose);
    poller.setActive(true);
    poller.setActive(true);
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(calls, 2);
    poller.setActive(false);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 2);
    poller.setActive(true);
    await tester.pump();
    expect(calls, 3);
    poller.dispose();
  });
  testWidgets(
    'Failures back off and slow requests cannot overlap or restart after dispose',
    (tester) async {
      var calls = 0;
      Completer<bool>? pending;
      final poller = AdaptivePoller(
        interval: const Duration(seconds: 4),
        fetch: () {
          calls++;
          return (pending = Completer<bool>()).future;
        },
      );
      poller.setActive(true);
      await tester.pump(const Duration(seconds: 20));
      expect(calls, 1);
      pending!.complete(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      poller.dispose();
      pending!.complete(true);
      await tester.pump(const Duration(minutes: 3));
      expect(calls, 2);
    },
  );
  testWidgets(
    'Route cover, background, return and disposal control the actual polling lifecycle',
    (tester) async {
      var calls = 0;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [pollingRoutes],
          home: _PollingPage(() async {
            calls++;
            return true;
          }),
        ),
      );
      await tester.pump();
      expect(calls, 1);
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(calls, 1);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
      expect(calls, 3);
    },
  );
}

class _PollingPage extends StatefulWidget {
  const _PollingPage(this.fetch);
  final Future<bool> Function() fetch;
  @override
  State<_PollingPage> createState() => _PollingPageState();
}

class _PollingPageState extends State<_PollingPage> {
  late final poll = RoutePolling(
    interval: const Duration(seconds: 4),
    fetch: widget.fetch,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    poll.attach(context);
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
  @override
  void dispose() {
    poll.dispose();
    super.dispose();
  }
}
