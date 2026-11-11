import 'package:flutter/material.dart';
import 'theme.dart';
import 'store.dart';

class NavRail extends StatelessWidget {
  final AppStore store;
  const NavRail({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final totalUnread = store.contacts
            .map((c) => store.unreadCount(c.id))
            .fold<int>(0, (a, b) => a + b);

        return Container(
          width: 72,
          decoration: const BoxDecoration(
            color: C.bgDeep,
            border: Border(right: BorderSide(color: C.divider)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _RailAvatar(store: store),
              const SizedBox(height: 16),
              const Divider(height: 1, color: C.divider),
              const SizedBox(height: 8),
              _RailButton(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                selected: store.currentTab == 0,
                badge: totalUnread,
                tooltip: 'Чаты',
                onTap: () => store.setTab(0),
              ),
              _RailButton(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                selected: store.currentTab == 1,
                tooltip: 'Настройки',
                onTap: () => store.setTab(1),
              ),
              _RailButton(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                selected: store.currentTab == 2,
                tooltip: 'Профиль',
                onTap: () => store.setTab(2),
              ),
              const Spacer(),
              _RailButton(
                icon: Icons.info_outline_rounded,
                activeIcon: Icons.info_rounded,
                selected: false,
                tooltip: 'О NeuroMesh',
                onTap: () => _showAbout(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.panel,
        title: const Text('NeuroMesh', style: TextStyle(color: C.text)),
        content: const Text(
          'Децентрализованная P2P-инфосеть с ИИ-иммунитетом.\n\n'
          'Версия 2.0.0 · Слои 1–4 активны\n'
          'Транспорт: libp2p · Идентичность: TPM ed25519\n'
          'Иммунитет: TF-IDF + Cosine Similarity',
          style: TextStyle(color: C.text2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: C.accent)),
          ),
        ],
      ),
    );
  }
}

class _RailAvatar extends StatelessWidget {
  final AppStore store;
  const _RailAvatar({required this.store});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Мой профиль',
      child: GestureDetector(
        onTap: () => store.setTab(2),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: store.profile.avatarColor,
            border: Border.all(color: C.accent, width: 2),
          ),
          child: Center(
            child: Text(
              store.profile.name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final String tooltip;
  final int badge;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? C.active
                        : _hover
                            ? C.hover
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.selected ? widget.activeIcon : widget.icon,
                    color: widget.selected ? C.text : C.text2,
                    size: 24,
                  ),
                ),
                if (widget.badge > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: C.badge,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.badge > 99 ? '99+' : '${widget.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}