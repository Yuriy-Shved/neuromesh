import 'package:flutter/material.dart';
import 'theme.dart';
import 'store.dart';

class ProfilePage extends StatefulWidget {
  final AppStore store;
  const ProfilePage({super.key, required this.store});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _name;
  late TextEditingController _username;
  late TextEditingController _bio;
  late TextEditingController _pubkey;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.store.profile;
    _name = TextEditingController(text: p.name)..addListener(_markDirty);
    _username = TextEditingController(text: p.username)..addListener(_markDirty);
    _bio = TextEditingController(text: p.bio)..addListener(_markDirty);
    _pubkey = TextEditingController(text: p.publicKeyBase58)..addListener(_markDirty);
  }

  void _markDirty() {
    final p = widget.store.profile;
    final changed = _name.text != p.name ||
        _username.text != p.username ||
        _bio.text != p.bio ||
        _pubkey.text != p.publicKeyBase58;
    if (changed != _dirty) setState(() => _dirty = changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _pubkey.dispose();
    super.dispose();
  }

  void _save() {
    widget.store.updateProfile(
      name: _name.text,
      username: _username.text,
      bio: _bio.text,
      publicKeyBase58: _pubkey.text,
    );
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Профиль сохранён'),
      backgroundColor: C.panelHi,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _reset() {
    final p = widget.store.profile;
    _name.text = p.name;
    _username.text = p.username;
    _bio.text = p.bio;
    _pubkey.text = p.publicKeyBase58;
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: [
              const Text(
                'Мой профиль',
                style: TextStyle(
                  color: C.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.store.profile.avatarColor,
                      ),
                      child: Center(
                        child: Text(
                          widget.store.profile.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 48,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: C.accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Загрузка фото — через TPM Secure Enclave'),
                              backgroundColor: C.panelHi,
                              behavior: SnackBarBehavior.floating,
                            ),
                          ),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Field(
                label: 'Имя',
                controller: _name,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'Имя пользователя',
                controller: _username,
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'О себе',
                controller: _bio,
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'Публичный ключ (Base58)',
                controller: _pubkey,
                icon: Icons.vpn_key_outlined,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.dividerHi),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: C.accent, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Корень доверия',
                          style: TextStyle(
                            color: C.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Аппаратный ключ ed25519 изолирован в TPM/Secure Enclave. '
                      'Приватный ключ не покидает чип. Привязка к номеру телефона отсутствует.',
                      style: TextStyle(color: C.text2, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _pill('TPM ed25519'),
                        const SizedBox(width: 6),
                        _pill('Social Recovery 3/5'),
                        const SizedBox(width: 6),
                        _pill('Merkle verified'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dirty ? _reset : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _dirty ? C.dividerHi : C.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Отменить',
                        style: TextStyle(
                          color: _dirty ? C.text2 : C.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _dirty ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _dirty ? C.accent : C.panelHi,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Сохранить',
                        style: TextStyle(
                          color: _dirty ? Colors.white : C.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Выход из аккаунта'),
                    backgroundColor: C.panelHi,
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
                icon: const Icon(Icons.logout, color: C.red, size: 18),
                label: const Text('Выйти из аккаунта', style: TextStyle(color: C.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: C.dividerHi),
      ),
      child: Text(text, style: const TextStyle(color: C.text2, fontSize: 11)),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;
  
  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: C.text, fontSize: 14),
      cursorColor: C.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: C.text2, fontSize: 13),
        prefixIcon: Icon(icon, color: C.muted, size: 18),
        filled: true,
        fillColor: C.panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: C.dividerHi),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: C.accent),
        ),
      ),
    );
  }
}