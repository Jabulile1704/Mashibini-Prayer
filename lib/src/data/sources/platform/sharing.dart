import 'package:share_plus/share_plus.dart';

/// Handing something to whatever the phone can send things with.
///
/// An interface for the same reason [Reminders] is one: the half that talks
/// to the operating system cannot be run in a test, and the half that
/// decides *what* to send can. `JournalExport` builds the document and is
/// pure; this sends it and is not.
abstract interface class Sharing {
  /// Opens the platform share sheet with [text].
  ///
  /// Returns false when the person dismissed it without choosing anything,
  /// so a caller can tell "sent" from "changed their mind" rather than
  /// claiming success either way.
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
    // `unavailable` means the platform could not say — every desktop and
    // some Android share targets. Treated as sent, because the sheet did
    // open and telling somebody their journal was not shared when it may
    // well have been is the worse of the two wrong answers.
    return result.status != ShareResultStatus.dismissed;
  }
}
