import 'package:mashibini_prayer/src/data/sources/platform/app_version.dart';

/// A version a test can state, rather than one the host happens to report.
class FakeAppVersion implements AppVersion {
  FakeAppVersion([this.value = '1.0.0 (1)']);

  String value;
  int calls = 0;

  @override
  Future<String> describe() async {
    calls++;
    return value;
  }
}
