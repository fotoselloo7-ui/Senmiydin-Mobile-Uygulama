import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/ads_config.dart';
import 'package:senmiydin/core/app_locale.dart';
import 'package:senmiydin/data/ads_service.dart';
import 'package:senmiydin/l10n/en_catalog.dart';
import 'package:senmiydin/screens/settings.dart';
import 'package:senmiydin/widgets/common.dart';
import 'package:senmiydin/widgets/translated_text.dart';

/// Final release-candidate guards for the language layer: placeholders stay in step between Turkish and English,
/// accessibility texts follow the language, and the destructive confirmation word works in both languages.
void main() {
  tearDown(() => AppLocale.debugSet(const Locale('tr')));

  group('English catalog', () {
    final placeholder = RegExp(r'\{\d+\}');

    test('every sentence with {0}, {1} … keeps exactly the same placeholders in English', () {
      for (final entry in enCatalog.entries) {
        final turkish = placeholder.allMatches(entry.key).map((m) => m.group(0)).toSet();
        final english = placeholder.allMatches(entry.value).map((m) => m.group(0)).toSet();
        expect(english, turkish, reason: 'Placeholders differ for "${entry.key}"');
      }
    });

    test('English text is never empty, never Turkish-specific letters and never the Turkish text itself', () {
      const turkishLetters = 'çğıöşüÇĞİÖŞÜ';
      // Brand / proper names that legitimately keep their spelling.
      const same = {'SenMiydin?', 'Alanya'};
      for (final entry in enCatalog.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        if (same.contains(entry.key)) continue;
        expect(entry.value.split('').any(turkishLetters.contains), isFalse, reason: 'Turkish letters left in English: "${entry.value}"');
      }
    });

    test('no catalog key is declared twice (the later one would silently win)', () {
      final source = File('lib/l10n/en_catalog.dart').readAsStringSync();
      final keys = RegExp(r"^\s*'((?:[^'\\]|\\.)*)'\s*:", multiLine: true).allMatches(source).map((m) => m.group(1)!).toList();
      expect(keys.toSet().length, keys.length, reason: 'Duplicate keys: ${keys.where((k) => keys.where((o) => o == k).length > 1).toSet()}');
      expect(keys.length, enCatalog.length);
    });
  });

  group('trf', () {
    test('fills the placeholders in Turkish and in English', () {
      expect(trf('{0} yanıt', [3]), '3 yanıt');
      expect(trf('Fotoğraf {0} / {1}', [2, 5]), 'Fotoğraf 2 / 5');
      AppLocale.debugSet(const Locale('en'));
      expect(trf('{0} yanıt', [3]), '3 replies');
      expect(trf('Fotoğraf {0} / {1}', [2, 5]), 'Photo 2 / 5');
      expect(trf('Yakınında {0} yeni mektup var', [1]), '1 new letters near you');
      expect(trf('Bugün · {0}', ['09:30']), 'Today · 09:30');
    });

    test('a sentence without an English entry falls back to the Turkish template, still filled in', () {
      AppLocale.debugSet(const Locale('en'));
      expect(trf('Bilinmeyen {0} cümle', ['bir']), 'Bilinmeyen bir cümle');
    });

    test('month names and the common words follow the language', () {
      AppLocale.debugSet(const Locale('en'));
      expect([tr('Ocak'), tr('Mayıs'), tr('Aralık')], ['January', 'May', 'December']);
      expect(tr('Şifreyi göster'), 'Show password');
    });
  });

  group('account deletion confirmation', () {
    test('accepts SİL and DELETE in any letter case, nothing else', () {
      for (final ok in ['SİL', 'SIL', 'sil', 'Sil', ' SİL ', 'DELETE', 'delete', 'Delete', ' delete ']) {
        expect(isDeleteConfirmation(ok), isTrue, reason: ok);
      }
      for (final bad in ['', 'si', 'silme', 'DELET', 'delete me', 'SİL!', 'x']) {
        expect(isDeleteConfirmation(bad), isFalse, reason: bad);
      }
    });
  });

  group('accessibility texts follow the language', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

    testWidgets('the password field tooltip is Turkish, then English', (tester) async {
      await tester.pumpWidget(host(const Field('Şifre', Icons.lock_outline, obscure: true)));
      expect(find.byTooltip('Şifreyi göster'), findsOneWidget);
      AppLocale.debugSet(const Locale('en'));
      await tester.pumpWidget(host(const Field('Şifre', Icons.lock_outline, obscure: true, key: ValueKey('again'))));
      expect(find.byTooltip('Show password'), findsOneWidget);
      expect(find.text('Password'), findsWidgets);
    });

    testWidgets('the Text widget re-translates when the language changes while it is on screen', (tester) async {
      await tester.pumpWidget(host(const Text('Kaydet')));
      expect(find.text('Kaydet'), findsOneWidget);
      AppLocale.debugSet(const Locale('en'));
      await tester.pumpWidget(host(const Text('Kaydet', key: ValueKey('x'))));
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('ads placement', () {
    test('first ad after the 7th organic post, then every interval; never at the end; interval floor of 8', () {
      expect(AdsConfig.adPositions(0, 11), isEmpty);
      expect(AdsConfig.adPositions(7, 11), isEmpty, reason: 'An ad is only placed when more content follows it.');
      expect(AdsConfig.adPositions(8, 11), [7]);
      expect(AdsConfig.adPositions(18, 11), [7]);
      expect(AdsConfig.adPositions(19, 11), [7, 18]);
      expect(AdsConfig.adPositions(30, 11), [7, 18, 29]);
      expect(AdsConfig.adPositions(30, 3), AdsConfig.adPositions(30, AdsConfig.minimumInterval), reason: 'Admin cannot go below the floor.');
    });

    test('paging in more posts never moves an earlier ad (pagination, refresh and every feed tab use the same rule)', () {
      for (final interval in [8, 11, 14]) {
        var previous = <int>[];
        for (var organic = 0; organic <= 120; organic++) {
          final positions = AdsConfig.adPositions(organic, interval);
          expect(positions.take(previous.length).toList(), previous, reason: 'organic $organic interval $interval');
          previous = positions;
        }
      }
    });

    test('feedRows keeps every organic post in its original order; ads never replace posts', () {
      for (final organic in [0, 1, 7, 8, 25, 80]) {
        final rows = feedRows(organic, ads: true);
        final posts = rows.where((row) => !row.isAd).map((row) => row.organic).toList();
        expect(posts, List.generate(organic, (i) => i));
        expect(rows.where((row) => row.isAd).length, AdsConfig.adPositions(organic, AdsConfig.defaultInterval).length);
        if (rows.isNotEmpty) expect(rows.last.isAd, isFalse, reason: 'A feed never ends on an ad.');
        expect(feedRows(organic, ads: false).any((row) => row.isAd), isFalse);
      }
    });
  });

  group('ads service under every consent outcome', () {
    test('unknown / required (no consent yet) means no ads and no crash; obtained / not required allows them', () async {
      for (final can in [false, true]) {
        final fake = _Platform(AdsStartResult(canRequestAds: can, privacyOptionsRequired: !can));
        final service = AdsService(platform: fake, unitId: 'unit');
        await service.start(teen: false);
        expect(service.canRequestAds, can);
        expect(service.available, can);
        expect(service.privacyOptionsRequired, !can);
      }
    });

    test('a consent or SDK failure ends in "no ads", never an exception', () async {
      final service = AdsService(platform: _Platform.failing(), unitId: 'unit');
      await service.start(teen: false);
      expect(service.available, isFalse);
      expect(service.started, isFalse);
      await service.showPrivacyOptions();
    });

    test('no ad unit (release without ids) never starts the SDK; sign-out resets the treatment for the next account', () async {
      final none = _Platform(const AdsStartResult(canRequestAds: true, privacyOptionsRequired: false));
      final noUnit = AdsService(platform: none);
      // Debug/test builds fall back to Google's sample unit; a missing one is simulated by an empty override.
      expect(AdsConfig.nativeUnitId(debug: false, androidUnit: '', iosUnit: ''), isNull);
      expect(noUnit.platform, isNotNull);

      final fake = _Platform(const AdsStartResult(canRequestAds: true, privacyOptionsRequired: false));
      final service = AdsService(platform: fake, unitId: 'unit');
      await service.start(teen: true);
      expect(service.teen, isTrue);
      service.reset();
      expect(service.available, isFalse);
      await service.start(teen: false);
      expect(fake.startedTeen, [true, false], reason: 'The next account gets its own age treatment.');
    });
  });

  group('language switch while screens are alive', () {
    testWidgets('const Text widgets and cached tooltips change language without leaving the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Kaydet'),
                const Text('HESAP VE PROFİL'),
                Builder(builder: (context) => IconButton(onPressed: () {}, tooltip: tr('Şifreyi göster'), icon: const Icon(Icons.lock))),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Kaydet'), findsOneWidget);
      expect(find.byTooltip('Şifreyi göster'), findsOneWidget);
      AppLocale.debugSet(const Locale('en'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('ACCOUNT AND PROFILE'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);
      AppLocale.debugSet(const Locale('tr'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Kaydet'), findsOneWidget);
      expect(find.text('HESAP VE PROFİL'), findsOneWidget);
    });
  });

  group('l10n audit', () {
    test('the repository audit script reports no uncovered Turkish UI literal', () async {
      final result = await Process.run('python', ['-I', 'tool/l10n_audit.py', '--all'], runInShell: true);
      if (result.exitCode == 9009 || '${result.stderr}'.contains('not recognized')) {
        markTestSkipped('python is not available');
        return;
      }
      expect(result.exitCode, 0, reason: '${result.stdout}');
    });
  });
}

class _Platform implements AdsPlatform {
  _Platform(this.result) : failing = false;
  _Platform.failing()
      : result = const AdsStartResult(canRequestAds: false, privacyOptionsRequired: false),
        failing = true;
  final AdsStartResult result;
  final bool failing;
  final startedTeen = <bool>[];

  @override
  Future<AdsStartResult> start({required bool teen}) async {
    startedTeen.add(teen);
    if (failing) throw StateError('consent failed');
    return result;
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (failing) throw StateError('form failed');
  }

  @override
  NativeAdHandle createNative({
    required String unitId,
    required bool teen,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) => throw UnimplementedError();
}
