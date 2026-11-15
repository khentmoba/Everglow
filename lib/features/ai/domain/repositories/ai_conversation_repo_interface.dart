import '../../domain/models/ai_conversation.dart';

abstract class IAIConversationRepository {
  AIConversation? get assistant;
  AIConversation? get guardian;

  void setConversation(String feature, AIConversation? conv);
  Future<AIConversation> getOrCreate(String feature);
  Future<void> save(AIConversation conversation);
  Future<void> archiveSession(AIConversation conversation);
  Future<void> loadSessionIntoConversation(AIConversation conversation);
  Future<void> clear(String feature, {bool archive = true});
  Future<void> loadAssistant();
  void startFresh();

  Future<List<AISession>> listSessions({int limit = 50});

  Stream<List<AISession>> watchSessions({int limit = 50});

  Future<void> loadSession(String sessionId);

  Future<void> deleteSession(String sessionId);
}

class AISession {
  final String id;
  final String feature;
  final int messageCount;
  final bool hasSummary;
  final String? summary;
  final DateTime createdAt;
  final String title;

  AISession({
    required this.id,
    required this.feature,
    required this.messageCount,
    required this.hasSummary,
    this.summary,
    required this.createdAt,
    required this.title,
  });
}
