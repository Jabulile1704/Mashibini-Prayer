import 'package:package_info_plus/package_info_plus.dart';

/// Which build of the app this is.
///
/// Behind an interface for the same reason every other platform call in this
/// app is: so a widget test can state a version instead of asking the host
/// operating system for one it does not have.
abstract interface class AppVersion {
  /// Something like `1.0.0 (1)` — the semantic version and the build number.
  ///
  /// Both, deliberately. The semantic version says what changed; the build
  /// number says *which* build, and two builds of the same version are the
  /// normal case while a release is being tested on a phone.
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
