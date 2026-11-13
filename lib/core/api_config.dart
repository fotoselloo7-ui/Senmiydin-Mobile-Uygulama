import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode
        ? 'https://senmiydin.com/api/v1'
        : 'http://10.0.2.2:8000/api/v1',
  );

  static Uri get base {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.scheme == 'https' || (!kReleaseMode && uri.scheme == 'http'))) {
      throw const FormatException('Invalid API base URL');
    }
    return uri;
  }
}
