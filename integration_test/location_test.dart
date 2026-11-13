import 'device_accounts.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/location_service.dart';
import 'package:senmiydin/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Pixel 6a location, distance filters, map and privacy',
    (tester) async {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: 'senmiydin_location_test'),
      );
      await storage.delete(key: 'senmiydin.session.token');
      addTearDown(() => storage.delete(key: 'senmiydin.session.token'));
      final store = AppStore(api: ApiClient(storage: storage));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      });

      Future<void> until(
        bool Function() condition,
        String label, {
        int attempts = 140,
      }) async {
        for (var i = 0; i < attempts; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (condition()) return;
        }
        fail('$label | ${store.location?.state} | ${store.location?.position}');
      }

      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          final vertical = find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first;
          await tester.scrollUntilVisible(finder, 230, scrollable: vertical);
        }
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String label, String value) async {
        await tester.enterText(
          find.widgetWithText(TextFormField, label),
          value,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(SenMiydinApp(store: store));
      final welcomeLogin = find.widgetWithText(OutlinedButton, 'Giriş Yap');
      await until(() => welcomeLogin.evaluate().isNotEmpty, 'Karşılama');
      await tap(welcomeLogin);
      await enter('E-posta veya kullanıcı adı', pixelLocation);
      await enter('Şifre', pixelPassword);
      await tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
      await until(
        () => store.account?.username == pixelLocation,
        'Demo girişi',
      );
      await tester.pumpAndSettle();
      await until(
        () => store.location?.state != DeviceLocationState.idle,
        'Cihaz izni durumu',
      );
      final allow = find.text('Yakındaki sonuçlar için konum izni ver.');
      if (allow.evaluate().isNotEmpty) {
        await tester.ensureVisible(allow);
        await tester.tap(allow);
      }
      await until(
        () =>
            store.location?.synced == true &&
            ((store.location?.position?.latitude ?? 0) - 36.544).abs() < 0.001,
        'Alanya cihaz konumu eşitlemesi',
      );
      await tester.pumpAndSettle();
      final nearby = await store.loadNearby(refresh: true);
      expect(nearby.items, isNotEmpty);
      final ahmet = nearby.items.singleWhere(
        (entry) => entry.person.handle == 'demo_ahmet',
      );
      expect(ahmet.meters, 400);
      final nearbyMeters = nearby.items.map((entry) => entry.meters).toList();
      expect(nearbyMeters, orderedEquals([...nearbyMeters]..sort()));
      expect(
        nearby.items.any((entry) => entry.person.handle == pixelLocation),
        false,
      );
      await until(
        () => find.text('400 m').evaluate().isNotEmpty,
        'Ana Sayfa yakınlık kartı',
      );

      await tap(find.text('Yakın'));
      final nearFeed = (await store.loadFeed(1)).items;
      final distances = nearFeed
          .map((post) => post.distanceMeters)
          .whereType<int>()
          .toList();
      expect(distances, isNotEmpty);
      expect(distances, orderedEquals([...distances]..sort()));

      await tap(find.text('Harita'));
      await until(
        () => find.byTooltip('Haritadaki paylaşım').evaluate().isNotEmpty,
        'Gerçek harita işaretleri',
      );
      await tap(find.text('5 km'));
      await until(
        () => find.byTooltip('Haritadaki paylaşım').evaluate().isNotEmpty,
        '5 km haritası',
      );
      final five = (await store.loadMap()).items;
      expect(five, isNotEmpty);
      expect(five.every((post) => post.meters! <= 5000), true);
      await tap(find.text('10 km'));
      await until(
        () => find.byTooltip('Haritadaki paylaşım').evaluate().isNotEmpty,
        '10 km haritası',
      );
      final ten = (await store.loadMap()).items;
      expect(ten.length, greaterThan(five.length));
      expect(ten.every((post) => post.meters! <= 10000), true);
      expect(
        (await store.loadFeed(1)).items
            .every((post) => post.distanceMeters! <= 10000),
        true,
      );

      final observer = ApiClient(
        storage: const FlutterSecureStorage(
          aOptions: AndroidOptions(
            storageNamespace: 'senmiydin_location_observer',
          ),
        ),
      );
      final observerAuth = AuthService(observer);
      await observerAuth.signIn('login', {
        'identifier': 'demo_ahmet',
        'password': 'Demo1234!',
      });
      addTearDown(() async {
        await observerAuth.logout();
        observer.dispose();
      });
      Future<bool> demoVisible() async {
        final data = await observer.send(
          'GET',
          'nearby/users',
          authenticated: true,
        ) as Map;
        return (data['items'] as List).any(
          (entry) => entry['username'] == pixelLocation,
        );
      }

      expect(await demoVisible(), true);

      await tap(find.text('Profil'));
      await tap(find.byTooltip('Ayarlar'));
      await tap(find.text('Gizlilik ve Konum'));
      final nearbyToggle = find.text("Yakınındaki İnsanlar'da görün");
      await tap(nearbyToggle);
      await until(
        () => store.account?.nearbyVisible == false,
        'Yakın görünürlük kapalı',
      );
      expect(await demoVisible(), false);
      await tap(nearbyToggle);
      await until(
        () => store.account?.nearbyVisible == true,
        'Yakın görünürlük açık',
      );

      await tap(find.widgetWithText(ChoiceChip, 'Konum'));
      final historyToggle = find.text('Geçtiğim Yerler');
      await tap(historyToggle);
      await tap(find.widgetWithText(FilledButton, 'Aç'));
      await until(
        () => store.account?.locationHistoryEnabled == true,
        'Konum geçmişi açık',
      );

      if (const bool.fromEnvironment('CHECK_ANDROID_BACKGROUND')) {
        await until(
          () => (store.location?.position?.latitude ?? 0) > 36.55,
          'Arka plan konum hareketi',
          attempts: 480,
        );
      }
      await tap(historyToggle);
      await until(
        () => store.account?.locationHistoryEnabled == false,
        'Konum geçmişi kapalı',
      );
      await store.signOut();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: pixelPassword.isEmpty,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
