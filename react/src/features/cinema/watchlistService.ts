// Shared Firestore streams for Cinema, Anime, Books, and Manga dashboard shelves.
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  where,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { just, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export type WatchMediaItem = {
  id: string;
  tmdbId: number;
  title: string;
  posterUrl: string;
  mediaType: string;
  source: string;
  status: string;
  userName: string;
  addedAt: Date;
};

export type OurBooksItem = {
  id: string;
  workKey: string;
  title: string;
  coverUrl: string;
  addedBy: string;
  addedAt: Date;
};

export type MangaLibraryItem = {
  id: string;
  title: string;
  coverUrl: string;
  libraryStatus: string;
  userName: string;
};

const DEMO_CINEMA: WatchMediaItem[] = [
  {
    id: 'demo_cinema_1',
    tmdbId: 550,
    title: 'Demo Movie Night',
    posterUrl: '/images/demo/poster-1.jpg',
    mediaType: 'movie',
    source: 'tmdb',
    status: 'watching',
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 14),
  },
  {
    id: 'demo_cinema_2',
    tmdbId: 27205,
    title: 'Demo Sunset Story',
    posterUrl: '/images/demo/poster-2.jpg',
    mediaType: 'movie',
    source: 'tmdb',
    status: 'watched',
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 16),
  },
];

const DEMO_ANIME: WatchMediaItem[] = [
  {
    id: 'demo_anime_1',
    tmdbId: 21,
    title: 'Demo Anime Adventure',
    posterUrl: '/images/demo/poster-3.jpg',
    mediaType: 'tv',
    source: 'jikan',
    status: 'watching',
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 15),
  },
];

const DEMO_BOOKS: OurBooksItem[] = [
  {
    id: 'demo_book_1',
    workKey: '/works/demo',
    title: 'A fictional reading adventure',
    coverUrl: '/images/demo/poster-1.jpg',
    addedBy: 'khentsgdz',
    addedAt: new Date(2026, 1, 14),
  },
];

const DEMO_MANGA: MangaLibraryItem[] = [
  {
    id: 'demo_manga_1',
    title: 'Fictional Starlight Manga',
    coverUrl: '/images/demo/poster-4.jpg',
    libraryStatus: 'reading',
    userName: 'khentsgdz',
  },
];

function mapWatchSnap(s: QuerySnapshot<DocumentData>): WatchMediaItem[] {
  return s.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      tmdbId: Number(data.tmdbId ?? 0),
      title: String(data.title ?? ''),
      posterUrl: String(data.posterUrl ?? data.posterPath ?? ''),
      mediaType: String(data.mediaType ?? 'movie'),
      source: String(data.source ?? 'tmdb'),
      status: String(data.status ?? ''),
      userName: String(data.userName ?? ''),
      addedAt: (data.addedAt as Timestamp | undefined)?.toDate() ?? new Date(),
    };
  });
}

export function watchUserWatchList(userName: string, max = 24): Source<WatchMediaItem[]> {
  if (!userName) return just([]);
  if (AgentMode.demo) {
    return just([...DEMO_CINEMA, ...DEMO_ANIME].map((item) => ({ ...item, userName })));
  }
  const q = query(collection(db, 'watch_list'), where('userName', '==', userName), limit(max));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, WatchMediaItem[]>(
      (next, error) => onSnapshot(q, next, error),
      mapWatchSnap,
    ),
    { label: `watch-list-${userName}` },
  );
}

export function watchOurBooks(max = 24): Source<OurBooksItem[]> {
  if (AgentMode.demo) return just(DEMO_BOOKS);
  const q = query(collection(db, 'our_books'), orderBy('addedAt', 'desc'), limit(max));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, OurBooksItem[]>(
      (next, error) => onSnapshot(q, next, error),
      (s) =>
        s.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            workKey: String(data.workKey ?? ''),
            title: String(data.title ?? ''),
            coverUrl: String(data.coverUrl ?? ''),
            addedBy: String(data.addedBy ?? ''),
            addedAt: (data.addedAt as Timestamp | undefined)?.toDate() ?? new Date(),
          };
        }),
    ),
    { label: 'our-books-preview' },
  );
}

export function watchMangaLibrary(userName: string, max = 24): Source<MangaLibraryItem[]> {
  if (!userName) return just([]);
  if (AgentMode.demo) return just(DEMO_MANGA.map((m) => ({ ...m, userName })));
  const q = query(collection(db, 'manga_library'), where('userName', '==', userName), limit(max));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, MangaLibraryItem[]>(
      (next, error) => onSnapshot(q, next, error),
      (s) =>
        s.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            title: String(data.title ?? ''),
            coverUrl: String(data.coverUrl ?? ''),
            libraryStatus: String(data.libraryStatus ?? 'none'),
            userName: String(data.userName ?? ''),
          };
        }),
    ),
    { label: `manga-lib-${userName}` },
  );
}
