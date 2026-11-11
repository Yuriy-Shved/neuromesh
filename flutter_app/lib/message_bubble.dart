import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Contact contact;
  final bool compact;
  final VoidCallback onRevealContext;

  const MessageBubble({
    super.key,
    required this.message,
    required this.contact,
    required this.onRevealContext,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.isOutgoing;
    final isRed = message.safetyStatus == 'RED';
    final rail = statusColor(message.safetyStatus);

    return Padding(
      padding: EdgeInsets.only(
        left: isMine ? 60 : 16,
        right: isMine ? 16 : 60,
        top: compact ? 1 : 3,
        bottom: 3,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(compact && !isMine ? 4 : 12),
              topRight: Radius.circular(compact && isMine ? 4 : 12),
              bottomLeft: Radius.circular(isMine ? 12 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 12),
            ),
            child: Container(
              color: isMine ? C.ownBubble : C.peerBubble,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Цветовая полоса статуса
                    Container(width: 3, color: rail),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 8, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMine && !compact)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  contact.name,
                                  style: TextStyle(
                                    color: contact.avatarColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            // Тело сообщения (затемняется, если RED)
                            Opacity(
                              opacity: isRed ? 0.55 : 1.0,
                              child: _bodyFor(message),
                            ),
                            // Баннер «Проявить контекст» для RED
                            if (isRed) ...[
                              const SizedBox(height: 8),
                              _RedBanner(onTap: onRevealContext),
                            ],
                            const SizedBox(height: 3),
                            _MetaRow(message: message, rail: rail),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyFor(ChatMessage m) {
    switch (m.type) {
      case MessageType.text:
        return SelectableText(
          m.text ?? '',
          style: const TextStyle(color: C.text, fontSize: 14, height: 1.4),
        );
      case MessageType.media:
        return _MediaBubble(label: m.mediaLabel ?? 'Медиа');
      case MessageType.voice:
        return _VoiceBubble(duration: m.voiceDuration ?? const Duration(seconds: 8));
    }
  }
}

class _MetaRow extends StatelessWidget {
  final ChatMessage message;
  final Color rail;
  const _MetaRow({required this.message, required this.rail});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (message.safetyStatus != 'GREEN')
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 11, color: rail.withOpacity(0.9)),
                const SizedBox(width: 3),
                Text(
                  '${(message.score * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: rail.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        Text(
          formatTime(message.timestamp),
          style: const TextStyle(color: C.muted, fontSize: 11),
        ),
        if (message.isOutgoing) ...[
          const SizedBox(width: 4),
          _DeliveryIcon(delivery: message.delivery),
        ],
      ],
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  final MessageDelivery delivery;
  const _DeliveryIcon({required this.delivery});

  @override
  Widget build(BuildContext context) {
    switch (delivery) {
      case MessageDelivery.sending:
        return const SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: C.muted),
        );
      case MessageDelivery.sent:
        return const Icon(Icons.done, size: 13, color: C.muted);
      case MessageDelivery.delivered:
        return const Icon(Icons.done_all, size: 13, color: C.muted);
      case MessageDelivery.read:
        return const Icon(Icons.done_all, size: 13, color: C.accent);
    }
  }
}

class _MediaBubble extends StatelessWidget {
  final String label;
  const _MediaBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 150,
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.dividerHi),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, color: C.text2, size: 40),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: C.text2, fontSize: 12)),
        ],
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  final Duration duration;
  const _VoiceBubble({required this.duration});

  @override
  Widget build(BuildContext context) {
    final bars = List<double>.generate(28, (i) => 6 + ((i * 13) % 20).toDouble());
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  for (final h in bars)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2.2, height: h,
                          decoration: BoxDecoration(color: C.text2, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: C.text2, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RedBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _RedBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: C.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.red.withOpacity(0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.warning_amber_rounded, color: C.red, size: 17),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Обнаружено замалчивание. Проявить контекст сети',
                  style: TextStyle(color: C.red, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}