import 'package:intl/intl.dart';

final _pesoWhole = NumberFormat('#,##0', 'en_PH');
final _pesoCents = NumberFormat('#,##0.00', 'en_PH');

String formatPeso(num amount) {
  final hasCents = (amount - amount.truncate()).abs() > 0.004;
  return '₱${(hasCents ? _pesoCents : _pesoWhole).format(amount)}';
}

String stripMarkdown(String text) {
  return text
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('*', '')
      .replaceAll('_', '')
      .replaceAll('`', '')
      .replaceAll('~~', '')
      .replaceAll('### ', '')
      .replaceAll('## ', '')
      .replaceAll('# ', '');
}

List<String> extractTitles(String text) {
  final titles = <String>[];
  final lines = text.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    var cleaned = trimmed.replaceFirst(RegExp(r'^[\d]+[\.\)]\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^[-*]\s+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^\*\*[\d]+\.?\*\*\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^["""]'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'["""]$'), '');
    cleaned = stripMarkdown(cleaned).trim();

    if (cleaned.length > 5 &&
        cleaned.contains(' ') &&
        cleaned[0] == cleaned[0].toUpperCase() &&
        !cleaned.contains('http') &&
        !cleaned.contains('watch') &&
        !cleaned.contains('recommend')) {
      final parenIdx = cleaned.indexOf(' (');
      if (parenIdx > 0) cleaned = cleaned.substring(0, parenIdx);
      titles.add(cleaned);
    }
  }
  return titles;
}

String displayNameFor(String? username) {
  switch (username) {
    case 'khentsgdz':
      return 'Khent';
    case 'clairjassen':
      return 'Clair';
    case 'breyan':
      return 'Breyan';
    case 'octagram':
      return 'Octagram';
    default:
      if (username == null || username.isEmpty) return 'Love';
      return username[0].toUpperCase() + username.substring(1);
  }
}
