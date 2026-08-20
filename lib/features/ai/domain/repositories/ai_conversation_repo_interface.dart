import '../../domain/models/ai_conversation.dart';

/// Abstract interface for conversation repository operations.
///
/// Enables dependency injection and test mocking.
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

  /// List all archived sessions, newest first.
  Future<List<AISession>> listSessions({int limit = 50});

  /// Load a specific session's messages into the assistant conversation.
  Future<void> loadSession(String sessionId);

  /// Delete a specific archived session.
  Future<void> deleteSession(String sessionId);
}

/// Represents an archived conversation session.
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
