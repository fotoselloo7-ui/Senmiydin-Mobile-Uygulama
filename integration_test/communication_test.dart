import 'device_accounts.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/data/account_api.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/screens/direct_chat.dart';
import 'package:uuid/uuid.dart';

class _Gallery extends ImagePickerPlatform {
  _Gallery(this.file);
  final XFile file;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Two accounts exchange messages and manage safety on Pixel 6a', (
    tester,
  ) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'senmiydin_communication_test',
      ),
    );
    const tokenKey = 'senmiydin.session.token';
    await storage.delete(key: tokenKey);
    addTearDown(() => storage.delete(key: tokenKey));
    if (!const bool.fromEnvironment('NATIVE_GALLERY')) {
      final folder = await Directory.systemTemp.createTemp(
        'senmiydin-message-',
      );
      final source = await rootBundle.load('assets/images/coast.jpg');
      final file = await File('${folder.path}/coast.jpg').writeAsBytes(
        source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
      );
      final picker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _Gallery(XFile(file.path));
      addTearDown(() async {
        ImagePickerPlatform.instance = picker;
        await file.delete();
        await folder.delete();
      });
    }
    final client = ApiClient(storage: storage);
    final store = AppStore(api: client);
    addTearDown(store.dispose);
    final uid = const Uuid().v4();
    const first = 'Merhaba Elif, sahildeki yürüyüşten sonra nasılsın?';
    const reply = 'Merhaba! İyiyim, yine yürüyüşe çıkacağım.';
    final input = find.byKey(const Key('chat-input'));
    final back = find.byTooltip('Geri');

    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (finder.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      fail('Could not find $finder');
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
        await tester.scrollUntilVisible(finder, 200, scrollable: vertical);
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> enter(Finder field, String value) async {
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
    }

    Future<void> login(String account) async {
      await waitFor(find.widgetWithText(OutlinedButton, 'Giriş Yap'));
      await tap(find.widgetWithText(OutlinedButton, 'Giriş Yap'));
      await enter(
        find.widgetWithText(TextFormField, 'E-posta veya kullanıcı adı'),
        account,
      );
      await enter(find.widgetWithText(TextFormField, 'Şifre'), pixelPassword);
      await tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
      await waitFor(find.text('Ana Sayfa'));
    }

    Future<void> changeAccount(String account) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await store.signOut();
      await tester.pumpWidget(SenMiydinApp(store: store));
      await login(account);
    }

    Future<void> go(String route, [Object? args]) async {
      final context = tester.element(find.byKey(const Key('nav-3')));
      Navigator.of(context).pushNamed(route, arguments: args);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(SenMiydinApp(store: store));
    await login(pixelMessageWriter);
    Future<void> updateLocation() async {
      await client.send(
        'PUT',
        'location',
        authenticated: true,
        body: {'latitude': 36.544, 'longitude': 32.0, 'accuracy': 25},
      );
    }

    await updateLocation();
    final nav = find.byKey(const Key('nav-3'));
    late int chat;
    late Person elif;

    await tap(find.byTooltip('Ara'));
    await enter(find.byKey(const Key('global-search')), pixelMessageReader);
    await waitFor(find.text('@$pixelMessageReader').first);
    await tap(find.text('@$pixelMessageReader').first);
    await tap(find.text('Mesaj'));
    await waitFor(input);
    await enter(input, first);
    await tap(find.byTooltip('Mesajı gönder'));
    await waitFor(find.text('Mesaj isteğin onay bekliyor.'));
    final outgoing = (await store.communication!.conversations(
      1,
      true,
      pixelMessageReader,
    )).items.single;
    chat = outgoing.id!;
    elif = outgoing.peer;
    debugPrint('Demo sent the initial message request.');

    await changeAccount(pixelMessageReader);
    await updateLocation();
    await store.communication!.registerDevice({
      'platform': 'android',
      'device_identifier': uid,
      'push_token': 'local-communication-$uid',
    });
    await tap(find.byTooltip('Bildirimler'));
    await waitFor(find.text('Yeni bir mesaj isteğin var.'));
    await tap(find.text('Yeni bir mesaj isteğin var.'));
    await waitFor(find.text('Kabul Et'));
    await tap(find.text('Kabul Et'));
    await waitFor(input);
    await enter(input, reply);
    await tap(find.byTooltip('Mesajı gönder'));
    await waitFor(find.text(reply));
    debugPrint('Elif accepted the notification request and replied.');

    await changeAccount(pixelMessageWriter);
    await store.refreshUnread();
    expect(store.unreadMessages, 1);
    expect(find.descendant(of: nav, matching: find.text('1')), findsOneWidget);
    await tap(nav);
    await waitFor(find.text(reply));
    await tap(find.text(reply));
    await waitFor(input);
    for (var i = 0; i < 40 && store.unreadMessages != 0; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(store.unreadMessages, 0);
    // Photo goes through the new attachment menu: [ + ] → Fotoğraf.
    await tap(find.byKey(const Key('chat-attach')));
    await tap(find.byKey(const ValueKey('attach-photo')));
    await waitFor(find.text('Fotoğraf eklendi'));
    await tap(find.byTooltip('Mesajı gönder'));
    await waitFor(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url.contains('/message-images/'),
      ),
    );
    final sent = (await store.communication!.messages(chat)).items.first;
    expect(sent.image, isNotEmpty);
    debugPrint(
      'Demo opened the unread message and sent an Android gallery image.',
    );

    await tap(find.byType(BackButton));

    await waitFor(find.widgetWithText(ConversationTile, elif.name));
    await tap(find.widgetWithText(ConversationTile, elif.name));
    await waitFor(find.byTooltip('Sohbet seçenekleri'));
    final nearbyBefore =
        await client.send('GET', 'nearby/users', authenticated: true) as Map;
    expect(
      (nearbyBefore['items'] as List).any(
        (person) => person['username'] == pixelMessageReader,
      ),
      isTrue,
    );
    await tap(find.byTooltip('Sohbet seçenekleri'));
    await tap(find.text('Engelle'));
    await tap(find.text('Engelle'));
    await waitFor(find.byType(DirectConversationList));
    final blockedSearch = await store.searchPeople(pixelMessageReader, 1);
    expect(blockedSearch.items, isEmpty);
    final nearbyAfter =
        await client.send('GET', 'nearby/users', authenticated: true) as Map;
    expect(
      (nearbyAfter['items'] as List).any(
        (person) => person['username'] == pixelMessageReader,
      ),
      isFalse,
    );
    await expectLater(
      store.communication!.send(elif, 'Merhaba', const Uuid().v4(), null),
      throwsA(isA<ApiFailure>().having((error) => error.status, 'status', 404)),
    );

    await go('/blocked');
    await waitFor(find.text('Engeli Kaldır'));
    await tap(find.text('Engeli Kaldır'));
    await waitFor(find.text('Engellenen kullanıcı yok.'));
    await tap(back);
    await waitFor(find.widgetWithText(ConversationTile, elif.name));
    await tap(find.widgetWithText(ConversationTile, elif.name));
    await waitFor(input);
    await enter(input, 'Tekrar merhaba, fotoğrafı görebildin mi?');
    await tap(find.byTooltip('Mesajı gönder'));
    await waitFor(find.text('Tekrar merhaba, fotoğrafı görebildin mi?'));
    await tap(find.byTooltip('Sohbet seçenekleri'));
    await tap(find.text('Şikâyet Et'));
    await tap(find.text('Spam veya dolandırıcılık'));
    await tap(find.text('Şikâyeti Gönder'));
    await waitFor(find.text('Şikâyetin alındı.'));
    debugPrint(
      'Demo blocked and unblocked Elif, resumed chat, and reported the profile.',
    );

    await changeAccount(pixelMessageReader);
    final read = (await store.communication!.messages(chat)).items
        .singleWhere((message) => message.body == reply);
    expect(read.read, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, skip: pixelPassword.isEmpty);
}
