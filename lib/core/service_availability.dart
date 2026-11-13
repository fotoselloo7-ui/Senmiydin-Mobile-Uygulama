import 'package:flutter/foundation.dart';

/// Public build identifiers only. Server secrets never belong in mobile defines.
abstract final class ServiceAvailability {
  static const googleServerId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const appleRedirect = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://senmiydin.com/auth/apple/callback',
  );
  static const appleEnabled = bool.fromEnvironment('APPLE_SIGN_IN_ENABLED');
  static const project = String.fromEnvironment('FCM_PROJECT_ID');
  static const sender = String.fromEnvironment('FCM_SENDER_ID');
  static const androidId = String.fromEnvironment('FCM_ANDROID_APP_ID');
  static const iosId = String.fromEnvironment('FCM_IOS_APP_ID');
  static const androidKey = String.fromEnvironment('FCM_ANDROID_API_KEY');
  static const iosKey = String.fromEnvironment('FCM_IOS_API_KEY');
  static bool get ios => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get push =>
      !kIsWeb &&
      (ios || defaultTargetPlatform == TargetPlatform.android) &&
      project.isNotEmpty &&
      sender.isNotEmpty &&
      (ios
          ? iosId.isNotEmpty && iosKey.isNotEmpty
          : androidId.isNotEmpty && androidKey.isNotEmpty);
  static bool social(String provider) =>
      !kIsWeb &&
      (provider == 'Google'
          ? googleServerId.isNotEmpty &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    (ios && googleIosId.isNotEmpty))
          : appleEnabled &&
                (ios ||
                    (defaultTargetPlatform == TargetPlatform.android &&
                        appleServiceId.isNotEmpty &&
                        Uri.tryParse(appleRedirect)?.scheme == 'https')));
  static bool store(Uri? uri, String platform) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host == (platform == 'ios' ? 'apps.apple.com' : 'play.google.com');
}
