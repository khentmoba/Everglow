// Reader settings are global (like Apple Books); chapter + scroll position
// are per book. Both live in Prefs so a book reopens exactly where Clair left
// it, even after a reload.
import { Prefs } from '../../core/system/prefs';
import type { BookItem } from './bookTypes';

export type ReaderTheme = 'dark' | 'sepia' | 'light';
export type ReaderFont = 'classic' | 'modern' | 'soft' | 'dyslexic';

export interface ReaderSettings {
  fontSize: number;
  theme: ReaderTheme;
  font: ReaderFont;
  lineHeight: number;
  ttsRate: number;
  brightness: number;
  margin: number;
  pageTurn: boolean;
  align: 'left' | 'justify';
  voiceUri?: string;
}

const timeOfDayTheme = (): ReaderTheme => {
  const hour = new Date().getHours();
  return hour >= 7 && hour < 19 ? 'sepia' : 'dark';
};

export const DEFAULT_READER_SETTINGS: ReaderSettings = {
  fontSize: 18,
  theme: timeOfDayTheme(),
  font: 'modern',
  lineHeight: 1.7,
  ttsRate: 1,
  brightness: 1,
  margin: 0.5,
  pageTurn: false,
  align: 'left',
};

const SETTINGS_KEY = 'reader_settings';
const PROGRESS_PREFIX = 'reader_progress::';

const clamp = (value: unknown, min: number, max: number, fallback: number): number =>
  typeof value === 'number' && Number.isFinite(value) ? Math.min(max, Math.max(min, value)) : fallback;

function asTheme(value: unknown): ReaderTheme {
  return value === 'sepia' || value === 'light' || value === 'dark' ? value : DEFAULT_READER_SETTINGS.theme;
}

function asFont(value: unknown): ReaderFont {
  return value === 'classic' || value === 'soft' || value === 'modern' || value === 'dyslexic' ? value : DEFAULT_READER_SETTINGS.font;
}

export function loadSettings(): ReaderSettings {
  const raw = Prefs.get(SETTINGS_KEY);
  const saved = raw && typeof raw === 'object' ? (raw as Partial<ReaderSettings>) : {};
  return {
    fontSize: clamp(saved.fontSize, 14, 28, DEFAULT_READER_SETTINGS.fontSize),
    theme: asTheme(saved.theme),
    font: asFont(saved.font),
    lineHeight: clamp(saved.lineHeight, 1.35, 2.1, DEFAULT_READER_SETTINGS.lineHeight),
    ttsRate: clamp(saved.ttsRate, 0.75, 2, DEFAULT_READER_SETTINGS.ttsRate),
    brightness: clamp(saved.brightness, 0.5, 1, DEFAULT_READER_SETTINGS.brightness),
    margin: clamp(saved.margin, 0, 1, DEFAULT_READER_SETTINGS.margin),
    pageTurn: typeof saved.pageTurn === 'boolean' ? saved.pageTurn : false,
    align: saved.align === 'justify' ? 'justify' : 'left',
    voiceUri: typeof saved.voiceUri === 'string' ? saved.voiceUri : undefined,
  };
}

export function saveSettings(settings: ReaderSettings): void {
  Prefs.set(SETTINGS_KEY, settings);
}

export interface ReaderProgress {
  workKey: string;
  chapter: number;
  scroll: number;
  /** Anchor to a paragraph so changing font size or spacing keeps the place. */
  paragraphIndex?: number;
  charOffset?: number;
  readerName?: string;
  updatedAt: number;
  title: string;
  author: string;
  coverUrl: string;
  iaId: string;
  readCandidates: string[];
}

function readRecord(workKey: string): ReaderProgress | null {
  const raw = Prefs.get(PROGRESS_PREFIX + workKey);
  // Older builds stored the chapter as a bare number.
  if (typeof raw === 'number') {
    return { workKey, chapter: raw, scroll: 0, updatedAt: 0, title: '', author: '', coverUrl: '', iaId: '', readCandidates: [] };
  }
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Partial<ReaderProgress>;
  return {
    workKey,
    chapter: clamp(r.chapter, 0, 100000, 0),
    scroll: clamp(r.scroll, 0, 1, 0),
    paragraphIndex: typeof r.paragraphIndex === 'number' ? r.paragraphIndex : undefined,
    charOffset: typeof r.charOffset === 'number' ? r.charOffset : undefined,
    readerName: typeof r.readerName === 'string' ? r.readerName : undefined,
    updatedAt: typeof r.updatedAt === 'number' ? r.updatedAt : 0,
    title: typeof r.title === 'string' ? r.title : '',
    author: typeof r.author === 'string' ? r.author : '',
    coverUrl: typeof r.coverUrl === 'string' ? r.coverUrl : '',
    iaId: typeof r.iaId === 'string' ? r.iaId : '',
    readCandidates: Array.isArray(r.readCandidates) ? r.readCandidates.map(String) : [],
  };
}

export function loadProgress(workKey: string): ReaderProgress | null {
  if (!workKey) return null;
  return readRecord(workKey);
}

export function saveProgress(progress: ReaderProgress): void {
  if (!progress.workKey) return;
  Prefs.set(PROGRESS_PREFIX + progress.workKey, progress);
}

export function listProgress(): ReaderProgress[] {
  return Prefs.keysWithPrefix(PROGRESS_PREFIX)
    .map((key) => readRecord(key.slice(PROGRESS_PREFIX.length)))
    .filter((p): p is ReaderProgress => p != null && p.title !== '')
    .sort((a, b) => b.updatedAt - a.updatedAt);
}

export interface ReaderBookmark {
  chapter: number;
  scroll: number;
  createdAt: number;
}

export interface ReaderHighlight {
  id: string;
  chapter: number;
  text: string;
  note: string;
  color?: string;
  createdAt: number;
}

const BOOKMARK_PREFIX = 'reader_bookmarks::';
const HIGHLIGHT_PREFIX = 'reader_highlights::';

function readList<T>(key: string): T[] {
  const raw = Prefs.get(key);
  return Array.isArray(raw) ? (raw as T[]) : [];
}

export function loadBookmarks(workKey: string): ReaderBookmark[] {
  return workKey ? readList<ReaderBookmark>(BOOKMARK_PREFIX + workKey) : [];
}

export function toggleBookmark(workKey: string, bookmark: ReaderBookmark): ReaderBookmark[] {
  const list = loadBookmarks(workKey);
  const next = list.some((b) => b.chapter === bookmark.chapter)
    ? list.filter((b) => b.chapter !== bookmark.chapter)
    : [bookmark, ...list];
  Prefs.set(BOOKMARK_PREFIX + workKey, next);
  return next;
}

export function replaceBookmarks(workKey: string, list: ReaderBookmark[]): void {
  Prefs.set(BOOKMARK_PREFIX + workKey, list);
}

export function loadHighlights(workKey: string): ReaderHighlight[] {
  return workKey ? readList<ReaderHighlight>(HIGHLIGHT_PREFIX + workKey) : [];
}

export function replaceHighlights(workKey: string, list: ReaderHighlight[]): void {
  Prefs.set(HIGHLIGHT_PREFIX + workKey, list);
}

export function saveHighlight(workKey: string, highlight: ReaderHighlight): ReaderHighlight[] {
  const next = [highlight, ...loadHighlights(workKey).filter((h) => h.id !== highlight.id)];
  Prefs.set(HIGHLIGHT_PREFIX + workKey, next);
  return next;
}

export function removeHighlight(workKey: string, id: string): ReaderHighlight[] {
  const next = loadHighlights(workKey).filter((h) => h.id !== id);
  Prefs.set(HIGHLIGHT_PREFIX + workKey, next);
  return next;
}

export function progressToBookItem(p: ReaderProgress): BookItem {
  return {
    id: '',
    workKey: p.workKey,
    editionKey: '',
    iaId: p.iaId,
    title: p.title,
    author: p.author,
    coverUrl: p.coverUrl,
    year: '',
    publisher: '',
    isbn: '',
    pageCount: 0,
    subjects: [],
    status: '',
    userName: '',
    addedAt: new Date(p.updatedAt || Date.now()),
    readSourceUrl: p.readCandidates[0] ?? '',
    readSourceLabel: p.iaId.startsWith('pg') ? 'Project Gutenberg' : p.iaId ? 'Internet Archive' : 'Open Library',
  };
}
