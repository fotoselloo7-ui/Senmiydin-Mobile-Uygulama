import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/social_sign_in.dart';
import 'package:senmiydin/l10n/en_catalog.dart';
import 'package:senmiydin/screens/auth.dart';
import 'package:senmiydin/screens/compose.dart';
import 'package:senmiydin/screens/settings.dart';
import 'package:senmiydin/widgets/common.dart';

/// Release QA for the global location model, the Google / Apple first sign-in, onboarding Back and the language
/// switch. The localization audit renders real screens in both languages and fails on any system text left in the
/// other language (the static l10n audit cannot see strings that are in the catalogue but rendered untranslated).
void main() {
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(
    AppStore store,
    Widget home, {
    Map<String, WidgetBuilder> routes = const {},
  }) => StoreScope(
    store: store,
    child: MaterialApp(
      home: home,
      onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
        settings: settings,
        builder: routes[settings.name] ??
            (_) => Scaffold(body: Text('route ${settings.name}')),
      ),
    ),
  );

  http.Response ok(Object? data, {int status = 200}) => http.Response(
    jsonEncode({'success': status < 400, 'message': '', 'data': data}),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  AppStore online(Future<http.Response> Function(http.Request) handler) {
    FlutterSecureStorage.setMockInitialValues({});
    return AppStore(api: ApiClient(httpClient: MockClient(handler)));
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Localization audit
  // ---------------------------------------------------------------------------------------------------------------

  /// Every piece of text on screen (labels, hints, buttons, list rows, dropdown values).
  Set<String> visibleTexts(WidgetTester tester) => {
    for (final rich in tester.widgetList<RichText>(
      find.byType(RichText, skipOffstage: false),
    ))
      rich.text.toPlainText().trim(),
  }..removeWhere((text) => text.isEmpty);

  final turkishLetters = RegExp('[çğıöşüÇĞİÖŞÜ]');
  final englishValues = {
    for (final entry in enCatalog.entries)
      if (entry.key != entry.value) entry.value,
  };

  /// Names and examples that are content, not system text (proper nouns, people, places, sample data).
  bool content(String text, Set<String> allowed) =>
      allowed.contains(text) ||
      allowed.any((name) => name.isNotEmpty && text.contains(name));

  List<String> wrongLanguage(
    WidgetTester tester, {
    required bool english,
    Set<String> allowed = const {},
  }) => [
    for (final text in visibleTexts(tester))
      if (!content(text, allowed) &&
          (english
              ? (enCatalog[text] != null && enCatalog[text] != text) ||
                    turkishLetters.hasMatch(text)
              : englishValues.contains(text) && !enCatalog.containsKey(text)))
        text,
  ];

  Future<void> audit(
    WidgetTester tester,
    Widget Function() screen, {
    AppStore? store,
    Future<void> Function()? prepare,
    Set<String> allowed = const {},
  }) async {
    tall(tester);
    for (final english in [true, false]) {
      AppLocale.debugSet(Locale(english ? 'en' : 'tr'));
      final scoped = store ?? AppStore();
      await tester.pumpWidget(app(scoped, screen()));
      await tester.pumpAndSettle();
      if (prepare != null) await prepare();
      expect(
        wrongLanguage(tester, english: english, allowed: allowed),
        isEmpty,
        reason: english ? 'Turkish left in English' : 'English left in Turkish',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      if (store == null) scoped.dispose();
    }
  }

  // People and places of the offline preview data, the brand and the age badge.
  const preview = {
    'SenMiydin',
    'Alanya',
    'İstanbul',
    'Selman',
    'Sönmez',
    'deniz@example.com',
    'Deniz',
  };

  group('Localization audit (English and Turkish, no restart)', () {
    testWidgets('Journey: the company, trip code and plate fields follow the language', (tester) async {
      await audit(
        tester,
        () => const ComposePage(),
        allowed: preview,
        prepare: () async {
          await tester.tap(find.text(tr('Yolculuk')).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(tr('Yolculuk bilgilerini ekle')));
          await tester.pumpAndSettle();
          if (AppLocale.english) {
            expect(find.text('Company / operator'), findsOneWidget);
            expect(find.text('Trip / vehicle code'), findsOneWidget);
            expect(find.text('Plate / vehicle identifier (optional)'), findsOneWidget);
            expect(find.text('Firma / işletmeci'), findsNothing);
          } else {
            expect(find.text('Firma / işletmeci'), findsOneWidget);
          }
        },
      );
    });

    testWidgets('Sign-up with e-mail', (tester) async {
      await audit(tester, () => const AuthPage(register: true), allowed: preview);
    });

    testWidgets('Google profile completion', (tester) async {
      await audit(
        tester,
        () => const AuthPage(
          register: true,
          social: SocialCredential('google', {}, email: 'deniz@example.com', name: 'Deniz'),
        ),
        allowed: preview,
      );
    });

    testWidgets('Profile completion, interests and permissions (setup)', (tester) async {
      await audit(tester, () => const CompleteProfilePage(), allowed: preview);
      await audit(tester, () => const InterestsPage(setup: true), allowed: preview);
      await audit(tester, () => const PermissionsPage(), allowed: preview);
    });

    testWidgets('Settings, account deletion and creating an app password', (tester) async {
      await audit(tester, () => const SettingsPage(), allowed: preview);
      await audit(tester, () => const DeleteAccountPage(), allowed: preview);
      await audit(tester, () => const ForgotPage(email: 'deniz@example.com', create: true), allowed: preview);
    });

    testWidgets('Location picker with results', (tester) async {
      final store = online((request) async => ok({
        'items': [
          {
            'token': 't1', 'name': 'Oba Mahallesi', 'context': 'Alanya · Antalya · Türkiye',
            'label': 'Oba Mahallesi, Alanya, Antalya', 'type': 'village', 'country_code': 'tr',
          },
        ],
        'attribution': '© OpenStreetMap',
      }));
      addTearDown(store.dispose);
      await audit(
        tester,
        () => Scaffold(body: PlacePicker(store, title: 'Konumunu seç')),
        store: store,
        allowed: {'Oba Mahallesi', 'Alanya · Antalya · Türkiye'},
        prepare: () async {
          await tester.enterText(find.byKey(const Key('place-search')), 'Oba');
          await tester.tap(find.byKey(const Key('place-search-button')));
          await tester.pumpAndSettle();
          expect(find.text('Oba Mahallesi'), findsOneWidget);
          expect(find.text(tr('Şehir, ilçe veya mahalle ara')), findsOneWidget);
          expect(find.text(tr('Konumunu seç')), findsOneWidget);
        },
      );
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  // Location picker
  // ---------------------------------------------------------------------------------------------------------------

  group('Location picker', () {
    testWidgets('searches only on submit, shows the real hierarchy and returns the chosen place with its area', (tester) async {
      final requests = <http.Request>[];
      final store = online((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/places/search')) {
          final q = request.url.queryParameters['q']!;
          if (q == 'zzz') return ok({'items': <Object>[], 'attribution': '© OpenStreetMap'});
          if (q == 'down') return ok(null, status: 503);
          return ok({
            'items': [
              {'token': 'oba', 'name': 'Oba Mahallesi', 'context': 'Alanya · Antalya · Türkiye', 'label': 'Oba Mahallesi, Alanya, Antalya'},
              {'token': 'mah', 'name': 'Mahmutlar', 'context': 'Alanya · Antalya · Türkiye', 'label': 'Mahmutlar, Alanya, Antalya'},
            ],
            'attribution': '© OpenStreetMap',
          });
        }
        expect(request.url.path, endsWith('/places/resolve'));
        expect(jsonDecode(request.body), {'token': 'mah'});
        return ok({
          'place': {'id': 7, 'name': 'Mahmutlar', 'context': 'Alanya · Antalya · Türkiye', 'label': 'Mahmutlar, Alanya, Antalya'},
          'city': {'id': 82, 'name': 'Alanya', 'slug': 'alanya'},
        });
      });
      addTearDown(store.dispose);
      ChosenPlace? chosen;
      await tester.pumpWidget(app(store, Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => chosen = await choosePlace(context),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Konumunu seç'), findsOneWidget);
      expect(find.text('Mevcut konumumu kullan'), findsOneWidget);
      expect(find.text('© OpenStreetMap katkıcıları'), findsOneWidget);

      // Typing never reaches the server; one letter is not a search.
      await tester.enterText(find.byKey(const Key('place-search')), 'M');
      await tester.pump();
      await tester.tap(find.byKey(const Key('place-search-button')));
      await tester.pumpAndSettle();
      expect(find.text('Aramak için en az 2 harf yaz.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('place-search')), 'Mahmutlar');
      await tester.pump();
      expect(requests, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(find.descendant(of: find.byKey(const Key('place-result-1')), matching: find.text('Mahmutlar')), findsOneWidget);
      expect(find.text('Alanya · Antalya · Türkiye'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('place-result-1')));
      await tester.pumpAndSettle();
      expect(chosen!.city.id, 82);
      expect(chosen!.placeId, 7);
      expect(chosen!.label, 'Mahmutlar, Alanya, Antalya');
      // The area is now known by name to the rest of the app.
      expect(await store.cityId('Alanya'), 82);

      // Empty results and a provider failure are readable, and the sheet stays usable.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('place-search')), 'zzz');
      await tester.tap(find.byKey(const Key('place-search-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('için sonuç bulunamadı'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('place-search')), 'down');
      await tester.tap(find.byKey(const Key('place-search-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('place-error')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  // Google first sign-in
  // ---------------------------------------------------------------------------------------------------------------

  group('Google first sign-in', () {
    testWidgets('a new Google account completes its profile without any password and with a real place', (tester) async {
      tall(tester);
      Map<String, dynamic>? sent;
      final store = online((request) async {
        if (request.url.path.endsWith('/places/search')) {
          return ok({'items': [
            {'token': 'oba', 'name': 'Oba Mahallesi', 'context': 'Alanya · Antalya · Türkiye', 'label': 'Oba Mahallesi, Alanya, Antalya'},
          ]});
        }
        if (request.url.path.endsWith('/places/resolve')) {
          return ok({
            'place': {'id': 7, 'name': 'Oba Mahallesi', 'label': 'Oba Mahallesi, Alanya, Antalya'},
            'city': {'id': 82, 'name': 'Alanya'},
          });
        }
        if (request.url.path.endsWith('/minimum-age') || request.url.path.endsWith('/app-config')) {
          return ok({'minimum_age': 16});
        }
        expect(request.url.path, endsWith('/auth/social/google'));
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return ok({
          'token': 'session',
          'user': {
            'id': 1, 'name': 'Deniz Yıldız', 'username': 'deniz.yildiz', 'email': 'deniz.yildiz@example.com',
            'birth_date': '1995-01-01', 'city': {'id': 82, 'name': 'Alanya'}, 'place': null, 'has_password': false,
            'social_providers': ['google'], 'bio': '', 'occupation_school': '', 'connections': <String>[],
            'nearby_visible': false, 'encounter_suggestions': false, 'city_discovery': false, 'onboarding_step': 0,
            'interests': <Object>[], 'avatar': null, 'cover_image': null,
          },
        }, status: 201);
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(app(
        store,
        const AuthPage(
          register: true,
          social: SocialCredential('google', {'id_token': 'google-token'}, email: 'deniz.yildiz@example.com', name: 'Deniz Yıldız'),
        ),
        routes: {'/complete': (_) => const Scaffold(body: Text('complete-step'))},
      ));
      await tester.pumpAndSettle();

      // No password, no e-mail field: the verified address is shown, the name and a username are prefilled.
      expect(find.text('Profilini tamamla'), findsOneWidget);
      expect(find.text('Şifre'), findsNothing);
      expect(find.text('Şifre Tekrar'), findsNothing);
      expect(find.textContaining('deniz.yildiz@example.com'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Deniz Yıldız'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'deniz.yildiz'), findsOneWidget);

      // Birth date, place and the terms are still required.
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Doğum tarihini seçmelisin.'), findsOneWidget);
      expect(find.text('Konumunu seç.'), findsOneWidget);
      expect(sent, isNull);

      await tester.tap(find.byKey(const Key('register-place')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('place-search')), 'Oba');
      await tester.tap(find.byKey(const Key('place-search-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oba Mahallesi'));
      await tester.pumpAndSettle();
      expect(find.text('Oba Mahallesi, Alanya, Antalya'), findsOneWidget);

      await tester.ensureVisible(find.text('Doğum Tarihi'));
      await tester.tap(find.text('Doğum Tarihi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!.containsKey('password'), isFalse, reason: 'No password is ever sent for a Google sign-up.');
      expect(sent!['id_token'], 'google-token');
      expect(sent!['place_id'], 7);
      expect(sent!['city_id'], 82);
      expect(sent!['username'], 'deniz.yildiz');
      expect(sent!['name'], 'Deniz Yıldız');
      expect(sent!['birth_date'], isNotNull);
      expect(find.text('complete-step'), findsOneWidget);
      expect(store.account!.hasPassword, isFalse);
    });

    testWidgets('an account without an app password is offered to create one, never asked for the Google password', (tester) async {
      tall(tester);
      final store = online((request) async => ok({
        'token': 'session',
        'user': {
          'id': 1, 'name': 'Deniz', 'username': 'deniz', 'email': 'deniz@example.com', 'birth_date': '1995-01-01',
          'city': {'id': 82, 'name': 'Alanya'}, 'has_password': false, 'social_providers': ['google'], 'bio': '',
          'occupation_school': '', 'connections': <String>[], 'nearby_visible': false, 'encounter_suggestions': false,
          'city_discovery': false, 'onboarding_step': 3, 'interests': <Object>[], 'avatar': null, 'cover_image': null,
        },
      }));
      addTearDown(store.dispose);
      await store.signIn('login', {});
      await tester.pumpWidget(app(store, const SettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Uygulama şifresi oluştur'), findsOneWidget);
      expect(find.text('Şifre Değiştir'), findsNothing);

      await tester.pumpWidget(app(store, const DeleteAccountPage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-password')), findsNothing);
      expect(find.textContaining('Google ile yeniden doğrulaman istenecek'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  // Onboarding Back
  // ---------------------------------------------------------------------------------------------------------------

  group('Onboarding Back', () {
    Map<String, WidgetBuilder> setupRoutes() => {
      '/complete': (_) => const CompleteProfilePage(),
      '/interests': (_) => const InterestsPage(setup: true),
      '/permissions': (_) => const PermissionsPage(),
      '/welcome': (_) => const Scaffold(body: Text('welcome')),
      '/home': (_) => const Scaffold(body: Text('home')),
    };

    Future<void> pick(WidgetTester tester, String interest) async {
      await tester.tap(find.text(interest));
      await tester.pumpAndSettle();
    }

    testWidgets('system Back and the back arrow go one step back, keep every choice and never close the app', (tester) async {
      tall(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const CompleteProfilePage(), routes: setupRoutes()));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Kısa Biyografi'), 'Sahilde yürümeyi severim');
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Hobilerini Seç'), findsOneWidget);
      final before = store.me.interests.length;
      for (final interest in ['Seyahat', 'Sinema', 'Kamp'].where((i) => !store.me.interests.contains(i))) {
        await pick(tester, interest);
      }
      final picked = tester.widget<Text>(find.textContaining('ilgi alanı seçtin')).data!;
      expect(picked, isNot(contains('$before ilgi')));

      // Android system Back: back to the profile step, with the text still there.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Profilini Tamamla'), findsWidgets);
      expect(find.text('Sahilde yürümeyi severim'), findsOneWidget);

      // Forward again: the three interests are still selected.
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text(picked), findsOneWidget);
      for (final interest in ['Yemek', 'Bisiklet', 'Oyun']) {
        if (find.text(tr(interest)).evaluate().isNotEmpty) await pick(tester, interest);
      }
      final chosen = tester.widget<Text>(find.textContaining('ilgi alanı seçtin')).data!;
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Kontrol Sende'), findsOneWidget);

      // The back arrow on the last step returns to the interests, still selected.
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.text(chosen), findsOneWidget);
      // One more Back reaches the first step; one more offers to leave setup instead of closing the app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Profilini Tamamla'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Kurulumdan çıkılsın mı?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('Profilini Tamamla'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çıkış Yap'));
      await tester.pumpAndSettle();
      expect(find.text('welcome'), findsOneWidget);
    });

    testWidgets('a name without a surname (e-mail sign-up) is asked for in setup instead of failing silently', (tester) async {
      tall(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      store.me
        ..name = 'deniz.kaya'
        ..handle = 'deniz.kaya';
      await tester.pumpWidget(app(store, const CompleteProfilePage(), routes: setupRoutes()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Ad Soyad'), findsOneWidget, reason: 'the missing name is asked for');
      expect(find.widgetWithText(TextField, 'Kullanıcı Adı'), findsNothing, reason: 'a valid username is not asked again');
      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Ad Soyad'));
      expect(field.controller!.text, isEmpty, reason: 'the username is not a name');

      await tester.enterText(find.widgetWithText(TextField, 'Ad Soyad'), 'Deniz');
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Hobilerini Seç'), findsNothing, reason: 'a first name alone does not continue');

      await tester.enterText(find.widgetWithText(TextField, 'Ad Soyad'), 'Deniz Kaya');
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Hobilerini Seç'), findsOneWidget);
      expect(store.me.name, 'Deniz Kaya');
    });

    testWidgets('a complete name is not asked for again in setup', (tester) async {
      tall(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      store.me
        ..name = 'Elif Bozkurt'
        ..handle = 'elif.bozkurt';
      await tester.pumpWidget(app(store, const CompleteProfilePage(), routes: setupRoutes()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Ad Soyad'), findsNothing);
    });

    testWidgets('reopened in the middle of setup, Back opens the previous step instead of a dead end', (tester) async {
      tall(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const PermissionsPage(), routes: setupRoutes()));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hobilerini Seç'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Profilini Tamamla'), findsWidgets);
    });
  });
}
