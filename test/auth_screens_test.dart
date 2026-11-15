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
import 'package:senmiydin/screens/auth.dart';
import 'package:senmiydin/widgets/auth_ui.dart';

/// The sign-in and sign-up screens (reference design): content, validation, inline errors, the Google / Apple
/// buttons, and the layouts that must never overflow (small screen, large text, open keyboard).
void main() {
  setUpAll(() async {
    final font = FontLoader('NunitoSans')
      ..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'));
    await font.load();
  });

  void screen(
    WidgetTester tester,
    double width,
    double height, {
    double keyboard = 0,
  }) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  Widget app(AppStore store, Widget page, {double textScale = 1}) => StoreScope(
    store: store,
    child: MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: page,
    ),
  );

  Future<AppStore> online(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    return AppStore(api: ApiClient(httpClient: MockClient(handler)));
  }

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  testWidgets(
    'Login: logo, title, fields, forgot link, call-to-action, Google and Apple, switch link and the 18+ note',
    (tester) async {
      screen(tester, 390, 844);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage()));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar karşılaşmaya hazır mısın?'), findsOneWidget);
      expect(
        find.text(
          'Hesabına giriş yap ve yarım kalan karşılaşmalarına devam et.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AuthField), findsNWidgets(2));
      expect(find.text('E-posta veya kullanıcı adı'), findsOneWidget);
      expect(find.text('Şifre'), findsOneWidget);
      expect(find.byTooltip('Şifreyi göster'), findsOneWidget);
      expect(find.text('Şifremi unuttum?'), findsOneWidget);
      expect(
        find.widgetWithText(AuthPrimaryButton, 'Giriş Yap'),
        findsOneWidget,
      );
      expect(find.text('veya'), findsOneWidget);
      expect(
        find.widgetWithText(AuthSocialButton, 'Google ile devam et'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AuthSocialButton, 'Apple ile devam et'),
        findsOneWidget,
      );
      expect(find.text('Hesabın yok mu?'), findsOneWidget);
      expect(find.text('Kayıt Ol'), findsOneWidget);
      expect(find.text('18+'), findsOneWidget);
      expect(find.textContaining('Kullanım Koşulları'), findsOneWidget);
      expect(find.textContaining('Gizlilik Politikası'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Login: an empty form shows the field errors, a filled one signs in (offline demo mode)',
    (tester) async {
      screen(tester, 390, 844);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AuthPrimaryButton, 'Giriş Yap'));
      await tester.pumpAndSettle();
      expect(find.text('Bu alanı doldurmalısın.'), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).at(0), 'ada@ornek.com');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ornek-parola-1',
      );
      await tester.pump();
      expect(find.text('Bu alanı doldurmalısın.'), findsNothing);
    },
  );

  testWidgets('Login: the password field hides and shows its content', (
    tester,
  ) async {
    screen(tester, 390, 844);
    final store = AppStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(app(store, const AuthPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'ornek-metin');
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(1)).obscureText,
      true,
    );
    await tester.tap(find.byTooltip('Şifreyi göster'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(1)).obscureText,
      false,
    );
  });

  testWidgets(
    'Login: a failed sign-in is shown inline, the form stays and the button is usable again',
    (tester) async {
      screen(tester, 390, 844);
      final store = await online((request) async {
        if (request.url.path.endsWith('/app-config')) {
          return json(200, {'success': true, 'data': <String, Object?>{}});
        }
        return json(422, {
          'success': false,
          'message': 'E-posta veya şifre hatalı.',
        });
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'ada');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'yanlis-parola-1',
      );
      await tester.tap(find.widgetWithText(AuthPrimaryButton, 'Giriş Yap'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthNotice), findsOneWidget);
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(
        find.widgetWithText(AuthPrimaryButton, 'Giriş Yap'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AuthPrimaryButton>(find.byType(AuthPrimaryButton))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Google and Apple without a configured provider explain it inline and keep the e-mail form',
    (tester) async {
      screen(tester, 390, 844);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage()));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(AuthSocialButton, 'Google ile devam et'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Google ile giriş şu anda kullanılamıyor'),
        findsOneWidget,
      );
      expect(find.byType(AuthField), findsNWidgets(2));
      await tester.tap(
        find.widgetWithText(AuthSocialButton, 'Apple ile devam et'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Apple ile giriş şu anda kullanılamıyor'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Register: content follows the reference (Google / Apple first, then the five fields, call-to-action, terms)',
    (tester) async {
      screen(tester, 390, 1200);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage(register: true)));
      await tester.pumpAndSettle();
      expect(find.text('SenMiydin?’e katıl'), findsOneWidget);
      expect(
        find.widgetWithText(AuthSocialButton, 'Google ile kayıt ol'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AuthSocialButton, 'Apple ile kayıt ol'),
        findsOneWidget,
      );
      expect(find.text('veya e-posta ile kayıt ol'), findsOneWidget);
      expect(find.byType(AuthField), findsNWidgets(4));
      for (final label in [
        'E-posta',
        'Şifre',
        'Şifre Tekrar',
        'Kullanıcı Adı',
        'Doğum Tarihi',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.widgetWithText(AuthPrimaryButton, 'Kayıt Ol'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.textContaining('18 yaşını doldurdum'), findsOneWidget);
      expect(find.textContaining('yalnızca bu yaş'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Register: nothing is sent until the form is valid; each problem is shown next to its field',
    (tester) async {
      screen(tester, 390, 1400);
      final store = AppStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage(register: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AuthPrimaryButton, 'Kayıt Ol'));
      await tester.pumpAndSettle();
      expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
      expect(
        find.text('En az 10 karakter, bir harf ve bir rakam kullan.'),
        findsOneWidget,
      );
      expect(
        find.text('3–24 harf, rakam, nokta veya alt çizgi kullan.'),
        findsOneWidget,
      );
      expect(find.text('Doğum tarihini seçmelisin.'), findsOneWidget);
      expect(
        find.text('Devam etmek için koşulları kabul etmelisin.'),
        findsOneWidget,
      );
      expect(
        find.byType(AuthPage),
        findsOneWidget,
        reason: 'still on the form',
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ada@ornek.com');
      await tester.enterText(fields.at(1), 'ornek-parola-1');
      await tester.enterText(fields.at(2), 'baska-parola-2');
      await tester.enterText(fields.at(3), 'ada_01');
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      await tester.enterText(fields.at(2), 'ornek-parola-1');
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsNothing);
      expect(find.text('Geçerli bir e-posta adresi gir.'), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(
        find.text('Devam etmek için koşulları kabul etmelisin.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Register: a server refusal is shown inline (for example a taken username)',
    (tester) async {
      screen(tester, 390, 1400);
      final store = await online((request) async {
        final path = request.url.path;
        if (path.endsWith('/app-config')) {
          return json(200, {
            'success': true,
            'data': {'minimum_age': 16},
          });
        }
        if (path.endsWith('/cities')) {
          return json(200, {
            'success': true,
            'data': [
              {'id': 1, 'name': 'Alanya'},
            ],
          });
        }
        return json(422, {
          'success': false,
          'message': 'Bu kullanıcı adı alınmış.',
        });
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(app(store, const AuthPage(register: true)));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ada@ornek.com');
      await tester.enterText(fields.at(1), 'ornek-parola-1');
      await tester.enterText(fields.at(2), 'ornek-parola-1');
      await tester.enterText(fields.at(3), 'ada_01');
      await tester.ensureVisible(find.text('Doğum Tarihi'));
      await tester.tap(find.text('Doğum Tarihi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(AuthPrimaryButton, 'Kayıt Ol'));
      await tester.pumpAndSettle();
      expect(find.text('Bu kullanıcı adı alınmış.'), findsOneWidget);
      expect(find.byType(AuthNotice), findsOneWidget);
    },
  );

  for (final register in [false, true]) {
    final name = register ? 'Register' : 'Login';
    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets(
          '$name never overflows at ${size.width.toInt()}x${size.height.toInt()}, text ×$scale, with and without the keyboard',
          (tester) async {
            for (final keyboard in [0.0, 280.0]) {
              screen(tester, size.width, size.height, keyboard: keyboard);
              final store = AppStore();
              addTearDown(store.dispose);
              await tester.pumpWidget(
                app(store, AuthPage(register: register), textScale: scale),
              );
              await tester.pumpAndSettle();
              // Scroll to the very end: every part is reachable and lays out.
              await tester.drag(
                find.byType(SingleChildScrollView).first,
                const Offset(0, -3000),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '$name ${size.width}x${size.height} ×$scale keyboard $keyboard',
              );
              await tester.pumpWidget(const SizedBox.shrink());
            }
          },
        );
      }
    }
  }
}
