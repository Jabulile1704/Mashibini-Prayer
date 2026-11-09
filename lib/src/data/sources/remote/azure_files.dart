import 'dart:convert';
import 'dart:io';

import '../platform/identity.dart';
import 'remote_files.dart';

/// Azure Blob Storage, reached through a Function that mints the key
/// (ADR-024).
///
/// The phone never holds an Azure credential. It asks a Function for a
/// short-lived SAS URL, proving who it is with the Firebase ID token it
/// already has from signing in (#76), and then `PUT`s the bytes straight at
/// Blob. The Function is the only thing that knows the storage account key.
///
/// ```text
///   phone ──(Firebase ID token)──► Function ──► SAS URL
///   phone ──────────(PUT bytes)─────────────► Blob
/// ```
///
/// **Nothing here throws.** ADR-024's third term is that the app behaves
/// exactly as it does today if any of this is unavailable, and the file is
/// already on the phone by the time any of these methods are called. So a
/// failure returns false and the caller carries on — which is also what
/// happens on the thirty-first day of a thirty-day credit, deliberately
/// and without a code change.
class AzureFiles implements RemoteFiles {
  AzureFiles({
    required this.functionBaseUrl,
    required this.identity,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  /// Where the SAS-minting Function lives, or empty if nobody has deployed
  /// one. Read from `--dart-define=AZURE_FILES_URL=...` in `main.dart`, so
  /// removing the spike is a build flag rather than an edit.
  final String functionBaseUrl;

  final Identity identity;
  final HttpClient _client;

  @override
  bool get isConfigured => functionBaseUrl.isNotEmpty;

  @override
  Future<bool> upload(File file, {required String key}) async {
    if (!isConfigured) {
      return false;
    }
    try {
      final Uri? target = await _sasFor(key, write: true);
      if (target == null) {
        return false;
      }

      final HttpClientRequest request = await _client.putUrl(target);
      // Required by Blob for a block blob; without it the PUT is refused
      // with a 400 that reads like an auth problem and is not one.
      request.headers.set('x-ms-blob-type', 'BlockBlob');
      request.headers.contentType = ContentType.binary;
      request.add(await file.readAsBytes());

      final HttpClientResponse response = await request.close();
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Object {
      // Deliberately swallowed. See the class comment: a file that did not
      // reach Azure is the behaviour this app shipped with.
      return false;
    }
  }

  @override
  Future<File?> download(String key, {required File destination}) async {
    if (!isConfigured) {
      return null;
    }
    try {
      final Uri? source = await _sasFor(key, write: false);
      if (source == null) {
        return null;
      }

      final HttpClientResponse response = await (await _client.getUrl(source))
          .close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }

      final List<int> bytes = <int>[
        await for (final List<int> chunk in response) ...chunk,
      ];
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(bytes);
      return destination;
    } on Object {
      return null;
    }
  }

  /// Asks the Function for a URL that grants one operation on one blob.
  ///
  /// Returns null when nobody is signed in, which is not a failure: the
  /// rules require an identity (ADR-023) and a phone that has not signed in
  /// simply keeps its files to itself.
  Future<Uri?> _sasFor(String key, {required bool write}) async {
    final SignedIn? who = identity.current;
    if (who == null) {
      return null;
    }

    final Uri ask = Uri.parse(functionBaseUrl).replace(
      queryParameters: <String, String>{
        'key': key,
        'permission': write ? 'w' : 'r',
      },
    );

    final HttpClientRequest request = await _client.getUrl(ask);
    // The Function verifies this against Firebase rather than trusting it.
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${who.uid}');
    final HttpClientResponse response = await request.close();

    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }

    final String body = await response.transform(utf8.decoder).join();
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final Object? url = decoded['url'];
    return url is String ? Uri.tryParse(url) : null;
  }
}
