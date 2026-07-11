/// A single message in an AI conversation.
class AIMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String> imageUrls; // optional image URLs for vision tasks

  AIMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.imageUrls = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      };

  factory AIMessage.fromJson(Map<String, dynamic> json) => AIMessage(
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? [],
      );

  /// Returns the payload for the Agnes API.
  /// If images are present, uses the multimodal content array format.
  Map<String, dynamic> toApiPayload() {
    if (imageUrls.isEmpty) {
      return {'role': role, 'content': content};
    }
    // Multimodal format: array of text and image_url blocks
    final List<Map<String, dynamic>> contentBlocks = [];
    if (content.isNotEmpty) {
      contentBlocks.add({'type': 'text', 'text': content});
    }
    for (final url in imageUrls) {
      contentBlocks.add({
        'type': 'image_url',
        'image_url': {'url': url},
      });
    }
    return {'role': role, 'content': contentBlocks};
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
