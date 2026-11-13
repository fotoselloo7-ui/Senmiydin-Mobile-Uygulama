import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senmiydin/main.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Pixel 6a: all screens and complete encounter flow', (t) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final store = AppStore();
    await t.pumpWidget(SenMiydinApp(store: store, initialRoute: '/home'));
    await t.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    Future<void> hideKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
    }

    Future<void> shot(String name) async {
      debugPrint('Capturing $name');
      await t.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await shot('01-home');
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    final routes = <String, (Object?, String)>{
      '/welcome': (null, '02-welcome'),
      '/register': (null, '03-register'),
      '/login': (null, '04-login'),
      '/complete': (null, '05-complete'),
      '/interests': (true, '06-interests'),
      '/permissions': (null, '07-permissions'),
      '/map': (null, '08-map'),
      '/filters': (null, '09-filters'),
      '/search': (null, '10-search'),
      '/profile': ('u0', '11-profile'),
      '/edit-profile': (null, '12-edit-profile'),
      '/saved': (null, '13-saved'),
      '/messages': (null, '14-messages'),
      '/chat': ('u1', '15-chat'),
      '/notifications': (null, '16-notifications'),
      '/settings': (null, '17-settings'),
      '/preferences': (null, '18-preferences'),
      '/blocked': (null, '19-blocked'),
      '/report': ('Paylaşım p0', '20-report'),
      '/delete-account': (null, '21-delete-account'),
      '/post': ('p0', '22-post'),
      '/comments': ('p0', '23-comments'),
      '/encounters': (null, '24-encounters'),
      '/profile-other': ('u1', '25-other-profile'),
    };
    for (final entry in routes.entries) {
      nav.pushNamed(
        entry.key == '/profile-other' ? '/profile' : entry.key,
        arguments: entry.value.$1,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: entry.key);
      await shot(entry.value.$2);
      nav.pop();
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const Key('compose-button')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('post-text')),
      'Sahilde aynı şarkıyı dinledik. Sen miydin? 🌊',
    );
    await hideKeyboard();
    await t.ensureVisible(find.text('Karşılaşma').last);
    await t.tap(find.text('Karşılaşma').last);
    await t.pumpAndSettle();
    await shot('26-compose');
    await t.ensureVisible(find.text('Karşılaştığım kişiyi etiketle'));
    await t.tap(find.text('Karşılaştığım kişiyi etiketle'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('tag-search')), '@elifb');
    await hideKeyboard();
    await shot('27-tag-search');
    await t.tap(find.text('Elif B.'));
    await t.pumpAndSettle();
    await hideKeyboard();
    await t.scrollUntilVisible(
      find.byKey(const Key('publish-post')),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('publish-post')));
    await t.pumpAndSettle();
    expect(store.encounters.first.status, EncounterStatus.pending);
    await shot('28-encounter-approval');
    await t.scrollUntilVisible(
      find.byKey(const Key('approve-encounter')),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.byKey(const Key('approve-encounter')));
    await t.pumpAndSettle();
    expect(store.encounters.first.status, EncounterStatus.approved);
    expect(store.featured.first.id, store.encounters.first.id);
    await shot('29-approved');
    await t.tap(find.text('Ana Sayfaya Dön'));
    await t.pumpAndSettle();
    await shot('30-home-with-new-encounter');
    expect(t.takeException(), isNull);
  });
}
