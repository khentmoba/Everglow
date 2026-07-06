/// A single message in an AI conversation.
class AIMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  /// Ephemeral image data URIs (e.g. "data:image/jpeg;base64,...").
  /// NOT persisted to Firestore — only sent in the current API call.
  /// Qwen 3.6 supports up to 5 images per request, each up to 4MB (base64).
  final List<String>? imageDataUris;

  AIMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.imageDataUris,
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

  /// Returns the payload for the Groq API.
  /// Text-only messages use the simple string format (backward-compatible).
  /// Messages with images use the OpenAI multimodal content array format.
  Map<String, dynamic> toApiPayload() {
    if (imageDataUris == null || imageDataUris!.isEmpty) {
      return {'role': role, 'content': content};
    }
    // OpenAI multimodal format
    final parts = <Map<String, dynamic>>[];
    if (content.isNotEmpty) {
      parts.add({'type': 'text', 'text': content});
    }
    for (final uri in imageDataUris!) {
      parts.add({'type': 'image_url', 'image_url': {'url': uri}});
    }
    return {'role': role, 'content': parts};
  }
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
