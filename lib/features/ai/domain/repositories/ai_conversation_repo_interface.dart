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
  Future<void> clear(String feature);
  Future<void> loadAssistant();
  void startFresh();
}
