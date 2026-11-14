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
import 'package:senmiydin/data/social_api.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/widgets/social.dart';
import 'package:uuid/uuid.dart';

class TestGallery extends ImagePickerPlatform {
  TestGallery(this.files);
  final List<XFile> files;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => files;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Social feed and interactions persist on Pixel 6a', (
    tester,
  ) async {
    const reader = pixelSocialReader;
    const writer = pixelSocialWriter;
    const password = pixelPassword;
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'senmiydin_social_test'),
    );
    await storage.delete(key: 'senmiydin.session.token');
    addTearDown(() => storage.delete(key: 'senmiydin.session.token'));

    const writerName = 'Deniz Kaya';
    const otherText = 'Kıyıda karşılaştık, bir merhaba yarım kaldı.';
    final creator = ApiClient(
      storage: const FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: 'senmiydin_social_creator'),
      ),
    );
    final creatorAuth = AuthService(creator);
    await creatorAuth.signIn('login', {
      'identifier': writer,
      'password': password,
    });
    final city = (await CatalogService(
      creator,
    ).cities()).firstWhere((c) => c.name == 'Alanya');
    final other = await SocialService(creator).object(
      'POST',
      'posts',
      body: {
        'body': otherText,
        'type': 'thought',
        'city_id': city.id,
        'visibility': 'city',
        'is_anonymous': false,
        'request_id': const Uuid().v4(),
      },
    );
    final otherId = other['id'].toString();
    await creatorAuth.logout();
    creator.dispose();

    final folder = await Directory.systemTemp.createTemp('senmiydin-pixel-');
    final images = <XFile>[];
    for (final name in ['coast.jpg', 'sunset.jpg']) {
      final source = await rootBundle.load('assets/images/$name');
      final file = await File('${folder.path}/$name').writeAsBytes(
        source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
      );
      images.add(XFile(file.path));
    }
    final originalPicker = ImagePickerPlatform.instance;
    if (!const bool.fromEnvironment('NATIVE_GALLERY')) {
      ImagePickerPlatform.instance = TestGallery(images);
    }
    addTearDown(() async {
      ImagePickerPlatform.instance = originalPicker;
      for (final image in images) {
        await File(image.path).delete();
      }
      await folder.delete();
    });

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
    var store = newStore();
    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (finder.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      fail('Missing $finder');
    }

    Future<void> tap(Finder finder, {Finder? scrollable}) async {
      if (finder.evaluate().isEmpty) {
        final vertical = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first;
        await tester.scrollUntilVisible(
          finder,
          230,
          scrollable: scrollable ?? vertical,
        );
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

    Future<void> enter(Finder field, String text) async {
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await hideKeyboard();
    }

    final homeScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('home-feed')),
          matching: find.byType(Scrollable),
        )
        .first;
    final postIds = <String, String>{otherText: otherId};
    Finder card(String text) => find.byWidgetPredicate(
      (widget) => widget is PostCard && widget.post.id == postIds[text],
    );
    Future<void> rememberOwn(String label) async {
      final page = await store.loadProfilePosts(reader, 1);
      postIds[label] = page.items
          .where((post) => !postIds.values.contains(post.id))
          .single
          .id;
    }

    Finder action(String text, String tooltip) =>
        find.descendant(of: card(text), matching: find.byTooltip(tooltip));

    await tester.pumpWidget(SenMiydinApp(store: store));
    await waitFor(find.text('Giriş Yap'));
    await tap(find.widgetWithText(OutlinedButton, 'Giriş Yap'));
    await enter(
      find.widgetWithText(TextFormField, 'E-posta veya kullanıcı adı'),
      reader,
    );
    await enter(find.widgetWithText(TextFormField, 'Şifre'), password);
    await tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
    await waitFor(find.text('Ana Sayfa'));

    final compose = find.byKey(const Key('compose-button'));
    final publish = find.byKey(const Key('publish-post'));
    final postText = find.byKey(const Key('post-text'));
    const ownText = 'Şehirde yeni bir anı, güzel bir yürüyüş.';
    await tap(compose);
    await enter(postText, ownText);
    await tap(publish);
    await waitFor(find.text('Ana Sayfa'));
    await rememberOwn(ownText);
    await tester.scrollUntilVisible(
      find.text(ownText),
      230,
      scrollable: homeScroll,
    );

    const photoText = 'Kıyının iki rengi, günün iki güzel anı.';
    await tap(compose);
    await enter(postText, photoText);
    await tap(find.byTooltip('Fotoğraf Ekle'));
    await waitFor(find.text('1/2'));
    await tap(publish);
    await waitFor(find.text('Ana Sayfa'));
    await rememberOwn(photoText);
    await tester.scrollUntilVisible(
      find.text(photoText),
      230,
      scrollable: homeScroll,
    );
    final carousel = find.descendant(
      of: card(photoText),
      matching: find.byType(ImageCarousel),
    );
    await tester.ensureVisible(carousel);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: carousel, matching: find.text('1/2')),
      findsOneWidget,
    );
    await tester.drag(carousel, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: carousel, matching: find.text('2/2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: carousel,
        matching: find.byIcon(Icons.broken_image_outlined),
      ),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text(otherText),
      230,
      scrollable: homeScroll,
    );
    await tap(action(otherText, 'Beğen'));
    await waitFor(
      find.descendant(
        of: card(otherText),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
    );
    expect(store.cachedPost(otherId)?.liked, true);
    await tap(action(otherText, 'Yorumlar'));
    const comment = 'Şehirde yeniden karşılaşmak güzel.';
    await enter(find.widgetWithText(TextField, 'Bir yorum yaz…'), comment);
    await tap(find.byTooltip('Yorumu gönder'));
    await waitFor(find.text(comment));
    // The comments panel is a bottom sheet over the feed now: close it, the feed stays where it was.
    await tap(find.byKey(const Key('comments-close')));
    await tap(action(otherText, 'Kaydet'));
    await waitFor(action(otherText, 'Kaydı kaldır'));
    expect(store.cachedPost(otherId)?.saved, true);

    await tap(find.byTooltip('Menü'));
    await tap(find.text('Kaydedilenler'));
    await waitFor(find.text(otherText));
    await tap(find.text(writerName));
    await tap(find.text('Takip Et'));
    await waitFor(find.text('Takip Ediliyor'));
    final writerId = store.cachedPost(otherId)!.authorId;
    expect(store.person(writerId).followersCount, 1);
    await tap(find.byTooltip('Geri'));
    await tap(find.byTooltip('Geri'));

    await tap(find.byTooltip('Ara'));
    final search = find.byKey(const Key('global-search'));
    await enter(search, writer);
    await waitFor(find.text(writerName));
    final postsTab = find.widgetWithText(ChoiceChip, 'Paylaşımlar');
    await tap(postsTab);
    expect(tester.widget<ChoiceChip>(postsTab).selected, true);
    await tap(search);
    await enter(search, otherText);
    expect(tester.widget<TextField>(search).controller!.text, otherText);
    await waitFor(
      find.descendant(
        of: find.byType(PostCard),
        matching: find.text(otherText),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    disposeStore(store);
    store = newStore();
    await tester.pumpWidget(SenMiydinApp(store: store));
    await waitFor(find.text('Ana Sayfa'));
    await tester.scrollUntilVisible(
      find.text(otherText),
      230,
      scrollable: homeScroll,
    );
    expect(store.cachedPost(otherId)?.liked, true);
    expect(store.cachedPost(otherId)?.saved, true);
    expect(store.cachedPost(otherId)?.commentCount, 1);
    expect(store.person(store.cachedPost(otherId)!.authorId).isFollowing, true);
    await store.signOut();
    await tester.pumpWidget(const SizedBox.shrink());
    disposeStore(store);
  }, skip: pixelPassword.isEmpty);
}
