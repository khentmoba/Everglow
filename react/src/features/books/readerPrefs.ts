// Reader settings are global (like Apple Books); chapter + scroll position
// are per book. Both live in Prefs so a book reopens exactly where Clair left
// it, even after a reload.
import { Prefs } from '../../core/system/prefs';
import type { BookItem } from './bookTypes';

export type ReaderTheme = 'dark' | 'sepia' | 'light';
export type ReaderFont = 'classic' | 'modern' | 'soft';

export interface ReaderSettings {
  fontSize: number;
  theme: ReaderTheme;
  font: ReaderFont;
  lineHeight: number;
  ttsRate: number;
  brightness: number;
  margin: number;
}

export const DEFAULT_READER_SETTINGS: ReaderSettings = {
  fontSize: 18,
  theme: 'dark',
  font: 'modern',
  lineHeight: 1.7,
  ttsRate: 1,
  brightness: 1,
  margin: 0.5,
};

const SETTINGS_KEY = 'reader_settings';
const PROGRESS_PREFIX = 'reader_progress::';

const clamp = (value: unknown, min: number, max: number, fallback: number): number =>
  typeof value === 'number' && Number.isFinite(value) ? Math.min(max, Math.max(min, value)) : fallback;

function asTheme(value: unknown): ReaderTheme {
  return value === 'sepia' || value === 'light' || value === 'dark' ? value : DEFAULT_READER_SETTINGS.theme;
}

function asFont(value: unknown): ReaderFont {
  return value === 'classic' || value === 'soft' || value === 'modern' ? value : DEFAULT_READER_SETTINGS.font;
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
  };
}

export function saveSettings(settings: ReaderSettings): void {
  Prefs.set(SETTINGS_KEY, settings);
}

export interface ReaderProgress {
  workKey: string;
  chapter: number;
  scroll: number;
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
