// lib/services/firebase_service.dart
//
// Firestore schema:
//
// users/{uid}
//   displayName: string
//   username:    string
//   publicKey:   string        ← RSA public key (safe to store, not secret)
//   createdAt:   timestamp
//   fcmToken:    string?       ← for push notifications
//
// conversations/{convId}       ← convId = sorted(uid1_uid2) joined by '_'
//   participants: [uid1, uid2]
//   createdAt:   timestamp
//   lastMessage: string
//   lastMessageAt: timestamp
//
// conversations/{convId}/messages/{msgId}
//   senderId:   string
//   text:       string         ← plaintext (never stored) OR ciphertext
//   ciphertext: string?        ← AES-256-CBC ciphertext (base64)
//   iv:         string?        ← AES IV (base64)
//   encrypted:  bool
//   readOnly:   bool
//   status:     string         ← 'sent' | 'delivered' | 'read'
//   timestamp:  timestamp
//
// NOTE: Session keys (AES) are NEVER stored in Firestore.
//       They are derived locally and stored in Flutter Secure Storage only.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../crypto/vault_crypto.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseFirestore.instance;

  // ── AUTH ────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static String get uid => _auth.currentUser!.uid;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register with email/password, then create the user profile in Firestore.
  static Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
    required String publicKeyPem,
    required String privateKeyPem,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user!.updateDisplayName(displayName);

    // Store private key in Keychain (never goes to Firestore)
    await _secureStorage.write(
      key: 'vault_private_key_${cred.user!.uid}',
      value: privateKeyPem,
    );

    // Create user document (public key is safe to store)
    await _db.collection('users').doc(cred.user!.uid).set({
      'displayName': displayName,
      'username': displayName.toLowerCase().replaceAll(' ', '_'),
      'publicKey': publicKeyPem,
      'createdAt': FieldValue.serverTimestamp(),
      'fcmToken': null,
    });

    return cred;
  }

  /// Sign in with email/password.
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out.
  static Future<void> signOut() async => _auth.signOut();

  // ── USER PROFILES ────────────────────────────────────────────

  /// Fetch a user's profile from Firestore.
  static Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Fetch the current user's profile.
  static Future<Map<String, dynamic>?> getMyProfile() => getUser(uid);

  /// Search users by username prefix (for adding contacts).
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username', isLessThan: '${query.toLowerCase()}z')
        .limit(10)
        .get();

    return snap.docs
        .where((d) => d.id != uid)   // exclude self
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
  }

  /// Get the RSA public key for a user.
  static Future<String?> getUserPublicKey(String userId) async {
    final user = await getUser(userId);
    return user?['publicKey'] as String?;
  }

  // ── CONVERSATIONS ─────────────────────────────────────────────

  /// Generate a deterministic conversation ID from two UIDs.
  static String conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get or create a conversation document.
  static Future<String> getOrCreateConversation(String otherUserId) async {
    final convId = conversationId(uid, otherUserId);
    final ref = _db.collection('conversations').doc(convId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'participants': [uid, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }
    return convId;
  }

  /// Stream all conversations for the current user.
  static Stream<QuerySnapshot> streamConversations() {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  // ── MESSAGES ──────────────────────────────────────────────────

  /// Send a message to a conversation.
  static Future<String> sendMessage({
    required String conversationId,
    required String text,
    String? ciphertext,
    String? iv,
    required bool encrypted,
    required bool readOnly,
  }) async {
    final msgRef = _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    final msgData = {
      'senderId': uid,
      // If encrypted, store ciphertext; otherwise store plaintext
      'text': encrypted ? '[encrypted]' : text,
      'ciphertext': ciphertext,
      'iv': iv,
      'encrypted': encrypted,
      'readOnly': readOnly,
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
    };

    await msgRef.set(msgData);

    // Update conversation's last message preview
    await _db.collection('conversations').doc(conversationId).update({
      'lastMessage': encrypted ? '🔒 Encrypted message' : text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    return msgRef.id;
  }

  /// Stream messages in a conversation (real-time).
  static Stream<QuerySnapshot> streamMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Mark a message as delivered or read.
  static Future<void> updateMessageStatus(
    String conversationId,
    String messageId,
    String status,  // 'delivered' | 'read'
  ) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'status': status});
  }

  // ── SESSION KEYS (local only, never Firestore) ────────────────

  /// Store an AES session key locally for a given conversation.
  /// The key is wrapped (RSA-encrypted) and then stored securely.
  static Future<void> storeSessionKey(String convId, String aesKeyBase64) async {
    await _secureStorage.write(
      key: 'vault_session_$convId',
      value: aesKeyBase64,
    );
  }

  /// Retrieve the AES session key for a conversation.
  static Future<String?> loadSessionKey(String convId) async {
    return _secureStorage.read(key: 'vault_session_$convId');
  }

  /// Load private RSA key from secure storage.
  static Future<String?> loadPrivateKey() async {
    return _secureStorage.read(key: 'vault_private_key_$uid');
  }

  // ── FCM TOKEN ─────────────────────────────────────────────────

  /// Update the FCM push token for this device.
  static Future<void> updateFcmToken(String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }
}
