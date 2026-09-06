import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// Shared markdown renderer for every chat surface (Mochi, Study, Sanctuary).
///
/// AI replies arrive as lightweight markdown — headings, **bold**, *italic*,
/// `code`, bullet/numbered lists, tables, dividers. This renders them as
/// warm, premium Everglow cards instead of raw `**` / `|` walls.
///
/// Design language (global — one look everywhere):
/// - Body 14px / 1.65, high-emphasis text for readability
/// - Section labels (emoji / ALL-CAPS lines) get a gold dot + hairline
/// - Bullets & steps are soft glass cards, never bare dots
/// - Tables WRAP text (no clipped "Shows system comp…" columns)
/// - Callouts (💡 lines) get a lilac→rose gradient card
/// - All colors/radii/type come from Dusk Petal tokens — no literals.
class EverglowMarkdown extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final double paragraphGap;
  final bool selectable;

  const EverglowMarkdown({
    super.key,
    required this.text,
    this.baseStyle,
    this.paragraphGap = 10,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        baseStyle ??
        AppTypography.bodyMedium().copyWith(
          color: AppColors.textHigh,
          height: 1.6,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        );
    final blocks = _parseBlocks(text.trim(), base);
    if (blocks.isEmpty) return const SizedBox.shrink();
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _withSpacing(blocks),
    );
    if (selectable) return SelectionArea(child: column);
    return column;
  }

  List<Widget> _withSpacing(List<Widget> blocks) {
    final out = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      out.add(blocks[i]);
      if (i == blocks.length - 1) break;
      final tight =
          (blocks[i] is _Bullet || blocks[i] is _Numbered) &&
          (blocks[i + 1] is _Bullet || blocks[i + 1] is _Numbered);
      out.add(SizedBox(height: tight ? 6 : paragraphGap));
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
        if (i < lines.length) i++;
        blocks.add(_CodeBlock(code: buf.join('\n')));
        continue;
      }

      // Table
      if (_looksLikeTableStart(lines, i)) {
        final tableLines = <String>[];
        while (i < lines.length &&
            lines[i].contains('|') &&
            lines[i].trim().isNotEmpty) {
          final t = lines[i].trim();
          if (t.startsWith('```') ||
              t.startsWith('>') ||
              RegExp(r'^#{1,4}\s*\S').hasMatch(t)) {
            break;
          }
          tableLines.add(lines[i]);
          i++;
        }
        final table = _buildTable(tableLines, base);
        if (table != null) {
          blocks.add(table);
        } else {
          for (final t in tableLines) {
            blocks.add(_paragraph(t, base));
          }
        }
        continue;
      }

      // Heading #, ##, ### — tolerant of missing space (`###Title`).
      final heading = RegExp(r'^(#{1,4})\s*(.+?)\s*$').firstMatch(trimmed);
      if (heading != null && (heading.group(2) ?? '').isNotEmpty) {
        final level = heading.group(1)!.length;
        final content = heading.group(2)!.trim();
        blocks.add(_Heading(level: level, content: content));
        i++;
        continue;
      }

      // Divider --- or *** or ___
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        blocks.add(const EverglowDivider());
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
        final buf = StringBuffer(content);
        var j = i + 1;
        while (j < lines.length) {
          final next = lines[j];
          if (next.trim().isEmpty) break;
          if (RegExp(r'^([-*•]|\d+[.)]|#{1,4}|```|\||>)')
              .hasMatch(next.trim())) {
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
        // A 💡/✨-led bullet is a tip — give it the callout card.
        if (_startsWithEmoji(content.trim())) {
          blocks.add(_Callout(text: content.trim(), base: base));
        } else {
          blocks.add(_Bullet(content: buf.toString(), base: base));
        }
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

      // Standalone "**Title:**" line — subhead pill.
      final boldLine = RegExp(r'^\*\*(.+?)\*\*:?\s*$').firstMatch(trimmed);
      if (boldLine != null && trimmed.length < 90) {
        blocks.add(_Subhead(content: boldLine.group(1)!.trim()));
        i++;
        continue;
      }

      // Emoji-led single line (💡 Quick hack…, 🧠 …) — callout card.
      if (_startsWithEmoji(trimmed) && trimmed.length < 220) {
        blocks.add(_Callout(text: trimmed, base: base));
        i++;
        continue;
      }

      // ALL-CAPS / emoji section label ("🔑 KEY POINTS AT A GLANCE").
      if (_isSectionLabel(trimmed)) {
        blocks.add(_SectionLabel(content: trimmed));
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
            _looksLikeTableStart(lines, i) ||
            RegExp(r'^#{1,4}\s*\S').hasMatch(nt) ||
            RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(nt) ||
            RegExp(r'^([-*•])\s+').hasMatch(nt) ||
            RegExp(r'^(\d+)[.)]\s+').hasMatch(nt)) {
          break;
        }
        if (RegExp(r'^\*\*(.+?)\*\*:?\s*$').hasMatch(nt) && nt.length < 90) {
          break;
        }
        if (_startsWithEmoji(nt) || _isSectionLabel(nt)) break;
        buf.add(next);
        i++;
      }
      final paraText = buf.join('\n').trim();
      // A short gathered paragraph that turns out to be a label/callout
      // still gets the premium treatment (model often emits these bare).
      if (_startsWithEmoji(paraText) && paraText.length < 220) {
        blocks.add(_Callout(text: paraText, base: base));
      } else if (_isSectionLabel(paraText)) {
        blocks.add(_SectionLabel(content: paraText));
      } else {
        blocks.add(_paragraph(paraText, base));
      }
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
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    for (final r in rows) {
      while (r.length < cols) {
        r.add('');
      }
    }
    return _EverglowTable(rows: rows, columnCount: cols, base: base);
  }

  List<String> _splitTableRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).toList();
  }
}

/// Wrapping table — text never clips. 2–3 column tables (the study
/// staple) flex to fill the bubble; wide 4+ column tables get a gentle
/// horizontal scroll with a sensible minimum cell width.
class _EverglowTable extends StatelessWidget {
  final List<List<String>> rows;
  final int columnCount;
  final TextStyle base;

  const _EverglowTable({
    required this.rows,
    required this.columnCount,
    required this.base,
  });

  @override
  Widget build(BuildContext context) {
    final headerStyle = AppTypography.bodySmall().copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: AppColors.blushGold,
      height: 1.4,
    );
    final cellStyle = AppTypography.bodySmall().copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: AppColors.textHigh,
      height: 1.55,
    );

    // Weight each column by its longest cell so narrow label columns
    // stay narrow and definition columns get room to wrap.
    final weights = List<double>.filled(columnCount, 1.0);
    for (var c = 0; c < columnCount; c++) {
      var longest = 8;
      for (final r in rows) {
        final len = r[c].length;
        if (len > longest) longest = len;
      }
      weights[c] = (longest / 22).clamp(1.0, 2.6);
    }

    Widget table(Map<int, TableColumnWidth> widths, {double? minWidth}) {
      final t = Table(
        columnWidths: widths,
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder(
          horizontalInside: BorderSide(
            color: AppColors.moonlight.withValues(alpha: 0.10),
            width: 0.5,
          ),
          verticalInside: BorderSide(
            color: AppColors.moonlight.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: BoxDecoration(
                color: r == 0
                    ? AppColors.blushGold.withValues(alpha: 0.12)
                    : (r.isOdd
                        ? AppColors.moonlight.withValues(alpha: 0.035)
                        : null),
              ),
              children: [
                for (var c = 0; c < columnCount; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: parseInline(
                          rows[r][c].trim(),
                          r == 0 ? headerStyle : cellStyle,
                        ),
                      ),
                      style: r == 0 ? headerStyle : cellStyle,
                      softWrap: true,
                    ),
                  ),
              ],
            ),
        ],
      );
      if (minWidth != null) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: IntrinsicWidth(child: t),
          ),
        );
      }
      return t;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.45),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.16),
        ),
        boxShadow: AppElevation.e2,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          if (columnCount >= 4) {
            return table(
              {
                for (var c = 0; c < columnCount; c++)
                  c: const FixedColumnWidth(130),
              },
              minWidth: maxW,
            );
          }
          return table({
            for (var c = 0; c < columnCount; c++)
              c: FlexColumnWidth(weights[c]),
          });
        },
      ),
    );
  }
}

/// `#` / `##` / `###` — warm display headings with a gold underline.
class _Heading extends StatelessWidget {
  final int level;
  final String content;
  const _Heading({required this.level, required this.content});

  @override
  Widget build(BuildContext context) {
    TextStyle style;
    double underlineWidth;
    switch (level) {
      case 1:
        style = AppTypography.titleLarge().copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.petalWhite,
          height: 1.3,
        );
        underlineWidth = 64;
        break;
      case 2:
        style = AppTypography.titleMedium().copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.petalWhite,
          height: 1.3,
        );
        underlineWidth = 48;
        break;
      default:
        style = AppTypography.bodyMedium().copyWith(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blushGold,
          height: 1.4,
        );
        underlineWidth = 36;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: parseInline(content, style)),
            style: style,
          ),
          const SizedBox(height: 6),
          Container(
            width: underlineWidth,
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blushGold.withValues(alpha: 0.9),
                  AppColors.deepRose.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
              borderRadius: AppRadius.radiusFull,
            ),
          ),
        ],
      ),
    );
  }
}

/// `**Section:**` on its own line — soft gold pill.
class _Subhead extends StatelessWidget {
  final String content;
  const _Subhead({required this.content});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyMedium().copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.blushGold,
      height: 1.4,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blushGold.withValues(alpha: 0.10),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.22),
        ),
      ),
      child: Text.rich(
        TextSpan(children: parseInline(content, style)),
        style: style,
      ),
    );
  }
}

/// Emoji / ALL-CAPS section labels ("🔑 KEY POINTS AT A GLANCE") —
/// gold dot + uppercase text + fading hairline.
class _SectionLabel extends StatelessWidget {
  final String content;
  const _SectionLabel({required this.content});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySmall().copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.blushGold,
      letterSpacing: 0.4,
      height: 1.4,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blushGold, AppColors.deepRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(children: parseInline(content, style)),
              style: style,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.055),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7, right: 11),
            decoration: BoxDecoration(
              color: AppColors.blushGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: parseInline(content, base)),
              style: base,
            ),
          ),
        ],
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.055),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blushGold, AppColors.deepRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.petalWhite,
                  height: 1.0,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(children: parseInline(content, base)),
                style: base,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 💡-led lines — lilac→rose gradient tip card.
class _Callout extends StatelessWidget {
  final String text;
  final TextStyle base;
  const _Callout({required this.text, required this.base});

  @override
  Widget build(BuildContext context) {
    final style = base.copyWith(height: 1.6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.auroraLilac.withValues(alpha: 0.16),
            AppColors.deepRose.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.auroraLilac.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.auroraLilac.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text.rich(
        TextSpan(children: parseInline(text, style)),
        style: style,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.softLavender.withValues(alpha: 0.09),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
          topLeft: Radius.circular(AppRadius.xs),
          bottomLeft: Radius.circular(AppRadius.xs),
        ),
        border: Border(
          left: BorderSide(
            color: AppColors.softLavender.withValues(alpha: 0.65),
            width: 3,
          ),
          top: BorderSide(
            color: AppColors.softLavender.withValues(alpha: 0.16),
          ),
          right: BorderSide(
            color: AppColors.softLavender.withValues(alpha: 0.16),
          ),
          bottom: BorderSide(
            color: AppColors.softLavender.withValues(alpha: 0.16),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 18,
            color: AppColors.softLavender.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: parseInline(text, base)),
              style: base.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.65),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.16),
        ),
        boxShadow: AppElevation.e2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.06),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.moonlight.withValues(alpha: 0.10),
                ),
              ),
            ),
            child: Row(
              children: [
                _Dot(color: AppColors.error.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                _Dot(color: AppColors.warning.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                _Dot(color: AppColors.success.withValues(alpha: 0.7)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Code copied',
                          style: AppTypography.bodySmall(),
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppColors.velvet,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusLg,
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: AppColors.textDisabled.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: Text(
              code,
              style: AppTypography.bodySmall().copyWith(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.auroraTeal,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Gradient hairline with a center glow dot — the global `---` divider.
/// Public so regression tests (and any surface) can find/style it.
class EverglowDivider extends StatelessWidget {
  const EverglowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.blushGold.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
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
    backgroundColor: AppColors.velvet.withValues(alpha: 0.85),
  );
  final boldStyle = base.copyWith(fontWeight: FontWeight.w700);
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
      spans.add(TextSpan(text: ' ${match.group(4)} ', style: codeStyle));
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

/// True when [lines[index]] starts a markdown table.
bool _looksLikeTableStart(List<String> lines, int index) {
  final first = lines[index].trim();
  if (first.isEmpty || !first.contains('|')) return false;
  if (first.startsWith('|')) return true;
  if (index + 1 >= lines.length) return false;
  final second = lines[index + 1].trim();
  if (!second.contains('|') && !second.contains('-')) return false;
  final cells = second
      .split('|')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  if (cells.isEmpty) return false;
  return cells.every((c) => RegExp(r'^:?-{1,}:?$').hasMatch(c));
}

/// Short, shouty lines ("🔑 KEY POINTS AT A GLANCE", "WHAT IS IT?")
/// are section labels, not body copy.
bool _isSectionLabel(String text) {
  final t = text.trim();
  if (t.isEmpty || t.length > 80) return false;
  if (t.contains('|') || t.startsWith('>') || t.startsWith('#')) return false;
  // Leading-emoji label (🔑 KEY POINTS…, 📦 BLOCK DIAGRAM — …).
  if (_startsWithEmoji(t)) {
    final withoutEmoji = t.replaceFirst(RegExp(r'^\S+\s*'), '').trim();
    if (withoutEmoji.isEmpty) return false;
    final letters = withoutEmoji.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 4) return false;
    final upper = letters.replaceAll(RegExp(r'[^A-Z]'), '').length;
    // Emoji-led + mostly-caps or short title → label.
    if (withoutEmoji.length <= 56 &&
        (upper / letters.length > 0.45 || withoutEmoji.length <= 34)) {
      return true;
    }
  }
  // Bare ALL-CAPS line ("WHAT IS IT?", "USES:").
  final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length >= 5 && letters.length <= 48) {
    final upper = letters.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (upper / letters.length > 0.8) return true;
  }
  return false;
}

/// True when the text starts with a common emoji / symbol marker.
bool _startsWithEmoji(String text) {
  final t = text.trimLeft();
  if (t.isEmpty) return false;
  final first = t.runes.first;
  // Fast path: the markers Mochi actually emits.
  const markers = '💡🧠✨📌🔑⭐🌙💭🎯📝📚❤️💖🔥✅❌⚠️👉🏷️📦🔹🔸🟣🟢🔵🟡🟠🔴💬🗺️🧭🎓📖📎';
  if (markers.contains(String.fromCharCode(first))) return true;
  // General ranges: emoticons, pictographs, dingbats, enclosed chars.
  return (first >= 0x1F300 && first <= 0x1FAFF) ||
      (first >= 0x2600 && first <= 0x27BF) ||
      (first >= 0x2B00 && first <= 0x2BFF) ||
      (first >= 0xFE00 && first <= 0xFE0F);
}
