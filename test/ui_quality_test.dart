import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senmiydin/core/theme.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/data/social_api.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/screens/auth.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/widgets/social.dart';
import 'package:senmiydin/widgets/social_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NunitoSans',
    )..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'))).load();
  });

  test('Action and secondary text keep readable contrast on white', () {
    double contrast(Color first, Color second) {
      final a = first.computeLuminance(), b = second.computeLuminance();
      return (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
    }

    expect(contrast(AppColors.action, Colors.white), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.muted, Colors.white), greaterThanOrEqualTo(4.5));
    expect(
      contrast(AppColors.action, AppColors.pale),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrast(AppColors.danger, Colors.white), greaterThanOrEqualTo(4.5));
  });

  test(
    'Every added content filter sends the actual existing API type',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final sent = <String?>[];
      final api = ApiClient(
        httpClient: MockClient((request) async {
          final Object data;
          if (request.url.path.endsWith('/auth/login')) {
            data = {
              'token': 'test-token',
              'user': {
                'id': 1,
                'name': 'Deniz',
                'username': 'deniz',
                'city': {'id': 1, 'name': 'Alanya'},
                'avatar': null,
                'bio': '',
                'occupation_school': '',
                'connections': [],
                'interests': [],
                'onboarding_step': 3,
                'nearby_visible': false,
                'encounter_suggestions': false,
                'city_discovery': true,
                'location_history_enabled': false,
              },
            };
          } else {
            if (request.url.path.endsWith('/feed')) {
              sent.add(request.url.queryParameters['content']);
            }
            data = {'items': [], 'next_page': null};
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final store = AppStore(api: api);
      addTearDown(store.dispose);
      await store.signIn('login', {
        'identifier': 'deniz',
        'password': 'test-password',
      });
      for (final label in ['Anı', 'İtiraf', 'Düşünce', 'Yolculuk']) {
        store.applyFilter(FeedFilter()..content = label);
        await store.loadFeed(1);
      }
      expect(sent, ['moment', 'confession', 'thought', 'travel']);
    },
  );

  testWidgets(
    'Combined filters (Karşılaşmalar + Fotoğraflı + 10 km + Yeni) compose without resetting each other',
    (t) async {
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
      await t.pumpAndSettle();
      unawaited(
        t
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/filters'),
      );
      await t.pumpAndSettle();
      for (final label in ['10 km', 'Yeni', 'Karşılaşmalar', 'Fotoğraflı']) {
        final chip = find.widgetWithText(ChoiceChip, label);
        await t.scrollUntilVisible(
          chip,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await t.pumpAndSettle();
        await t.tap(chip);
        await t.pumpAndSettle();
        expect(
          t.widget<ChoiceChip>(chip).selected,
          true,
          reason: '$label must be selected when tapped',
        );
      }
      await t.tap(find.widgetWithText(FilledButton, 'Uygula'));
      await t.pumpAndSettle();
      expect(store.filter.range, '10 km');
      expect(store.filter.sort, 'Yeni');
      expect(store.filter.content, 'Karşılaşmalar');
      expect(store.filter.media, 'Fotoğraflı');
      expect(
        store.feed.every(
          (p) =>
              p.kind == PostKind.encounter &&
              p.images.isNotEmpty &&
              p.distance <= 10,
        ),
        true,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Filter selection is applied, and unsupported combinations are not fabricated',
    (t) async {
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
      await t.pumpAndSettle();
      unawaited(
        t
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/filters'),
      );
      await t.pumpAndSettle();
      final choice = find.widgetWithText(ChoiceChip, 'Yolculuk');
      await t.ensureVisible(choice);
      await t.pumpAndSettle();
      await t.tap(choice);
      await t.pumpAndSettle();
      expect(t.widget<ChoiceChip>(choice).selected, true);
      await t.tap(find.widgetWithText(FilledButton, 'Uygula'));
      await t.pumpAndSettle();
      expect(store.filter.content, 'Yolculuk');
      expect(store.feed.every((p) => p.kind == PostKind.journey), true);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Profile edit protects changes on back and preserves the form when cancelled',
    (t) async {
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
      await t.pumpAndSettle();
      unawaited(
        t
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/edit-profile'),
      );
      await t.pumpAndSettle();
      final name = find.descendant(
        of: find.widgetWithText(Field, 'Ad Soyad'),
        matching: find.byType(TextFormField),
      );
      await t.ensureVisible(name);
      await t.enterText(name, 'Değişen Ad');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Geri'));
      await t.pumpAndSettle();
      expect(find.text('Değişiklikler kaydedilmedi'), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(find.text('Değişen Ad'), findsOneWidget);
      await t.tap(find.byTooltip('Geri'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kaydetmeden Çık'));
      await t.pumpAndSettle();
      expect(store.me.name, isNot('Değişen Ad'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Secure fields expose a labelled visibility control without losing content',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: Field('Şifre', Icons.lock_outline, obscure: true),
          ),
        ),
      );
      final input = find.byType(TextFormField);
      await t.enterText(input, 'ornek-metin');
      expect(
        t.widget<EditableText>(find.byType(EditableText)).obscureText,
        true,
      );
      await t.tap(find.byTooltip('Şifreyi göster'));
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).obscureText,
        false,
      );
      expect(find.text('ornek-metin'), findsOneWidget);
    },
  );

  testWidgets(
    'Anonymous text posts reveal neither owner nor a media placeholder',
    (t) async {
      final store = AppStore();
      await t.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: PostCard(
                Post(
                  id: 'private-owner',
                  authorId: store.me.id,
                  text: 'Şehirde bir anı.',
                  anonymous: true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Anonim'), findsOneWidget);
      expect(find.text(store.me.name), findsNothing);
      expect(find.byType(ImageCarousel), findsNothing);
      expect(t.widget<Avatar>(find.byType(Avatar)).person, isNull);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Home does not imply nearby people are online or invent activity counts',
    (t) async {
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
      await t.pumpAndSettle();
      expect(find.textContaining('27 yeni iz'), findsNothing);
      expect(
        t
            .widgetList<Avatar>(find.byType(Avatar))
            .where((avatar) => avatar.online),
        isEmpty,
      );
      expect(
        t.getSize(find.byKey(const Key('compose-button'))).shortestSide,
        greaterThanOrEqualTo(48),
      );
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Paged lists offer accessible placeholders and retry the failed first page once',
    (t) async {
      var calls = 0;
      final first = Completer<SocialPage<String>>();
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: PagedContent<String>(
              fetch: (_) {
                calls++;
                return calls == 1
                    ? first.future
                    : Future.value(const SocialPage(['Hazır'], null));
              },
              builder: (_, items, footer, _) => ListView(
                children: [for (final item in items) Text(item), ?footer],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LoadingState), findsOneWidget);
      first.completeError(const ApiFailure('Bağlantı kurulamadı.'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tekrar Dene'));
      await t.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Hazır'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Read-only profile interests remain readable without a fake tap action',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: const Scaffold(body: InterestChip('Müzik')),
          ),
        );
        expect(find.bySemanticsLabel('Müzik'), findsOneWidget);
        expect(find.byType(ActionChip), findsNothing);
        expect(t.widget<Text>(find.text('Müzik')).style?.color, AppColors.navy);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Search and post counts expose descriptive accessible labels', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    try {
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/search'));
      await t.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('İnsan, kullanıcı adı veya paylaşım ara')),
        findsWidgets,
      );
      await t.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: PostCard(
                Post(
                  id: 'semantic-post',
                  authorId: store.me.id,
                  text: 'Bir anı.',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Yorumlar, 0'), findsOneWidget);
      expect(find.bySemanticsLabel('Beğen, 0'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'Settings separates history collection from story notifications',
    (t) async {
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/settings'));
      await t.pumpAndSettle();
      expect(find.text('HESAP VE PROFİL'), findsOneWidget);
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(nav.pushNamed('/preferences', arguments: 'Konum'));
      await t.pumpAndSettle();
      expect(find.text('Geçtiğim Yerler'), findsOneWidget);
      expect(find.text('Geçtiğim yer bildirimleri'), findsNothing);
      expect(store.preferences['Geçtiğim yer bildirimleri'], false);
      final link = find.text('Geçtiğim Yerlerden Haber Ver');
      await t.ensureVisible(link);
      await t.pumpAndSettle();
      await t.tap(link);
      await t.pumpAndSettle();
      expect(
        t
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Bildirimler'))
            .selected,
        true,
      );
      expect(store.preferences['Geçtiğim yer bildirimleri'], false);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Long city names remain fully readable on a narrow screen with large text',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final store = AppStore()..city = 'Afyonkarahisar';
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
      await t.pumpAndSettle();
      final city = find.text('Afyonkarahisar');
      expect(city, findsOneWidget);
      expect(t.widget<Text>(city).overflow, isNot(TextOverflow.ellipsis));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  for (final route in [
    '/home',
    '/profile',
    '/filters',
    '/settings',
    '/preferences',
    '/search',
    '/permissions',
    '/interests',
    '/messages',
    '/saved',
  ]) {
    testWidgets('Small viewport and enlarged text remain usable: $route', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final store = AppStore();
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: route));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: route);
      final scroll = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .hitTestable();
      if (scroll.evaluate().isNotEmpty) {
        await t.drag(scroll.first, const Offset(0, -420));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$route scrolled');
      }
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }

  /// Shows the splash with its artwork already decoded (so the gaze, which starts when the artwork is visible, begins
  /// on the first frames), and returns once it has started.
  Future<void> showSplash(
    WidgetTester t, {
    bool disableAnimations = false,
  }) async {
    final store = AppStore();
    addTearDown(store.dispose);
    Widget page = const MaterialApp(home: SplashPage());
    if (disableAnimations) {
      page = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: page,
      );
    }
    await t.pumpWidget(StoreScope(store: store, child: page));
    await t.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand/splash_eyeless.png'),
        t.element(find.byType(SplashPage)),
      );
    });
    await t.pump();
    await t.pump();
  }

  double leftPupil(WidgetTester t) =>
      t.widget<Positioned>(find.byKey(const Key('splash-pupil-left'))).left!;
  double rightPupil(WidgetTester t) =>
      t.widget<Positioned>(find.byKey(const Key('splash-pupil-right'))).left!;

  testWidgets(
    'Animated splash: about 1.8 s from the moment the artwork is visible, pupils only: centre, a little right, a little left, back to the centre',
    (t) async {
      await showSplash(t);
      expect(find.byType(ClipOval), findsNWidgets(2));
      final leftCenter0 = leftPupil(t);
      final rightCenter0 = rightPupil(t);

      // The gaze holds the centre first (0.3 s), then looks right.
      await t.pump(const Duration(milliseconds: 200));
      expect((leftPupil(t) - leftCenter0).abs(), lessThan(2.0));
      await t.pump(
        const Duration(milliseconds: 500),
      ); // 0.7 s: holding the right gaze
      expect(leftPupil(t), greaterThan(leftCenter0 + 25));
      expect(rightPupil(t), greaterThan(rightCenter0 + 20));

      // 1.3 s: holding the left gaze
      await t.pump(const Duration(milliseconds: 600));
      expect(leftPupil(t), lessThan(leftCenter0 - 25));
      expect(rightPupil(t), lessThan(rightCenter0 - 20));

      // 1.8 s: back at the centre, and the animation is over
      await t.pump(const Duration(milliseconds: 500));
      expect((leftPupil(t) - leftCenter0).abs(), lessThan(2.0));
      expect((rightPupil(t) - rightCenter0).abs(), lessThan(2.0));
      await t.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'The gaze still plays when the system animation scale is off (disableAnimations): the eyes visibly move',
    (t) async {
      await showSplash(t, disableAnimations: true);
      final start = leftPupil(t);
      await t.pump(const Duration(milliseconds: 700));
      expect(leftPupil(t), greaterThan(start + 25));
      await t.pump(const Duration(milliseconds: 600));
      expect(leftPupil(t), lessThan(start - 25));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 500));
    },
  );
}
