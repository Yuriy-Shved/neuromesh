import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';

class PeerProfilePanel extends StatelessWidget {
  final AppStore store;
  final Contact contact;
  const PeerProfilePanel({super.key, required this.store, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(left: BorderSide(color: C.divider)),
      ),
      child: Column(
        children: [
          Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.divider)),
            ),
            child: Row(
              children: [
                const Text(
                  'Информация',
                  style: TextStyle(
                    color: C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Закрыть',
                  icon: const Icon(Icons.close, color: C.text2, size: 20),
                  onPressed: store.togglePeerProfile,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: contact.avatarColor,
                    ),
                    child: Center(
                      child: Text(
                        contact.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    contact.name,
                    style: const TextStyle(
                      color: C.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    contact.username,
                    style: const TextStyle(color: C.accent, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    contact.isOnline
                        ? 'в сети'
                        : (contact.lastSeen != null
                            ? lastSeenText(contact.lastSeen!)
                            : 'был(а) недавно'),
                    style: TextStyle(
                      color: contact.isOnline ? C.online : C.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: C.divider),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.info_outline,
                  label: 'О себе',
                  value: contact.bio.isEmpty ? '—' : contact.bio,
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.alternate_email,
                  label: 'Имя пользователя',
                  value: contact.username,
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Идентичность',
                  value: contact.isVerified 
                      ? 'TPM ed25519 · верифицирован' 
                      : 'Не верифицирован Web-of-Trust',
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.lock_outline,
                  label: 'Шифрование',
                  value: 'E2E · Merkle-цепочка подписей',
                ),
                const SizedBox(height: 20),
                const Divider(color: C.divider),
                const SizedBox(height: 12),
                _ActionRow(
                  icon: contact.isMuted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  label: contact.isMuted
                      ? 'Включить уведомления'
                      : 'Отключить уведомления',
                  onTap: () => store.toggleMute(contact.id),
                ),
                _ActionRow(
                  icon: contact.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  label: contact.isPinned ? 'Открепить чат' : 'Закрепить чат',
                  onTap: () => store.togglePin(contact.id),
                ),
                _ActionRow(
                  icon: Icons.delete_outline,
                  label: 'Удалить чат',
                  danger: true,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: const Text('Удалить чат?', style: TextStyle(color: C.text)),
        content: Text(
          'История с ${contact.name} будет удалена.',
          style: const TextStyle(color: C.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: C.text2)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.red),
            onPressed: () {
              store.deleteChat(contact.id);
              Navigator.pop(ctx);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: C.muted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: C.text, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? C.red : C.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, color: danger ? C.red : C.text2, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}