import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/apk_signing_key.dart';

/// The parser behind the check that #103 found doing nothing.
void main() {
  /// A DER certificate, as far as this parser is concerned: opaque bytes.
  Uint8List certificateBytes(String seed) =>
      Uint8List.fromList(utf8.encode('-----CERT-----$seed'));

  /// uint32 length, then the payload.
  Uint8List chunk(List<int> payload) {
    final BytesBuilder out = BytesBuilder();
    out.add(
      (ByteData(
        4,
      )..setUint32(0, payload.length, Endian.little)).buffer.asUint8List(),
    );
    out.add(payload);
    return out.toBytes();
  }

  /// The value of a v2/v3 block: signers → signer → signed data →
  /// (digests, certificates).
  Uint8List signerValue(List<Uint8List> certificates) {
    final BytesBuilder chain = BytesBuilder();
    for (final Uint8List certificate in certificates) {
      chain.add(chunk(certificate));
    }
    final BytesBuilder signedData = BytesBuilder()
      ..add(chunk(<int>[1, 2, 3, 4])) // digests, skipped by the parser
      ..add(chunk(chain.toBytes()));
    final Uint8List signer = chunk(signedData.toBytes());
    return chunk(chunk(signer));
  }

  /// `uint64 length | uint32 id | value`.
  Uint8List pair(int id, Uint8List value) {
    final BytesBuilder out = BytesBuilder();
    out.add(
      (ByteData(
        8,
      )..setUint64(0, 4 + value.length, Endian.little)).buffer.asUint8List(),
    );
    out.add(
      (ByteData(4)..setUint32(0, id, Endian.little)).buffer.asUint8List(),
    );
    out.add(value);
    return out.toBytes();
  }

  /// The block's length is written at both ends so it can be found from
  /// either; the parser reads the trailing copy.
  Uint8List signingBlock(List<Uint8List> pairs) {
    final BytesBuilder body = BytesBuilder();
    for (final Uint8List p in pairs) {
      body.add(p);
    }
    final int length = body.length + 8 + signingBlockMagic.length;
    final Uint8List size = (ByteData(
      8,
    )..setUint64(0, length, Endian.little)).buffer.asUint8List();

    return (BytesBuilder()
          ..add(size)
          ..add(body.toBytes())
          ..add(size)
          ..add(utf8.encode(signingBlockMagic)))
        .toBytes();
  }

  /// A ZIP holding no entries, whose central directory begins wherever the
  /// signing block ends.
  Uint8List apkWith(Uint8List? block) {
    final BytesBuilder out = BytesBuilder();
    if (block != null) {
      out.add(block);
    }
    final int directoryStart = out.length;

    final ByteData record = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint32(16, directoryStart, Endian.little);
    out.add(record.buffer.asUint8List());
    return out.toBytes();
  }

  group('finds the certificate', () {
    test('in a v2 block', () {
      final Uint8List certificate = certificateBytes('one');
      final Uint8List apk = apkWith(
        signingBlock(<Uint8List>[
          pair(schemeV2Id, signerValue(<Uint8List>[certificate])),
        ]),
      );

      final List<ApkSigner> signers = signersOf(apk);

      expect(signers, hasLength(1));
      expect(signers.single.scheme, 'v2');
      expect(signers.single.certificate, certificate);
    });

    test('in a v3 block, which is what newer builds carry', () {
      final Uint8List apk = apkWith(
        signingBlock(<Uint8List>[
          pair(schemeV3Id, signerValue(<Uint8List>[certificateBytes('three')])),
        ]),
      );

      expect(signersOf(apk).single.scheme, 'v3');
    });

    test('past blocks it does not understand', () {
      final Uint8List apk = apkWith(
        signingBlock(<Uint8List>[
          pair(0x42726577, Uint8List.fromList(<int>[9, 9, 9])),
          pair(schemeV2Id, signerValue(<Uint8List>[certificateBytes('one')])),
        ]),
      );

      expect(signersOf(apk), hasLength(1));
    });

    test('the fingerprint is SHA-256 of the DER bytes', () {
      final Uint8List certificate = certificateBytes('one');
      final Uint8List apk = apkWith(
        signingBlock(<Uint8List>[
          pair(schemeV2Id, signerValue(<Uint8List>[certificate])),
        ]),
      );

      expect(
        signersOf(apk).single.fingerprint,
        sha256.convert(certificate).toString(),
      );
    });
  });

  group('refuses rather than reporting nothing', () {
    test('a ZIP with no signing block at all', () {
      expect(
        () => signersOf(apkWith(null)),
        throwsA(
          isA<NotSignedException>().having(
            (NotSignedException e) => e.toString(),
            'message',
            contains('No APK Signing Block'),
          ),
        ),
      );
    });

    test('a signing block carrying no v2 or v3 signer', () {
      final Uint8List apk = apkWith(
        signingBlock(<Uint8List>[
          pair(0x42726577, Uint8List.fromList(<int>[1, 2, 3])),
        ]),
      );

      expect(
        () => signersOf(apk),
        throwsA(
          isA<NotSignedException>().having(
            (NotSignedException e) => e.toString(),
            'message',
            contains('no v2 or v3 signer'),
          ),
        ),
      );
    });

    test('something that is not a ZIP', () {
      expect(
        () => signersOf(Uint8List.fromList(utf8.encode('not an apk at all'))),
        throwsA(isA<NotSignedException>()),
      );
    });

    test('a pair whose length runs off the end', () {
      final Uint8List good = apkWith(
        signingBlock(<Uint8List>[
          pair(schemeV2Id, signerValue(<Uint8List>[certificateBytes('one')])),
        ]),
      );
      final Uint8List corrupt = Uint8List.fromList(good);
      ByteData.sublistView(corrupt).setUint64(8, 1 << 40, Endian.little);

      expect(() => signersOf(corrupt), throwsA(isA<NotSignedException>()));
    });
  });

  test('two releases signed with one key share a fingerprint', () {
    final Uint8List certificate = certificateBytes('the release key');
    Uint8List release() => apkWith(
      signingBlock(<Uint8List>[
        pair(schemeV2Id, signerValue(<Uint8List>[certificate])),
      ]),
    );

    expect(
      signersOf(release()).single.fingerprint,
      signersOf(release()).single.fingerprint,
    );
    expect(
      signersOf(release()).single.fingerprint,
      isNot(
        signersOf(
          apkWith(
            signingBlock(<Uint8List>[
              pair(
                schemeV2Id,
                signerValue(<Uint8List>[certificateBytes('a debug key')]),
              ),
            ]),
          ),
        ).single.fingerprint,
      ),
    );
  });
}
