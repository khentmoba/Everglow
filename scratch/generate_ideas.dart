import 'dart:convert';
import 'dart:io';

void main() {
  final ideas = [
    'Picnic at the park',
    'Movie marathon',
    'Visit a museum',
    'Cook a new recipe together',
    'Go for a late-night drive',
    'Watch the sunset',
    'Stargazing',
    'Visit a cat cafe',
    'Go to an arcade',
    'Try a new boba spot',
    'Botanical garden walk',
    'Board game night',
    'Mini golf tournament',
    'Visit a local bookstore',
    'Attend a workshop',
    'Go to a farmers market',
    'Take a pottery class',
    'Visit an art gallery',
    'Go for a hike',
    'Beach day',
  ];

  final result = [];
  for (var i = 0; i < 1000; i++) {
    final base = ideas[i % ideas.length];
    result.add({
      'id': 'idea_$i',
      'title': '$base (#${i + 1})',
    });
  }

  final directory = Directory('assets/data');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  final file = File('assets/data/date_ideas_seed.json');
  file.writeAsStringSync(jsonEncode(result));
  print('Generated 1000 ideas in assets/data/date_ideas_seed.json');
}
