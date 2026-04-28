// lib/crypto/vault_crypto.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Vault Crypto Engine
///
/// PKI Flow:
///  1. Generate RSA-2048 key pair (stored in Flutter Secure Storage)
///  2. Key exchange: RSA-OAEP encrypts a random AES-256 session key
///  3. Messages: AES-256-CBC encrypted with random IV per message
///  4. Each conversation has a unique session key

class VaultCrypto {
  // ── RSA ──────────────────────────────────────────────────

  /// Generate a new RSA-2048 key pair.
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair() {
    final secureRandom = _buildSecureRandom();
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  /// Export RSA public key to PEM string.
  static String exportPublicKey(RSAPublicKey key) {
    final subject = SubjectPublicKeyInfo.fromPublicKey(key);
    final encoded = base64.encode(subject.encodedBytes);
    final chunks = RegExp('.{1,64}').allMatches(encoded).map((m) => m.group(0)!).join('\n');
    return '-----BEGIN PUBLIC KEY-----\n$chunks\n-----END PUBLIC KEY-----';
  }

  /// Export RSA private key to PEM string.
  static String exportPrivateKey(RSAPrivateKey key) {
    final info = PrivateKeyInfo.fromPrivateKey(key);
    final encoded = base64.encode(info.encodedBytes);
    final chunks = RegExp('.{1,64}').allMatches(encoded).map((m) => m.group(0)!).join('\n');
    return '-----BEGIN PRIVATE KEY-----\n$chunks\n-----END PRIVATE KEY-----';
  }

  /// Import RSA public key from PEM string.
  static RSAPublicKey importPublicKey(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    final bytes = base64.decode(b64);
    final asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    final seq = asn1Parser.nextObject() as ASN1Sequence;
    final bitString = seq.elements![1] as ASN1BitString;
    final pubKeyParser = ASN1Parser(bitString.stringValues!);
    final pubKeySeq = pubKeyParser.nextObject() as ASN1Sequence;
    final modulus = (pubKeySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (pubKeySeq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  /// Import RSA private key from PEM string.
  static RSAPrivateKey importPrivateKey(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    final bytes = base64.decode(b64);
    final asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    final seq = asn1Parser.nextObject() as ASN1Sequence;
    // PKCS#8: sequence > sequence > bitstring
    final innerSeq = seq.elements![2] as ASN1OctetString;
    final rsaParser = ASN1Parser(innerSeq.octets!);
    final rsaSeq = rsaParser.nextObject() as ASN1Sequence;
    final modulus   = (rsaSeq.elements![1] as ASN1Integer).integer!;
    final pubExp    = (rsaSeq.elements![2] as ASN1Integer).integer!;
    final privExp   = (rsaSeq.elements![3] as ASN1Integer).integer!;
    final p         = (rsaSeq.elements![4] as ASN1Integer).integer!;
    final q         = (rsaSeq.elements![5] as ASN1Integer).integer!;
    return RSAPrivateKey(modulus, privExp, p, q);
  }

  // ── RSA ENCRYPT / DECRYPT ─────────────────────────────────

  /// RSA-OAEP encrypt bytes with a public key.
  static Uint8List rsaEncrypt(RSAPublicKey publicKey, Uint8List data) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return _processInBlocks(cipher, data);
  }

  /// RSA-OAEP decrypt bytes with a private key.
  static Uint8List rsaDecrypt(RSAPrivateKey privateKey, Uint8List data) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return _processInBlocks(cipher, data);
  }

  static Uint8List _processInBlocks(AsymmetricBlockCipher cipher, Uint8List data) {
    final output = <int>[];
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + cipher.inputBlockSize).clamp(0, data.length);
      output.addAll(cipher.process(data.sublist(offset, end)));
      offset = end;
    }
    return Uint8List.fromList(output);
  }

  // ── AES-256-CBC ───────────────────────────────────────────

  /// Generate a random 256-bit AES key (returned as hex string).
  static String generateAESKey() {
    final key = enc.Key.fromSecureRandom(32);
    return key.base64; // store as base64
  }

  /// Generate a random 128-bit IV.
  static enc.IV generateIV() => enc.IV.fromSecureRandom(16);

  /// Encrypt plaintext with AES-256-CBC.
  /// Returns { ciphertext, iv } both base64-encoded.
  static Map<String, String> aesEncrypt(String plaintext, String keyBase64) {
    final key = enc.Key.fromBase64(keyBase64);
    final iv = generateIV();
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return {
      'ciphertext': encrypted.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypt AES-256-CBC ciphertext.
  static String aesDecrypt(String cipherBase64, String keyBase64, String ivBase64) {
    final key = enc.Key.fromBase64(keyBase64);
    final iv = enc.IV.fromBase64(ivBase64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }

  // ── KEY WRAPPING ──────────────────────────────────────────

  /// Wrap (RSA-encrypt) an AES session key for a recipient.
  static String wrapSessionKey(String aesKeyBase64, RSAPublicKey recipientPublicKey) {
    final keyBytes = base64.decode(aesKeyBase64);
    final encrypted = rsaEncrypt(recipientPublicKey, Uint8List.fromList(keyBytes));
    return base64.encode(encrypted);
  }

  /// Unwrap (RSA-decrypt) a session key with our private key.
  static String unwrapSessionKey(String wrappedBase64, RSAPrivateKey ourPrivateKey) {
    final encBytes = base64.decode(wrappedBase64);
    final decrypted = rsaDecrypt(ourPrivateKey, Uint8List.fromList(encBytes));
    return base64.encode(decrypted);
  }

  // ── UTILITIES ─────────────────────────────────────────────

  static String shortKey(String pem) {
    final clean = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    if (clean.length < 24) return clean;
    return '${clean.substring(0, 12)}…${clean.substring(clean.length - 12)}';
  }

  static SecureRandom _buildSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}

// ── ASN.1 Helpers ─────────────────────────────────────────────────────────────

class SubjectPublicKeyInfo {
  final Uint8List encodedBytes;
  SubjectPublicKeyInfo._(this.encodedBytes);

  static SubjectPublicKeyInfo fromPublicKey(RSAPublicKey key) {
    // Build the RSA public key sequence
    final keySeq = ASN1Sequence();
    keySeq.add(ASN1Integer(key.modulus!));
    keySeq.add(ASN1Integer(key.publicExponent!));
    keySeq.encode();

    // Wrap in BitString
    final bitString = ASN1BitString(stringValues: keySeq.encodedBytes);

    // Algorithm identifier for RSA
    final algIdSeq = ASN1Sequence();
    algIdSeq.add(ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1])); // rsaEncryption
    algIdSeq.add(ASN1Null());
    algIdSeq.encode();

    // SPKI sequence
    final spki = ASN1Sequence();
    spki.add(algIdSeq);
    spki.add(bitString);
    spki.encode();

    return SubjectPublicKeyInfo._(spki.encodedBytes!);
  }
}

class PrivateKeyInfo {
  final Uint8List encodedBytes;
  PrivateKeyInfo._(this.encodedBytes);

  static PrivateKeyInfo fromPrivateKey(RSAPrivateKey key) {
    final p = key.p!;
    final q = key.q!;
    final dP = key.privateExponent! % (p - BigInt.one);
    final dQ = key.privateExponent! % (q - BigInt.one);
    final qInv = q.modInverse(p);

    final rsaKey = ASN1Sequence();
    rsaKey.add(ASN1Integer(BigInt.zero));       // version
    rsaKey.add(ASN1Integer(key.modulus!));      // modulus
    rsaKey.add(ASN1Integer(key.publicExponent ?? BigInt.from(65537)));
    rsaKey.add(ASN1Integer(key.privateExponent!));
    rsaKey.add(ASN1Integer(p));
    rsaKey.add(ASN1Integer(q));
    rsaKey.add(ASN1Integer(dP));
    rsaKey.add(ASN1Integer(dQ));
    rsaKey.add(ASN1Integer(qInv));
    rsaKey.encode();

    final algIdSeq = ASN1Sequence();
    algIdSeq.add(ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 1]));
    algIdSeq.add(ASN1Null());
    algIdSeq.encode();

    final octet = ASN1OctetString(octets: rsaKey.encodedBytes!);

    final pkcs8 = ASN1Sequence();
    pkcs8.add(ASN1Integer(BigInt.zero));
    pkcs8.add(algIdSeq);
    pkcs8.add(octet);
    pkcs8.encode();

    return PrivateKeyInfo._(pkcs8.encodedBytes!);
  }
}
