// lib/services/messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/vault_crypto.dart';
import 'firebase_service.dart';

// ── CONTACT / CONVERSATION MODEL ─────────────────────────────────────────────

class FirebaseContact {
  final String userId;       // Firebase UID of the other person
  final String displayName;
  final String username;
  final String publicKey;    // Their RSA public key
  final String conversationId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool isOnline;

  const FirebaseContact({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.publicKey,
    required this.conversationId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.isOnline = false,
  });

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ── FIREBASE MESSAGE MODEL ────────────────────────────────────────────────────

class FirebaseMessage {
  final String id;
  final String senderId;
  final String text;           // Plaintext (decrypted locally)
  final String? ciphertext;
  final String? iv;
  final bool encrypted;
  final bool readOnly;
  final String status;
  final DateTime timestamp;

  bool get isMe => senderId == FirebaseService.uid;

  const FirebaseMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.ciphertext,
    this.iv,
    required this.encrypted,
    required this.readOnly,
    required this.status,
    required this.timestamp,
  });

  factory FirebaseMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FirebaseMessage(
      id:         doc.id,
      senderId:   d['senderId'] ?? '',
      text:       d['text'] ?? '',
      ciphertext: d['ciphertext'],
      iv:         d['iv'],
      encrypted:  d['encrypted'] ?? false,
      readOnly:   d['readOnly'] ?? false,
      status:     d['status'] ?? 'sent',
      timestamp:  (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ── PROVIDERS ─────────────────────────────────────────────────────────────────

/// Stream of conversations for the current user.
final conversationsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseService.streamConversations().map((snap) =>
    snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList()
  );
});

/// Stream of messages for a specific conversation.
final messagesStreamProvider = StreamProvider.family<List<FirebaseMessage>, String>((ref, convId) {
  return FirebaseService.streamMessages(convId).map((snap) {
    final msgs = snap.docs.map((d) => FirebaseMessage.fromDoc(d)).toList();
    // Mark incoming messages as read
    for (final msg in msgs) {
      if (!msg.isMe && msg.status != 'read') {
        FirebaseService.updateMessageStatus(convId, msg.id, 'read');
      }
    }
    return msgs;
  });
});

// ── MESSAGING NOTIFIER ────────────────────────────────────────────────────────

class MessagingNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Send a message.
  /// If encrypted=true, AES-encrypts the text before sending to Firestore.
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String? sessionKeyBase64,
    required bool encrypted,
    required bool readOnly,
  }) async {
    String? ciphertext;
    String? iv;

    if (encrypted && sessionKeyBase64 != null) {
      try {
        final result = VaultCrypto.aesEncrypt(text, sessionKeyBase64);
        ciphertext = result['ciphertext'];
        iv = result['iv'];
      } catch (e) {
        // Fallback: send unencrypted if crypto fails
      }
    }

    await FirebaseService.sendMessage(
      conversationId: conversationId,
      text: text,
      ciphertext: ciphertext,
      iv: iv,
      encrypted: encrypted && ciphertext != null,
      readOnly: readOnly,
    );
  }

  /// Decrypt a received message using the session key.
  String decryptMessage(FirebaseMessage msg, String sessionKeyBase64) {
    if (!msg.encrypted || msg.ciphertext == null || msg.iv == null) {
      return msg.text;
    }
    try {
      return VaultCrypto.aesDecrypt(msg.ciphertext!, sessionKeyBase64, msg.iv!);
    } catch (_) {
      return '[decryption failed]';
    }
  }

  /// Establish a new encrypted conversation with a user:
  ///  1. Fetch their RSA public key from Firestore
  ///  2. Generate a new AES session key
  ///  3. RSA-wrap it (in production, exchange via Firestore handshake doc)
  ///  4. Store AES key locally in Secure Storage
  Future<String?> startConversation(String otherUserId) async {
    try {
      // Get or create the Firestore conversation doc
      final convId = await FirebaseService.getOrCreateConversation(otherUserId);

      // Check if we already have a session key
      final existing = await FirebaseService.loadSessionKey(convId);
      if (existing != null) return convId;

      // Generate and store a new session key
      final sessionKey = VaultCrypto.generateAESKey();
      await FirebaseService.storeSessionKey(convId, sessionKey);

      return convId;
    } catch (e) {
      return null;
    }
  }
}

final messagingNotifierProvider = NotifierProvider<MessagingNotifier, AsyncValue<void>>(
  MessagingNotifier.new,
);

// ── USER SEARCH PROVIDER ──────────────────────────────────────────────────────

final userSearchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) {
  if (query.length < 2) return Future.value([]);
  return FirebaseService.searchUsers(query);
});
