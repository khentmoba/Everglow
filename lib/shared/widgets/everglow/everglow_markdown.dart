import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// Shared markdown renderer for every chat surface (Mochi, Study, etc).
///
/// Why this exists: AI replies arrive as lightweight markdown — headings,
/// **bold**, *italic*, `code`, bullet/numbered lists, tables, dividers.
/// Showing that raw (as Study did with `SelectableText`) reads as a wall
/// of `**` and `|`, which is exactly the "ass experience" Khent flagged.
///
/// This is intentionally dependency-free (no `flutter_markdown` package)
/// so it works offline, stays selectable on web, and matches Dusk Petal
/// tokens. It handles the subset Mochi actually emits:
/// headings, bold/italic/code, lists, tables, quotes, code blocks, `---`.
///
/// Usage: wrap is a [SelectionArea] so long answers stay copyable across
/// blocks on phone, tablet, and web.
class EverglowMarkdown extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final double paragraphGap;
  final bool selectable;

  const EverglowMarkdown({
    super.key,
    required this.text,
    this.baseStyle,
    this.paragraphGap = 8,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        baseStyle ??
        AppTypography.bodyMedium().copyWith(
          color: AppColors.textHigh,
          height: 1.55,
          fontSize: 14,
        );
    final blocks = _parseBlocks(text.trim(), base);
    if (blocks.isEmpty) return const SizedBox.shrink();
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _withSpacing(blocks, paragraphGap),
    );
    if (selectable) return SelectionArea(child: column);
    return column;
  }

  List<Widget> _withSpacing(List<Widget> blocks, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      out.add(blocks[i]);
      if (i != blocks.length - 1) out.add(SizedBox(height: gap));
    }
    return out;
  }

  List<Widget> _parseBlocks(String input, TextStyle base) {
    if (input.isEmpty) return [];
    final lines = input.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip blank lines (spacing is handled between blocks).
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Code block ``` ... ```
      if (trimmed.startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        // consume closing ```
        if (i < lines.length) i++;
        blocks.add(_CodeBlock(code: buf.join('\n')));
        continue;
      }

      // Table: consecutive lines starting with |
      if (trimmed.startsWith('|') && trimmed.contains('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }
        final table = _buildTable(tableLines, base);
        if (table != null) {
          blocks.add(table);
        } else {
          // Fallback: render as plain paragraphs if table parse failed.
          for (final t in tableLines) {
            blocks.add(_paragraph(t, base));
          }
        }
        continue;
      }

      // Heading #, ##, ###, ####
      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final content = heading.group(2)!.trim();
        blocks.add(_Heading(level: level, content: content, base: base));
        i++;
        continue;
      }

      // Divider --- or *** or ___
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              height: 1,
              color: AppColors.moonlight.withValues(alpha: 0.16),
            ),
          ),
        );
        i++;
        continue;
      }

      // Quote > ...
      if (trimmed.startsWith('>')) {
        final buf = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          buf.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_Quote(text: buf.join('\n'), base: base));
        continue;
      }

      // Bullet list item
      final bullet = RegExp(r'^([-*•])\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        final content = bullet.group(2) ?? '';
        // Collect continuation lines that are indented (part of same bullet).
        final buf = StringBuffer(content);
        var j = i + 1;
        while (j < lines.length) {
          final next = lines[j];
          if (next.trim().isEmpty) break;
          if (RegExp(r'^([-*•]|\d+[.)]|#{1,4}\s|```|\||>|\|)').hasMatch(
            next.trim(),
          )) {
            break;
          }
          if (next.startsWith('  ') || next.startsWith('\t')) {
            buf.write('\n${next.trim()}');
            j++;
          } else {
            break;
          }
        }
        i = j;
        blocks.add(_Bullet(content: buf.toString(), base: base));
        continue;
      }

      // Numbered list item
      final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        blocks.add(
          _Numbered(
            number: numbered.group(1)!,
            content: numbered.group(2) ?? '',
            base: base,
          ),
        );
        i++;
        continue;
      }

      // Standalone bold line "**Title:**" or "**Title**" — treat as subhead.
      // Study answers use this constantly as section titles.
      final boldLine = RegExp(r'^\*\*(.+?)\*\*:?\s*$').firstMatch(trimmed);
      if (boldLine != null && trimmed.length < 90) {
        blocks.add(_Subhead(content: boldLine.group(1)!.trim(), base: base));
        i++;
        continue;
      }

      // Normal paragraph: gather until blank or special block.
      final buf = <String>[line];
      i++;
      while (i < lines.length) {
        final next = lines[i];
        final nt = next.trim();
        if (nt.isEmpty) break;
        if (nt.startsWith('```') ||
            nt.startsWith('|') ||
            nt.startsWith('>') ||
            RegExp(r'^(#{1,4})\s+').hasMatch(nt) ||
            RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(nt) ||
            RegExp(r'^([-*•])\s+').hasMatch(nt) ||
            RegExp(r'^(\d+)[.)]\s+').hasMatch(nt)) {
          break;
        }
        // A standalone bold line starts a new subhead, don't merge it.
        if (RegExp(r'^\*\*(.+?)\*\*:?\s*$').hasMatch(nt) && nt.length < 90) {
          break;
        }
        buf.add(next);
        i++;
      }
      blocks.add(_paragraph(buf.join('\n').trim(), base));
    }
    return blocks;
  }

  Widget _paragraph(String text, TextStyle base) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: parseInline(text, base)),
      style: base,
    );
  }

  Widget? _buildTable(List<String> lines, TextStyle base) {
    // Parse cells per row, drop the markdown separator row (|---|---|).
    final rows = <List<String>>[];
    for (final line in lines) {
      final cells = _splitTableRow(line);
      if (cells.isEmpty) continue;
      final isSeparator = cells.every(
        (c) => RegExp(r'^:?-{1,}:?$').hasMatch(c.trim()),
      );
      if (isSeparator) continue;
      rows.add(cells);
    }
    if (rows.length < 2) return null;
    // Normalize column count.
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    for (final r in rows) {
      while (r.length < cols) {
        r.add('');
      }
    }

    final headerStyle = AppTypography.bodySmall().copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.blushGold,
      height: 1.35,
    );
    final cellStyle = AppTypography.bodySmall().copyWith(
      fontSize: 12,
      color: AppColors.textMedium,
      height: 1.45,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.35),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280),
          child: Table(
            columnWidths: {
              for (var c = 0; c < cols; c++)
                c: const IntrinsicColumnWidth(),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: AppColors.moonlight.withValues(alpha: 0.10),
                width: 0.5,
              ),
              verticalInside: BorderSide(
                color: AppColors.moonlight.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            children: [
              for (var r = 0; r < rows.length; r++)
                TableRow(
                  decoration: BoxDecoration(
                    color: r == 0
                        ? AppColors.blushGold.withValues(alpha: 0.10)
                        : (r.isOdd
                              ? AppColors.moonlight.withValues(alpha: 0.03)
                              : null),
                  ),
                  children: [
                    for (var c = 0; c < cols; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: parseInline(
                              rows[r][c].trim(),
                              r == 0 ? headerStyle : cellStyle,
                            ),
                          ),
                          style: r == 0 ? headerStyle : cellStyle,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _splitTableRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).toList();
  }
}

/// Heading inside a chat answer — `#`, `##`, `###`.
class _Heading extends StatelessWidget {
  final int level;
  final String content;
  final TextStyle base;
  const _Heading({
    required this.level,
    required this.content,
    required this.base,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle style;
    switch (level) {
      case 1:
        style = AppTypography.titleMedium().copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.petalWhite,
          height: 1.3,
        );
        break;
      case 2:
        style = AppTypography.titleSmall().copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.petalWhite,
          height: 1.3,
        );
        break;
      default:
        style = AppTypography.bodySmall().copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.blushGold,
          letterSpacing: 0.3,
          height: 1.35,
        );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text.rich(
        TextSpan(children: parseInline(content, style)),
        style: style,
      ),
    );
  }
}

/// `**Section:**` on its own line — Study answers use this as a header.
class _Subhead extends StatelessWidget {
  final String content;
  final TextStyle base;
  const _Subhead({required this.content, required this.base});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyMedium().copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.blushGold,
      height: 1.4,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text.rich(
        TextSpan(children: parseInline(content, style)),
        style: style,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String content;
  final TextStyle base;
  const _Bullet({required this.content, required this.base});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7, right: 10),
          decoration: BoxDecoration(
            color: AppColors.blushGold.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(children: parseInline(content, base)),
            style: base,
          ),
        ),
      ],
    );
  }
}

class _Numbered extends StatelessWidget {
  final String number;
  final String content;
  final TextStyle base;
  const _Numbered({
    required this.number,
    required this.content,
    required this.base,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Text(
            '$number.',
            style: AppTypography.bodyMedium().copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blushGold,
              height: 1.55,
            ),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(children: parseInline(content, base)),
            style: base,
          ),
        ),
      ],
    );
  }
}

class _Quote extends StatelessWidget {
  final String text;
  final TextStyle base;
  const _Quote({required this.text, required this.base});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softLavender.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          left: BorderSide(
            color: AppColors.softLavender.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Text.rich(
        TextSpan(children: parseInline(text, base)),
        style: base.copyWith(
          fontStyle: FontStyle.italic,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.55),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code,
          style: AppTypography.bodySmall().copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppColors.auroraTeal,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Inline spans: **bold**, __bold__, `code`, *italic*, _italic_.
///
/// Lenient on purpose — unmatched markers are shown as-is so no text
/// silently disappears mid-stream.
List<TextSpan> parseInline(String input, TextStyle base) {
  final codeStyle = base.copyWith(
    fontFamily: 'monospace',
    fontSize: (base.fontSize ?? 14) - 1,
    color: AppColors.auroraTeal,
    backgroundColor: AppColors.velvet.withValues(alpha: 0.7),
  );
  final boldStyle = base.copyWith(fontWeight: FontWeight.w700);
  // Keep bold readable on dark: force high-emphasis text unless the base
  // already carries an accent color (headings, table headers, numbers).
  final spans = <TextSpan>[];
  final regex = RegExp(r'(\*\*(.+?)\*\*|__(.+?)__|`(.+?)`|\*(.+?)\*|_(.+?)_)');
  var lastEnd = 0;
  for (final match in regex.allMatches(input)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: input.substring(lastEnd, match.start)));
    }
    if (match.group(1) != null && match.group(0)!.startsWith('**')) {
      spans.add(
        TextSpan(
          text: match.group(2),
          style: boldStyle.copyWith(color: AppColors.textHigh),
        ),
      );
    } else if (match.group(3) != null) {
      spans.add(
        TextSpan(
          text: match.group(3),
          style: boldStyle.copyWith(color: AppColors.textHigh),
        ),
      );
    } else if (match.group(4) != null) {
      spans.add(TextSpan(text: match.group(4), style: codeStyle));
    } else if (match.group(5) != null) {
      spans.add(
        TextSpan(
          text: match.group(5),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    } else if (match.group(6) != null) {
      spans.add(
        TextSpan(
          text: match.group(6),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }
    lastEnd = match.end;
  }
  if (lastEnd < input.length) {
    spans.add(TextSpan(text: input.substring(lastEnd)));
  }
  if (spans.isEmpty) return [TextSpan(text: input)];
  return spans;
}
