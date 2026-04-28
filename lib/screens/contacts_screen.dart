// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../widgets/vault_widgets.dart';
import '../crypto/vault_crypto.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});
  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  Map<String, dynamic>? _myProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await FirebaseService.getMyProfile();
    if (mounted) setState(() => _myProfile = p);
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts.toDate() as DateTime;
      final now = DateTime.now();
      if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
      if (now.difference(dt).inDays == 1) return 'Yesterday';
      return DateFormat('dd MMM').format(dt);
    } catch (_) { return ''; }
  }

  void _openAddContact() {
    final ctrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppColors.border2),
                left: BorderSide(color: AppColors.border2), right: BorderSide(color: AppColors.border2)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(2)))),
                const Gap(20),
                const Text('Find a Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                const Gap(4),
                const Text('Search by username to start an encrypted conversation',
                  style: TextStyle(fontSize: 13, color: AppColors.text2)),
                const Gap(16),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Search username…',
                    prefixIcon: Icon(Icons.search, color: AppColors.text3, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (q) async {
                    if (q.length < 2) { set(() => results = []); return; }
                    set(() => loading = true);
                    final r = await FirebaseService.searchUsers(q);
                    set(() { results = r; loading = false; });
                  },
                ),
                const Gap(12),
                if (loading) const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))),
                if (results.isNotEmpty) Container(
                  decoration: BoxDecoration(color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final u = results[i];
                      final name = u['displayName'] as String? ?? 'Unknown';
                      final words = name.trim().split(' ');
                      final ini = (words.length >= 2 ? '${words[0][0]}${words[1][0]}'
                        : name.substring(0, name.length >= 2 ? 2 : 1)).toUpperCase();
                      return ListTile(
                        leading: VaultAvatar(initials: ini, color: AppColors.accent2, size: 40),
                        title: Text(name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                        subtitle: Text('@${u['username'] ?? ''}',
                          style: const TextStyle(color: AppColors.text3, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.text3),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final convId = await ref.read(messagingNotifierProvider.notifier)
                              .startConversation(u['id']);
                          if (convId != null && context.mounted) {
                            context.go('/chat/$convId/$name/$ini/${AppColors.accent2.value}?userId=${u['id']}');
                          }
                        },
                      );
                    },
                  ),
                ),
                Gap(MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vault', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                        Text('@${_myProfile?['username'] ?? '…'}',
                          style: const TextStyle(fontSize: 11, color: AppColors.text3, fontFamily: 'DMMono')),
                      ],
                    ),
                  ),
                  _Btn(icon: '🔑', onTap: () => EncryptionModal.show(
                    context, myPublicKey: _myProfile?['publicKey'] ?? '')),
                  const Gap(8),
                  _Btn(icon: '＋', onTap: _openAddContact),
                  const Gap(8),
                  _Btn(icon: '⏻', onTap: () => ref.read(authNotifierProvider.notifier).signOut()),
                ],
              ),
            ),

            if (_myProfile?['publicKey'] != null)
              GestureDetector(
                onTap: () => EncryptionModal.show(context, myPublicKey: _myProfile!['publicKey']),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('🛡️', style: TextStyle(fontSize: 20)),
                      const Gap(10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Public Key (tap to share)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                          const Gap(2),
                          Text(VaultCrypto.shortKey(_myProfile!['publicKey']),
                            style: const TextStyle(fontSize: 10, color: AppColors.text3, fontFamily: 'DMMono'),
                            overflow: TextOverflow.ellipsis),
                        ],
                      )),
                      const Text('›', style: TextStyle(fontSize: 18, color: AppColors.text3)),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    const Padding(padding: EdgeInsets.only(left: 12),
                      child: Text('🔍', style: TextStyle(fontSize: 14))),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 14, color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Search conversations…',
                        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    )),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('Messages', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.text3, letterSpacing: 1.5))),
            ),

            Expanded(
              child: conversations.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (convs) {
                  final myUid = FirebaseService.uid;
                  if (convs.isEmpty) {
                    return const Center(child: Text('No conversations yet.\nTap ＋ to find someone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.text3, height: 1.6)));
                  }
                  return ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (_, i) {
                      final conv    = convs[i];
                      final convId  = conv['id'] as String;
                      final parts   = convId.split('_');
                      final otherId = parts.firstWhere((p) => p != myUid, orElse: () => '');
                      final lastMsg = conv['lastMessage'] as String? ?? '';
                      final lastAt  = conv['lastMessageAt'];

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: FirebaseService.getUser(otherId),
                        builder: (_, snap) {
                          final user  = snap.data;
                          final name  = user?['displayName'] as String? ?? 'Unknown';
                          final words = name.trim().split(' ');
                          final ini   = (words.length >= 2 ? '${words[0][0]}${words[1][0]}'
                            : name.substring(0, name.length >= 2 ? 2 : 1)).toUpperCase();

                          if (_search.isNotEmpty && !name.toLowerCase().contains(_search.toLowerCase())) {
                            return const SizedBox.shrink();
                          }

                          return InkWell(
                            onTap: () => context.go(
                              '/chat/$convId/$name/$ini/${AppColors.accent2.value}?userId=$otherId'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  VaultAvatar(initials: ini, color: AppColors.accent2, size: 50),
                                  const Gap(12),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                                      const Gap(2),
                                      Text(lastMsg.isEmpty ? 'No messages yet' : lastMsg,
                                        style: const TextStyle(fontSize: 12, color: AppColors.text2),
                                        overflow: TextOverflow.ellipsis),
                                    ],
                                  )),
                                  Text(_formatTime(lastAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.text3, fontFamily: 'DMMono')),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
    ),
  );
}
