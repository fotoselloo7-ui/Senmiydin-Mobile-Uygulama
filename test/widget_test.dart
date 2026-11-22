import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/screens/auth.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/core/theme.dart';

Future<void> loadFont() async {
  final loader = FontLoader('NunitoSans')
    ..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFont);
  test('Every primary text style has an explicit readable navy color', () {
    final text = buildTheme().textTheme;
    expect(buildTheme().chipTheme.labelStyle!.color, AppColors.navy);
    expect(text.bodySmall!.color, AppColors.muted);
    for (final style in [
      text.bodyMedium,
      text.bodyLarge,
      text.titleMedium,
      text.titleLarge,
      text.headlineMedium,
    ]) {
      expect(style!.color, AppColors.navy);
      expect(style.fontFamily, 'NunitoSans');
    }
  });
  setUp(() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  });
  testWidgets(
    'Splash advances to onboarding; the demo enters the real navigation',
    (t) async {
      await t.pumpWidget(SenMiydinApp(store: AppStore()));
      expect(find.byType(SplashPage), findsOneWidget);
      // The gaze starts when the artwork is on screen (about 1.8 s): decode it first, then let the splash play out.
      await t.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/brand/splash_eyeless.png'),
          t.element(find.byType(SplashPage)),
        );
      });
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
      await t.tap(find.text('Uygulamayı keşfet'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('compose-button')), findsOneWidget);
      expect(find.text('Yakınındaki İnsanlar'), findsOneWidget);
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(891, 411),
  ]) {
    testWidgets(
      'All mobile routes render and scroll at ${size.width}x${size.height}',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final errorHook = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          errorHook?.call(details);
        };
        await t.pumpWidget(
          SenMiydinApp(store: AppStore(), initialRoute: '/home'),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'home');
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        final routes = <String, Object?>{
          '/welcome': null,
          '/register': null,
          '/login': null,
          '/forgot': null,
          '/social': 'Google',
          '/complete': null,
          '/interests': true,
          '/permissions': null,
          '/map': null,
          '/nearby': null,
          '/search': null,
          '/tag': null,
          '/filters': null,
          '/compose': null,
          '/camera': null,
          '/encounter': 'e2',
          '/encounters': null,
          '/featured': null,
          '/post': 'p0',
          '/comments': 'p0',
          '/profile': 'u1',
          '/edit-profile': null,
          '/people': 'Takip',
          '/saved': null,
          '/notifications': null,
          '/messages': null,
          '/chat': 'u1',
          '/share': 'p0',
          '/settings': null,
          '/preferences': null,
          '/blocked': null,
          '/report': 'Paylaşım p0',
          '/delete-account': null,
          '/legal': 'Gizlilik Politikası',
        };
        for (final route in routes.entries) {
          nav.pushNamed(route.key, arguments: route.value);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '${route.key} top');
          final scrolls = find.byType(Scrollable).hitTestable();
          if (scrolls.evaluate().isNotEmpty) {
            await t.drag(scrolls.first, const Offset(0, -900));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '${route.key} scroll');
          }
          nav.pop();
          await t.pumpAndSettle();
          // /comments is a bridge: the post opens and raises the comments sheet over it, so there are two routes to close.
          if (route.key == '/comments') {
            nav.pop();
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull, reason: '${route.key} back');
        }
        for (final id in [1, 3, 4, 0]) {
          await t.tap(find.byKey(Key('nav-$id')));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'tab $id');
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'Encounter: home → compose → username search → publish → approve → featured',
    (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = AppStore();
      final before = store.featured.length;
      await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('compose-button')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('post-text')),
        'Sahilde aynı şarkıyı dinledik. Sen miydin?',
      );
      await t.ensureVisible(find.text('Karşılaşma').last);
      await t.tap(find.text('Karşılaşma').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Karşılaştığım kişiyi etiketle'));
      await t.tap(find.text('Karşılaştığım kişiyi etiketle'));
      await t.pumpAndSettle();
      expect(find.byType(UserRow), findsNothing);
      await t.enterText(find.byKey(const Key('tag-search')), '@elifb');
      await t.pumpAndSettle();
      expect(find.byType(UserRow), findsOneWidget);
      await t.tap(find.text('Elif Bozkurt'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('publish-post')));
      await t.tap(find.byKey(const Key('publish-post')));
      await t.pumpAndSettle();
      expect(store.encounters.first.status, EncounterStatus.pending);
      expect(store.featured.length, before);
      await t.ensureVisible(find.byKey(const Key('approve-encounter')));
      await t.tap(find.byKey(const Key('approve-encounter')));
      await t.pumpAndSettle();
      expect(store.encounters.first.status, EncounterStatus.approved);
      expect(store.featured.length, before + 1);
      expect(find.text('Karşılaşmalarım'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Forms and chat fit a small screen with the keyboard and enlarged text',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final errorHook = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        errorHook?.call(details);
      };
      await t.pumpWidget(
        SenMiydinApp(store: AppStore(), initialRoute: '/home'),
      );
      await t.pumpAndSettle();
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      for (final route in [
        '/register',
        '/complete',
        '/compose',
        '/comments',
        '/chat',
        '/report',
        '/search',
        '/tag',
      ]) {
        nav.pushNamed(
          route,
          arguments: route == '/chat'
              ? 'u1'
              : route == '/comments'
              ? 'p0'
              : null,
        );
        await t.pumpAndSettle();
        t.view.viewInsets = const FakeViewPadding(bottom: 250);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$route with keyboard');
        t.view.resetViewInsets();
        await t.pumpAndSettle();
        nav.pop();
        await t.pumpAndSettle();
        if (route == '/comments') {
          nav.pop();
          await t.pumpAndSettle();
        }
      }
    },
  );
}
