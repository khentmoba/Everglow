// Port of lib/shared/widgets/everglow/everglow_markdown.dart.
import type { CSSProperties, ReactNode } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';
import { showSnackBar } from './SnackBar';

const e2 = '0 6px 16px rgba(0,0,0,0.25)';
type Block = { kind: 'heading' | 'subhead' | 'label' | 'list' | 'table' | 'other'; node: ReactNode };

const HEADING = /^(#{1,4})\s*(.+?)\s*$/;
const RULE = /^(-{3,}|\*{3,}|_{3,})$/;
const BULLET = /^([-*•])\s+(.*)$/;
const NUMBERED = /^(\d+)[.)]\s+(.*)$/;
const BOLD_LINE = /^\*\*(.+?)\*\*:?\s*$/;

export function EverglowMarkdown({
  text,
  baseStyle,
  paragraphGap = 10,
  plain = false,
}: {
  text: string;
  baseStyle?: CSSProperties;
  paragraphGap?: number;
  plain?: boolean;
}) {
  const base: CSSProperties = baseStyle ?? {
    ...AppTypography.bodyMedium,
    color: Derived.textHigh,
    lineHeight: 1.6,
    fontSize: 14.5,
    fontWeight: 500,
  };
  const blocks = parseBlocks(text.trim(), base, plain);
  if (blocks.length === 0) return null;
  const out: ReactNode[] = [];
  blocks.forEach((b, i) => {
    out.push(<div key={`b${i}`}>{b.node}</div>);
    if (i === blocks.length - 1) return;
    const next = blocks[i + 1];
    const hugs =
      (b.kind === 'subhead' || b.kind === 'label' || b.kind === 'heading') && (next.kind === 'list' || next.kind === 'table');
    out.push(<div key={`g${i}`} style={{ height: hugs ? 7 : paragraphGap }} />);
  });
  return <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch', userSelect: 'text' }}>{out}</div>;
}

function parseBlocks(input: string, base: CSSProperties, plain: boolean): Block[] {
  if (input === '') return [];
  const lines = input.replaceAll('\r\n', '\n').split('\n');
  const blocks: Block[] = [];
  const para = (t: string, style = base): Block => ({ kind: 'other', node: <Paragraph text={t} base={style} /> });
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();
    if (trimmed === '') {
      i++;
      continue;
    }
    if (trimmed.startsWith('```')) {
      const buf: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) buf.push(lines[i++]);
      if (i < lines.length) i++;
      const code = buf.join('\n');
      if (code.trim() !== '') blocks.push({ kind: 'other', node: <CodeBlock code={code} /> });
      continue;
    }
    if (looksLikeTableStart(lines, i)) {
      const tableLines: string[] = [];
      while (i < lines.length && lines[i].includes('|') && lines[i].trim() !== '') {
        const t = lines[i].trim();
        if (t.startsWith('```') || t.startsWith('>') || /^#{1,4}\s*\S/.test(t)) break;
        tableLines.push(lines[i++]);
      }
      const rows = buildTable(tableLines);
      if (rows) blocks.push({ kind: 'table', node: <MarkdownTable rows={rows} /> });
      else for (const t of tableLines) blocks.push(para(t));
      continue;
    }
    const heading = HEADING.exec(trimmed);
    if (heading && heading[2]) {
      const level = heading[1].length;
      const content = heading[2].trim();
      const size = typeof base.fontSize === 'number' ? base.fontSize : 16;
      blocks.push(
        plain
          ? para(content, { ...base, fontSize: size + (level === 1 ? 4 : 2), fontWeight: 600 })
          : { kind: 'heading', node: <Heading level={level} content={content} /> },
      );
      i++;
      continue;
    }
    if (RULE.test(trimmed)) {
      blocks.push({ kind: 'other', node: <EverglowDivider /> });
      i++;
      continue;
    }
    if (trimmed.startsWith('>')) {
      const buf: string[] = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) buf.push(lines[i++].trim().replace(/^>\s?/, ''));
      blocks.push({ kind: 'other', node: <Quote text={buf.join('\n')} base={base} /> });
      continue;
    }
    if (BULLET.test(trimmed)) {
      const items: string[] = [];
      while (i < lines.length) {
        const m = BULLET.exec(lines[i].trim());
        if (!m) break;
        let buf = m[2] ?? '';
        let j = i + 1;
        while (j < lines.length) {
          const next = lines[j];
          if (next.trim() === '') break;
          if (/^([-*•]|\d+[.)]|#{1,4}|```|\||>)/.test(next.trim())) break;
          if (next.startsWith('  ') || next.startsWith('\t')) {
            buf += `\n${next.trim()}`;
            j++;
          } else break;
        }
        items.push(buf);
        let k = j;
        while (k < lines.length && lines[k].trim() === '') k++;
        if (k < lines.length && /^([-*•])\s+/.test(lines[k].trim())) i = k;
        else {
          i = j;
          break;
        }
      }
      blocks.push({ kind: 'list', node: <BulletGroup items={items} base={base} plain={plain} /> });
      continue;
    }
    if (NUMBERED.test(trimmed)) {
      const items: [string, string][] = [];
      while (i < lines.length) {
        const m = NUMBERED.exec(lines[i].trim());
        if (!m) break;
        items.push([m[1], m[2] ?? '']);
        let k = i + 1;
        while (k < lines.length && lines[k].trim() === '') k++;
        if (k < lines.length && /^\d+[.)]\s+/.test(lines[k].trim())) i = k;
        else {
          i = i + 1;
          break;
        }
      }
      blocks.push({ kind: 'list', node: <NumberedGroup items={items} base={base} plain={plain} /> });
      continue;
    }
    const boldLine = BOLD_LINE.exec(trimmed);
    if (!plain && boldLine && trimmed.length < 90) {
      blocks.push({ kind: 'subhead', node: <Subhead content={boldLine[1].trim()} /> });
      i++;
      continue;
    }
    if (!plain && isSectionLabel(trimmed)) {
      blocks.push({ kind: 'label', node: <SectionLabel content={trimmed} /> });
      i++;
      continue;
    }
    if (!plain && isTipLead(trimmed) && trimmed.length < 220) {
      blocks.push({ kind: 'other', node: <Callout text={trimmed} base={base} /> });
      i++;
      continue;
    }
    const buf = [line];
    i++;
    while (i < lines.length) {
      const next = lines[i];
      const nt = next.trim();
      if (nt === '') break;
      if (
        nt.startsWith('```') ||
        nt.startsWith('|') ||
        nt.startsWith('>') ||
        looksLikeTableStart(lines, i) ||
        /^#{1,4}\s*\S/.test(nt) ||
        RULE.test(nt) ||
        /^([-*•])\s+/.test(nt) ||
        /^(\d+)[.)]\s+/.test(nt)
      ) {
        break;
      }
      if (BOLD_LINE.test(nt) && nt.length < 90) break;
      if (startsWithEmoji(nt) || isSectionLabel(nt)) break;
      buf.push(next);
      i++;
    }
    const paraText = buf.join('\n').trim();
    if (!plain && isSectionLabel(paraText)) blocks.push({ kind: 'label', node: <SectionLabel content={paraText} /> });
    else if (!plain && isTipLead(paraText) && paraText.length < 220)
      blocks.push({ kind: 'other', node: <Callout text={paraText} base={base} /> });
    else blocks.push(para(paraText));
  }
  return blocks;
}

function Paragraph({ text, base }: { text: string; base: CSSProperties }) {
  if (text === '') return null;
  return <div style={{ ...base, whiteSpace: 'pre-wrap', overflowWrap: 'break-word' }}>{parseInline(text, base)}</div>;
}

function buildTable(lines: string[]): string[][] | null {
  const rows: string[][] = [];
  for (const line of lines) {
    const cells = splitTableRow(line);
    if (cells.length === 0) continue;
    if (cells.every((c) => /^:?-{1,}:?$/.test(c.trim()))) continue;
    rows.push(cells);
  }
  if (rows.length < 2) return null;
  const cols = Math.max(...rows.map((r) => r.length));
  for (const r of rows) while (r.length < cols) r.push('');
  return rows;
}

function splitTableRow(line: string): string[] {
  let t = line.trim();
  if (t.startsWith('|')) t = t.slice(1);
  if (t.endsWith('|')) t = t.slice(0, -1);
  return t.split('|').map((c) => c.trim());
}

function MarkdownTable({ rows }: { rows: string[][] }) {
  const cols = rows[0].length;
  const headerStyle: CSSProperties = {
    ...AppTypography.bodySmall,
    fontSize: 12.5,
    fontWeight: 700,
    color: AppColors.blushGold,
    lineHeight: 1.4,
  };
  const cellStyle: CSSProperties = {
    ...AppTypography.bodySmall,
    fontSize: 13.5,
    fontWeight: 500,
    color: Derived.textHigh,
    lineHeight: 1.55,
  };
  const weights = Array.from({ length: cols }, (_, c) => {
    let longest = 8;
    for (const r of rows) longest = Math.max(longest, r[c].length);
    return Math.min(2.6, Math.max(1, longest / 22));
  });
  const wide = cols >= 4;
  const total = weights.reduce((a, b) => a + b, 0);
  const grid = (
    <table
      style={{
        borderCollapse: 'collapse',
        tableLayout: 'fixed',
        width: wide ? Math.max(130 * cols, 0) : '100%',
        minWidth: wide ? '100%' : undefined,
      }}
    >
      <colgroup>
        {weights.map((w, c) => (
          <col key={c} style={{ width: wide ? 130 : `${(w / total) * 100}%` }} />
        ))}
      </colgroup>
      <tbody>
        {rows.map((row, r) => (
          <tr
            key={r}
            style={{
              background:
                r === 0 ? withAlpha(AppColors.blushGold, 0.12) : r % 2 === 1 ? withAlpha(AppColors.moonlight, 0.035) : undefined,
              borderTop: r > 0 ? `0.5px solid ${withAlpha(AppColors.moonlight, 0.1)}` : undefined,
            }}
          >
            {row.map((cell, c) => (
              <td
                key={c}
                style={{
                  padding: '10px 12px',
                  verticalAlign: 'top',
                  borderLeft: c > 0 ? `0.5px solid ${withAlpha(AppColors.moonlight, 0.07)}` : undefined,
                  ...(r === 0 ? headerStyle : cellStyle),
                  overflowWrap: 'break-word',
                }}
              >
                {parseInline(cell.trim(), r === 0 ? headerStyle : cellStyle)}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
  return (
    <div
      style={{
        width: '100%',
        background: withAlpha(AppColors.inkDeep, 0.45),
        borderRadius: AppRadius.md,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.16)}, ${e2}`,
        overflow: 'hidden',
      }}
    >
      {wide ? (
        <div className="no-scrollbar" style={{ overflowX: 'auto' }}>
          {grid}
        </div>
      ) : (
        grid
      )}
    </div>
  );
}

function Heading({ level, content }: { level: number; content: string }) {
  const [style, underline]: [CSSProperties, number] =
    level === 1
      ? [{ ...AppTypography.titleLarge, fontSize: 20, fontWeight: 700, color: AppColors.petalWhite, lineHeight: 1.3 }, 64]
      : level === 2
        ? [{ ...AppTypography.titleMedium, fontSize: 17, fontWeight: 700, color: AppColors.petalWhite, lineHeight: 1.3 }, 48]
        : [{ ...AppTypography.bodyMedium, fontSize: 14.5, fontWeight: 700, color: AppColors.blushGold, lineHeight: 1.4 }, 36];
  return (
    <div style={{ padding: '8px 0 2px' }}>
      <div style={style}>{parseInline(content, style)}</div>
      <div style={{ height: 6 }} />
      <div
        style={{
          width: underline,
          height: 3,
          borderRadius: AppRadius.full,
          background: linear([withAlpha(AppColors.blushGold, 0.9), withAlpha(AppColors.deepRose, 0.55), AppColors.transparent]),
        }}
      />
    </div>
  );
}

function Subhead({ content }: { content: string }) {
  const style: CSSProperties = {
    ...AppTypography.bodyMedium,
    fontSize: 15,
    fontWeight: 700,
    color: AppColors.petalWhite,
    lineHeight: 1.4,
  };
  return (
    <div style={{ padding: '10px 0 2px', display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 3.5,
          height: 17,
          flexShrink: 0,
          borderRadius: AppRadius.full,
          background: `linear-gradient(180deg, ${AppColors.blushGold}, ${AppColors.deepRose})`,
        }}
      />
      <div style={{ width: 9 }} />
      <div style={{ ...style, minWidth: 0 }}>{parseInline(content, style)}</div>
    </div>
  );
}

function SectionLabel({ content }: { content: string }) {
  const style: CSSProperties = {
    ...AppTypography.bodySmall,
    fontSize: 13,
    fontWeight: 700,
    color: AppColors.blushGold,
    letterSpacing: 0.4,
    lineHeight: 1.4,
  };
  return (
    <div style={{ padding: '10px 0 2px', display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 8,
          height: 8,
          flexShrink: 0,
          borderRadius: '50%',
          background: `linear-gradient(135deg, ${AppColors.blushGold}, ${AppColors.deepRose})`,
          boxShadow: `0 0 8px ${withAlpha(AppColors.blushGold, 0.45)}`,
        }}
      />
      <div style={{ width: 8 }} />
      <div style={{ ...style, minWidth: 0 }}>{parseInline(content, style)}</div>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, height: 1, background: linear([withAlpha(AppColors.blushGold, 0.35), AppColors.transparent]) }} />
    </div>
  );
}

function ListGroupShell({ plain, children }: { plain: boolean; children: ReactNode }) {
  if (plain) return <div>{children}</div>;
  return (
    <div
      style={{
        width: '100%',
        padding: '3px 0',
        borderRadius: AppRadius.md,
        background: withAlpha(AppColors.moonlight, 0.045),
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.1)}`,
      }}
    >
      {children}
    </div>
  );
}

const ListDivider = () => (
  <div style={{ height: 0.8, margin: '0 13px 0 30px', background: withAlpha(AppColors.moonlight, 0.08) }} />
);

export function BulletGroup({ items, base, plain }: { items: string[]; base: CSSProperties; plain: boolean }) {
  return (
    <ListGroupShell plain={plain}>
      {items.map((item, i) => {
        const split = splitLeadingEmoji(item);
        return (
          <div key={i}>
            {i > 0 && !plain && <ListDivider />}
            <div style={{ padding: plain ? '6px 4px' : '9px 13px', display: 'flex', alignItems: 'flex-start' }}>
              {split ? (
                <span style={{ paddingTop: 1, paddingRight: 10, fontSize: 14, lineHeight: 1.43 }}>{split[0]}</span>
              ) : (
                <span
                  style={{
                    width: 6,
                    height: 6,
                    flexShrink: 0,
                    margin: '8px 11px 0 0',
                    borderRadius: '50%',
                    background: plain ? Derived.textMuted : AppColors.blushGold,
                    boxShadow: plain ? undefined : `0 0 6px ${withAlpha(AppColors.blushGold, 0.5)}`,
                  }}
                />
              )}
              <div style={{ ...base, flex: 1, minWidth: 0, whiteSpace: 'pre-wrap', overflowWrap: 'break-word' }}>
                {parseInline(split ? split[1] : item, base)}
              </div>
            </div>
          </div>
        );
      })}
    </ListGroupShell>
  );
}

export function NumberedGroup({ items, base, plain }: { items: [string, string][]; base: CSSProperties; plain: boolean }) {
  return (
    <ListGroupShell plain={plain}>
      {items.map(([n, item], i) => (
        <div key={i}>
          {i > 0 && !plain && <ListDivider />}
          <div style={{ padding: '9px 13px', display: 'flex', alignItems: 'flex-start' }}>
            {plain ? (
              <span style={{ ...base, paddingRight: 11 }}>{n}.</span>
            ) : (
              <span
                style={{
                  width: 22,
                  height: 22,
                  flexShrink: 0,
                  margin: '1px 11px 0 0',
                  borderRadius: '50%',
                  background: `linear-gradient(135deg, ${AppColors.blushGold}, ${AppColors.deepRose})`,
                  boxShadow: `0 2px 8px ${withAlpha(AppColors.deepRose, 0.35)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...AppTypography.bodySmall,
                  fontSize: 11.5,
                  fontWeight: 700,
                  color: AppColors.petalWhite,
                  lineHeight: 1,
                }}
              >
                {n}
              </span>
            )}
            <div style={{ ...base, flex: 1, minWidth: 0, paddingTop: 1, whiteSpace: 'pre-wrap', overflowWrap: 'break-word' }}>
              {parseInline(item, base)}
            </div>
          </div>
        </div>
      ))}
    </ListGroupShell>
  );
}

function Callout({ text, base }: { text: string; base: CSSProperties }) {
  const style = { ...base, lineHeight: 1.6 };
  return (
    <div
      style={{
        width: '100%',
        padding: '13px 16px',
        borderRadius: AppRadius.lg,
        background: `linear-gradient(135deg, ${withAlpha(AppColors.auroraLilac, 0.18)}, ${withAlpha(AppColors.deepRose, 0.12)})`,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.32)}, 0 4px 18px ${withAlpha(AppColors.auroraLilac, 0.14)}, 0 1px 12px ${withAlpha(AppColors.blushGold, 0.06)}`,
        ...style,
        whiteSpace: 'pre-wrap',
      }}
    >
      {parseInline(text, style)}
    </div>
  );
}

function Quote({ text, base }: { text: string; base: CSSProperties }) {
  const edge = withAlpha(AppColors.softLavender, 0.16);
  return (
    <div
      style={{
        width: '100%',
        padding: '11px 14px 11px 14px',
        background: withAlpha(AppColors.softLavender, 0.09),
        borderRadius: `${AppRadius.xs}px ${AppRadius.md}px ${AppRadius.md}px ${AppRadius.xs}px`,
        borderLeft: `3px solid ${withAlpha(AppColors.softLavender, 0.65)}`,
        borderTop: `1px solid ${edge}`,
        borderRight: `1px solid ${edge}`,
        borderBottom: `1px solid ${edge}`,
        display: 'flex',
        alignItems: 'flex-start',
      }}
    >
      <Icon name="format_quote" size={18} color={withAlpha(AppColors.softLavender, 0.8)} />
      <div style={{ width: 8 }} />
      <div style={{ ...base, fontStyle: 'italic', color: Derived.textMuted, lineHeight: 1.6, flex: 1, whiteSpace: 'pre-wrap' }}>
        {parseInline(text, base)}
      </div>
    </div>
  );
}

function CodeBlock({ code }: { code: string }) {
  const dot = (c: string) => (
    <span style={{ width: 9, height: 9, borderRadius: '50%', background: c, display: 'inline-block' }} />
  );
  return (
    <div
      style={{
        width: '100%',
        background: withAlpha(AppColors.inkDeep, 0.65),
        borderRadius: AppRadius.md,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.16)}, ${e2}`,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          padding: '8px 12px',
          background: withAlpha(AppColors.moonlight, 0.06),
          borderBottom: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
          display: 'flex',
          alignItems: 'center',
          gap: 5,
        }}
      >
        {dot(withAlpha(AppColors.error, 0.7))}
        {dot(withAlpha(AppColors.warmAmber, 0.7))}
        {dot(withAlpha(AppColors.success, 0.7))}
        <div style={{ flex: 1 }} />
        <button
          type="button"
          className="bare-button"
          aria-label="Copy code"
          onClick={() => {
            void navigator.clipboard?.writeText(code);
            showSnackBar('Code copied', { duration: 1000 });
          }}
          style={{ padding: 5, borderRadius: 8, display: 'flex' }}
        >
          <Icon name="copy" size={13} color={withAlpha(Derived.textDisabled, 0.8 * 0.52)} />
        </button>
      </div>
      <div className="no-scrollbar" style={{ overflowX: 'auto', padding: 14 }}>
        <pre
          style={{
            margin: 0,
            ...AppTypography.bodySmall,
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: 500,
            color: AppColors.auroraTeal,
            lineHeight: 1.6,
          }}
        >
          {code}
        </pre>
      </div>
    </div>
  );
}

export function EverglowDivider() {
  const line = (
    <div
      style={{
        flex: 1,
        height: 1,
        background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.35), AppColors.transparent]),
      }}
    />
  );
  return (
    <div style={{ padding: '6px 0', display: 'flex', alignItems: 'center' }}>
      {line}
      <div
        style={{ width: 5, height: 5, margin: '0 8px', borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.6) }}
      />
      {line}
    </div>
  );
}

/** `parseInline`: bold, code and italic runs. */
export function parseInline(input: string, base: CSSProperties): ReactNode[] {
  const size = typeof base.fontSize === 'number' ? base.fontSize : 14;
  const codeStyle: CSSProperties = {
    fontFamily: 'monospace',
    fontSize: size - 1,
    color: AppColors.auroraTeal,
    background: withAlpha(AppColors.velvet, 0.85),
  };
  const out: ReactNode[] = [];
  const regex = /(\*\*(.+?)\*\*|__(.+?)__|`(.+?)`|\*(.+?)\*|_(.+?)_)/g;
  let last = 0;
  let k = 0;
  for (const m of input.matchAll(regex)) {
    const start = m.index!;
    if (start > last) out.push(input.slice(last, start));
    if (m[1] != null && m[0].startsWith('**'))
      out.push(
        <b key={k++} style={{ fontWeight: 700, color: Derived.textHigh }}>
          {m[2]}
        </b>,
      );
    else if (m[3] != null)
      out.push(
        <b key={k++} style={{ fontWeight: 700, color: Derived.textHigh }}>
          {m[3]}
        </b>,
      );
    else if (m[4] != null) out.push(<span key={k++} style={codeStyle}>{` ${m[4]} `}</span>);
    else if (m[5] != null) out.push(<i key={k++}>{m[5]}</i>);
    else if (m[6] != null) out.push(<i key={k++}>{m[6]}</i>);
    last = start + m[0].length;
  }
  if (last < input.length) out.push(input.slice(last));
  return out.length === 0 ? [input] : out;
}

function looksLikeTableStart(lines: string[], index: number): boolean {
  const first = lines[index].trim();
  if (first === '' || !first.includes('|')) return false;
  if (first.startsWith('|')) return true;
  if (index + 1 >= lines.length) return false;
  const second = lines[index + 1].trim();
  if (!second.includes('|') && !second.includes('-')) return false;
  const cells = second
    .split('|')
    .map((c) => c.trim())
    .filter((c) => c !== '');
  if (cells.length === 0) return false;
  return cells.every((c) => /^:?-{1,}:?$/.test(c));
}

function isSectionLabel(text: string): boolean {
  const t = text.trim();
  if (t === '' || t.length > 80) return false;
  if (t.includes('|') || t.startsWith('>') || t.startsWith('#')) return false;
  if (startsWithEmoji(t)) {
    const withoutEmoji = t.replace(/^\S+\s*/, '').trim();
    if (withoutEmoji === '') return false;
    const letters = withoutEmoji.replace(/[^A-Za-z]/g, '');
    if (letters.length < 4) return false;
    const upper = letters.replace(/[^A-Z]/g, '').length;
    if (withoutEmoji.length <= 56 && (upper / letters.length > 0.45 || withoutEmoji.length <= 34)) return true;
  }
  const letters = t.replace(/[^A-Za-z]/g, '');
  if (letters.length >= 5 && letters.length <= 48) {
    const upper = letters.replace(/[^A-Z]/g, '').length;
    if (upper / letters.length > 0.8) return true;
  }
  return false;
}

const MARKERS = '💡🧠✨📌🔑⭐🌙💭🎯📝📚❤️💖🔥✅❌⚠️👉🏷️📦🔹🔸🟣🟢🔵🟡🟠🔴💬🗺️🧭🎓📖📎';

function startsWithEmoji(text: string): boolean {
  const t = text.trimStart();
  if (t === '') return false;
  const first = t.codePointAt(0)!;
  if (MARKERS.includes(String.fromCodePoint(first))) return true;
  return (
    (first >= 0x1f300 && first <= 0x1faff) ||
    (first >= 0x2600 && first <= 0x27bf) ||
    (first >= 0x2b00 && first <= 0x2bff) ||
    (first >= 0x1f1e6 && first <= 0x1f1ff) ||
    (first >= 0xfe00 && first <= 0xfe0f)
  );
}

function isTipLead(text: string): boolean {
  const t = text.trimStart();
  if (t === '') return false;
  return '💡✨📌🔑⭐🎯📝✅⚠️👉💬🧠📚'.includes(String.fromCodePoint(t.codePointAt(0)!));
}

function splitLeadingEmoji(text: string): [string, string] | null {
  const t = text.trimStart();
  if (t === '' || !startsWithEmoji(t)) return null;
  const seg = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
  const first = seg.segment(t)[Symbol.iterator]().next().value?.segment ?? '';
  const rest = t.slice(first.length).trimStart();
  if (rest === '') return null;
  return [first, rest];
}

/** `stripMarkdown` from lib/shared/utils/text_utils.dart. */
export function stripMarkdown(text: string): string {
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
