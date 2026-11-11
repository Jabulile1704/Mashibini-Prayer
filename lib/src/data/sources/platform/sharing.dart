import 'package:share_plus/share_plus.dart';

/// Handing something to whatever the phone can send things with.
abstract interface class Sharing {
  /// Opens the platform share sheet with [text].
  Future<bool> shareText({required String text, required String subject});
}

class PlatformSharing implements Sharing {
  const PlatformSharing();

  @override
  Future<bool> shareText({
    required String text,
    required String subject,
  }) async {
    final ShareResult result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
