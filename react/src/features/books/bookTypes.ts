import { AppColors } from '../../core/theme/colors';

export const BookColors = {
  black: '#080810',
  card: AppColors.shimmerBase,
  rose: AppColors.roseQuartz,
  deepRose: AppColors.deepRose,
  amber: AppColors.warmAmber,
  white: AppColors.petalWhite,
  muted: AppColors.mutedPurple,
  pink: '#FF6B9D',
  cyan: '#22D3EE',
  gold: '#F59E0B',
} as const;

export interface BookItem {
  id: string;
  workKey: string;
  editionKey: string;
  iaId: string;
  title: string;
  author: string;
  coverUrl: string;
  year: string;
  publisher: string;
  isbn: string;
  pageCount: number;
  subjects: string[];
  status: string;
  userName: string;
  addedAt: Date;
  readSourceUrl: string;
  readSourceLabel: string;
}

export interface BookSearchResult {
  title: string;
  author: string;
  coverUrl: string;
  year: string;
  language: string;
  publisher: string;
  pageCount: number;
  filetype: string;
  sizeMb?: number;
  ratingCount?: number;
  description: string;
  subjects: string[];
  isbn: string;
  isbn13: string;
  categories: string[];
  sourceLabel: string;
  workKey: string;
  iaId: string;
  gutenbergId: number;
  downloadUrls: Record<string, string>;
  readCandidates: string[];
}

export interface OurBooksItem {
  id: string;
  workKey: string;
  editionKey: string;
  iaId: string;
  title: string;
  author: string;
  coverUrl: string;
  year: string;
  subjects: string[];
  addedBy: string;
  addedAt: Date;
  khentReadAt?: Date;
  clairReadAt?: Date;
}

export interface BookCategory {
  name: string;
  query: string;
  icon: string;
  color: string;
}

export const BOOK_CATEGORIES: BookCategory[] = [
  { name: 'Romance', query: 'romance', icon: 'favorite', color: '#E91E63' },
  { name: 'Mystery', query: 'mystery', icon: 'search', color: '#7B1FA2' },
  { name: 'Science Fiction', query: 'science fiction', icon: 'rocket_launch', color: '#00BCD4' },
  { name: 'Fantasy', query: 'fantasy', icon: 'auto_awesome', color: '#3949AB' },
  { name: 'Classics', query: 'classics', icon: 'menu_book', color: '#E8C97A' },
  { name: 'Adventure', query: 'adventure', icon: 'explore', color: '#EF6C00' },
  { name: 'Horror', query: 'horror', icon: 'brightness_3', color: AppColors.twilight },
  { name: 'Poetry', query: 'poetry', icon: 'auto_awesome_motion', color: AppColors.softLavender },
  { name: 'History', query: 'history', icon: 'account_balance', color: '#5D4037' },
  { name: 'Biography', query: 'biography', icon: 'person', color: AppColors.cinemaBlue },
  { name: 'Children', query: 'children', icon: 'child_care', color: AppColors.cinemaGreen },
  { name: 'Cooking', query: 'cooking', icon: 'restaurant', color: '#E65100' },
];

export function bookReadDisplay(status: string): string {
  if (status === 'read-khent') return 'Read by Khent';
  if (status === 'read-clair') return 'Read by Clair';
  if (status === 'read-both' || status === 'read') return 'Read by Both';
  if (status === 'read-self') return 'Read';
  return 'To Read';
}

export function isBookRead(status: string): boolean {
  return (
    status === 'read' ||
    status === 'read-khent' ||
    status === 'read-clair' ||
    status === 'read-both' ||
    status === 'read-self'
  );
}

export function searchResultToBookItem(r: BookSearchResult): BookItem {
  const workKey =
    r.workKey || (r.gutenbergId > 0 ? `pg:${r.gutenbergId}` : r.iaId ? `ia:${r.iaId}` : r.title);
  return {
    id: '',
    workKey,
    editionKey: '',
    iaId: r.iaId,
    title: r.title,
    author: r.author,
    coverUrl: r.coverUrl,
    year: r.year,
    publisher: r.publisher,
    isbn: r.isbn || r.isbn13,
    pageCount: r.pageCount,
    subjects: r.subjects,
    status: '',
    userName: '',
    addedAt: new Date(),
    readSourceUrl: r.readCandidates[0] ?? '',
    readSourceLabel: r.sourceLabel,
  };
}

export function bookItemToSearchResult(b: BookItem): BookSearchResult {
  const pgMatch = /^pg:(\d+)$/.exec(b.workKey);
  const gutenbergId = pgMatch ? Number(pgMatch[1]) : 0;
  return {
    title: b.title,
    author: b.author,
    coverUrl: b.coverUrl,
    year: b.year,
    language: '',
    publisher: b.publisher,
    pageCount: b.pageCount,
    filetype: '',
    description: '',
    subjects: b.subjects,
    isbn: b.isbn,
    isbn13: '',
    categories: b.subjects.slice(0, 3),
    sourceLabel: b.readSourceLabel || (b.iaId ? 'Internet Archive' : 'Open Library'),
    workKey: b.workKey,
    iaId: b.iaId,
    gutenbergId,
    downloadUrls: {},
    readCandidates: buildReadCandidates(b),
  };
}

export function buildReadCandidates(b: Pick<BookItem, 'readSourceUrl' | 'iaId' | 'workKey'>): string[] {
  const candidates: string[] = [];
  if (b.readSourceUrl && (b.readSourceUrl.endsWith('.txt') || b.readSourceUrl.includes('gutenberg.org'))) {
    candidates.push(b.readSourceUrl);
  }
  const pgId =
    b.iaId.startsWith('pg') && b.iaId.length > 2
      ? b.iaId.slice(2)
      : b.workKey.startsWith('pg:')
        ? b.workKey.slice(3)
        : '';
  if (pgId) {
    candidates.push(`https://www.gutenberg.org/cache/epub/${pgId}/pg${pgId}.txt`);
    candidates.push(`https://www.gutenberg.org/files/${pgId}/${pgId}-0.txt`);
  } else if (b.iaId) {
    candidates.push(`https://archive.org/download/${b.iaId}/${b.iaId}_djvu.txt`);
    candidates.push(`https://archive.org/download/${b.iaId}/${b.iaId}.txt`);
  }
  return Array.from(new Set(candidates));
}

export function ourBookStatus(b: OurBooksItem): string {
  const k = Boolean(b.khentReadAt);
  const c = Boolean(b.clairReadAt);
  if (k && c) return 'read-both';
  if (k) return 'read-khent';
  if (c) return 'read-clair';
  return 'to-read';
}

export function ourBookToBookItem(b: OurBooksItem): BookItem {
  return {
    id: b.id,
    workKey: b.workKey,
    editionKey: b.editionKey,
    iaId: b.iaId,
    title: b.title,
    author: b.author,
    coverUrl: b.coverUrl,
    year: b.year,
    publisher: '',
    isbn: '',
    pageCount: 0,
    subjects: b.subjects,
    status: ourBookStatus(b),
    userName: b.addedBy,
    addedAt: b.addedAt,
    readSourceUrl: '',
    readSourceLabel: b.iaId ? 'Internet Archive' : b.workKey ? 'Open Library' : '',
  };
}
