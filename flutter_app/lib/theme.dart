import 'package:flutter/material.dart';

class C {
  C._();
  static const bg       = Color(0xFF0E1621);
  static const bgDeep   = Color(0xFF0A1018);
  static const panel    = Color(0xFF17212B);
  static const panelHi  = Color(0xFF1C2733);
  static const hover    = Color(0xFF202B36);
  static const active   = Color(0xFF2B5278);
  
  static const text     = Color(0xFFF5F7F9);
  static const text2    = Color(0xFFA8B8C7);
  static const muted    = Color(0xFF6D7F8F);
  
  static const accent   = Color(0xFF56A8E0);
  static const green    = Color(0xFF4DCD5E);
  static const yellow   = Color(0xFFE8B548);
  static const red      = Color(0xFFE8453C);
  
  static const divider  = Color(0xFF232E3C);
  static const dividerHi= Color(0xFF2A3745);
  static const ownBubble= Color(0xFF2B5278);
  static const peerBubble=Color(0xFF182533);
  static const online   = Color(0xFF4DCD5E);
  static const badge    = Color(0xFF56A8E0);
}

// Алиасы для совместимости с ранее написанным кодом
const kBg = C.bg;
const kPanel = C.panel;
const kAccent = C.accent;

class AppTheme {
  AppTheme._();
  
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(
        primary: C.accent,
        surface: C.panel,
        background: C.bg,
        onSurface: C.text,
        error: C.red,
      ),
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
    );
    
    return base.copyWith(
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(C.dividerHi),
        thickness: MaterialStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: C.panelHi,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: C.dividerHi),
        ),
        textStyle: const TextStyle(color: C.text, fontSize: 12),
      ),
    );
  }
}

Color statusColor(String s) => switch (s) {
  'GREEN'  => C.green,
  'YELLOW' => C.yellow,
  'RED'    => C.red,
  _        => C.muted,
};

String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String formatDateHeader(DateTime t) {
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
      
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  
  const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  
  if (t.year == now.year) {
    return '${t.day} ${months[t.month - 1]}';
  }
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}

String lastSeenText(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'был(а) только что';
  if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч назад';
  return 'был(а) ${formatDateHeader(t)}';
}