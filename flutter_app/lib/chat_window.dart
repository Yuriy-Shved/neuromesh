import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'store.dart';
import 'message_bubble.dart';
import 'input_panel.dart';
import 'fact_graph_canvas.dart';

class ChatWindow extends StatefulWidget {
  final AppStore store;
  const ChatWindow({super.key, required this.store});

  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final ScrollController _scroll = ScrollController();
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 200;
      if (show != _showJumpButton) setState(() => _showJumpButton = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final c = store.selectedContact;
        if (c == null) return const _EmptyChatPlaceholder();

        final messages = store.messagesFor(c.id);
        final pinned = store.pinnedMessage;

        return Container(
          color: C.bg,
          child: Column(
            children: [
              _Header(store: store, contact: c),
              if (pinned != null) _PinnedBar(store: store, msg: pinned),
              Expanded(
                child: Stack(
                  children: [
                    messages.isEmpty
                        ? const Center(
                            child: Text('Начните диалог', style: TextStyle(color: C.muted)),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: messages.length + _dateSeparatorCount(messages),
                            itemBuilder: (context, i) {
                              final built = _buildItems(messages);
                              return built[i];
                            },
                          ),
                    if (_showJumpButton)
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: FloatingActionButton.small(
                          backgroundColor: C.panelHi,
                          foregroundColor: C.text,
                          onPressed: _jumpToBottom,
                          child: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ),
                  ],
                ),
              ),
              InputPanel(
                onSendText: store.sendText,
                onSendVoice: store.sendVoice,
                onSendMedia: store.sendMedia,
              ),
            ],
          ),
        );
      },
    );
  }

  int _dateSeparatorCount(List<ChatMessage> msgs) {
    int count = 0;
    DateTime? last;
    for (final m in msgs) {
      final day = DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);
      if (last != day) count++;
      last = day;
    }
    return count;
  }

  List<Widget> _buildItems(List<ChatMessage> msgs) {
    final items = <Widget>[];
    DateTime? lastDay;
    
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final day = DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);
      if (lastDay != day) {
        items.add(_DateSeparator(label: formatDateHeader(m.timestamp)));
        lastDay = day;
      }
      final prev = i > 0 ? msgs[i - 1] : null;
      final sameAuthor = prev != null &&
          prev.isOutgoing == m.isOutgoing &&
          prev.timestamp.difference(m.timestamp).inMinutes.abs() < 2;
          
      items.add(RepaintBoundary(
        child: MessageBubble(
          message: m,
          contact: widget.store.selectedContact!,
          compact: sameAuthor,
          onRevealContext: () => _openGraph(m),
        ),
      ));
    }
    return items;
  }

  void _openGraph(ChatMessage red) {
    final contexts = <FactNode>[
      const FactNode(
        id: 'ctx1',
        sender: 'Ольга Ким',
        text: 'Официальное заявление администрации: производство перенесено в промзону Y, штат сохранён в полном объёме.',
        safetyStatus: 'GREEN',
        score: 0.02,
        linkedNodeIds: ['center'],
      ),
      const FactNode(
        id: 'ctx2',
        sender: 'Дмитрий Волков',
        text: 'Профсоюз подтвердил: 340 сотрудников переведены на новую площадку без сокращений, компенсации выплачены.',
        safetyStatus: 'GREEN',
        score: 0.03,
        linkedNodeIds: ['center'],
      ),
      const FactNode(
        id: 'ctx3',
        sender: 'Мария Соколова',
        text: 'Документы о переводе имущества завода опубликованы в реестре 12.11, ссылка на первоисточник.',
        safetyStatus: 'GREEN',
        score: 0.01,
        linkedNodeIds: ['center'],
      ),
    ];
    final center = FactNode(
      id: 'center',
      sender: widget.store.selectedContact!.name,
      text: red.text ?? '',
      safetyStatus: red.safetyStatus,
      score: red.score,
      linkedNodeIds: contexts.map((c) => c.id).toList(),
    );
    final consensus = <String, double>{'ctx1': 94, 'ctx2': 88, 'ctx3': 81};
    showDialog(
      context: context,
      builder: (_) => FactGraphDialog(
        centerNode: center,
        contextNodes: contexts,
        consensus: consensus,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final AppStore store;
  final Contact contact;
  const _Header({required this.store, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(bottom: BorderSide(color: C.divider)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: store.togglePeerProfile,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: contact.avatarColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        contact.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          color: C.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          if (contact.isOnline) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: C.online,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('в сети', style: TextStyle(color: C.accent, fontSize: 11)),
                          ] else
                            Text(
                              contact.lastSeen != null ? lastSeenText(contact.lastSeen!) : 'был(а) недавно',
                              style: const TextStyle(color: C.muted, fontSize: 11),
                            ),
                          const SizedBox(width: 8),
                          const Text('· P2P · Merkle', style: TextStyle(color: C.muted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Позвонить',
            icon: const Icon(Icons.call_outlined, color: C.text2),
            onPressed: () => _notify(context, 'P2P-звонок недоступен в демо'),
          ),
          IconButton(
            tooltip: 'Информация',
            icon: Icon(
              store.showPeerProfile ? Icons.info : Icons.info_outline,
              color: store.showPeerProfile ? C.accent : C.text2,
            ),
            onPressed: store.togglePeerProfile,
          ),
          PopupMenuButton<String>(
            color: C.panelHi,
            icon: const Icon(Icons.more_vert, color: C.text2),
            onSelected: (v) {
              switch (v) {
                case 'mute': store.toggleMute(contact.id); break;
                case 'pin': store.togglePin(contact.id); break;
                case 'delete': store.deleteChat(contact.id); break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(contact.isMuted ? 'Включить уведомления' : 'Отключить уведомления', style: const TextStyle(color: C.text)),
              ),
              PopupMenuItem(
                value: 'pin',
                child: Text(contact.isPinned ? 'Открепить' : 'Закрепить', style: const TextStyle(color: C.text)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Удалить чат', style: TextStyle(color: C.red))),
            ],
          ),
        ],
      ),
    );
  }

  void _notify(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: C.text)),
      backgroundColor: C.panelHi,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _PinnedBar extends StatelessWidget {
  final AppStore store;
  final ChatMessage msg;
  const _PinnedBar({required this.store, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(
          left: BorderSide(color: C.yellow, width: 3),
          bottom: BorderSide(color: C.divider),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, size: 16, color: C.yellow),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Закреплённое сообщение', style: TextStyle(color: C.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                Text(
                  msg.text ?? '[медиа]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.text2, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: C.panelHi,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(color: C.text2, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: C.panel,
                shape: BoxShape.circle,
                border: Border.all(color: C.dividerHi, width: 2),
              ),
              child: const Icon(Icons.chat_bubble_outline, color: C.muted, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Выберите чат', style: TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Слева — список ваших диалогов в папках', style: TextStyle(color: C.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}