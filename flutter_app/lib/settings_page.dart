import 'package:flutter/material.dart';
import 'theme.dart';
import 'store.dart';

class SettingsPage extends StatefulWidget {
  final AppStore store;
  const SettingsPage({super.key, required this.store});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Локальные состояния переключателей (в проде синхронизируются с базой)
  bool _sound = true;
  bool _vibration = true;
  bool _readReceipts = true;
  bool _typingIndicator = true;
  bool _deepAiAudit = true;
  bool _autoDownload = false;
  double _powBits = 16.0;

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
                'Настройки',
                style: TextStyle(
                  color: C.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              // === УВЕДОМЛЕНИЯ ===
              const _SectionTitle('Уведомления'),
              _SwitchTile(
                title: 'Звук',
                subtitle: 'Воспроизводить звук при новом сообщении',
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
              ),
              _SwitchTile(
                title: 'Вибрация',
                subtitle: 'Короткая вибрация при получении',
                value: _vibration,
                onChanged: (v) => setState(() => _vibration = v),
              ),
              const SizedBox(height: 16),

              // === ПРИВАТНОСТЬ ===
              const _SectionTitle('Приватность и безопасность'),
              _SwitchTile(
                title: 'Отчёты о прочтении',
                subtitle: 'Отправлять статус «прочитано» собеседнику',
                value: _readReceipts,
                onChanged: (v) => setState(() => _readReceipts = v),
              ),
              _SwitchTile(
                title: 'Индикатор набора',
                subtitle: 'Показывать, когда вы печатаете',
                value: _typingIndicator,
                onChanged: (v) => setState(() => _typingIndicator = v),
              ),
              _SwitchTile(
                title: 'Автозагрузка медиа',
                subtitle: 'Скачивать изображения и голосовые по Wi-Fi',
                value: _autoDownload,
                onChanged: (v) => setState(() => _autoDownload = v),
              ),
              const SizedBox(height: 16),

              // === ИИ-ИММУНИТЕТ ===
              const _SectionTitle('ИИ-Иммунитет (Слой 4)'),
              _SwitchTile(
                title: 'Глубокий аудит (Deep Path)',
                subtitle: 'Использовать локальную модель MiniLM для анализа контекста',
                value: _deepAiAudit,
                onChanged: (v) => setState(() => _deepAiAudit = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Проверка целостности модели', style: TextStyle(color: C.text, fontSize: 15)),
                subtitle: const Text('Тест Honey Pot (запуск трибунала при сбое)', style: TextStyle(color: C.muted, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.security, color: C.accent),
                  onPressed: () {
                    // Имитация вызова Rust FFI verify_integrity()
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Модель MiniLM Q4_K_M: подпись Swiss Verein верна.'),
                        backgroundColor: C.panelHi,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // === СЕТЬ ===
              const _SectionTitle('Сеть NeuroMesh'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Сложность Proof-of-Work (Anti-Spam)', style: TextStyle(color: C.text, fontSize: 15)),
                subtitle: Text(
                  'Текущий порог: ${_powBits.toInt()} бит. Влияет на энергопотребление и защиту от ботов.',
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ),
              Slider(
                value: _powBits,
                min: 14,
                max: 22,
                divisions: 8,
                activeColor: C.accent,
                inactiveColor: C.panelHi,
                label: '${_powBits.toInt()} bits',
                onChanged: (v) => setState(() => _powBits = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Свидетели контента (Witnesses)', style: TextStyle(color: C.text, fontSize: 15)),
                subtitle: const Text('Хранить копии оригиналов на устройстве: 7 дней', style: TextStyle(color: C.muted, fontSize: 12)),
                trailing: Switch(
                  value: true,
                  activeColor: C.accent,
                  onChanged: (v) {},
                ),
              ),
              const SizedBox(height: 16),

              // === О ПРИЛОЖЕНИИ ===
              const _SectionTitle('О приложении'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Версия', style: TextStyle(color: C.text, fontSize: 15)),
                trailing: const Text('2.0.0', style: TextStyle(color: C.muted, fontSize: 14)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Транспорт', style: TextStyle(color: C.text, fontSize: 15)),
                trailing: const Text('go-libp2p v0.50', style: TextStyle(color: C.muted, fontSize: 14)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Лицензия', style: TextStyle(color: C.text, fontSize: 15)),
                trailing: const Text('AGPL-3.0', style: TextStyle(color: C.muted, fontSize: 14)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: C.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: C.accent,
      inactiveThumbColor: C.muted,
      inactiveTrackColor: C.panelHi,
      title: Text(title, style: const TextStyle(color: C.text, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: C.muted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}