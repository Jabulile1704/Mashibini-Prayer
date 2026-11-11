import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';
import 'package:mashibini_prayer/src/data/sources/remote/azure_files.dart';
import 'package:mashibini_prayer/src/data/sources/remote/remote_files.dart';

import '../support/fake_identity.dart';

/// ADR-024's third term, as tests.
void main() {
  late Directory scratch;
  late File something;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('mashibini-files');
    something = File('${scratch.path}/a-song.mp3')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  group('when there is no remote store at all', () {
    const RemoteFiles files = FilesStayOnThisPhone();

    test('it says so, rather than pretending', () {
      expect(files.isConfigured, isFalse);
    });

    test('uploading answers false and does not throw', () async {
      expect(await files.upload(something, key: 'song/1'), isFalse);
    });

    test('downloading answers null and does not throw', () async {
      expect(
        await files.download(
          'song/1',
          destination: File('${scratch.path}/out.mp3'),
        ),
        isNull,
      );
    });

    test('the file it was given is untouched', () async {
      await files.upload(something, key: 'song/1');
      expect(something.existsSync(), isTrue);
      expect(something.readAsBytesSync(), <int>[1, 2, 3, 4]);
    });
  });

  group('Azure, unconfigured', () {
    test('an empty Function url is simply not configured', () {
      final AzureFiles files = AzureFiles(
        functionBaseUrl: '',
        identity: FakeIdentity(),
      );

      expect(files.isConfigured, isFalse);
    });

    test('and it does not attempt anything', () async {
      final AzureFiles files = AzureFiles(
        functionBaseUrl: '',
        identity: FakeIdentity(),
      );

      expect(await files.upload(something, key: 'k'), isFalse);
      expect(
        await files.download('k', destination: File('${scratch.path}/o')),
        isNull,
      );
    });
  });

  group('Azure, configured but not working', () {
    test('nobody signed in means nothing leaves the phone', () async {
      final AzureFiles files = AzureFiles(
        functionBaseUrl: 'http://127.0.0.1:1/sas',
        identity: FakeIdentity(),
      );

      expect(await files.upload(something, key: 'k'), isFalse);
    });

    test('an unreachable Function is false, not an exception', () async {
      final AzureFiles files = AzureFiles(
        functionBaseUrl: 'http://127.0.0.1:1/sas',
        identity: FakeIdentity(signedIn: const SignedIn(uid: 'uid-jabulile')),
      );

      expect(await files.upload(something, key: 'k'), isFalse);
      expect(
        await files.download('k', destination: File('${scratch.path}/o')),
        isNull,
      );
    });

    test('a Function that errors is false, not an exception', () async {
      final HttpServer broken = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      unawaited(
        broken.forEach((HttpRequest request) {
          request.response.statusCode = 500;
          request.response.close();
        }),
      );
      addTearDown(() => broken.close(force: true));

      final AzureFiles files = AzureFiles(
        functionBaseUrl: 'http://127.0.0.1:${broken.port}/sas',
        identity: FakeIdentity(signedIn: const SignedIn(uid: 'uid-jabulile')),
      );

      expect(await files.upload(something, key: 'k'), isFalse);
    });

    test('a Function answering nonsense is false, not an exception', () async {
      final HttpServer nonsense = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      unawaited(
        nonsense.forEach((HttpRequest request) {
          request.response.write('<html>Sign in to Azure</html>');
          request.response.close();
        }),
      );
      addTearDown(() => nonsense.close(force: true));

      final AzureFiles files = AzureFiles(
        functionBaseUrl: 'http://127.0.0.1:${nonsense.port}/sas',
        identity: FakeIdentity(signedIn: const SignedIn(uid: 'uid-jabulile')),
      );

      expect(await files.upload(something, key: 'k'), isFalse);
    });
  });

  group('Azure, working', () {
    test('it asks for a key and then puts the bytes where told', () async {
      final List<String> seen = <String>[];
      late HttpServer server;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.forEach((HttpRequest request) async {
          seen.add('${request.method} ${request.uri.path}');
          if (request.uri.path == '/sas') {
            request.response.write(
              '{"url":"http://127.0.0.1:${server.port}/blob/a-song.mp3"}',
            );
          } else {
            seen.add('blob-type=${request.headers.value('x-ms-blob-type')}');
            request.response.statusCode = 201;
          }
          await request.response.close();
        }),
      );
      addTearDown(() => server.close(force: true));

      final AzureFiles files = AzureFiles(
        functionBaseUrl: 'http://127.0.0.1:${server.port}/sas',
        identity: FakeIdentity(signedIn: const SignedIn(uid: 'uid-jabulile')),
      );

      expect(await files.upload(something, key: 'song/1'), isTrue);
      expect(seen, contains('GET /sas'));
      expect(seen, contains('PUT /blob/a-song.mp3'));
      expect(
        seen,
        contains('blob-type=BlockBlob'),
        reason:
            'Blob refuses a block blob PUT without it, with a 400 that '
            'reads like an auth failure and is not one',
      );
    });
  });
}
