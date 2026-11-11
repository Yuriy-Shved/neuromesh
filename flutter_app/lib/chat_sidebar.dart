import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';

class ChatSidebar extends StatelessWidget {
  final AppStore store;
  const ChatSidebar({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Container(
          width: 320,
          decoration: const BoxDecoration(
            color: C.panel,
            border: Border(right: BorderSide(color: C.divider)),
          ),
          child: Column(
            children: [
              _Header(store: store),
              _FolderChips(store: store),
              _SearchBar(store: store),
              const Divider(height: 1, color: C.divider),
              Expanded(
                child: store.visibleContacts.isEmpty
                    ? _EmptyState(text: _emptyText(store))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: store.visibleContacts.length,
                        itemBuilder: (_, i) {
                          final c = store.visibleContacts[i];
                          return _ContactTile(
                            store: store,
                            contact: c,
                            selected: store.selectedContactId == c.id,
                            onTap: () => store.selectContact(c.id),
                            onContext: (pos) => _showContext(context, c, pos),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _emptyText(AppStore s) {
    if (s.searchQuery.isNotEmpty) return 'Ничего не найдено';
    if (s.selectedFolderId == 'all') return 'Пока нет чатов';
    return 'В этой папке нет чатов';
  }

  void _showContext(BuildContext context, Contact c, Offset pos) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy,
        overlay.size.width - pos.dx,
        overlay.size.height - pos.dy,
      ),
      color: C.panelHi,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: C.dividerHi),
      ),
      items: [
        PopupMenuItem(
          onTap: () => store.togglePin(c.id),
          child: _MenuRow(
            icon: c.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: c.isPinned ? 'Открепить' : 'Закрепить',
          ),
        ),
        PopupMenuItem(
          onTap: () => store.toggleMute(c.id),
          child: _MenuRow(
            icon: c.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            label: c.isMuted ? 'Включить уведомления' : 'Отключить уведомления',
          ),
        ),
        PopupMenuItem(
          onTap: () => store.selectContact(c.id),
          child: const _MenuRow(icon: Icons.open_in_new, label: 'Открыть'),
        ),
        PopupMenuItem(
          onTap: () => _confirmDelete(context, c),
          child: const _MenuRow(icon: Icons.delete_outline, label: 'Удалить чат', danger: true),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Contact c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: const Text('Удалить чат?', style: TextStyle(color: C.text)),
        content: Text(
          'История переписки с ${c.name} будет удалена безвозвратно.',
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
              store.deleteChat(c.id);
              Navigator.pop(ctx);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final AppStore store;
  const _Header({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.blur_on_rounded, color: C.accent, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'NeuroMesh',
              style: TextStyle(
                color: C.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Новый чат',
            icon: const Icon(Icons.edit_outlined, color: C.text2, size: 20),
            onPressed: () => _showNewChat(context),
          ),
        ],
      ),
    );
  }

  void _showNewChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: const Text('Новый чат', style: TextStyle(color: C.text)),
        content: SizedBox(
          width: 360,
          height: 360,
          child: ListView.builder(
            itemCount: store.contacts.length,
            itemBuilder: (_, i) {
              final c = store.contacts[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: c.avatarColor,
                  child: Text(
                    c.name.characters.first,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(c.name, style: const TextStyle(color: C.text)),
                subtitle: Text(c.username, style: const TextStyle(color: C.muted)),
                onTap: () {
                  Navigator.pop(ctx);
                  store.selectContact(c.id);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FolderChips extends StatelessWidget {
  final AppStore store;
  const _FolderChips({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in store.folders) ...[
            _FolderChip(
              store: store,
              folder: f,
              onTap: () => store.selectFolder(f.id),
              onLongPress: f.isSystem ? null : () => _showFolderMenu(context, f),
            ),
            const SizedBox(width: 6),
          ],
          _AddFolderChip(store: store),
        ],
      ),
    );
  }

  void _showFolderMenu(BuildContext context, ChatFolder f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Text(f.name, style: const TextStyle(color: C.text)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _editFolder(context, f);
            },
            child: const Text('Изменить', style: TextStyle(color: C.accent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              store.deleteFolder(f.id);
            },
            child: const Text('Удалить', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  void _editFolder(BuildContext context, ChatFolder f) {
    final nameCtrl = TextEditingController(text: f.name);
    final sel = <String>{...f.contactIds};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: C.panel,
          title: const Text('Изменить папку', style: TextStyle(color: C.text)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: C.text),
                  cursorColor: C.accent,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    labelStyle: const TextStyle(color: C.text2),
                    filled: true,
                    fillColor: C.bg,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.dividerHi)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.accent)),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Абоненты', style: TextStyle(color: C.text2, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: store.contacts.length,
                    itemBuilder: (_, i) {
                      final c = store.contacts[i];
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: C.accent,
                        value: sel.contains(c.id),
                        title: Text(c.name, style: const TextStyle(color: C.text, fontSize: 14)),
                        onChanged: (v) => setSt(() {
                          if (v == true) { sel.add(c.id); } else { sel.remove(c.id); }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: C.text2)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.accent),
              onPressed: () {
                final n = nameCtrl.text.trim();
                if (n.isEmpty) return;
                store.updateFolder(f.id, n, sel);
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderChip extends StatefulWidget {
  final AppStore store;
  final ChatFolder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FolderChip({
    required this.store,
    required this.folder,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_FolderChip> createState() => _FolderChipState();
}

class _FolderChipState extends State<_FolderChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.store.selectedFolderId == widget.folder.id;
    final unread = widget.store.folderUnread(widget.folder.id);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? widget.folder.color.withOpacity(0.25)
                : _hover
                    ? C.hover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? widget.folder.color.withOpacity(0.7)
                  : C.dividerHi,
            ),
          ),
          child: Row(
            children: [
              Text(
                widget.folder.name,
                style: TextStyle(
                  color: selected ? C.text : C.text2,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: widget.folder.color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFolderChip extends StatelessWidget {
  final AppStore store;
  const _AddFolderChip({required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.dividerHi, style: BorderStyle.solid),
        ),
        child: const Row(
          children: [
            Icon(Icons.add, color: C.text2, size: 16),
            SizedBox(width: 4),
            Text('Папка', style: TextStyle(color: C.text2, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showCreate(BuildContext context) {
    final nameCtrl = TextEditingController();
    final sel = <String>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: C.panel,
          title: const Text('Новая папка', style: TextStyle(color: C.text)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: C.text),
                  cursorColor: C.accent,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например: Работа',
                    labelStyle: const TextStyle(color: C.text2),
                    hintStyle: const TextStyle(color: C.muted),
                    filled: true,
                    fillColor: C.bg,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.dividerHi)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.accent)),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Выберите абонентов', style: TextStyle(color: C.text2, fontSize: 12)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: store.contacts.length,
                    itemBuilder: (_, i) {
                      final c = store.contacts[i];
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: C.accent,
                        value: sel.contains(c.id),
                        title: Text(c.name, style: const TextStyle(color: C.text, fontSize: 14)),
                        secondary: CircleAvatar(
                          radius: 14,
                          backgroundColor: c.avatarColor,
                          child: Text(c.name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        onChanged: (v) => setSt(() {
                          if (v == true) { sel.add(c.id); } else { sel.remove(c.id); }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: C.text2)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.accent),
              onPressed: () {
                final n = nameCtrl.text.trim();
                if (n.isEmpty) return;
                store.createFolder(n, sel);
                Navigator.pop(ctx);
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final AppStore store;
  const _SearchBar({required this.store});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          style: const TextStyle(color: C.text, fontSize: 13),
          cursorColor: C.accent,
          onChanged: store.setSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: C.muted, size: 18),
            hintText: 'Поиск',
            hintStyle: TextStyle(color: C.muted, fontSize: 13),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatefulWidget {
  final AppStore store;
  final Contact contact;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset) onContext;

  const _ContactTile({
    required this.store,
    required this.contact,
    required this.selected,
    required this.onTap,
    required this.onContext,
  });

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final c = widget.contact;
    final last = store.lastMessageFor(c.id);
    final unread = store.unreadCount(c.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (d) => widget.onContext(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? C.active
                : _hover
                    ? C.hover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _Avatar(contact: c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (c.isPinned)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.push_pin, size: 12, color: C.muted),
                                ),
                              Expanded(
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: C.text,
                                    fontSize: 14,
                                    fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          last != null ? formatTime(last.timestamp) : '',
                          style: TextStyle(
                            color: unread > 0 ? C.accent : C.muted,
                            fontSize: 11,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (last != null && last.isOutgoing)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.done_all, size: 13, color: C.accent),
                          ),
                        if (last != null && last.safetyStatus != 'GREEN')
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: statusColor(last.safetyStatus),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _preview(last),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ),
                        if (c.isMuted)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.notifications_off_outlined, size: 13, color: C.muted),
                          ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 18),
                            decoration: BoxDecoration(
                              color: c.isMuted ? C.muted : C.badge,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(ChatMessage? m) {
    if (m == null) return 'Нет сообщений';
    switch (m.type) {
      case MessageType.voice:
        return '🎤 Голосовое · ${m.voiceDuration?.inSeconds ?? 0}с';
      case MessageType.media:
        return '🖼 ${m.mediaLabel ?? "Медиа"}';
      case MessageType.text:
        return m.text ?? '';
    }
  }
}

class _Avatar extends StatelessWidget {
  final Contact contact;
  const _Avatar({required this.contact});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          Container(
            width: 46,
            height: 46,
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
                  fontSize: 17,
                ),
              ),
            ),
          ),
          if (contact.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: C.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.panel, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _MenuRow({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? C.red : C.text;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, color: C.muted, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}