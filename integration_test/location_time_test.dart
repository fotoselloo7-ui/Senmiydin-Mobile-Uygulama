import 'device_accounts.dart';

import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/post_context.dart';
import 'package:senmiydin/main.dart';

const scenarioWriter = String.fromEnvironment('SCENARIO_WRITER');
const scenarioReader = String.fromEnvironment('SCENARIO_READER');
const scenarioPassword = String.fromEnvironment('SCENARIO_PASSWORD');

Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready,
  String label, {
  int attempts = 180,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (ready()) return;
  }
  fail('Beklenen durum oluşmadı: $label');
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      220,
      maxScrolls: 40,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enterField(WidgetTester tester, Finder target, String text) async {
  await tester.ensureVisible(target);
  await tester.enterText(target, text);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump(const Duration(milliseconds: 600));
}

Future<AppStore> signedStore(String user, String namespace) async {
  final storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: namespace),
  );
  await storage.delete(key: 'senmiydin.session.token');
  final store = AppStore(api: ApiClient(storage: storage));
  await store.signIn('login', {'identifier': user, 'password': pixelPassword});
  if (user != pixelLocation) {
    await store.location!.refresh();
    store.location!.configure(active: false, history: false);
  }
  return store;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'SenMiydin active city follows Ankara GPS and returns to Alanya without changing profile',
    (tester) async {
      final store = await signedStore(
        pixelLocation,
        'senmiydin_active_city_test',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      });
      await tester.pumpWidget(
        SenMiydinApp(store: store, initialRoute: '/home'),
      );
      await tester.pumpAndSettle();
      debugPrint('SENMIYDIN_GPS_ANKARA');
      for (var i = 0; i < 6 && store.city != 'Ankara'; i++) {
        await store.location!.refresh(force: true);
        await tester.pump(const Duration(seconds: 2));
      }
      await waitFor(tester, () => store.city == 'Ankara', 'Aktif şehir Ankara');
      expect(store.account!.city.name, 'Alanya');
      expect(store.me.city, 'Alanya');
      expect(
        (store.location!.position!.latitude - 39.9208).abs(),
        lessThan(.003),
      );
      expect(find.text('Ankara'), findsWidgets);
      debugPrint('SENMIYDIN_GPS_ALANYA');
      for (var i = 0; i < 6 && store.city != 'Alanya'; i++) {
        await store.location!.refresh(force: true);
        await tester.pump(const Duration(seconds: 2));
      }
      await waitFor(tester, () => store.city == 'Alanya', 'Aktif şehir Alanya');
      expect(store.account!.city.name, 'Alanya');
      await store.signOut();
    },
    skip: scenarioWriter.isEmpty,
  );

  testWidgets(
    'SenMiydin historical place and past time create a match, boosted feed and one notification',
    (tester) async {
      final writer = await signedStore(
        scenarioWriter,
        'senmiydin_history_writer_test',
      );
      final reader = await signedStore(
        scenarioReader,
        'senmiydin_history_reader_test',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        writer.dispose();
        reader.dispose();
      });
      await writer.setCity('İstanbul');
      await reader.setCity('İstanbul');
      await tester.pumpWidget(
        SenMiydinApp(store: writer, initialRoute: '/compose'),
      );
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.byKey(const Key('compose-button')).evaluate().isNotEmpty,
        'Ana Sayfa',
      );
      await writer.location!.refresh();
      writer.location!.configure(active: false, history: false);
      await writer.setCity('İstanbul');
      await tapVisible(tester, find.byKey(const Key('compose-button')));
      const message = 'Bugün Gülhane’de gördüğüm kişi sen miydin?';
      final before = (await writer.loadProfilePosts(
        scenarioWriter,
        1,
      )).items.map((p) => p.id).toSet();
      await enterField(tester, find.byKey(const Key('post-text')), message);
      await tapVisible(tester, find.text('Karşılaşma').first);
      await tapVisible(tester, find.text('Paylaşım yeri'));
      await tapVisible(tester, find.text('Geçtiğim yerlerden seç'));
      await waitFor(
        tester,
        () => find.text('İstanbul · Yaklaşık bölge').evaluate().isNotEmpty,
        'Geçmiş yer',
      );
      await tapVisible(tester, find.text('İstanbul · Yaklaşık bölge'));
      await tapVisible(tester, find.text('Ne zaman oldu?'));
      expect(find.text('Tarih / saat seç'), findsOneWidget);
      // Choosing a saved place supplies its rounded past hour; retain it instead of replacing with creation time.
      Navigator.of(tester.element(find.text('Tarih / saat seç'))).pop();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('publish-post')));
      final created = (await writer.loadProfilePosts(
        scenarioWriter,
        1,
      )).items.where((p) => !before.contains(p.id)).single;
      Post? matched;
      for (var i = 0; i < 30; i++) {
        final page = await reader.loadFeed(1);
        matched = page.items.where((p) => p.id == created.id).firstOrNull;
        if (matched?.matchHint != null) break;
        await tester.pump(const Duration(seconds: 1));
      }
      expect(matched, isNotNull);
      expect(matched!.occurredAt, isNotNull);
      expect(
        DateTime.now().difference(matched.occurredAt!).inMinutes,
        greaterThan(60),
      );
      expect(matched.matchHint, 'Geçtiğin bir bölgeden');
      expect(matched.encounterConfirmed, false);
      final notices = (await reader.communication!.inbox(1, false)).items
          .where(
            (n) =>
                n.type == 'location_match' &&
                n.entity.toString() == matched!.id,
          )
          .toList();
      expect(notices, hasLength(1));
      expect(notices.single.route, '/post');
      await tester.pumpWidget(
        SenMiydinApp(
          key: const ValueKey('history-reader'),
          store: reader,
          initialRoute: '/notifications',
        ),
      );
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.byTooltip('Bildirimler').evaluate().isNotEmpty,
        'Okuyucu Ana Sayfa',
      );
      await tapVisible(tester, find.byTooltip('Bildirimler'));
      await waitFor(
        tester,
        () => find
            .textContaining('Birine denk gelmiş olabilirsin')
            .evaluate()
            .isNotEmpty,
        'Eşleşme bildirimi',
      );
      await tapVisible(
        tester,
        find.textContaining('Birine denk gelmiş olabilirsin').first,
      );
      await waitFor(
        tester,
        () => find.text(message).evaluate().isNotEmpty,
        'Bildirimden gönderi',
      );
      expect(find.text('Geçtiğin bir bölgeden'), findsWidgets);
      await writer.signOut();
      await reader.signOut();
    },
    skip: scenarioWriter.isEmpty,
  );

  testWidgets(
    'SenMiydin Pamukkale Ankara Erzincan travel is recommended with optional vehicle and no group',
    (tester) async {
      final writer = await signedStore(
        scenarioWriter,
        'senmiydin_travel_writer_test',
      );
      final reader = await signedStore(
        scenarioReader,
        'senmiydin_travel_reader_test',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        writer.dispose();
        reader.dispose();
      });
      await writer.setCity('Ankara');
      await reader.setCity('Ankara');
      final details = TravelDetails(
        transport: 'bus',
        origin: CatalogItem(await writer.cityId('Ankara'), 'Ankara'),
        destination: CatalogItem(await writer.cityId('Erzincan'), 'Erzincan'),
        departureAt: DateTime.parse(
          const String.fromEnvironment('SCENARIO_DEPARTURE_AT'),
        ),
        operatorName: 'Pamukkale',
        vehicleIdentifier: '07 NM 365',
        isPublic: true,
      );
      final post = await writer.publishPost(
        body: 'Aynı otobüsteysen bir sonraki molada kahve içelim mi? ☕',
        kind: PostKind.journey,
        media: [],
        anonymous: false,
        cityWide: true,
        location: 'Ankara',
        requestId: const Uuid().v4(),
        travel: details,
      );
      Post? result;
      for (var i = 0; i < 30; i++) {
        result = (await reader.loadFeed(1)).items
            .where((p) => p.id == post.id)
            .firstOrNull;
        if (result?.matchHint != null) break;
        await tester.pump(const Duration(seconds: 1));
      }
      expect(result!.matchHint, 'Geçtiğin bir bölgeden');
      expect(result.travel!.vehicleIdentifier, '07 NM 365');
      await tester.pumpWidget(
        SenMiydinApp(store: reader, initialRoute: '/home'),
      );
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.byTooltip('Bildirimler').evaluate().isNotEmpty,
        'Yolculuk Ana Sayfa',
      );
      await reader.location!.refresh();
      reader.location!.configure(active: false, history: false);
      await reader.setCity('Ankara');
      await tester.pumpAndSettle();
      final journeyTitle = find.text('Ankara → Erzincan');
      final feedScrollable = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      for (var i = 0; i < 40 && journeyTitle.evaluate().isEmpty; i++) {
        await tester.drag(feedScrollable, const Offset(0, -220));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(journeyTitle, findsWidgets);
      await tester.ensureVisible(journeyTitle.first);
      await waitFor(
        tester,
        () => find.text('Ankara → Erzincan').evaluate().isNotEmpty,
        'Yolculuk kartı',
      );
      expect(find.text('Otobüs · Pamukkale'), findsWidgets);
      expect(find.text('07 NM 365'), findsWidgets);
      expect(find.text('Yolculuğa katıl'), findsNothing);
      expect(result.encounterConfirmed, false);
      await writer.signOut();
      await reader.signOut();
    },
    skip: scenarioWriter.isEmpty,
  );
}
