import '../core/service_availability.dart';

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'communication_api.dart';
import '../core/release_info.dart';

class PushClient {
  PushClient(this.api, this.accountId);
  final CommunicationApi api;
  final int? Function() accountId;
  static const _storage = FlutterSecureStorage();
  static const _deviceKey = 'senmiydin.push.device';
  static const _disabledKey = 'senmiydin.push.disabled';
  static const _project = ServiceAvailability.project;
  static const _sender = ServiceAvailability.sender;
  static const _androidId = ServiceAvailability.androidId;
  static const _iosId = ServiceAvailability.iosId;
  static const _androidKey = ServiceAvailability.androidKey;
  static const _iosKey = ServiceAvailability.iosKey;

  final _subscriptions = <StreamSubscription<dynamic>>[];
  void Function(int)? onOpen;
  void Function(int)? onForeground;
  Future<FirebaseMessaging>? _initialization;
  RemoteMessage? _pending;
  int? _registeredAccount;
  String? _registeredToken;
  bool _enabled = true, _disposed = false, _starting = false;

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  bool get configured => ServiceAvailability.push;

  Future<FirebaseMessaging> _initialize() async {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: _ios ? _iosKey : _androidKey,
        appId: _ios ? _iosId : _androidId,
        messagingSenderId: _sender,
        projectId: _project,
        iosBundleId: _ios ? 'com.senmiydin.app' : null,
      ),
    );
    final messaging = FirebaseMessaging.instance;
    _enabled = (await _storage.read(key: _disabledKey)) != '1';
    if (!_disposed) {
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          final id = _notificationForAccount(message);
          if (id != null) onForeground?.call(id);
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _pending = message;
          consumePending();
        }),
      );
      _subscriptions.add(
        messaging.onTokenRefresh.listen((token) {
          unawaited(_registerSafely(token));
        }),
      );
      _pending = await messaging.getInitialMessage() ?? _pending;
    }
    return messaging;
  }

  Future<void> _registerSafely(String token) async {
    try {
      await _register(token);
    } catch (_) {
      // A later foreground sync retries token registration.
    }
  }

  Future<bool> status() async {
    if (!configured) return false;
    final messaging = await (_initialization ??= _initialize());
    return _enabled && _granted(await messaging.getNotificationSettings());
  }

  bool _granted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  Future<bool> setEnabled(bool enabled) async {
    if (!configured) return false;
    final messaging = await (_initialization ??= _initialize());
    if (enabled && !_granted(await messaging.requestPermission())) return false;
    _enabled = enabled;
    await _storage.write(key: _disabledKey, value: enabled ? '0' : '1');
    if (enabled) {
      await sync();
    } else {
      final id = await _storage.read(key: _deviceKey);
      if (id != null) await api.disableDevice(id);
      await messaging.setAutoInitEnabled(false);
      await messaging.deleteToken();
      _registeredToken = null;
    }
    return enabled;
  }

  Future<void> sync() async {
    if (_disposed || _starting || !configured || accountId() == null) return;
    _starting = true;
    try {
      final messaging = await (_initialization ??= _initialize());
      if (!_enabled || !_granted(await messaging.getNotificationSettings())) {
        return;
      }
      if (_ios && await messaging.getAPNSToken() == null) return;
      await messaging.setAutoInitEnabled(true);
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (_) {
      // Local inbox remains available if the platform service is unavailable.
    } finally {
      _starting = false;
      consumePending();
    }
  }

  Future<void> _register(String token) async {
    final user = accountId();
    if (!_enabled ||
        _disposed ||
        user == null ||
        (_registeredAccount == user && _registeredToken == token)) {
      return;
    }
    var id = await _storage.read(key: _deviceKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _deviceKey, value: id);
    }
    if (user != accountId() || _disposed) return;
    String? version;
    try {
      version = (await ReleaseInfo.package).version;
    } catch (_) {
      /* Optional on unsupported platforms. */
    }
    if (user != accountId() || _disposed) return;
    await api.registerDevice({
      'device_identifier': id,
      'platform': _ios ? 'ios' : 'android',
      'push_token': token,
      'app_version': ?version,
    });
    if (user == accountId()) {
      _registeredAccount = user;
      _registeredToken = token;
    }
  }

  int? _notificationForAccount(RemoteMessage message) =>
      message.data['recipient_id']?.toString() == accountId()?.toString()
      ? int.tryParse(message.data['notification_id']?.toString() ?? '')
      : null;

  void consumePending() {
    final message = _pending;
    final handler = onOpen;
    if (message == null || accountId() == null || handler == null) return;
    _pending = null;
    final id = _notificationForAccount(message);
    if (id != null) handler(id);
  }

  void endSession() {
    _registeredAccount = null;
    _registeredToken = null;
    _pending = null;
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
