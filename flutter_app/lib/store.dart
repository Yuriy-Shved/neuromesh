import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

class AppStore extends ChangeNotifier {
  // --- Идентичность (Слой 3) ---
  final UserProfile profile = UserProfile(
    name: 'Иван Петров',
    username: '@ipetrov',
    bio: 'Исследователь децентрализованных сетей. NeuroMesh advocate.',
    publicKeyBase58: '8f3Kx9PzL2mN4vB7wR1tY6uQ5sA0cD', // Замена phone
    avatarColor: const Color(0xFF56A8E0),
  );

  // --- Данные ---
  final List<Contact> contacts = [];
  final List<ChatMessage> messages = [];
  late List<ChatFolder> folders;

  // --- Состояние UI ---
  int currentTab = 0; // 0: чаты, 1: настройки, 2: профиль
  String selectedFolderId = 'all';
  String? selectedContactId;
  bool showPeerProfile = false;
  String searchQuery = '';
  String chatSearchQuery = '';

  AppStore() {
    _seed();
  }

  // --------------------------------------------------------------------------
  // Вычисляемые свойства
  // --------------------------------------------------------------------------
  Contact? get selectedContact {
    final id = selectedContactId;
    if (id == null) return null;
    for (final c in contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  ChatFolder get currentFolder =>
      folders.firstWhere((f) => f.id == selectedFolderId,
          orElse: () => folders.first);

  List<Contact> get visibleContacts {
    final f = currentFolder;
    List<Contact> base;
    
    if (f.isUnknown) {
      // Папка "Незнакомые" (Web-of-Trust фильтр)
      base = contacts.where((c) => !c.isVerified).toList();
    } else if (f.id == 'all') {
      base = List<Contact>.from(contacts);
    } else {
      base = contacts.where((c) => f.contactIds.contains(c.id)).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      base.retainWhere((c) =>
          c.name.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q));
    }
    
    // Сортировка: закрепленные -> последнее сообщение
    base.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final am = lastMessageFor(a.id);
      final bm = lastMessageFor(b.id);
      if (am == null && bm == null) return a.name.compareTo(b.name);
      if (am == null) return 1;
      if (bm == null) return -1;
      return bm.timestamp.compareTo(am.timestamp);
    });
    return base;
  }

  List<ChatMessage> messagesFor(String contactId) {
    final list = messages.where((m) => m.contactId == contactId).toList();
    if (chatSearchQuery.isNotEmpty) {
      final q = chatSearchQuery.toLowerCase();
      list.retainWhere((m) => (m.text ?? '').toLowerCase().contains(q));
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  ChatMessage? lastMessageFor(String contactId) {
    final list = messages.where((m) => m.contactId == contactId).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list.last;
  }

  int unreadCount(String contactId) =>
      messages.where((m) => m.contactId == contactId && !m.isOutgoing && !m.isRead).length;

  int folderUnread(String folderId) {
    final f = folders.firstWhere((x) => x.id == folderId);
    int total = 0;
    for (final c in contacts) {
      if (folderId == 'all' || f.contactIds.contains(c.id)) {
        total += unreadCount(c.id);
      }
    }
    return total;
  }

  ChatMessage? get pinnedMessage {
    final id = selectedContactId;
    if (id == null) return null;
    final list = messages
        .where((m) => m.contactId == id && m.safetyStatus == 'RED')
        .toList();
    return list.isEmpty ? null : list.last;
  }

  // --------------------------------------------------------------------------
  // Действия UI
  // --------------------------------------------------------------------------
  void setTab(int t) {
    currentTab = t;
    showPeerProfile = false;
    notifyListeners();
  }

  void selectFolder(String id) {
    selectedFolderId = id;
    selectedContactId = null;
    showPeerProfile = false;
    chatSearchQuery = '';
    notifyListeners();
  }

  void selectContact(String id) {
    selectedContactId = id;
    showPeerProfile = false;
    chatSearchQuery = '';
    for (final m in messages) {
      if (m.contactId == id && !m.isOutgoing) m.isRead = true;
    }
    notifyListeners();
  }

  void clearChatSelection() {
    selectedContactId = null;
    showPeerProfile = false;
    notifyListeners();
  }

  void togglePeerProfile() {
    showPeerProfile = !showPeerProfile;
    notifyListeners();
  }

  void setSearch(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setChatSearch(String q) {
    chatSearchQuery = q;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Отправка сообщений
  // --------------------------------------------------------------------------
  void _dispatch(ChatMessage msg) {
    messages.add(msg);
    notifyListeners();
    
    // Симуляция сети (Delivery Status)
    Future.delayed(const Duration(milliseconds: 350), () {
      msg.delivery = MessageDelivery.sent;
      notifyListeners();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      msg.delivery = MessageDelivery.delivered;
      notifyListeners();
    });
    Future.delayed(const Duration(seconds: 2), () {
      msg.delivery = MessageDelivery.read;
      notifyListeners();
    });
  }

  void sendText(String text) {
    final id = selectedContactId;
    if (id == null || text.trim().isEmpty) return;
    _dispatch(ChatMessage(
      id: 'out_${DateTime.now().microsecondsSinceEpoch}',
      contactId: id,
      type: MessageType.text,
      text: text.trim(),
      safetyStatus: 'GREEN',
      score: 0.0,
      timestamp: DateTime.now(),
      isOutgoing: true,
      delivery: MessageDelivery.sending,
    ));
  }

  void sendVoice(Duration d) {
    final id = selectedContactId;
    if (id == null) return;
    _dispatch(ChatMessage(
      id: 'out_${DateTime.now().microsecondsSinceEpoch}',
      contactId: id,
      type: MessageType.voice,
      voiceDuration: d,
      safetyStatus: 'GREEN',
      score: 0.0,
      timestamp: DateTime.now(),
      isOutgoing: true,
      delivery: MessageDelivery.sending,
    ));
  }

  void sendMedia(String label) {
    final id = selectedContactId;
    if (id == null) return;
    _dispatch(ChatMessage(
      id: 'out_${DateTime.now().microsecondsSinceEpoch}',
      contactId: id,
      type: MessageType.media,
      mediaLabel: label,
      safetyStatus: 'GREEN',
      score: 0.0,
      timestamp: DateTime.now(),
      isOutgoing: true,
      delivery: MessageDelivery.sending,
    ));
  }

  // --------------------------------------------------------------------------
  // Управление папками
  // --------------------------------------------------------------------------
  void createFolder(String name, Set<String> ids) {
    folders = [
      ...folders,
      ChatFolder(
        id: 'folder_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        contactIds: ids,
        color: _nextColor(),
      ),
    ];
    selectedFolderId = folders.last.id;
    selectedContactId = null;
    notifyListeners();
  }

  void updateFolder(String id, String name, Set<String> ids) {
    for (final f in folders) {
      if (f.id == id) {
        f.name = name;
        f.contactIds = ids;
        break;
      }
    }
    notifyListeners();
  }

  void deleteFolder(String id) {
    if (id == 'all' || id == 'unknown') return; // Системные нельзя удалять
    folders = folders.where((f) => f.id != id).toList();
    if (selectedFolderId == id) {
      selectedFolderId = 'all';
      selectedContactId = null;
    }
    notifyListeners();
  }

  Color _nextColor() {
    const palette = [
      Color(0xFF4DCD5E), Color(0xFFE8453C), Color(0xFFBA68C8),
      Color(0xFF64B5F6), Color(0xFFE8B548), Color(0xFF4DD0E1),
    ];
    return palette[(folders.length - 1) % palette.length];
  }

  // --------------------------------------------------------------------------
  // Действия с контактами
  // --------------------------------------------------------------------------
  void togglePin(String id) {
    for (final c in contacts) {
      if (c.id == id) c.isPinned = !c.isPinned;
    }
    notifyListeners();
  }

  void toggleMute(String id) {
    for (final c in contacts) {
      if (c.id == id) c.isMuted = !c.isMuted;
    }
    notifyListeners();
  }

  void deleteChat(String id) {
    messages.removeWhere((m) => m.contactId == id);
    if (selectedContactId == id) {
      selectedContactId = null;
      showPeerProfile = false;
    }
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Профиль
  // --------------------------------------------------------------------------
  void updateProfile({
    String? name, 
    String? username, 
    String? bio, 
    String? publicKeyBase58
  }) {
    if (name != null && name.trim().isNotEmpty) profile.name = name.trim();
    if (username != null) profile.username = username.trim();
    if (bio != null) profile.bio = bio.trim();
    if (publicKeyBase58 != null) profile.publicKeyBase58 = publicKeyBase58.trim();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Начальные данные (Mock)
  // --------------------------------------------------------------------------
  void _seed() {
    final now = DateTime.now();
    
    Contact mk(String id, String name, String user, Color color, {
      bool online = false, String bio = '', bool pinned = false, bool muted = false, bool verified = true
    }) => Contact(
      id: id, name: name, username: user, bio: bio, avatarColor: color,
      isOnline: online, lastSeen: online ? null : now.subtract(Duration(minutes: id.hashCode % 60)),
      isPinned: pinned, isMuted: muted, isVerified: verified,
    );

    contacts.addAll([
      mk('alex', 'Алексей Гордеев', '@agordeev', const Color(0xFF56A8E0), online: true, bio: 'Журналист, расследования', pinned: true),
      mk('maria', 'Мария Соколова', '@msokolova', const Color(0xFFE57373), bio: 'Правозащитник'),
      mk('dmitry', 'Дмитрий Волков', '@dvolkov', const Color(0xFF81C784), bio: 'Инженер, профсоюз'),
      mk('olga', 'Ольга Ким', '@okim', const Color(0xFFBA68C8), bio: 'Экономист', muted: true),
      mk('ivan', 'Иван Сидоров', '@isidorov', const Color(0xFF64B5F6), bio: 'Активист'),
      mk('natalia', 'Наталья Мороз', '@nmoroz', const Color(0xFFFFB74D), bio: 'Юрист', pinned: true),
      mk('sergey', 'Сергей Белов', '@sbelov', const Color(0xFF4DD0E1), bio: 'Аналитик'),
      mk('anna', 'Анна Ковалёва', '@akovaleva', const Color(0xFFF06292), bio: 'Эколог'),
      // Незнакомец (не верифицирован Web-of-Trust)
      mk('stranger', 'Спам-Бот', '@spam', const Color(0xFF9E9E9E), bio: 'Неизвестный отправитель', verified: false),
    ]);

    folders = [
      ChatFolder(id: 'all', name: 'Все', contactIds: {}, color: kAccent, isSystem: true),
      ChatFolder(id: 'unknown', name: 'Незнакомые', contactIds: {}, color: const Color(0xFF9E9E9E), isSystem: true, isUnknown: true),
      ChatFolder(id: 'work', name: 'Работа', contactIds: {'alex', 'dmitry', 'sergey'}, color: const Color(0xFF4DCD5E)),
      ChatFolder(id: 'family', name: 'Семья', contactIds: {'maria', 'natalia', 'anna'}, color: const Color(0xFFBA68C8)),
      ChatFolder(id: 'news', name: 'Новости', contactIds: {'olga', 'ivan', 'anna'}, color: const Color(0xFFE8B548)),
    ];

    final seedData = <({String cid, MessageType type, String? text, String? label, Duration? dur, String status, double score, bool out, int minutesAgo, bool unread})>[
      (cid: 'alex', type: MessageType.text, text: 'Завод Х закрыли из-за переноса производства в промзону Y', label: null, dur: null, status: 'GREEN', score: 0.0, out: false, minutesAgo: 45, unread: false),
      (cid: 'alex', type: MessageType.text, text: 'Срочно, посмотри что пишут!', label: null, dur: null, status: 'GREEN', score: 0.0, out: false, minutesAgo: 30, unread: false),
      (cid: 'alex', type: MessageType.text, text: 'Завод Х закрыли!', label: null, dur: null, status: 'RED', score: 0.86, out: false, minutesAgo: 22, unread: false),
      (cid: 'alex', type: MessageType.text, text: 'Это очень тревожная новость', label: null, dur: null, status: 'YELLOW', score: 0.42, out: false, minutesAgo: 18, unread: false),
      (cid: 'alex', type: MessageType.text, text: 'Проверяю через сеть', label: null, dur: null, status: 'GREEN', score: 0.0, out: true, minutesAgo: 15, unread: false),
      (cid: 'alex', type: MessageType.voice, text: null, label: null, dur: const Duration(seconds: 14), status: 'GREEN', score: 0.0, out: false, minutesAgo: 10, unread: false),
      (cid: 'alex', type: MessageType.media, text: null, label: 'Схема промзоны Y', dur: null, status: 'GREEN', score: 0.0, out: false, minutesAgo: 6, unread: false),
      (cid: 'maria', type: MessageType.text, text: 'Привет! Видел новость про завод?', label: null, dur: null, status: 'GREEN', score: 0.0, out: false, minutesAgo: 120, unread: true),
      (cid: 'maria', type: MessageType.text, text: 'Держи полный контекст по заводу', label: null, dur: null, status: 'GREEN', score: 0.0, out: false, minutesAgo: 118, unread: true),
      (cid: 'dmitry', type: MessageType.text, text: 'Профсоюз подтвердил перевод 340 сотрудников', label: null, dur: null, status: 'GREEN', score: 0.0, out: false, minutesAgo: 240, unread: true),
      (cid: 'stranger', type: MessageType.text, text: 'Вы выиграли приз! Перейдите по ссылке...', label: null, dur: null, status: 'RED', score: 0.99, out: false, minutesAgo: 5, unread: true),
    ];

    for (final s in seedData) {
      messages.add(ChatMessage(
        id: 'seed_${messages.length}',
        contactId: s.cid,
        type: s.type,
        text: s.text,
        mediaLabel: s.label,
        voiceDuration: s.dur,
        safetyStatus: s.status,
        score: s.score,
        timestamp: now.subtract(Duration(minutes: s.minutesAgo)),
        isOutgoing: s.out,
        isRead: !s.unread,
      ));
    }
  }
}