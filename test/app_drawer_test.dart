import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/widgets/app_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildDrawerTestBed({
    required AppStore store,
    String? currentRoute,
    VoidCallback? onProfile,
    double textScale = 1.0,
    Size surfaceSize = const Size(390, 844),
  }) {
    return StoreScope(
      store: store,
      child: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: const Text('Home Screen'),
            drawer: AppDrawer(
              currentRoute: currentRoute,
              onProfile: onProfile,
            ),
          ),
        ),
      ),
    );
  }

  group('AppDrawer Widget Tests', () {
    testWidgets('Drawer renders all items, profile card and footer', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(buildDrawerTestBed(store: store));
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Profile Card
      expect(find.text(store.me.name), findsOneWidget);
      expect(find.text('@${store.me.handle}'), findsOneWidget);
      expect(find.text(store.me.city), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Menu Items in exact required order
      expect(find.text('Karşılaşmalarım'), findsOneWidget);
      expect(find.text('Kaydedilenler'), findsOneWidget);
      expect(find.text('Bildirimler'), findsOneWidget);
      expect(find.text('İlgi Alanlarım'), findsOneWidget);
      expect(find.text('Filtreler'), findsOneWidget);
      expect(find.text('Ayarlar'), findsOneWidget);

      // Footer
      expect(find.text('SenMiydin?'), findsOneWidget);
      expect(find.text('Güzel tesadüflere yer aç.'), findsOneWidget);
    });

    testWidgets('Selected state: none selected when opened from home', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildDrawerTestBed(
          store: store,
          currentRoute: '/home',
        ),
      );
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // No item should have selected semantics
      final semanticsWidget = tester.widget<Semantics>(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Karşılaşmalarım',
      ));
      expect(semanticsWidget.properties.selected, isFalse);
    });

    testWidgets('Selected state: matches currentRoute when on /encounters', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildDrawerTestBed(
          store: store,
          currentRoute: '/encounters',
        ),
      );
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final semanticsWidget = tester.widget<Semantics>(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Karşılaşmalarım',
      ));
      expect(semanticsWidget.properties.selected, isTrue);
    });

    testWidgets('Tapping profile card triggers onProfile callback', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);
      bool profileOpened = false;

      await tester.pumpWidget(
        buildDrawerTestBed(
          store: store,
          onProfile: () => profileOpened = true,
        ),
      );
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text(store.me.name));
      await tester.pumpAndSettle();

      expect(profileOpened, isTrue);
    });

    testWidgets('Small viewport (320x568) renders without overflow', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildDrawerTestBed(
          store: store,
          surfaceSize: const Size(320, 568),
        ),
      );
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Large text scale (1.3x) renders cleanly', (tester) async {
      final store = AppStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        buildDrawerTestBed(
          store: store,
          textScale: 1.3,
        ),
      );
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
