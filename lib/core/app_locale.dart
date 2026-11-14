import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/en_catalog.dart';

export '../l10n/app_localizations.dart';

/// The one place that knows the active UI language (`tr` or `en`).
///
/// First launch: a Turkish device gets Turkish, every other device language gets English. A manual choice in Settings
/// is persisted in the app's private storage and wins from then on. Tests never call [init], so they stay in Turkish.
class AppLocale {
  AppLocale._();

  static const supported = [Locale('tr'), Locale('en')];
  static final ValueNotifier<Locale> notifier = ValueNotifier(
    const Locale('tr'),
  );

  static Locale get current => notifier.value;
  static bool get english => current.languageCode == 'en';
  static String get code => current.languageCode;

  /// `tr` for Turkish device language, `en` for everything else.
  static Locale forDevice(Locale device) =>
      device.languageCode.toLowerCase() == 'tr'
      ? const Locale('tr')
      : const Locale('en');

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/preferred_locale.txt');
    } catch (_) {
      return null;
    }
  }

  /// Resolves the startup language: saved choice, otherwise the device language.
  static Future<void> init() async {
    var locale = forDevice(ui.PlatformDispatcher.instance.locale);
    try {
      final file = await _file();
      if (file != null && await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved == 'tr' || saved == 'en') locale = Locale(saved);
      }
    } catch (_) {
      // Unreadable preference: fall back to the device language.
    }
    notifier.value = locale;
  }

  static Future<void> set(Locale locale) async {
    notifier.value = Locale(locale.languageCode);
    rebuildEverything();
    try {
      await (await _file())?.writeAsString(locale.languageCode);
    } catch (_) {
      // Persisting is best effort; the in-memory choice already applies.
    }
  }

  /// Marks every mounted element dirty so `const` widgets and cached labels pick up the new language too (the
  /// framework only rebuilds what depends on `Localizations`). The navigation stack and all state are kept.
  static void rebuildEverything() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    final binding = WidgetsBinding.instance;
    // Defer to after the current frame so the language is already set when the dirty elements build.
    binding.addPostFrameCallback((_) => binding.rootElement?.visitChildren(rebuild));
    binding.scheduleFrame();
  }

  /// Test hook: forces a language without touching storage.
  @visibleForTesting
  static void debugSet(Locale locale) {
    notifier.value = locale;
    rebuildEverything();
  }
}

extension AppL10n on BuildContext {
  /// Localized strings. Falls back to Turkish when no localization delegate is mounted (bare test hosts).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('tr'));
}

/// Context-free localized strings for code that has no [BuildContext] (time formatting, API error fallbacks).
AppLocalizations get currentL10n => lookupAppLocalizations(AppLocale.current);

/// English text for a Turkish source string (see `lib/l10n/en_catalog.dart`); Turkish and unknown strings pass through.
String tr(String turkish) =>
    AppLocale.english ? (enCatalog[turkish] ?? turkish) : turkish;

/// [tr] for sentences with values: the Turkish source uses `{0}`, `{1}` … placeholders, the English catalog entry uses
/// the same ones, and both languages are filled in here. Without an English entry the Turkish sentence is used.
String trf(String turkish, List<Object?> values) {
  var text = tr(turkish);
  for (var i = 0; i < values.length; i++) {
    text = text.replaceAll('{$i}', '${values[i]}');
  }
  return text;
}
