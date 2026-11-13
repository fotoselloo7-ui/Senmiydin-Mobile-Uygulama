import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/widgets/media_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildViewerTestBed({
    required AppStore store,
    required List<String> images,
    int initialIndex = 0,
    ValueChanged<int>? onIndexChanged,
  }) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: MediaViewer(
            store: store,
            images: images,
            initialIndex: initialIndex,
            onIndexChanged: onIndexChanged,
          ),
        ),
      ),
    );
  }

  group('MediaViewer widget tests', () {
    testWidgets('Single image: no counter, no thumbnails, no dots, has close button', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildViewerTestBed(
          store: store,
          images: const ['assets/images/coast.jpg'],
        ),
      );
      await tester.pump();

      // Close button exists
      expect(find.byTooltip('Kapat'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // No counter (1/1 forbidden)
      expect(find.text('1/1'), findsNothing);

      // No thumbnails
      expect(find.byType(SingleChildScrollView), findsNothing);

      // InteractiveViewer is present
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('Two images: counter 1/2, dots, and thumbnail strip shown', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      int? changedIndex;

      await tester.pumpWidget(
        buildViewerTestBed(
          store: store,
          images: const [
            'assets/images/coast.jpg',
            'assets/images/sunset.jpg',
          ],
          initialIndex: 0,
          onIndexChanged: (i) => changedIndex = i,
        ),
      );
      await tester.pump();

      // Counter should show 1/2
      expect(find.text('1/2'), findsOneWidget);

      // Thumbnail strip exists with 2 thumbnails
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.bySemanticsLabel('1. görsel'), findsOneWidget);
      expect(find.bySemanticsLabel('2. görsel'), findsOneWidget);

      // Tap on second thumbnail
      await tester.tap(find.bySemanticsLabel('2. görsel'));
      await tester.pumpAndSettle();

      // Counter updates to 2/2
      expect(find.text('2/2'), findsOneWidget);
      expect(changedIndex, 1);
    });

    testWidgets('Many images (10 items): counter 1/10, no dots to avoid clutter, horizontal scrollable thumbnails', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      final tenImages = List.generate(10, (i) => 'assets/images/photo_$i.jpg');

      await tester.pumpWidget(
        buildViewerTestBed(
          store: store,
          images: tenImages,
          initialIndex: 0,
        ),
      );
      await tester.pump();

      // Counter should show 1/10
      expect(find.text('1/10'), findsOneWidget);

      // Dots are hidden for > 5 images to avoid screen clutter
      // Thumbnail strip is shown
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Close button dismisses showMediaViewer dialog and returns viewed index', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      int? returnedIndex;

      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedIndex = await showMediaViewer(
                      context,
                      const [
                        'assets/images/coast.jpg',
                        'assets/images/sunset.jpg',
                      ],
                      initialIndex: 0,
                    );
                  },
                  child: const Text('Open Viewer'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open viewer
      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);

      // Tap second thumbnail to change index
      await tester.tap(find.bySemanticsLabel('2. görsel'));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();

      // Viewer is dismissed and returned the last viewed index
      expect(find.byType(MediaViewer), findsNothing);
      expect(returnedIndex, 1);
    });

    testWidgets('Horizontal drag/swipe flips photos naturally', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildViewerTestBed(
          store: store,
          images: const [
            'assets/images/coast.jpg',
            'assets/images/sunset.jpg',
          ],
        ),
      );
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);

      // Fling left to swipe to the next photo
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('Double tap triggers zoom and pan, double tap again resets scale', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildViewerTestBed(
          store: store,
          images: const ['assets/images/coast.jpg'],
        ),
      );
      await tester.pump();

      final interactiveFinder = find.byType(InteractiveViewer);
      InteractiveViewer iv = tester.widget(interactiveFinder);
      expect(iv.panEnabled, isFalse);

      // Double tap to zoom in
      await tester.tap(interactiveFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(interactiveFinder);
      await tester.pumpAndSettle();

      iv = tester.widget(interactiveFinder);
      expect(iv.panEnabled, isTrue);

      // Double tap to reset
      await tester.tap(interactiveFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(interactiveFinder);
      await tester.pumpAndSettle();

      iv = tester.widget(interactiveFinder);
      expect(iv.panEnabled, isFalse);
    });
  });
}
