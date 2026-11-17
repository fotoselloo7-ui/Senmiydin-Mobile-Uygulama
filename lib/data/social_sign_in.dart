import '../core/service_availability.dart';

import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'account_api.dart';

class SocialCredential {
  const SocialCredential(
    this.provider,
    this.fields, {
    this.email = '',
    this.name = '',
    this.photoUrl,
  });
  final String provider;
  final Map<String, Object?> fields;
  final String email, name;

  /// The provider profile photo (Google only), used to prefill the new profile.
  final String? photoUrl;
}

abstract final class SocialSignIn {
  static const googleServerId = ServiceAvailability.googleServerId;
  static const googleIosId = ServiceAvailability.googleIosId;
  static const appleServiceId = ServiceAvailability.appleServiceId;
  static const appleRedirect = ServiceAvailability.appleRedirect;
  static Future<void>? _google;
  static bool configured(String provider) =>
      ServiceAvailability.social(provider);

  /// Signs in with the provider. Returns null when the person cancels (nothing to report). The provider password is
  /// entered only in the provider's own sheet: the app never sees it.
  static Future<SocialCredential?> authenticate(
    String provider,
    AuthService auth,
  ) async {
    if (!configured(provider)) {
      throw const ApiFailure('Bu giriş yöntemi şu anda kullanılamıyor.');
    }
    try {
      if (provider == 'Google') {
        await (_google ??= GoogleSignIn.instance.initialize(
          serverClientId: googleServerId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? googleIosId
              : null,
        ));
        final user = await GoogleSignIn.instance.authenticate();
        final token = user.authentication.idToken;
        if (token == null) {
          throw const ApiFailure('Giriş doğrulanamadı. Tekrar dene.');
        }
        return SocialCredential(
          'google',
          {'id_token': token},
          email: user.email,
          name: user.displayName ?? '',
          photoUrl: user.photoUrl,
        );
      }
      final challenge = await auth.client.send(
        'POST',
        'auth/social/apple/challenge',
      ) as Map<String, dynamic>;
      final nonce = challenge['nonce'] as String;
      final state = sha256.convert(utf8.encode(nonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: state,
        state: state,
        webAuthenticationOptions:
            defaultTargetPlatform == TargetPlatform.android
            ? WebAuthenticationOptions(
                clientId: appleServiceId,
                redirectUri: Uri.parse(appleRedirect),
              )
            : null,
      );
      if (credential.identityToken == null || credential.state != state) {
        throw const ApiFailure('Giriş doğrulanamadı. Tekrar dene.');
      }
      return SocialCredential(
        'apple',
        {
          'id_token': credential.identityToken,
          'authorization_code': credential.authorizationCode,
          'nonce': nonce,
        },
        email: credential.email ?? '',
        name: [
          credential.givenName,
          credential.familyName,
        ].whereType<String>().join(' '),
      );
    } on ApiFailure {
      rethrow;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw const ApiFailure(
        'Giriş tamamlanamadı. Tekrar deneyebilir veya e-posta ile giriş yapabilirsin.',
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw const ApiFailure(
        'Giriş tamamlanamadı. Tekrar deneyebilir veya e-posta ile giriş yapabilirsin.',
      );
    } catch (_) {
      throw const ApiFailure(
        'Giriş tamamlanamadı. Tekrar deneyebilir veya e-posta ile giriş yapabilirsin.',
      );
    }
  }
}
