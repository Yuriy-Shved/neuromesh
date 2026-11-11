import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';

class FactGraphDialog extends StatefulWidget {
  final FactNode centerNode;
  final List<FactNode> contextNodes;
  final Map<String, double> consensus;

  const FactGraphDialog({
    super.key,
    required this.centerNode,
    required this.contextNodes,
    required this.consensus,
  });

  @override
  State<FactGraphDialog> createState() => _FactGraphDialogState();
}

class _FactGraphDialogState extends State<FactGraphDialog> {
  final _positions = <String, Offset>{};
  final _hitRects = <String, Rect>{};
  String? _selectedId;
  Size _lastSize = Size.zero;

  void _layout(Size size) {
    if (size == _lastSize) return;
    _lastSize = size;
    _positions.clear();
    _hitRects.clear();

    final center = Offset(size.width / 2, size.height / 2);
    _positions[widget.centerNode.id] = center;
    _hitRects[widget.centerNode.id] = Rect.fromCenter(center: center, width: 220, height: 120);

    final radius = math.min(size.width, size.height) * 0.34;
    final n = widget.contextNodes.length;
    
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      _positions[widget.contextNodes[i].id] = pos;
      _hitRects[widget.contextNodes[i].id] = Rect.fromCenter(center: pos, width: 170, height: 90);
    }
  }

  void _onTap(Offset local) {
    for (final e in _hitRects.entries) {
      if (e.value.contains(local)) {
        setState(() => _selectedId = e.key);
        return;
      }
    }
    setState(() => _selectedId = null);
  }

  String? _label(String id) {
    if (id == widget.centerNode.id) return widget.centerNode.sender;
    for (final n in widget.contextNodes) {
      if (n.id == id) return n.sender;
    }
    return null;
  }

  String? _text(String id) {
    if (id == widget.centerNode.id) return widget.centerNode.text;
    for (final n in widget.contextNodes) {
      if (n.id == id) return n.text;
    }
    return null;
  }

  String _status(String id) {
    if (id == widget.centerNode.id) return widget.centerNode.safetyStatus;
    for (final n in widget.contextNodes) {
      if (n.id == id) return n.safetyStatus;
    }
    return 'GREEN';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: C.divider)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_outlined, color: C.accent, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Карта связей фактов', style: TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: C.text2),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                _layout(size);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onTap(d.localPosition),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _FactGraphPainter(
                        center: widget.centerNode,
                        contexts: widget.contextNodes,
                        positions: _positions,
                        hitRects: _hitRects,
                        consensus: widget.consensus,
                        selectedId: _selectedId,
                      ),
                      size: size,
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: _selectedId == null ? 64 : 140,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: C.divider)),
            ),
            child: _selectedId == null
                ? const Center(child: Text('Нажмите на узел, чтобы увидеть полный текст факта', style: TextStyle(color: C.muted, fontSize: 13)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: statusColor(_status(_selectedId!)), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(_label(_selectedId!) ?? '—', style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                          const Spacer(),
                          Text('${(widget.consensus[_selectedId] ?? 0).toStringAsFixed(0)}% консенсус', style: const TextStyle(color: C.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(_text(_selectedId!) ?? '', style: const TextStyle(color: C.text2, fontSize: 13, height: 1.4)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FactGraphPainter extends CustomPainter {
  final FactNode center;
  final List<FactNode> contexts;
  final Map<String, Offset> positions;
  final Map<String, Rect> hitRects;
  final Map<String, double> consensus;
  final String? selectedId;

  _FactGraphPainter({
    required this.center, required this.contexts, required this.positions,
    required this.hitRects, required this.consensus, required this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerPos = positions[center.id] ?? size.center(Offset.zero);
    final edge = Paint()..color = C.accent.withOpacity(0.55)..strokeWidth = 1.6..style = PaintingStyle.stroke;
    final dot = Paint()..color = C.accent;

    for (final n in contexts) {
      final pos = positions[n.id];
      if (pos == null) continue;
      
      final start = _rectEdgeToward(hitRects[center.id]!, pos);
      final end = _rectEdgeToward(hitRects[n.id]!, centerPos);
      canvas.drawLine(start, end, edge);

      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      canvas.drawCircle(mid, 3, dot);

      final pct = consensus[n.id] ?? 0;
      final tp = TextPainter(
        text: TextSpan(text: '${pct.toStringAsFixed(0)}% консенсус', style: const TextStyle(color: C.accent, fontSize: 11, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      
      final off = mid - Offset(tp.width / 2, tp.height / 2);
      final bg = RRect.fromRectAndRadius(Rect.fromLTWH(off.dx - 6, off.dy - 2, tp.width + 12, tp.height + 4), const Radius.circular(4));
      canvas.drawRRect(bg, Paint()..color = C.bg.withOpacity(0.85));
      tp.paint(canvas, off);
    }

    _drawNode(canvas, center, hitRects[center.id]!, selectedId == center.id, true);
    for (final n in contexts) {
      _drawNode(canvas, n, hitRects[n.id]!, selectedId == n.id, false);
    }
  }

  Offset _rectEdgeToward(Rect r, Offset target) {
    final c = r.center;
    final d = target - c;
    if (d.distance < 1) return c;
    final tx = (r.width / 2) / d.dx.abs();
    final ty = (r.height / 2) / d.dy.abs();
    final t = tx < ty ? tx : ty;
    return c + d * (t / d.distance) * d.distance;
  }

  void _drawNode(Canvas canvas, FactNode n, Rect r, bool selected, {required bool isCenter}) {
    final st = statusColor(n.safetyStatus);
    canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(0, 2)), const Radius.circular(12)), Paint()..color = Colors.black.withOpacity(0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
    canvas.drawRRect(rr, Paint()..color = isCenter ? C.panelHi : C.panel);
    canvas.drawRRect(rr, Paint()..color = selected ? C.accent : st.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = selected ? 2.4 : 1.4);
    canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(r.left, r.top, 4, r.height), topLeft: const Radius.circular(12), bottomLeft: const Radius.circular(12)), Paint()..color = st);

    final title = TextPainter(
      text: TextSpan(text: n.sender, style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: isCenter ? 14 : 12)),
      textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…',
    )..layout(maxWidth: r.width - 20);
    title.paint(canvas, Offset(r.left + 12, r.top + 10));

    final body = TextPainter(
      text: TextSpan(text: n.text, style: TextStyle(color: C.text2, fontSize: isCenter ? 12 : 11, height: 1.35)),
      textDirection: TextDirection.ltr, maxLines: isCenter ? 3 : 2, ellipsis: '…',
    )..layout(maxWidth: r.width - 20);
    body.paint(canvas, Offset(r.left + 12, r.top + 30));
  }

  @override
  bool shouldRepaint(covariant _FactGraphPainter old) => old.selectedId != selectedId || old.positions.length != positions.length || !identical(old.positions, positions);
}