import 'package:mashibini_prayer/src/data/sources/platform/photos.dart';

/// A photo library that never opens one.
///
/// [next] is what the picker "returns" — null for somebody tapping Cancel,
/// which is an ordinary answer rather than a failure and is the case most
/// worth testing. [throws] is a picker that will not open at all.
class FakePhotos implements Photos {
  FakePhotos({this.next, this.throws});

  String? next;
  Object? throws;

  final List<String> askedFor = <String>[];
  final List<String> removed = <String>[];

  @override
  Future<String?> pickFor(String memberId) async {
    askedFor.add(memberId);
    final Object? error = throws;
    if (error != null) {
      throw error;
    }
    return next;
  }

  @override
  Future<void> remove(String path) async => removed.add(path);
}
