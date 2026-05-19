import 'package:encrypt/encrypt.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecurityService {
  late final Fernet _fernet;
  late final Encrypter _encrypter;

  SecurityService() {
    final keyStr = dotenv.env['ENCRYPTION_KEY'] ?? 'fallback_key_if_needed';
    
    // Hash keyStr using SHA-256 to get exactly 32 bytes
    final bytes = utf8.encode(keyStr);
    final digest = sha256.convert(bytes);
    
    // Create Fernet key
    final key = Key(Uint8List.fromList(digest.bytes));
    _fernet = Fernet(key);
    _encrypter = Encrypter(_fernet);
  }

  String decrypt(dynamic encryptedText) {
    if (encryptedText == null) return '';
    final String str = encryptedText.toString().trim();
    if (str.isEmpty) return '';
    try {
      return _encrypter.decrypt(Encrypted.fromBase64(str));
    } catch (e) {
      // If decryption fails, return the raw text
      return str;
    }
  }

  String encrypt(String? text) {
    if (text == null || text.isEmpty) return '';
    try {
      return _encrypter.encrypt(text).base64;
    } catch (e) {
      return text ?? '';
    }
  }
}

final securityService = SecurityService();
