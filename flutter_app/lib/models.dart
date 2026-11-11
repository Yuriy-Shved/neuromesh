import 'package:flutter/material.dart';

enum MessageType { text, media, voice }

enum MessageDelivery { sending, sent, delivered, read }

class UserProfile {
  String name;
  String username;
  String bio;
  String publicKeyBase58; // Замена номера телефона (SIM-free identity)
  Color avatarColor;

  UserProfile({
    required this.name,
    required this.username,
    required this.bio,
    required this.publicKeyBase58,
    required this.avatarColor,
  });
}

class Contact {
  final String id;
  String name;
  String username;
  String bio;
  Color avatarColor;
  bool isOnline;
  DateTime? lastSeen;
  bool isPinned;
  bool isMuted;
  bool isVerified; // Флаг Web-of-Trust (для папки "Незнакомые")

  Contact({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    required this.avatarColor,
    this.isOnline = false,
    this.lastSeen,
    this.isPinned = false,
    this.isMuted = false,
    this.isVerified = false,
  });
}

class ChatMessage {
  final String id;
  final String contactId;
  final MessageType type;
  final String? text;
  final String? mediaLabel;
  final Duration? voiceDuration;
  final String safetyStatus; // 'GREEN', 'YELLOW', 'RED'
  final double score;
  final DateTime timestamp;
  final bool isOutgoing;
  MessageDelivery delivery;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.contactId,
    required this.type,
    this.text,
    this.mediaLabel,
    this.voiceDuration,
    required this.safetyStatus,
    required this.score,
    required this.timestamp,
    required this.isOutgoing,
    this.delivery = MessageDelivery.read,
    this.isRead = true,
  });
}

class ChatFolder {
  final String id;
  String name;
  Set<String> contactIds;
  Color color;
  bool isSystem;
  bool isUnknown; // Флаг для системной папки "Незнакомые"

  ChatFolder({
    required this.id,
    required this.name,
    required this.contactIds,
    required this.color,
    this.isSystem = false,
    this.isUnknown = false,
  });
}