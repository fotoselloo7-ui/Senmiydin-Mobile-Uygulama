import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/widgets/social.dart';
import 'package:senmiydin/data/app_store.dart';

void main() {
  testWidgets('Opening a different photo post starts at its own first image', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final bucket = PageStorageBucket();
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    const pairs = [
      ['assets/images/user_0.jpg', 'assets/images/user_1.jpg'],
      ['assets/images/user_2.jpg', 'assets/images/user_3.jpg'],
    ];
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: SingleChildScrollView(
                key: const PageStorageKey('feed'),
                child: ValueListenableBuilder<int>(
                  valueListenable: selected,
                  builder: (context, value, _) =>
                      ImageCarousel(pairs[value], key: ValueKey(value)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    selected.value = 1;
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2/2'), findsNothing);
  });
}
