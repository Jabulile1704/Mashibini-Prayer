import 'package:package_info_plus/package_info_plus.dart';

/// Which build of the app this is.
abstract interface class AppVersion {
  /// Something like `1.0.0 (1)` — the semantic version and the build number.
  Future<String> describe();
}

class PlatformAppVersion implements AppVersion {
  const PlatformAppVersion();

  @override
  Future<String> describe() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }
}
