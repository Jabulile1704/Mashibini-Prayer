import 'package:mashibini_prayer/src/data/sources/platform/sharing.dart';

/// A share sheet that does not open.
class FakeSharing implements Sharing {
  String? sharedText;
  String? sharedSubject;
  int shares = 0;

  /// What the sheet reports back. Set false to test a dismissal.
  bool accepted = true;

  /// Set to stand in for a platform with no share sheet at all, which is
  /// what `share_plus` throws on.
  Object? throws;

  @override
  Future<bool> shareText({
    required String text,
    required String subject,
  }) async {
    shares++;
    if (throws case final Object error) {
      throw error;
    }
    sharedText = text;
    sharedSubject = subject;
    return accepted;
  }
}
