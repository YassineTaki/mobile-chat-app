// lib/widgets/vault_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../crypto/vault_crypto.dart';

// ── AVATAR ────────────────────────────────────────────────────────────────────

class VaultAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final bool? isOnline;

  const VaultAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 48,
    this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(size * 0.33),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: color,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isOnline != null)
            Positioned(
              bottom: size * 0.02,
              right: size * 0.02,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: isOnline! ? AppColors.accent : AppColors.text3,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: size * 0.05),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KEY BADGE ─────────────────────────────────────────────────────────────────

class KeyBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;

  const KeyBadge({super.key, this.onTap, this.label = 'E2EE'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔐', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFamily: 'DMMono',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ENCRYPTION MODAL ─────────────────────────────────────────────────────────

class EncryptionModal extends StatelessWidget {
  final String myPublicKey;
  final String? sessionKey;
  final String? peerPublicKey;
  final String? contactName;

  const EncryptionModal({
    super.key,
    required this.myPublicKey,
    this.sessionKey,
    this.peerPublicKey,
    this.contactName,
  });

  static Future<void> show(
    BuildContext context, {
    required String myPublicKey,
    String? sessionKey,
    String? peerPublicKey,
    String? contactName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EncryptionModal(
        myPublicKey: myPublicKey,
        sessionKey: sessionKey,
        peerPublicKey: peerPublicKey,
        contactName: contactName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.border2),
            left: BorderSide(color: AppColors.border2),
            right: BorderSide(color: AppColors.border2),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    contactName != null ? 'Session Keys — $contactName' : 'My Cryptographic Identity',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contactName != null
                        ? 'AES-256-CBC session key from RSA-2048 PKI exchange'
                        : 'Your RSA-2048 key pair for key exchange',
                    style: const TextStyle(fontSize: 13, color: AppColors.text2),
                  ),
                  const SizedBox(height: 20),
                  _KeySection(label: 'My RSA-2048 Public Key', value: myPublicKey, color: AppColors.accent),
                  if (sessionKey != null)
                    _KeySection(label: 'AES-256 Session Key (this chat)', value: sessionKey!, color: AppColors.accent2),
                  if (peerPublicKey != null)
                    _KeySection(label: '${contactName ?? "Peer"} RSA Public Key', value: peerPublicKey!, color: AppColors.text3),
                  _LegendBox(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surface2,
                    foregroundColor: AppColors.text2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeySection extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KeySection({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.8)),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 2), backgroundColor: AppColors.surface3),
                  );
                },
                child: Text('Copy', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 10, color: color, fontFamily: 'DMMono', height: 1.6),
              maxLines: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  final rows = const [
    ('🔑', 'RSA-2048 used only for encrypting session keys'),
    ('⚡', 'AES-256-CBC encrypts all message content'),
    ('🔒', 'Each conversation has a unique session key'),
    ('✅', 'Private key stored in device Keychain/Keystore'),
  ];

  const _LegendBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(r.$1, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 10),
              Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 12, color: AppColors.text2))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

// ── MESSAGE BUBBLE ────────────────────────────────────────────────────────────

class MessageBubble extends StatelessWidget {
  final bool isOut;
  final String text;
  final String? ciphertext;
  final bool encrypted;
  final bool readOnly;
  final bool showCipher;
  final String status;
  final String time;

  const MessageBubble({
    super.key,
    required this.isOut,
    required this.text,
    this.ciphertext,
    required this.encrypted,
    required this.readOnly,
    this.showCipher = false,
    required this.status,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = (showCipher && encrypted && ciphertext != null) ? ciphertext! : text;
    final isCipherView = showCipher && encrypted && ciphertext != null;

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: readOnly
            ? () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚫 Copying disabled by sender'),
                    backgroundColor: AppColors.surface3,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            : null,
        child: Container(
          margin: EdgeInsets.only(
            top: 2, bottom: 2,
            left: isOut ? 60 : 16,
            right: isOut ? 16 : 60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOut ? AppColors.bubbleOut : AppColors.bubbleIn,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isOut ? 18 : 5),
              bottomRight: Radius.circular(isOut ? 5 : 18),
            ),
            border: Border.all(
              color: readOnly
                  ? AppColors.danger.withOpacity(0.25)
                  : isOut
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.border,
              width: readOnly ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (readOnly)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.dangerDim,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                  ),
                  child: const Text('🚫 PROTECTED', style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w700, fontFamily: 'DMMono', letterSpacing: 0.5)),
                ),
              SelectionContainer.disabled(
                child: isCipherView
                    ? Text(displayText, style: const TextStyle(fontSize: 10, color: AppColors.text3, fontFamily: 'DMMono', height: 1.5))
                    : Text(displayText, style: TextStyle(fontSize: 14, color: AppColors.text, height: 1.45), maxLines: readOnly ? null : null),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (encrypted) const Text('🔒', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(time, style: const TextStyle(fontSize: 10, color: AppColors.text3, fontFamily: 'DMMono')),
                  if (isOut) ...[
                    const SizedBox(width: 4),
                    Text(
                      status == 'read' ? '✓✓' : status == 'sending' ? '○' : '✓',
                      style: TextStyle(fontSize: 11, color: status == 'read' ? AppColors.accent : AppColors.text3),
                    ),
                  ],
                  if (readOnly) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.dangerDim,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                      ),
                      child: const Text('read-only', style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w700, fontFamily: 'DMMono')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── COMPOSE BAR ───────────────────────────────────────────────────────────────

class ComposeBar extends StatefulWidget {
  final void Function(String text, {required bool encrypted, required bool readOnly}) onSend;

  const ComposeBar({super.key, required this.onSend});

  @override
  State<ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<ComposeBar> {
  final _controller = TextEditingController();
  bool _encrypted = true;
  bool _readOnly = false;

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, encrypted: _encrypted, readOnly: _readOnly);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggles
          Row(
            children: [
              _Toggle(
                label: '🔒 Encrypt',
                active: _encrypted,
                onTap: () => setState(() => _encrypted = !_encrypted),
              ),
              const SizedBox(width: 6),
              _Toggle(
                label: '🚫 Read-only',
                active: _readOnly,
                danger: true,
                onTap: () => setState(() => _readOnly = !_readOnly),
              ),
              if (!_encrypted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x1FFF9F40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x40FF9F40)),
                  ),
                  child: const Text('⚠ Unencrypted', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border2, width: 1.5),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                      hintStyle: TextStyle(color: AppColors.text3),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Color(0xFF2AF580)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_upward, color: Color(0xFF0A1A12), size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  const _Toggle({required this.label, required this.active, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color.withOpacity(0.3) : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? color : AppColors.text2,
            fontFamily: 'DMMono',
          ),
        ),
      ),
    );
  }
}
