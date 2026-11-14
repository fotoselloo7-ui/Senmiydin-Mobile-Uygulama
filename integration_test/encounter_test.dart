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
import 'package:senmiydin/main.dart';
import 'package:senmiydin/widgets/social.dart';

class _FixtureGallery extends ImagePickerPlatform {
  _FixtureGallery(this.files);
  final List<XFile> files;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => files;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Both owned accounts confirm and publish one encounter', (
    tester,
  ) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'senmiydin_encounter_test'),
    );
    const tokenKey = 'senmiydin.session.token';
    await storage.delete(key: tokenKey);
    addTearDown(() => storage.delete(key: tokenKey));

    if (!const bool.fromEnvironment('NATIVE_GALLERY')) {
      final folder = await Directory.systemTemp.createTemp('encounter-');
      final files = <XFile>[];
      for (final name in ['coast.jpg', 'sunset.jpg']) {
        final source = await rootBundle.load('assets/images/$name');
        final file = await File('${folder.path}/$name').writeAsBytes(
          source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
        );
        files.add(XFile(file.path));
      }
      final picker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _FixtureGallery(files);
      addTearDown(() async {
        ImagePickerPlatform.instance = picker;
        for (final file in files) {
          await File(file.path).delete();
        }
        await folder.delete();
      });
    }

    const source = 'Sahilde karşılaştığımız akşam';
    const rejectedSource = 'Bir başka sahil yürüyüşü';
    const storyTitle = 'Sahilde ikinci merhaba';
    const storyBody = 'Deniz kenarında yürürken yeniden karşılaştık.';
    final store = AppStore(api: ApiClient(storage: storage));
    addTearDown(store.dispose);

    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 140; attempt++) {
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
        await tester.scrollUntilVisible(finder, 210, scrollable: vertical);
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> enter(Finder field, String text) async {
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
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

    Future<void> switchTo(String account) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await store.signOut();
      await tester.pumpWidget(SenMiydinApp(store: store));
      await login(account);
    }

    final compose = find.byKey(const Key('compose-button'));
    final publish = find.byKey(const Key('publish-post'));
    final postText = find.byKey(const Key('post-text'));
    final back = find.byTooltip('Geri');
    Future<String> tag(String body) async {
      final before = (await store.loadEncounters(1)).items
          .map((entry) => entry.id)
          .toSet();
      await tap(compose);
      await enter(postText, body);
      await tap(find.widgetWithText(ChoiceChip, 'Karşılaşma'));
      await tap(find.text('Karşılaştığım kişiyi etiketle'));
      await enter(find.byKey(const Key('tag-search')), pixelEncounterReader);
      await waitFor(find.text('@$pixelEncounterReader'));
      await tap(find.text('@$pixelEncounterReader'));
      await tap(publish);
      await waitFor(find.text('Onay bekliyor'));
      expect(find.text('Karşılaşmayı Onayla'), findsNothing);
      return (await store.loadEncounters(1)).items
          .where((entry) => !before.contains(entry.id))
          .single
          .id;
    }

    Future<void> openInbox(
      String requestId, {
      String type = 'encounter_request',
    }) async {
      final entry = await store.loadEncounter(requestId);
      await tap(find.byTooltip('Bildirimler'));
      final notices = await store.communication!.inbox(1, false);
      final notice = notices.items.firstWhere(
        (item) => item.type == type && item.entity?.toString() == entry.id,
      );
      final row = find.byKey(ValueKey(('notification', notice.id)));
      await waitFor(row);
      await tap(row);
    }

    await tester.pumpWidget(SenMiydinApp(store: store));
    await login(pixelEncounterWriter);
    final rejectedId = await tag(rejectedSource);
    await tap(back);
    final sourceId = await tag(source);
    debugPrint('Both encounter requests are pending.');

    await switchTo(pixelEncounterReader);
    await openInbox(sourceId);
    await waitFor(find.byKey(const Key('approve-encounter')));
    await tap(find.byKey(const Key('approve-encounter')));
    await waitFor(find.text('Karşılaşıldı ✓'));
    final accepted = await store.loadEncounter(sourceId);
    final repeated = await store.respondEncounter(accepted.id, 'accept');
    expect(repeated.encounterId, accepted.encounterId);
    debugPrint(
      'Elif accepted the encounter and the repeated response reused its record.',
    );
    await tap(find.text('Karşılaşmayı Paylaş'));
    await enter(find.byKey(const Key('encounter-story-title')), storyTitle);
    await enter(postText, storyBody);
    await tap(find.byTooltip('Fotoğraf Ekle'));
    await waitFor(find.text('1/2'));
    debugPrint('Two images were selected.');
    await tap(publish);
    await waitFor(find.text('Ortak Hikâye'));
    final waitingForPartner = find.text(
      'Yayın için karşı tarafın onayı bekleniyor.',
    );
    await tester.scrollUntilVisible(
      waitingForPartner,
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await waitFor(waitingForPartner);
    expect(find.text('Yayınlamayı Onayla'), findsNothing);
    debugPrint('The joint story is waiting for partner approval.');

    // The bell opens a quick panel over Home now (no Bildirimler page in the stack): one back reaches Home.
    await tap(back);
    await openInbox(rejectedId);
    await waitFor(find.text('Reddet'));
    await tap(find.text('Reddet'));
    await waitFor(find.text('Reddedildi'));
    expect(find.text('Karşılaşıldı ✓'), findsNothing);
    debugPrint('Elif rejected the second encounter request.');

    await switchTo(pixelEncounterWriter);
    await openInbox(sourceId, type: 'encounter_story_approval');
    await waitFor(find.text('Ortak Hikâye'));
    final reviewCard = find.ancestor(
      of: find.text(storyTitle),
      matching: find.byType(PostCard),
    );
    expect(
      find.descendant(of: reviewCard, matching: find.byType(ImageCarousel)),
      findsOneWidget,
    );
    await tap(find.text('Yayınlamayı Onayla'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if ((await store.loadEncounter(accepted.id)).story?.storyStatus ==
          'published') {
        break;
      }
    }
    expect(
      (await store.loadEncounter(accepted.id)).story?.storyStatus,
      'published',
    );
    await tester.pumpAndSettle();
    final publishedAction = find.text('Yayınlanan Hikâyeyi Gör');
    await tester.scrollUntilVisible(
      publishedAction,
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await waitFor(publishedAction);
    debugPrint('Demo approved the story for publication.');
    final publishedId = (await store.loadEncounter(accepted.id)).story!.id;
    await tap(back);
    await waitFor(find.byType(PublishedEncounterCard));
    final featured = find.byWidgetPredicate(
      (widget) =>
          widget is PublishedEncounterCard && widget.post.id == publishedId,
    );
    for (var i = 0; i < 20 && featured.evaluate().isEmpty; i++) {
      final cards = find.byType(PublishedEncounterCard);
      final pager = find
          .ancestor(of: cards.first, matching: find.byType(PageView))
          .first;
      await tester.ensureVisible(pager);
      await tester.dragFrom(
        tester.getTopLeft(pager) + const Offset(170, 22),
        const Offset(-310, 0),
      );
      await tester.pumpAndSettle();
    }
    await waitFor(featured);
    final body = find.descendant(of: featured, matching: find.text(storyBody));
    final carousel = find.descendant(
      of: featured,
      matching: find.byType(ImageCarousel),
    );
    expect(
      find.descendant(of: featured, matching: find.byType(EncounterAvatars)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(carousel).dy,
      greaterThan(tester.getBottomLeft(body).dy),
    );
    await tester.ensureVisible(carousel);
    await tester.pumpAndSettle();
    await tester.drag(carousel, const Offset(-290, 0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: carousel, matching: find.text('2/2')),
      findsOneWidget,
    );

    final feedCard = find.byWidgetPredicate(
      (widget) => widget is PostCard && widget.post.id == publishedId,
    );
    if (feedCard.evaluate().isEmpty) {
      final feedScroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('home-feed')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(feedCard, 210, scrollable: feedScroll);
    }
    expect(feedCard, findsOneWidget);
    final feedCarousel = find.descendant(
      of: feedCard,
      matching: find.byType(ImageCarousel),
    );
    expect(feedCarousel, findsOneWidget);
    expect(tester.widget<ImageCarousel>(feedCarousel).images, hasLength(2));
    await tester.ensureVisible(feedCarousel);
    await tester.pumpAndSettle();
    await tester.drag(feedCarousel, const Offset(-290, 0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: feedCarousel, matching: find.text('2/2')),
      findsOneWidget,
    );
    debugPrint('Two real story photos verified in featured and normal feed.');

    final rejected = await store.loadEncounter(rejectedId);
    expect(rejected.status, 'rejected');
    expect(rejected.encounterId, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, skip: pixelPassword.isEmpty);
}
