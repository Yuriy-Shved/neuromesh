import 'package:flutter/material.dart';
import 'theme.dart';

class InputPanel extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final ValueChanged<Duration> onSendVoice;
  final ValueChanged<String> onSendMedia;

  const InputPanel({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.onSendMedia,
  });

  @override
  State<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<InputPanel> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _emojiOpen = false;
  bool _recording = false;
  DateTime? _recordingStart;

  static const _emojis = [
    '😀','😄','😁','😅','😂','🙂','😉','😍','😘','🤔',
    '😐','😴','🤯','🥳','😎','🤩','😢','😡','👍','👎',
    '🔥','💯','⚡','✅','❌','⚠️','❤️','💔','🎯','🚀',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() {
      if (_focus.hasFocus && _emojiOpen) setState(() => _emojiOpen = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty;

  void _toggleEmoji() {
    if (_focus.hasFocus) _focus.unfocus();
    setState(() => _emojiOpen = !_emojiOpen);
  }

  void _insertEmoji(String e) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final newText = text.replaceRange(start, end, e);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + e.length),
    );
  }

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    widget.onSendText(t);
    _controller.clear();
    setState(() {});
  }

  void _startRec() {
    setState(() {
      _recording = true;
      _recordingStart = DateTime.now();
    });
  }

  void _stopRec() {
    final start = _recordingStart;
    setState(() {
      _recording = false;
      _recordingStart = null;
    });
    if (start == null) return;
    var d = DateTime.now().difference(start);
    if (d < const Duration(seconds: 1)) d = const Duration(seconds: 1);
    widget.onSendVoice(d);
  }

  void _openAttach() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _attachTile(Icons.photo_outlined, 'Фото', () {
              Navigator.pop(ctx);
              widget.onSendMedia('Фото');
            }),
            _attachTile(Icons.insert_drive_file_outlined, 'Файл', () {
              Navigator.pop(ctx);
              widget.onSendMedia('Файл');
            }),
            _attachTile(Icons.location_on_outlined, 'Локация', () {
              Navigator.pop(ctx);
              widget.onSendMedia('Локация');
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _attachTile(IconData i, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(i, color: C.accent),
      title: Text(label, style: const TextStyle(color: C.text)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_emojiOpen) _EmojiGrid(emojis: _emojis, onPick: _insertEmoji),
          if (_recording) _RecBanner(onStop: _stopRec),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Прикрепить',
                  icon: const Icon(Icons.attach_file, color: C.text2),
                  onPressed: _recording ? null : _openAttach,
                ),
                IconButton(
                  tooltip: 'Эмодзи',
                  icon: Icon(
                    _emojiOpen ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                    color: _emojiOpen ? C.accent : C.text2,
                  ),
                  onPressed: _recording ? null : _toggleEmoji,
                ),
                IconButton(
                  tooltip: _recording ? 'Остановить' : 'Голосовое',
                  icon: Icon(
                    _recording ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
                    color: _recording ? C.red : C.text2,
                  ),
                  onPressed: _recording ? _stopRec : _startRec,
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 6,
                      style: const TextStyle(color: C.text, fontSize: 14),
                      cursorColor: C.accent,
                      decoration: const InputDecoration(
                        hintText: 'Написать сообщение…',
                        hintStyle: TextStyle(color: C.muted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _canSend
                      ? Material(
                          key: const ValueKey('send'),
                          color: C.accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _send,
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), width: 42, height: 42),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onPick;
  const _EmojiGrid({required this.emojis, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.divider)),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: emojis.length,
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onPick(emojis[i]),
          child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 22))),
        ),
      ),
    );
  }
}

class _RecBanner extends StatelessWidget {
  final VoidCallback onStop;
  const _RecBanner({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: C.red.withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: C.red, size: 14),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Идёт запись голосового сообщения…',
              style: TextStyle(color: C.red, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onStop,
            child: const Text(
              'Остановить и отправить',
              style: TextStyle(color: C.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}