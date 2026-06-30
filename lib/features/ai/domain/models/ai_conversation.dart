/// A single message in an AI conversation.
class AIMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  AIMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AIMessage.fromJson(Map<String, dynamic> json) => AIMessage(
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );

  Map<String, dynamic> toApiPayload() => {
        'role': role,
        'content': content,
      };
}

/// A conversation thread for a specific AI feature.
class AIConversation {
  final String id;
  final String feature; // 'assistant', 'guardian', 'recommendations', 'date_ideas'
  final List<AIMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  AIConversation({
    required this.id,
    required this.feature,
    List<AIMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'feature': feature,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AIConversation.fromJson(Map<String, dynamic> json) =>
      AIConversation(
        id: json['id'] ?? '',
        feature: json['feature'] ?? 'assistant',
        messages: (json['messages'] as List?)
                ?.map((m) => AIMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );
}
