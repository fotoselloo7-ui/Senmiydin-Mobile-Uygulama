import 'package:package_info_plus/package_info_plus.dart';

abstract final class ReleaseInfo {
  static Future<PackageInfo> get package => PackageInfo.fromPlatform();
}
