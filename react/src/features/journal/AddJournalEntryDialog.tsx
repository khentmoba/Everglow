// Port of lib/features/journal/presentation/widgets/add_journal_entry_dialog.dart.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { authService } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppSpacing } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { forgetDraft, useDraft } from '../../shared/utils/draft';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowIconButton } from '../../shared/widgets/EverglowScaffold';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { awardDaily, journalAward } from '../xp/xpService';
import {
  countWords,
  JOURNAL_CATEGORIES,
  JOURNAL_MOODS,
  JournalEditConflict,
  journalService,
  newEntry,
  type JournalCategory,
  type JournalEntry,
  type JournalMood,
} from './journalService';
import { journalAuthorName, journalCategoryColor, journalReadingTime } from './journalUi';

/** Opens the dialog the way Flutter's `showDialog(builder: AddJournalEntryDialog(...))` does. */
export function showAddJournalEntryDialog(author: string, existing?: JournalEntry): Promise<void> {
  const compact = window.innerWidth < 600;
  return showDialog<void>((close) => <AddJournalEntryDialog author={author} existing={existing} close={() => close(null)} />, {
    insetPadding: compact ? `${AppSpacing.sm}px ${AppSpacing.xs}px` : `${AppSpacing.lg}px`,
  }).then(() => undefined);
}

const PENDING_ID_KEY = 'journal:new:pendingId';
const SYNC_WAIT_MS = 4000;
const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/** MaterialLocalizations.formatFullDate: "Tuesday, November 17, 2026". */
const fullDate = (d: Date) => `${weekdays[d.getDay()]}, ${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
const isoDay = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

function pendingEntryId(): string {
  try {
    const saved = Prefs.getString(PENDING_ID_KEY);
    if (saved != null) return saved;
    const id = journalService.newEntryId();
    Prefs.set(PENDING_ID_KEY, id);
    return id;
  } catch (e) {
    Logger.e('Journal: could not keep the pending entry id', e);
    return journalService.newEntryId();
  }
}

function afterNewEntrySaved(id: string, words?: { title: string; content: string }) {
  const uid = authService.uid;
  if (uid) void awardDaily(uid, 'journal', journalAward);
  if (Prefs.getString(PENDING_ID_KEY) === id) Prefs.remove(PENDING_ID_KEY);
  if (words) {
    forgetDraft('journal:new:title', words.title);
    forgetDraft('journal:new:content', words.content);
  }
}

const label: CSSProperties = {
  ...AppTypography.outfitBold,
  fontSize: 11,
  lineHeight: lineHeight(11),
  color: withAlpha(AppColors.petalWhite, 0.6),
};

function AddJournalEntryDialog({ author, existing, close }: { author: string; existing?: JournalEntry; close: () => void }) {
  const { width, height } = useViewport();
  const compact = width < 600;
  const sectionGap = compact ? AppSpacing.sm : AppSpacing.md;
  const isNew = existing == null;
  const [title, setTitle, clearTitle] = useDraft('journal:new:title', existing?.title ?? '', isNew);
  const [content, setContent, clearContent] = useDraft('journal:new:content', existing?.content ?? '', isNew);
  const [tag, setTag] = useState('');
  const [category, setCategory] = useState<JournalCategory>(existing?.category ?? 'daily');
  const [memoryDate, setMemoryDate] = useState<Date>(existing?.createdAt ?? new Date());
  const [mood, setMood] = useState<JournalMood | null>(existing?.mood ?? null);
  const [isPinned, setPinned] = useState(existing?.isPinned ?? false);
  const [isLocked, setLocked] = useState(existing?.isLocked ?? false);
  const [tags, setTags] = useState<string[]>(() => [...(existing?.tags ?? [])]);
  const [saving, setSaving] = useState(false);
  const [conflict, setConflict] = useState(false);
  const [original, setOriginal] = useState<JournalEntry | undefined>(existing);
  const [saveError, setSaveError] = useState<string | null>(null);
  const errorRef = useRef<HTMLDivElement>(null);
  const datePicker = useRef<HTMLInputElement>(null);
  const savingRef = useRef(false);

  useEffect(() => {
    if (saveError) errorRef.current?.scrollIntoView({ block: 'center' });
  }, [saveError]);

  const addTag = () => {
    const t = tag.trim().toLowerCase().replaceAll('#', '');
    if (t === '' || tags.includes(t) || tags.length >= 5) return;
    setTags([...tags, t]);
    setTag('');
  };

  const pickMemoryDate = () => {
    const el = datePicker.current;
    if (!el) return;
    try {
      el.showPicker();
    } catch {
      el.click();
    }
  };

  const save = async () => {
    const t = title.trim();
    const c = content.trim();
    if (savingRef.current || (t === '' && c === '')) return;
    savingRef.current = true;
    setSaving(true);
    setSaveError(null);
    const now = new Date();
    const wordCount = countWords(c);
    try {
      if (original) {
        const updated: JournalEntry = {
          ...original,
          title: t === '' ? 'Untitled' : t,
          content: c,
          createdAt: memoryDate,
          category,
          mood,
          tags,
          isPinned,
          isLocked,
          updatedAt: now,
          wordCount,
        };
        await journalService.update(updated, original);
      } else {
        const entry = newEntry({
          id: '',
          title: t === '' ? 'Untitled' : t,
          content: c,
          author,
          createdAt: memoryDate,
          updatedAt: now,
          category,
          mood,
          tags,
          isPinned,
          isLocked,
          wordCount,
        });
        const id = pendingEntryId();
        const write = journalService.add(entry, id);
        let timer = 0;
        const confirmed = await Promise.race([
          write.then(() => true),
          new Promise<boolean>((resolve) => (timer = window.setTimeout(() => resolve(false), SYNC_WAIT_MS))),
        ]).finally(() => clearTimeout(timer));
        if (!confirmed) {
          write.then(
            () => afterNewEntrySaved(id, { title: t, content: c }),
            (e: unknown) => Logger.e('Journal: queued save failed; draft kept', e),
          );
          close();
          showSnackBar("Saved on this device. It will sync when you're back online.");
          return;
        }
        afterNewEntrySaved(id);
      }
      if (isNew) {
        clearTitle();
        clearContent();
      }
      close();
    } catch (e) {
      Logger.e('Journal save failed; keeping draft', e);
      const isConflict = e instanceof JournalEditConflict;
      setConflict(isConflict);
      setSaveError(
        isConflict
          ? 'This page changed on another device. Reload the latest version before saving.'
          : 'Could not save your page. Your words are still here — please try again.',
      );
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  };

  const reloadLatest = async () => {
    const id = original?.id;
    if (id == null || savingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    setSaveError(null);
    try {
      const latest = await journalService.get(id);
      setOriginal(latest);
      setTitle(latest.title);
      setContent(latest.content);
      setMemoryDate(latest.createdAt);
      setCategory(latest.category);
      setMood(latest.mood);
      setTags([...latest.tags]);
      setPinned(latest.isPinned);
      setLocked(latest.isLocked);
      setConflict(false);
    } catch (e) {
      Logger.e('Journal reload failed', e);
      setSaveError('Could not reload this page. Your draft is still here — try again.');
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  };

  const words = countWords(content);
  const today = isoDay(new Date());
  return (
    <div
      style={{
        width: '100%',
        maxWidth: 560,
        minWidth: 280,
        maxHeight: Math.min(height * 0.92, 820),
        background: AppColors.velvet,
        borderRadius: 20,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
        boxSizing: 'border-box',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
      }}
    >
      <div
        className="no-scrollbar"
        style={{
          overflowY: 'auto',
          padding: compact ? `${AppSpacing.lg}px ${AppSpacing.md}px` : `${AppSpacing.xl}px`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
        }}
      >
        <div style={{ alignSelf: 'stretch', display: 'flex', alignItems: 'flex-start' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.handwrittenTitle, fontSize: 28, lineHeight: lineHeight(28) }}>
              {isNew ? 'A new page' : 'Edit this page'}
            </div>
            <div
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 11,
                lineHeight: lineHeight(11),
                color: withAlpha(AppColors.petalWhite, 0.55),
              }}
            >
              for us, by {journalAuthorName(author)}
            </div>
          </div>
          <EverglowIconButton icon="close" onPressed={close} semanticLabel="Close" tooltip="Close" />
        </div>
        <div style={{ height: sectionGap }} />
        <button
          type="button"
          className="bare-button"
          disabled={saving}
          onClick={pickMemoryDate}
          style={{
            alignSelf: 'stretch',
            position: 'relative',
            padding: `${AppSpacing.sm}px ${AppSpacing.md}px`,
            background: AppColors.twilight,
            borderRadius: 12,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.24)}`,
            display: 'flex',
            alignItems: 'center',
            textAlign: 'left',
          }}
        >
          <Icon name="calendar_month" size={20} color={AppColors.blushGold} />
          <div style={{ width: AppSpacing.sm }} />
          <div style={{ flex: 1 }}>
            <div style={label}>Memory date</div>
            <div style={{ height: AppSpacing.xs }} />
            <div style={{ ...AppTypography.outfitWhite, fontSize: 14, lineHeight: lineHeight(14) }}>{fullDate(memoryDate)}</div>
          </div>
          <Icon name="edit_calendar" size={18} color={withAlpha(AppColors.petalWhite, 0.55)} />
          <input
            ref={datePicker}
            type="date"
            tabIndex={-1}
            aria-hidden
            min="1900-01-01"
            max={today}
            value={isoDay(memoryDate)}
            onChange={(e) => {
              const [y, m, d] = e.target.value.split('-').map(Number);
              if (!y || !m || !d) return;
              setMemoryDate((prev) => new Date(y, m - 1, d, prev.getHours(), prev.getMinutes()));
            }}
            style={{ position: 'absolute', left: 0, bottom: 0, width: 1, height: 1, opacity: 0, pointerEvents: 'none' }}
          />
        </button>
        <div style={{ height: sectionGap }} />
        <div style={label}>Category</div>
        <div style={{ height: AppSpacing.sm }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: AppSpacing.sm }}>
          {JOURNAL_CATEGORIES.map((c) => {
            const sel = category === c.id;
            const hue = journalCategoryColor(c.id);
            return (
              <Chip
                key={c.id}
                onTap={() => setCategory(c.id)}
                padding={`${AppSpacing.sm}px ${AppSpacing.md}px`}
                background={sel ? withAlpha(hue, 0.22) : AppColors.twilight}
                border={sel ? hue : withAlpha(hue, 0.3)}
                fontSize={12}
                bold={sel}
                color={sel ? hue : withAlpha(AppColors.petalWhite, 0.7)}
              >
                {c.emoji} {c.displayName}
              </Chip>
            );
          })}
        </div>
        <div style={{ height: sectionGap }} />
        <Field
          value={title}
          onChange={setTitle}
          hint="Title (e.g., Our first roadtrip)"
          fontSize={16}
          fontWeight={600}
          hintSize={16}
          padding={`${AppSpacing.md}px ${AppSpacing.lg}px`}
        />
        <div style={{ height: sectionGap }} />
        <Field
          value={content}
          onChange={setContent}
          hint={'Write your heart out... ✨\n\nA date, a fight, a laugh — keep it forever.'}
          fontSize={14}
          hintSize={13}
          padding={`${compact ? AppSpacing.md : AppSpacing.lg}px`}
          minLines={compact ? 4 : 5}
          maxLines={compact ? 6 : 8}
        />
        <div style={{ height: AppSpacing.sm }} />
        <div
          style={{
            alignSelf: 'stretch',
            textAlign: 'right',
            ...AppTypography.outfitWhite,
            fontSize: 11,
            lineHeight: lineHeight(11),
            color: withAlpha(AppColors.blushGold, 0.8),
          }}
        >
          {words === 0
            ? 'Every love story deserves ink ✨'
            : `${words} ${words === 1 ? 'word' : 'words'} • ${journalReadingTime(words)}`}
        </div>
        <div style={{ height: AppSpacing.md }} />
        <div style={label}>Mood (optional)</div>
        <div style={{ height: AppSpacing.sm }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: AppSpacing.sm }}>
          {[null, ...JOURNAL_MOODS.map((m) => m.id)].map((m) => {
            const sel = mood === m;
            return (
              <Chip
                key={m ?? 'none'}
                onTap={() => setMood(m)}
                padding={`${AppSpacing.sm}px`}
                background={sel ? withAlpha(AppColors.deepRose, 0.25) : AppColors.twilight}
                border={sel ? AppColors.blushGold : Derived.border}
                fontSize={11}
                bold={sel}
                color={sel ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.7)}
              >
                {m == null ? 'None' : `${JOURNAL_MOODS.find((x) => x.id === m)!.emoji} ${m}`}
              </Chip>
            );
          })}
        </div>
        <div style={{ height: sectionGap }} />
        <Field
          value={tag}
          onChange={setTag}
          onSubmit={addTag}
          hint="Add tag (press enter)"
          fontSize={13}
          hintSize={16}
          padding={`${AppSpacing.md}px`}
          suffix={<MaterialIconButton icon="add" color={AppColors.blushGold} onPressed={addTag} />}
        />
        {tags.length > 0 && (
          <>
            <div style={{ height: AppSpacing.sm }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: AppSpacing.xs }}>
              {tags.map((t) => (
                <TagChip key={t} label={`#${t}`} onDeleted={() => setTags(tags.filter((x) => x !== t))} />
              ))}
            </div>
          </>
        )}
        <div style={{ height: sectionGap }} />
        <div style={{ alignSelf: 'stretch', display: 'flex' }}>
          <Toggle
            on={isPinned}
            onTap={() => setPinned(!isPinned)}
            hue={AppColors.blushGold}
            icon={isPinned ? 'push_pin' : 'push_pin_outlined'}
            text={isPinned ? 'Pinned' : 'Pin'}
          />
          <div style={{ width: AppSpacing.sm }} />
          <Toggle
            on={isLocked}
            onTap={() => setLocked(!isLocked)}
            hue={AppColors.warmAmber}
            icon={isLocked ? 'lock' : 'lock_open'}
            text={isLocked ? 'Locked' : 'Lock'}
          />
        </div>
        <div style={{ height: compact ? AppSpacing.md : AppSpacing.xl }} />
        {saveError != null && (
          <>
            <div
              ref={errorRef}
              style={{
                fontSize: 14,
                lineHeight: lineHeight(14),
                color: AppColors.error,
                fontFamily: AppTypography.bodyMedium.fontFamily,
              }}
            >
              {saveError}
            </div>
            {conflict && (
              <>
                <div style={{ height: AppSpacing.xs }} />
                <TextButton onPressed={saving ? undefined : () => void reloadLatest()}>Reload latest version</TextButton>
              </>
            )}
            <div style={{ height: AppSpacing.md }} />
          </>
        )}
        <button
          type="button"
          className="bare-button"
          onClick={saving ? undefined : () => void save()}
          style={{
            alignSelf: 'stretch',
            padding: `${AppSpacing.md}px 0`,
            background: saving ? AppColors.moonlight : `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.rosePressed})`,
            borderRadius: 14,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            minHeight: 44,
          }}
        >
          {saving ? (
            <CircularProgress size={18} strokeWidth={2} color={AppColors.petalWhite} />
          ) : (
            <span style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14), color: AppColors.petalWhite }}>
              {isNew ? 'Save Entry ✨' : 'Update Entry'}
            </span>
          )}
        </button>
      </div>
    </div>
  );
}

function Chip({
  onTap,
  padding,
  background,
  border,
  fontSize,
  bold,
  color,
  children,
}: {
  onTap: () => void;
  padding: string;
  background: string;
  border: string;
  fontSize: number;
  bold: boolean;
  color: string;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        padding,
        background,
        borderRadius: 20,
        border: `1px solid ${border}`,
        ...AppTypography.outfitWhite,
        fontSize,
        lineHeight: lineHeight(fontSize),
        fontWeight: bold ? 700 : 500,
        color,
      }}
    >
      {children}
    </button>
  );
}

function Toggle({ on, onTap, hue, icon, text }: { on: boolean; onTap: () => void; hue: string; icon: string; text: string }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        flex: 1,
        padding: '12px 0',
        background: on ? withAlpha(hue, 0.15) : AppColors.twilight,
        borderRadius: 12,
        border: `1px solid ${on ? hue : Derived.border}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={16} color={on ? hue : withAlpha(AppColors.petalWhite, 0.6)} />
      <div style={{ width: 6 }} />
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 12,
          lineHeight: lineHeight(12),
          color: on ? hue : withAlpha(AppColors.petalWhite, 0.7),
        }}
      >
        {text}
      </span>
    </button>
  );
}

/** M3 InputChip-style `Chip` with a delete icon. */
function TagChip({ label: text, onDeleted }: { label: string; onDeleted: () => void }) {
  return (
    <div
      style={{
        height: 32,
        padding: '0 4px 0 8px',
        borderRadius: 8,
        background: withAlpha(AppColors.softLavender, 0.15),
        border: `1px solid ${withAlpha(AppColors.softLavender, 0.2)}`,
        boxSizing: 'border-box',
        display: 'flex',
        alignItems: 'center',
        gap: 8,
      }}
    >
      <span style={{ ...AppTypography.labelLarge, fontSize: 11, lineHeight: lineHeight(11), color: AppColors.petalWhite }}>
        {text}
      </span>
      <button type="button" className="bare-button" aria-label="Delete" onClick={onDeleted} style={{ display: 'flex' }}>
        <Icon name="close" size={14} color={withAlpha(AppColors.petalWhite, 0.7)} />
      </button>
    </div>
  );
}

/** Filled twilight TextField, radius 12, no border line. */
function Field({
  value,
  onChange,
  onSubmit,
  hint,
  fontSize,
  fontWeight = 500,
  hintSize,
  padding,
  minLines,
  maxLines,
  suffix,
}: {
  value: string;
  onChange: (v: string) => void;
  onSubmit?: () => void;
  hint: string;
  fontSize: number;
  fontWeight?: number;
  hintSize: number;
  padding: string;
  minLines?: number;
  maxLines?: number;
  suffix?: ReactNode;
}) {
  const ref = useRef<HTMLTextAreaElement>(null);
  const line = fontSize * 1.5;
  useEffect(() => {
    const el = ref.current;
    if (!el || minLines == null) return;
    el.style.height = '0px';
    const pad = parseFloat(getComputedStyle(el).paddingTop) + parseFloat(getComputedStyle(el).paddingBottom);
    const lines = Math.min(maxLines ?? minLines, Math.max(minLines, Math.round((el.scrollHeight - pad) / line)));
    el.style.height = `${lines * line + pad}px`;
  }, [value, minLines, maxLines, line]);
  const text: CSSProperties = {
    flex: 1,
    minWidth: 0,
    padding,
    background: 'transparent',
    border: 'none',
    outline: 'none',
    resize: 'none',
    ...AppTypography.outfitWhite,
    fontSize,
    fontWeight,
    lineHeight: `${line}px`,
    color: AppColors.petalWhite,
    ['--hint-color' as string]: withAlpha(AppColors.petalWhite, 0.35),
    ['--hint-size' as string]: `${hintSize}px`,
  };
  return (
    <div
      style={{
        alignSelf: 'stretch',
        background: AppColors.twilight,
        borderRadius: 12,
        display: 'flex',
        alignItems: 'center',
        minHeight: suffix ? 48 : undefined,
      }}
    >
      {minLines != null ? (
        <textarea
          ref={ref}
          className="money-input no-scrollbar"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={hint}
          style={text}
        />
      ) : (
        <input
          className="money-input"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && onSubmit) {
              e.preventDefault();
              onSubmit();
            }
          }}
          placeholder={hint}
          style={text}
        />
      )}
      {suffix}
    </div>
  );
}
