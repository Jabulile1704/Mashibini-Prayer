// Reads the certificate an APK was signed with, and says so.
//
// This exists because the thing that was supposed to do it did not. The
// release workflow ran:
//
//     keytool -printcert -jarfile app-release.apk | grep -E 'Owner:|SHA256:' || true
//
// `-jarfile` reads only the **v1 JAR signature** — the `META-INF/*.RSA`
// block. Flutter's release APKs are signed with schemes v2 and v3 and carry
// no v1 block at all, so keytool found nothing, grep matched nothing, and
// `|| true` turned the non-zero exit into a pass. It reported success, every
// release, without ever reading a certificate (#103).
//
// What it was guarding is #67: Android refuses to install a release signed
// with a different key than the one already on the phone, and the only way
// through is uninstalling, which takes that phone's rota and journal with it
// (ADR-014). A silent guard on that is worse than none, because it is
// believed.
//
// Written in Dart rather than reaching for `apksigner` so that the check can
// be run by a person holding a downloaded APK on a laptop with no Android
// SDK — which is exactly what had to be done to find this bug — and so that
// the parsing is covered by the same `flutter test` as everything else.
//
// Usage:
//   dart run tool/apk_signing_key.dart <apk> [<apk> …]
//   dart run tool/apk_signing_key.dart <apk> --expect <sha256-hex>
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The magic that marks the end of an APK Signing Block.
const String signingBlockMagic = 'APK Sig Block 42';

/// Block ids for the v2 and v3 signature schemes.
const int schemeV2Id = 0x7109871a;
const int schemeV3Id = 0xf05368c0;

/// A signing certificate found in an APK, and which scheme carried it.
class ApkSigner {
  const ApkSigner({required this.scheme, required this.certificate});

  /// 'v2' or 'v3'.
  final String scheme;

  /// The DER-encoded X.509 certificate.
  final Uint8List certificate;

  /// SHA-256 of the DER bytes, lower-case hex.
  ///
  /// The same value `apksigner verify --print-certs` reports as the
  /// "certificate SHA-256 digest", so the two can be compared directly.
  String get fingerprint => sha256.convert(certificate).toString();
}

/// Raised when an APK cannot be read, or carries no v2/v3 signature.
///
/// An exception rather than an empty list on purpose. "No certificate found"
/// is the state this whole file exists to stop being mistaken for success.
class NotSignedException implements Exception {
  const NotSignedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every signing certificate in [apk], newest scheme last.
List<ApkSigner> signersOf(Uint8List apk) {
  final ByteData bytes = ByteData.sublistView(apk);
  final int directoryStart = _centralDirectoryOffset(apk, bytes);
  final Uint8List block = _signingBlock(apk, bytes, directoryStart);

  final List<ApkSigner> found = <ApkSigner>[];
  for (final _Pair pair in _pairs(block)) {
    final String? scheme = switch (pair.id) {
      schemeV2Id => 'v2',
      schemeV3Id => 'v3',
      _ => null,
    };
    if (scheme == null) {
      continue;
    }
    for (final Uint8List certificate in _certificates(pair.value)) {
      found.add(ApkSigner(scheme: scheme, certificate: certificate));
    }
  }

  if (found.isEmpty) {
    throw const NotSignedException(
      'An APK Signing Block is present but holds no v2 or v3 signer. '
      'This APK cannot be verified.',
    );
  }
  return found;
}

/// Where the ZIP central directory begins, read from the end-of-central-
/// directory record.
int _centralDirectoryOffset(Uint8List apk, ByteData bytes) {
  // The record is at the very end unless there is a ZIP comment, which may
  // be up to 65535 bytes. Scanned backwards for its signature.
  const int recordLength = 22;
  final int earliest = apk.length - recordLength - 0xFFFF;
  for (
    int i = apk.length - recordLength;
    i >= (earliest < 0 ? 0 : earliest);
    i--
  ) {
    if (bytes.getUint32(i, Endian.little) == 0x06054b50) {
      return bytes.getUint32(i + 16, Endian.little);
    }
  }
  throw const NotSignedException('Not a ZIP: no end-of-central-directory.');
}

/// The pairs region of the APK Signing Block that sits before [directoryStart].
Uint8List _signingBlock(Uint8List apk, ByteData bytes, int directoryStart) {
  if (directoryStart < 24 + signingBlockMagic.length) {
    throw const NotSignedException('No APK Signing Block: file is too short.');
  }
  final String magic = String.fromCharCodes(
    apk.sublist(directoryStart - 16, directoryStart),
  );
  if (magic != signingBlockMagic) {
    throw const NotSignedException(
      'No APK Signing Block. The APK is unsigned, or carries only a v1 JAR '
      'signature — which is the case keytool reads and nothing else does.',
    );
  }
  // The block's own length is written twice, before the pairs and after
  // them, so it can be found from either end. This reads the trailing copy
  // because only the end of the block is at a known offset.
  final int length = bytes.getUint64(directoryStart - 24, Endian.little);
  final int start = directoryStart - 8 - length;
  if (start < 0 || start + 8 > directoryStart - 24) {
    throw const NotSignedException('APK Signing Block length is nonsense.');
  }
  return apk.sublist(start + 8, directoryStart - 24);
}

class _Pair {
  const _Pair(this.id, this.value);

  final int id;
  final Uint8List value;
}

Iterable<_Pair> _pairs(Uint8List block) sync* {
  final ByteData bytes = ByteData.sublistView(block);
  int offset = 0;
  while (offset + 12 <= block.length) {
    final int length = bytes.getUint64(offset, Endian.little);
    if (length < 4 || offset + 8 + length > block.length) {
      throw const NotSignedException('A signing block pair runs off the end.');
    }
    yield _Pair(
      bytes.getUint32(offset + 8, Endian.little),
      block.sublist(offset + 12, offset + 8 + length),
    );
    offset += 8 + length;
  }
}

/// Reads one uint32-length-prefixed chunk, and where the next one starts.
(Uint8List, int) _chunk(Uint8List buffer, int offset) {
  final ByteData bytes = ByteData.sublistView(buffer);
  if (offset + 4 > buffer.length) {
    throw const NotSignedException('A length-prefixed chunk runs off the end.');
  }
  final int length = bytes.getUint32(offset, Endian.little);
  if (offset + 4 + length > buffer.length) {
    throw const NotSignedException('A length-prefixed chunk runs off the end.');
  }
  return (buffer.sublist(offset + 4, offset + 4 + length), offset + 4 + length);
}

/// signers → signer → signed data → (digests, certificates).
List<Uint8List> _certificates(Uint8List value) {
  final (Uint8List signers, _) = _chunk(value, 0);
  final List<Uint8List> found = <Uint8List>[];
  int offset = 0;
  while (offset < signers.length) {
    final (Uint8List signer, int next) = _chunk(signers, offset);
    offset = next;

    final (Uint8List signedData, _) = _chunk(signer, 0);
    // Digests come first and are skipped; certificates follow.
    final (_, int afterDigests) = _chunk(signedData, 0);
    final (Uint8List chain, _) = _chunk(signedData, afterDigests);

    int inner = 0;
    while (inner < chain.length) {
      final (Uint8List certificate, int nextCertificate) = _chunk(chain, inner);
      inner = nextCertificate;
      found.add(certificate);
    }
  }
  return found;
}

Future<void> main(List<String> arguments) async {
  final int expectAt = arguments.indexOf('--expect');
  final String? expected = expectAt >= 0 && expectAt + 1 < arguments.length
      ? arguments[expectAt + 1].trim().toLowerCase()
      : null;
  final List<String> paths = <String>[
    for (int i = 0; i < arguments.length; i++)
      if (i != expectAt && i != expectAt + 1) arguments[i],
  ];

  if (paths.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/apk_signing_key.dart <apk> [--expect <sha256>]',
    );
    exitCode = 64;
    return;
  }

  bool wrong = false;
  for (final String path in paths) {
    final List<ApkSigner> signers;
    try {
      signers = signersOf(await File(path).readAsBytes());
    } on NotSignedException catch (error) {
      stderr.writeln('$path: $error');
      wrong = true;
      continue;
    } on FileSystemException catch (error) {
      stderr.writeln('$path: ${error.message}');
      wrong = true;
      continue;
    }

    for (final ApkSigner signer in signers) {
      stdout.writeln('$path  ${signer.scheme}  SHA256:${signer.fingerprint}');
    }

    if (expected != null &&
        !signers.any((ApkSigner s) => s.fingerprint == expected)) {
      stderr.writeln(
        '$path: signed with a different key than every previous release.\n'
        '  expected  $expected\n'
        '  found     ${signers.map((ApkSigner s) => s.fingerprint).join('\n            ')}\n'
        'Android will refuse to install this over the version already on a '
        "phone, and uninstalling takes that phone's rota and journal with it "
        '(#67, ADR-014).',
      );
      wrong = true;
    }
  }

  if (wrong) {
    exitCode = 1;
  }
}
