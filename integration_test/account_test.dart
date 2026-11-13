import 'device_accounts.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Account setup, profile edit, secure restore, logout and login', (
    tester,
  ) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'senmiydin_account_test'),
    );
    const username = pixelRegistrationUsername;
    const email = pixelRegistrationEmail;
    const password = pixelPassword;
    final stores = <AppStore>{};
    AppStore newStore() {
      final created = AppStore(api: ApiClient(storage: storage));
      stores.add(created);
      return created;
    }

    void disposeStore(AppStore value) {
      if (stores.remove(value)) value.dispose();
    }

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final value in stores.toList()) {
        disposeStore(value);
      }
    });
    await storage.delete(key: 'senmiydin.session.token');
    var store = newStore();
    addTearDown(() async {
      await storage.delete(key: 'senmiydin.session.token');
    });

    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 80; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (finder.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      fail('Ekranda bulunamadı: $finder');
    }

    Future<void> tap(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 225);
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> hideKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label);
      if (field.evaluate().isEmpty) await tester.scrollUntilVisible(field, 225);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, text);
      await hideKeyboard();
    }

    Future<void> chooseCity(String current, String wanted) async {
      await tap(find.text(current).last);
      await tester.enterText(
        find.widgetWithText(TextField, 'Şehir ara'),
        wanted,
      );
      await hideKeyboard();
      await waitFor(find.widgetWithText(ListTile, wanted));
      await tap(find.widgetWithText(ListTile, wanted));
    }

    await tester.pumpWidget(SenMiydinApp(store: store));
    await waitFor(find.text('Uygulamayı keşfet'));
    await tap(find.text('Uygulamayı keşfet'));
    await enter('Ad Soyad', 'Ada Kaya');
    await enter('Kullanıcı Adı', username);
    await enter('E-posta', email);
    await enter('Şifre', password);
    await tap(find.text('Doğum Tarihi'));
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    await tap(find.text(localizations.okButtonLabel));
    await chooseCity('Alanya', 'Ankara');
    await tap(find.byType(Checkbox));
    await tap(find.text('Devam Et').last);
    await waitFor(find.text('Profilini Tamamla'));
    expect(store.account?.username, username);
    debugPrint('SENMIYDIN_ACCOUNT_CREATED:${store.account!.id}');
    expect(store.account?.city.name, 'Ankara');

    await enter(
      'Kısa Biyografi',
      'Nehir kıyısında yürümeyi ve kahveyi seviyorum.',
    );
    await enter('Meslek / Okul', 'Mühendis');
    await tap(find.text('Sohbet'));
    await tap(find.text('Konumumu şehir içinde göster'));
    await tap(find.text('Devam Et').last);

    await waitFor(find.text('Hobilerini Seç'));
    await waitFor(find.text('Kahve'));
    for (final hobby in [
      'Kahve',
      'Müzik',
      'Kitap',
      'Seyahat',
      'Sahil yürüyüşü',
    ]) {
      await tap(find.text(hobby));
    }
    await tap(find.text('Devam Et').last);
    await waitFor(find.text('Kontrol Sende'));
    await tap(find.text('Şehir içinde keşif'));
    await tap(find.text('Keşfetmeye Başla'));
    await waitFor(find.text('Ana Sayfa'));
    expect(store.account?.interests, hasLength(5));
    expect(store.account?.onboardingStep, 3);
    expect(store.account?.nearbyVisible, true);
    expect(store.account?.cityDiscovery, true);

    await tap(find.text('Profil'));
    expect(
      find.text('Nehir kıyısında yürümeyi ve kahveyi seviyorum.'),
      findsOneWidget,
    );
    await tap(find.text('Profili Düzenle'));
    await enter('Ad Soyad', 'Ada Yılmaz');
    await tap(find.text('Değişiklikleri Kaydet'));
    await waitFor(find.text('Ada Yılmaz'));

    await tester.pumpWidget(const SizedBox.shrink());
    disposeStore(store);
    store = newStore();
    await tester.pumpWidget(SenMiydinApp(store: store));
    await waitFor(find.text('Ana Sayfa'));
    expect(store.account?.name, 'Ada Yılmaz');
    expect(store.account?.interests, hasLength(5));

    await tap(find.text('Profil'));
    await tap(find.byTooltip('Ayarlar').last);
    await tap(find.text('Çıkış Yap'));
    await waitFor(find.text('E-posta veya kullanıcı adı'));
    expect(store.account, isNull);
    expect(await storage.read(key: 'senmiydin.session.token'), isNull);
    await enter('E-posta veya kullanıcı adı', username.toUpperCase());
    await enter('Şifre', password);
    await tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await waitFor(find.text('Ana Sayfa'));
    expect(store.account?.name, 'Ada Yılmaz');
    await tap(find.text('Profil'));
    await tap(find.byTooltip('Ayarlar').last);
    await tap(find.text('Hesabımı Sil'));
    await enter('Şifre', password);
    final confirmation = find.byKey(const Key('delete-confirmation'));
    if (confirmation.evaluate().isEmpty) {
      await tester.scrollUntilVisible(confirmation, 200);
    }
    await tester.enterText(confirmation, 'SİL');
    await hideKeyboard();
    await tap(find.byKey(const Key('delete-account')));
    await waitFor(find.text('E-posta veya kullanıcı adı'));
    expect(store.account, isNull);
    expect(await storage.read(key: 'senmiydin.session.token'), isNull);
    final rejected = ApiClient(storage: storage);
    await expectLater(
      AuthService(rejected)
          .signIn('login', {'identifier': username, 'password': password}),
      throwsA(isA<ApiFailure>().having((error) => error.status, 'status', 401)),
    );
    rejected.dispose();
    debugPrint(
      'The disposable Pixel account was erased through the password-confirmed form.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    disposeStore(store);
  }, skip: pixelPassword.isEmpty);
}
