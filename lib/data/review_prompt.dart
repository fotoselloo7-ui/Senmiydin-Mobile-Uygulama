import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// The platform's official review API, behind a seam so tests (and the debug app) never touch a real store dialog.
abstract class ReviewPlatform {
  /// True when the official in-app review sheet can be asked for.
  Future<bool> isAvailable();

  /// Asks the OS for its review sheet. The OS decides whether anything is shown (quota, already reviewed, debug build).
  Future<void> requestReview();

  /// Opens the real store listing; false when there is none to open.
  Future<bool> openStoreListing();
}

/// Google Play In-App Review on Android, StoreKit's review request on iOS (through the `in_app_review` package).
class OfficialReviewPlatform implements ReviewPlatform {
  final _review = InAppReview.instance;

  /// Real listing addresses are supplied at build time once the store pages exist; none is invented.
  static const _androidUrl = String.fromEnvironment('PLAY_STORE_URL');
  static const _iosUrl = String.fromEnvironment('APP_STORE_URL');

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> requestReview() => _review.requestReview();

  @override
  Future<bool> openStoreListing() async {
    final raw = Platform.isIOS ? _iosUrl : _androidUrl;
    final uri = raw.isEmpty ? null : Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.scheme != 'https') return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Where the per-account bookkeeping lives. A seam for tests.
abstract class ReviewStateStore {
  Future<int?> readInt(String key);
  Future<void> writeInt(String key, int value);
  Future<void> remove(String key);
}

class PreferencesReviewState implements ReviewStateStore {
  @override
  Future<int?> readInt(String key) async =>
      (await SharedPreferences.getInstance()).getInt(key);

  @override
  Future<void> writeInt(String key, int value) async {
    await (await SharedPreferences.getInstance()).setInt(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

/// When the app's own "rate SenMiydin?" invitation may appear. The invitation is ours to schedule; whether the
/// platform then shows its sheet is the platform's decision (Google and Apple apply their own quotas) and is never
/// guaranteed or reported as an error.
class ReviewPrompt {
  ReviewPrompt({
    ReviewStateStore? state,
    ReviewPlatform? platform,
    DateTime Function()? clock,
  }) : state = state ?? PreferencesReviewState(),
       platform = platform ?? OfficialReviewPlatform(),
       _now = clock ?? DateTime.now;

  final ReviewStateStore state;
  final ReviewPlatform platform;
  final DateTime Function() _now;

  /// At most one invitation per account in this long, whatever the answer was.
  static const cooldown = Duration(days: 7);

  /// A brand new account is never asked: it must be at least this old ...
  static const minimumAccountAge = Duration(days: 3);

  /// ... and have completed this many meaningful actions (a post, a comment, a message, a Map Note or a reply).
  static const minimumActions = 3;

  static String _actionsKey(Object userId) => 'review.$userId.actions';
  static String _promptedKey(Object userId) => 'review.$userId.last_prompt_at';

  final _shownThisSession = <Object>{};

  /// Counts one meaningful action of [userId].
  Future<void> recordAction(Object userId) async {
    final key = _actionsKey(userId);
    await state.writeInt(key, ((await state.readInt(key)) ?? 0) + 1);
  }

  /// True when [userId] (account created at [createdAt]) may be invited right now.
  Future<bool> isEligible(Object userId, DateTime? createdAt) async {
    if (createdAt == null || _shownThisSession.contains(userId)) return false;
    final now = _now();
    if (now.difference(createdAt) < minimumAccountAge) return false;
    if (((await state.readInt(_actionsKey(userId))) ?? 0) < minimumActions) {
      return false;
    }
    final last = await state.readInt(_promptedKey(userId));
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < cooldown) {
      return false;
    }
    return true;
  }

  /// The invitation was put on screen: no second one this session, and the weekly cooldown starts now, whichever
  /// button is pressed (or if it is dismissed).
  Future<void> markShown(Object userId) async {
    _shownThisSession.add(userId);
    await state.writeInt(_promptedKey(userId), _now().millisecondsSinceEpoch);
  }

  /// "Rate": the same official request for everybody. Never throws: a suppressed or failing platform API shows
  /// nothing to the person; the real store page is a fallback only when a real address is configured.
  Future<void> rate() async {
    try {
      if (await platform.isAvailable()) {
        await platform.requestReview();
        return;
      }
    } catch (error) {
      debugPrint('Review request failed quietly: $error');
    }
    try {
      await platform.openStoreListing();
    } catch (error) {
      debugPrint('Store listing could not be opened: $error');
    }
  }

  /// Forgets everything about [userId] (account deletion).
  Future<void> forget(Object userId) async {
    await state.remove(_actionsKey(userId));
    await state.remove(_promptedKey(userId));
    _shownThisSession.remove(userId);
  }
}
