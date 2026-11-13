import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/mock_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Pixel 6a: multiple photos, reorder, preview and publish', (
    t,
  ) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final store = AppStore();
    await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
    await t.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await t.tap(find.byKey(const Key('compose-button')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('post-text')),
      'Günün iki güzel anı. ☕🌅',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Fotoğraf Ekle'));
    await t.pumpAndSettle();
    await binding.takeScreenshot('31-compose-media-actions');
    await t.tap(find.text('Fotoğraf Ekle'));
    await t.pumpAndSettle();
    await t.tap(find.image(AssetImage(demoPhotos[0])).last);
    await t.pumpAndSettle();
    await t.tap(find.image(AssetImage(demoPhotos[1])).last);
    await t.pumpAndSettle();
    await binding.takeScreenshot('32-multiple-photo-picker');
    await t.tap(find.text('2 Fotoğrafı Kullan'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byIcon(Icons.arrow_back).last);
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.arrow_back).last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Paylaşım Önizlemesi'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Paylaşım Önizlemesi'));
    await t.pumpAndSettle();
    expect(find.text('Düzenlemeye Dön'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('1/2')),
      findsOneWidget,
    );
    await binding.takeScreenshot('33-photo-post-preview');
    await t.tap(find.text('Düzenlemeye Dön'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('publish-post')),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('publish-post')));
    await t.pumpAndSettle();
    expect(
      store.posts.first.images,
      orderedEquals([demoPhotos[1], demoPhotos[0]]),
    );
    expect(store.posts.first.text, 'Günün iki güzel anı. ☕🌅');
    expect(t.takeException(), isNull);
    await binding.takeScreenshot('34-published-photo-post');
  });
}
