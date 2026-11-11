import 'package:flutter/material.dart';
import 'theme.dart';
import 'store.dart';

// Импорт всех компонентов интерфейса
import 'nav_rail.dart';
import 'chat_sidebar.dart';
import 'chat_window.dart';
import 'peer_profile.dart';
import 'profile_page.dart';
import 'settings_page.dart';

void main() {
  runApp(const NeuroMeshApp());
}

class NeuroMeshApp extends StatelessWidget {
  const NeuroMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroMesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final AppStore _store = AppStore();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _store,
          builder: (context, _) {
            return Row(
              children: [
                // ============================================================
                // ЗОНА 1: Левая панель навигации (всегда видима)
                // ============================================================
                NavRail(store: _store),

                // ============================================================
                // ЗОНА 2: Основной контент (зависит от выбранной вкладки)
                // ============================================================
                if (_store.currentTab == 0) ...[
                  // --- Вкладка "ЧАТЫ" ---
                  ChatSidebar(store: _store),
                  
                  Expanded(
                    child: ChatWindow(store: _store),
                  ),
                  
                  // Правая панель профиля собеседника (выдвигается поверх/сбоку)
                  if (_store.showPeerProfile && _store.selectedContact != null)
                    PeerProfilePanel(
                      store: _store,
                      contact: _store.selectedContact!,
                    ),
                ] else if (_store.currentTab == 1) ...[
                  // --- Вкладка "НАСТРОЙКИ" ---
                  Expanded(
                    child: SettingsPage(store: _store),
                  ),
                ] else ...[
                  // --- Вкладка "ПРОФИЛЬ" ---
                  Expanded(
                    child: ProfilePage(store: _store),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}