import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _greeting =
    '我是你的设计顾问。可以直接说房子、预算，或者想改的那一面墙。输出只供灵感，不构成结构、施工结论。';

class ChatMessage {
  const ChatMessage({required this.mine, required this.text, this.at});

  final bool mine;
  final String text;
  final DateTime? at;

  Map<String, dynamic> toJson() => {
        'mine': mine,
        'text': text,
        if (at != null) 'at': at!.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        mine: json['mine'] == true,
        text: '${json['text'] ?? ''}',
        at: json['at'] != null ? DateTime.tryParse('${json['at']}') : null,
      );
}

class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  String title;
  DateTime updatedAt;
  List<ChatMessage> messages;

  bool get isEmptyChat =>
      messages.isEmpty || (messages.length == 1 && !messages.first.mine && messages.first.text == _greeting);

  String get preview {
    for (final m in messages.reversed) {
      final t = m.text.trim();
      if (t.isNotEmpty && t != _greeting) return t;
    }
    return '新对话';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory AiConversation.fromJson(Map<String, dynamic> json) => AiConversation(
        id: '${json['id']}',
        title: '${json['title'] ?? '新对话'}',
        updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime.now(),
        messages: [
          for (final item in (json['messages'] as List? ?? const []))
            if (item is Map) ChatMessage.fromJson(Map<String, dynamic>.from(item)),
        ],
      );

  static AiConversation create() {
    final now = DateTime.now();
    return AiConversation(
      id: 'c_${now.microsecondsSinceEpoch}',
      title: '新对话',
      updatedAt: now,
      messages: [ChatMessage(mine: false, text: _greeting, at: now)],
    );
  }
}

class AiConversationStore extends ChangeNotifier {
  AiConversationStore();

  static const _key = 'ai_consult_conversations_v1';
  static const _activeKey = 'ai_consult_active_id_v1';

  final List<AiConversation> conversations = [];
  String? activeId;
  bool loaded = false;

  AiConversation get active {
    final id = activeId;
    if (id != null) {
      for (final c in conversations) {
        if (c.id == id) return c;
      }
    }
    if (conversations.isEmpty) {
      final created = AiConversation.create();
      conversations.add(created);
      activeId = created.id;
      return created;
    }
    activeId = conversations.first.id;
    return conversations.first;
  }

  Future<void> load() async {
    if (loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    activeId = prefs.getString(_activeKey);
    conversations.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              conversations.add(AiConversation.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (_) {
        conversations.clear();
      }
    }
    if (conversations.isEmpty) {
      final created = AiConversation.create();
      conversations.add(created);
      activeId = created.id;
    } else {
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (activeId == null || !conversations.any((c) => c.id == activeId)) {
        activeId = conversations.first.id;
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(conversations.map((c) => c.toJson()).toList()));
    if (activeId != null) await prefs.setString(_activeKey, activeId!);
  }

  Future<AiConversation> createNew() async {
    final created = AiConversation.create();
    conversations.insert(0, created);
    activeId = created.id;
    await _persist();
    notifyListeners();
    return created;
  }

  Future<void> select(String id) async {
    if (activeId == id) return;
    if (!conversations.any((c) => c.id == id)) return;
    activeId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    conversations.removeWhere((c) => c.id == id);
    if (conversations.isEmpty) {
      final created = AiConversation.create();
      conversations.add(created);
      activeId = created.id;
    } else if (activeId == id) {
      activeId = conversations.first.id;
    }
    await _persist();
    notifyListeners();
  }

  AiConversation? byId(String id) {
    for (final chat in conversations) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  Future<void> append(String id, ChatMessage message, {String? titleHint}) async {
    final chat = byId(id);
    if (chat == null) return;
    chat.messages = [...chat.messages, message];
    chat.updatedAt = DateTime.now();
    if (chat.title == '新对话' && message.mine) {
      final hint = (titleHint ?? message.text).trim();
      chat.title = hint.length > 18 ? '${hint.substring(0, 18)}…' : hint;
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    notifyListeners();
  }

  /// 流式回复：增量更新最后一条助手消息；finalize 时再落盘。
  Future<void> upsertAssistantStream(String id, String text, {bool finalize = false}) async {
    final chat = byId(id);
    if (chat == null) return;
    final now = DateTime.now();
    if (chat.messages.isNotEmpty && !chat.messages.last.mine) {
      final copy = List<ChatMessage>.from(chat.messages);
      copy[copy.length - 1] = ChatMessage(mine: false, text: text, at: now);
      chat.messages = copy;
    } else {
      chat.messages = [...chat.messages, ChatMessage(mine: false, text: text, at: now)];
    }
    chat.updatedAt = now;
    if (finalize) {
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _persist();
    }
    notifyListeners();
  }

  Future<void> replaceMessages(String id, List<ChatMessage> messages) async {
    final chat = byId(id);
    if (chat == null) return;
    chat.messages = messages;
    chat.updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }
}
