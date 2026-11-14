import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senmiydin/data/voice_service.dart';

import 'support/fake_voice.dart';

/// Every widget test gets fake microphone / player devices, so the platform plugins are never loaded in tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    FakeVoice();
    // The emoji picker keeps its "recent" list in preferences.
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(VoiceServices.reset);
  await testMain();
}
