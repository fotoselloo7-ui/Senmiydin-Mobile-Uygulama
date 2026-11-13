import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/api_config.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.errors = const {}});

  final String message;
  final int? status;
  final Map<String, String> errors;

  String get detail => errors.values.firstOrNull ?? message;
}

class ApiClient {
  ApiClient({http.Client? httpClient, FlutterSecureStorage? storage})
    : _http = httpClient ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'senmiydin.session.token';
  static const _timeout = Duration(seconds: 15);
  final http.Client _http;
  final FlutterSecureStorage _storage;
  String? _token;
  void Function()? onUnauthorized;

  Future<bool> restoreToken() async {
    try {
      _token = await _storage.read(key: _tokenKey);
      return _token != null && _token!.isNotEmpty;
    } on PlatformException {
      throw const ApiFailure('Güvenli oturum bilgisine erişilemedi.');
    }
  }

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      _token = token;
    } on PlatformException {
      throw const ApiFailure(
        'Oturum bu cihazda güvenli şekilde kaydedilemedi.',
      );
    }
  }

  Future<void> clearToken() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } on PlatformException {
      // Revoked credentials will also be rejected on the next launch.
    }
  }

  bool _disposed = false;
  int _pending = 0;

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    XFile? avatar,
    XFile? messageImage,
    List<XFile> media = const [],
    Map<String, dynamic>? query,
  }) {
    if (_disposed) return Future.error(const ApiFailure('Bağlantı kapatıldı.'));
    _pending++;
    return _send(
      method,
      path,
      body: body,
      authenticated: authenticated,
      avatar: avatar,
      messageImage: messageImage,
      media: media,
      query: query,
    ).whenComplete(() {
      _pending--;
      if (_disposed && _pending == 0) _http.close();
    });
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    XFile? avatar,
    XFile? messageImage,
    List<XFile> media = const [],
    Map<String, dynamic>? query,
  }) async {
    final token = authenticated ? _token : null;
    if (authenticated && token == null) {
      throw const ApiFailure(
        'Oturumun sona erdi. Tekrar giriş yap.',
        status: 401,
      );
    }

    final Uri uri;
    try {
      final base = ApiConfig.base;
      uri = base.replace(
        queryParameters: query,
        path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/$path',
      );
    } on FormatException {
      throw const ApiFailure('Sunucu adresi yapılandırılamadı.');
    }

    final http.BaseRequest request;
    if (avatar == null && messageImage == null && media.isEmpty) {
      final jsonRequest = http.Request(method, uri);
      if (body != null) {
        jsonRequest.headers['Content-Type'] = 'application/json';
        jsonRequest.body = jsonEncode(body);
      }
      request = jsonRequest;
    } else {
      try {
        final upload = http.MultipartRequest(method, uri);
        if (body != null) {
          upload.fields.addAll(multipartFields(body));
        }
        final single = avatar ?? messageImage;
        final files = single == null ? media : [single];
        for (final (index, file) in files.indexed) {
          final length = await file.length();
          if (length > 5 * 1024 * 1024) {
            throw const ApiFailure('Her fotoğraf en fazla 5 MB olabilir.');
          }
          upload.files.add(
            http.MultipartFile(
              avatar != null
                  ? 'avatar'
                  : messageImage != null
                  ? 'image'
                  : 'media[$index]',
              file.openRead(),
              length,
              filename: file.name,
            ),
          );
        }
        request = upload;
      } on FileSystemException {
        throw const ApiFailure('Fotoğraf dosyası okunamadı. Yeniden seç.');
      }
    }

    request.followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final http.Response response;
    try {
      response = await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            media.isEmpty && messageImage == null
                ? _timeout
                : const Duration(seconds: 90),
          );
    } on TimeoutException {
      throw const ApiFailure('Sunucu zamanında yanıt vermedi. Tekrar dene.');
    } on FileSystemException {
      throw const ApiFailure('Fotoğraf dosyası okunamadı. Yeniden seç.');
    } on HandshakeException {
      throw const ApiFailure(
        'Güvenli bağlantı kurulamadı. Daha sonra tekrar dene.',
      );
    } on SocketException {
      throw const ApiFailure('İnternet bağlantını kontrol edip tekrar dene.');
    } on http.ClientException {
      throw const ApiFailure('Sunucuya bağlanılamadı. Bağlantını kontrol et.');
    }

    if (authenticated && _token != token) {
      throw const ApiFailure(
        'Oturumun sona erdi. Tekrar giriş yap.',
        status: 401,
      );
    }
    if (response.statusCode == 401 && authenticated) {
      final clearing = clearToken();
      onUnauthorized?.call();
      await clearing;
      throw const ApiFailure(
        'Oturumun sona erdi. Tekrar giriş yap.',
        status: 401,
      );
    }
    if (response.statusCode == 503) {
      try {
        final unavailable = jsonDecode(utf8.decode(response.bodyBytes));
        if (unavailable is Map &&
            unavailable['unavailable'] is String &&
            unavailable['message'] is String) {
          throw ApiFailure(unavailable['message'] as String, status: 503);
        }
      } on FormatException {
        // Generic server error below.
      }
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const ApiFailure('Sunucuya bağlanılamadı. Daha sonra tekrar dene.');
    }
    if (response.statusCode >= 500) {
      throw const ApiFailure(
        'Sunucuda bir sorun oluştu. Daha sonra tekrar dene.',
      );
    }

    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      json = decoded;
    } on FormatException {
      throw const ApiFailure('Sunucudan geçerli bir yanıt alınamadı.');
    }
    if (response.statusCode >= 400 || json['success'] != true) {
      final rawErrors = json['errors'];
      throw ApiFailure(
        json['message'] as String? ?? 'İşlem tamamlanamadı.',
        status: response.statusCode,
        errors: rawErrors is Map<String, dynamic>
            ? {
                for (final entry in rawErrors.entries)
                  if (entry.value is List && (entry.value as List).isNotEmpty)
                    entry.key: (entry.value as List).first.toString(),
              }
            : const {},
      );
    }
    return json['data'];
  }

  Map<String, String> mediaHeaders(String url) {
    final uri = Uri.tryParse(url);
    final token = _token;
    if (token != null &&
        uri?.hasAuthority == true &&
        uri!.origin == ApiConfig.base.origin &&
        ['post-media', 'message-images'].any(
          (path) => uri.path.startsWith(
            '${ApiConfig.base.path.replaceFirst(RegExp(r'/$'), '')}/$path/',
          ),
        )) {
      return {'Authorization': 'Bearer $token'};
    }
    return const {};
  }

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final uri = ApiConfig.base.resolve(path);
    return uri.scheme == 'https' ||
            (!const bool.fromEnvironment('dart.vm.product') &&
                uri.scheme == 'http' &&
                uri.origin == ApiConfig.base.origin)
        ? uri.toString()
        : '';
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_pending == 0) _http.close();
  }
}

Map<String, String> multipartFields(Map<String, Object?> body) {
  final fields = <String, String>{};
  void add(String key, Object? value) {
    if (value == null) return;
    if (value is Map) {
      for (final entry in value.entries) {
        add('$key[${entry.key}]', entry.value);
      }
    } else if (value is List) {
      for (final (index, entry) in value.indexed) {
        add('$key[$index]', entry);
      }
    } else {
      fields[key] = value.toString();
    }
  }

  for (final entry in body.entries) {
    add(entry.key, entry.value);
  }
  return fields;
}

class CatalogItem {
  const CatalogItem(this.id, this.name, {this.icon});

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
    json['id'] as int,
    json['name'] as String,
    icon: json['icon'] as String?,
  );

  final int id;
  final String name;
  final String? icon;

  static List<CatalogItem> list(dynamic data) => (data as List)
      .map((entry) => CatalogItem.fromJson(entry as Map<String, dynamic>))
      .toList(growable: false);
}

class AccountProfile {
  AccountProfile.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      username = json['username'] as String,
      activeCity = json['active_city'] is Map<String, dynamic>
          ? CatalogItem.fromJson(json['active_city'] as Map<String, dynamic>)
          : null,
      activeCitySource = json['active_city_source'] as String?,
      city = CatalogItem.fromJson(json['city'] as Map<String, dynamic>),
      avatar = ApiClient.mediaUrl(json['avatar'] as String?),
      cover = ApiClient.mediaUrl(json['cover_image'] as String?),
      bio = json['bio'] as String,
      occupation = json['occupation_school'] as String,
      connections = List<String>.from(json['connections'] as List),
      nearbyVisible = json['nearby_visible'] as bool,
      messagePrivacy = json['message_privacy'] as String? ?? 'everyone',
      showActivity = json['show_activity'] == true,
      pushPreferences = Map<String, bool>.from(
        json['push_preferences'] as Map? ?? const {},
      ),
      encounterSuggestions = json['encounter_suggestions'] as bool,
      cityDiscovery = json['city_discovery'] as bool,
      locationHistoryEnabled = json['location_history_enabled'] == true,
      onboardingStep = json['onboarding_step'] as int,
      interests = CatalogItem.list(json['interests']);

  final String messagePrivacy;
  final bool showActivity;
  final Map<String, bool> pushPreferences;
  final int id, onboardingStep;
  final String name, username, avatar, cover, bio, occupation;
  final CatalogItem city;
  final CatalogItem? activeCity;
  final String? activeCitySource;
  final List<String> connections;
  final bool nearbyVisible,
      encounterSuggestions,
      cityDiscovery,
      locationHistoryEnabled;
  final List<CatalogItem> interests;
}

class AuthService {
  AuthService(this.client);

  final ApiClient client;

  Future<AccountProfile?> restore() async {
    if (!await client.restoreToken()) return null;
    return AccountProfile.fromJson(
      await client.send('GET', 'auth/me', authenticated: true)
          as Map<String, dynamic>,
    );
  }

  Future<AccountProfile> signIn(String path, Map<String, Object?> body) async {
    final data = await client.send(
      'POST',
      'auth/$path',
      body: body,
    ) as Map<String, dynamic>;
    final profile = AccountProfile.fromJson(
      data['user'] as Map<String, dynamic>,
    );
    await client.saveToken(data['token'] as String);
    return profile;
  }

  Future<void> logout() async {
    await client.send('POST', 'auth/logout', authenticated: true);
    await client.clearToken();
  }

  Future<void> erase(String password) async {
    await client.send(
      'DELETE',
      'auth/account',
      authenticated: true,
      body: {'password': password, 'confirmation': 'SİL'},
    );
    await client.clearToken();
  }

  Future<void> forgot(String email) async {
    await client.send('POST', 'auth/forgot-password', body: {'email': email});
  }

  Future<void> reset(Map<String, Object?> body) async {
    await client.send('POST', 'auth/reset-password', body: body);
  }

  Future<void> changePassword(Map<String, Object?> body) async {
    await client.send('PUT', 'auth/password', authenticated: true, body: body);
  }
}

class ProfileService {
  ProfileService(this.client);

  final ApiClient client;

  Future<AccountProfile> save(Map<String, Object?> fields) async =>
      AccountProfile.fromJson(
        await client.send('PUT', 'profile', authenticated: true, body: fields)
            as Map<String, dynamic>,
      );

  Future<AccountProfile> uploadAvatar(XFile image) async =>
      AccountProfile.fromJson(
        await client.send(
          'POST',
          'profile/avatar',
          authenticated: true,
          avatar: image,
        ) as Map<String, dynamic>,
      );

  Future<AccountProfile> saveInterests(List<int> ids) async =>
      AccountProfile.fromJson(
        await client.send(
          'PUT',
          'profile/interests',
          authenticated: true,
          body: {'interest_ids': ids},
        ) as Map<String, dynamic>,
      );
}

class CatalogService {
  CatalogService(this.client);

  final ApiClient client;

  Future<List<CatalogItem>> cities() async =>
      CatalogItem.list(await client.send('GET', 'cities'));

  Future<List<CatalogItem>> interests() async =>
      CatalogItem.list(await client.send('GET', 'interests'));
}
