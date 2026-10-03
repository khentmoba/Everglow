enum TonightOptionType {
  movie,
  date,
  game;

  String get label {
    switch (this) {
      case TonightOptionType.movie:
        return 'Movie';
      case TonightOptionType.date:
        return 'Date Idea';
      case TonightOptionType.game:
        return 'Game';
    }
  }

  String get emoji {
    switch (this) {
      case TonightOptionType.movie:
        return '🎬';
      case TonightOptionType.date:
        return '🌹';
      case TonightOptionType.game:
        return '🎮';
    }
  }

  static TonightOptionType fromString(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'movie':
          return TonightOptionType.movie;
        case 'date':
          return TonightOptionType.date;
        case 'game':
          return TonightOptionType.game;
      }
    }
    return TonightOptionType.date;
  }
}

class TonightOption {
  final String id;
  final TonightOptionType type;
  final String title;
  final String subtitle;
  final String description;
  final String? imageUrl;
  final String? targetRoute;

  const TonightOption({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.imageUrl,
    this.targetRoute,
  });

  factory TonightOption.fromMap(Map<String, dynamic>? data, [String? id]) {
    if (data == null) {
      return TonightOption(
        id: id ?? 'opt_fallback',
        type: TonightOptionType.date,
        title: 'Cozy Evening Together',
        subtitle: 'Everglow',
        description: 'Spend a relaxing night together.',
      );
    }
    return TonightOption(
      id:
          id ??
          _toStr(
            data['id'],
            fallback: 'opt_${DateTime.now().millisecondsSinceEpoch}',
          ),
      type: TonightOptionType.fromString(data['type']),
      title: _toStr(data['title'], fallback: 'Untitled Activity'),
      subtitle: _toStr(data['subtitle']),
      description: _toStr(data['description']),
      imageUrl: _toNullableStr(data['imageUrl']),
      targetRoute: _toNullableStr(data['targetRoute']),
    );
  }

  static String _toStr(dynamic value, {String fallback = ''}) {
    if (value is String) return value.isNotEmpty ? value : fallback;
    return fallback;
  }

  static String? _toNullableStr(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (targetRoute != null) 'targetRoute': targetRoute,
  };
}
