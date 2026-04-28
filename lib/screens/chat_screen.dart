// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/messaging_service.dart';
import '../widgets/vault_widgets.dart';
import '../crypto/vault_crypto.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String convId;
  final String contactName;
  final String contactInitials;
  final Color  contactColor;
  final String contactUserId;

  const ChatScreen({
    super.key,
    required this.convId,
    required this.contactName,
    required this.contactInitials,
    required this.contactColor,
    required this.contactUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  bool   _showCipher    = false;
  String _sessionKey    = '';
  String _peerPublicKey = '';
  String _myPublicKey   = '';

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    final sk        = await FirebaseService.loadSessionKey(widget.convId);
    final myProfile = await FirebaseService.getMyProfile();
    String peerKey  = '';
    if (widget.contactUserId.isNotEmpty) {
      final peer = await FirebaseService.getUser(widget.contactUserId);
      peerKey = peer?['publicKey'] as String? ?? '';
    }
    if (mounted) setState(() {
      _sessionKey    = sk ?? '';
      _myPublicKey   = myProfile?['publicKey'] as String? ?? '';
      _peerPublicKey = peerKey;
    });
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text, {required bool encrypted, required bool readOnly}) async {
    await ref.read(messagingNotifierProvider.notifier).sendMessage(
      conversationId: widget.convId,
      text: text,
      sessionKeyBase64: _sessionKey.isNotEmpty ? _sessionKey : null,
      encrypted: encrypted,
      readOnly: readOnly,
    );
    _scrollBottom();
  }

  String _decrypt(FirebaseMessage msg) {
    if (!msg.encrypted || msg.ciphertext == null || msg.iv == null || _sessionKey.isEmpty) {
      return msg.text;
    }
    try {
      return VaultCrypto.aesDecrypt(msg.ciphertext!, _sessionKey, msg.iv!);
    } catch (_) {
      return '[decryption failed]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.convId));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/contacts'),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.chevron_left, color: AppColors.text, size: 28),
                    ),
                  ),
                  VaultAvatar(initials: widget.contactInitials, color: widget.contactColor, size: 38),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.contactName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                        Row(children: [
                          Container(width: 6, height: 6,
                            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                          const Gap(5),
                          const Text('E2E encrypted · Firebase sync',
                            style: TextStyle(fontSize: 11, color: AppColors.accent)),
                        ]),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showCipher = !_showCipher),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _showCipher ? AppColors.accent2Dim : AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _showCipher
                          ? AppColors.accent2.withOpacity(0.3) : AppColors.border),
                      ),
                      child: Text(_showCipher ? '👁 Raw' : '💬 Text',
                        style: const TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  KeyBadge(onTap: () => EncryptionModal.show(
                    context,
                    myPublicKey: _myPublicKey,
                    sessionKey: _sessionKey.isNotEmpty ? _sessionKey : null,
                    peerPublicKey: _peerPublicKey.isNotEmpty ? _peerPublicKey : null,
                    contactName: widget.contactName,
                  )),
                ],
              ),
            ),

            // E2E banner
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent2Dim,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent2.withOpacity(0.2)),
                ),
                child: const Text(
                  '🔑 RSA key exchange · AES-256-CBC · Synced via Firestore',
                  style: TextStyle(fontSize: 10, color: AppColors.accent2, fontFamily: 'DMMono'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Messages — real-time Firestore stream
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔐', style: TextStyle(fontSize: 48)),
                          Gap(12),
                          Text('Messages are end-to-end encrypted\nand synced in real-time via Firebase.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.text2, height: 1.5)),
                        ],
                      ),
                    );
                  }
                  _scrollBottom();
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg  = messages[i];
                      final isMe = msg.senderId == FirebaseService.uid;
                      return MessageBubble(
                        isOut:      isMe,
                        text:       _decrypt(msg),
                        ciphertext: msg.ciphertext,
                        encrypted:  msg.encrypted,
                        readOnly:   msg.readOnly,
                        showCipher: _showCipher,
                        status:     msg.status,
                        time:       DateFormat('HH:mm').format(msg.timestamp),
                      );
                    },
                  );
                },
              ),
            ),

            // Compose bar
            ComposeBar(onSend: (text, {required encrypted, required readOnly}) =>
              _handleSend(text, encrypted: encrypted, readOnly: readOnly)),
          ],
        ),
      ),
    );
  }
}
