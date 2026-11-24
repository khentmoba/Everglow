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
  anilistId?: number;
  title: string;
  posterUrl: string;
  mediaType: string;
  format: string;
  source: string;
  status: string;
  isAnime: boolean;
  currentEpisode?: number;
  episodeCount?: number;
  userName: string;
  addedAt: Date;
  progressUpdatedAt?: Date;
};

export type OurBooksItem = {
  id: string;
  workKey: string;
  title: string;
  coverUrl: string;
  addedBy: string;
  addedAt: Date;
};

const DEMO_CINEMA: WatchMediaItem[] = [
  {
    id: 'demo_cinema_1',
    tmdbId: 550,
    title: 'Demo Movie Night',
    posterUrl: '/images/demo/poster-1.jpg',
    mediaType: 'movie',
    format: 'MOVIE',
    source: 'tmdb',
    status: 'watching',
    isAnime: false,
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 14),
  },
  {
    id: 'demo_cinema_2',
    tmdbId: 27205,
    title: 'Demo Sunset Story',
    posterUrl: '/images/demo/poster-2.jpg',
    mediaType: 'movie',
    format: 'MOVIE',
    source: 'tmdb',
    status: 'watched',
    isAnime: false,
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
    format: 'TV',
    source: 'jikan',
    status: 'watching',
    isAnime: true,
    currentEpisode: 5,
    episodeCount: 12,
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 15),
  },
  {
    id: 'demo_anime_3',
    tmdbId: 22,
    title: 'Demo Nebula Courier',
    posterUrl: '/images/demo/poster-2.jpg',
    mediaType: 'tv',
    format: 'TV',
    source: 'jikan',
    status: 'watching',
    isAnime: true,
    currentEpisode: 2,
    episodeCount: 24,
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 17),
  },
  {
    id: 'demo_anime_4',
    tmdbId: 23,
    title: 'Demo Sugar Rush',
    posterUrl: '/images/demo/poster-1.jpg',
    mediaType: 'tv',
    format: 'TV',
    source: 'jikan',
    status: 'watching',
    isAnime: true,
    currentEpisode: 7,
    episodeCount: 12,
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 19),
  },
  {
    id: 'demo_anime_2',
    tmdbId: 16498,
    title: 'Demo Finished Quest',
    posterUrl: '/images/demo/poster-4.jpg',
    mediaType: 'tv',
    format: 'TV',
    source: 'jikan',
    status: 'watched-self',
    isAnime: true,
    currentEpisode: 25,
    episodeCount: 25,
    userName: 'khentsgdz',
    addedAt: new Date(2026, 1, 18),
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

function mapWatchSnap(s: QuerySnapshot<DocumentData>): WatchMediaItem[] {
  return s.docs
    .map((d) => {
      const data = d.data();
      const source = String(data.source ?? 'tmdb');
      const addedAt = (data.addedAt as Timestamp | undefined)?.toDate() ?? new Date();
      const progressUpdatedAt = (data.progressUpdatedAt as Timestamp | undefined)?.toDate();
      return {
        id: d.id,
        tmdbId: Number(data.tmdbId ?? 0),
        anilistId: typeof data.anilistId === 'number' ? data.anilistId : undefined,
        title: String(data.title ?? ''),
        posterUrl: String(data.posterUrl ?? data.posterPath ?? ''),
        mediaType: String(data.mediaType ?? 'movie'),
        format: String(data.format ?? ''),
        source,
        status: String(data.status ?? ''),
        isAnime: Boolean(data.isAnime) || source === 'jikan',
        currentEpisode: typeof data.currentEpisode === 'number' ? data.currentEpisode : undefined,
        episodeCount: typeof data.episodeCount === 'number' ? data.episodeCount : undefined,
        userName: String(data.userName ?? ''),
        addedAt,
        progressUpdatedAt,
      };
    })
    .sort((a, b) => (b.progressUpdatedAt ?? b.addedAt).getTime() - (a.progressUpdatedAt ?? a.addedAt).getTime());
}

export function watchUserWatchList(userName: string, max = 500): Source<WatchMediaItem[]> {
  if (!userName) return just([]);
  if (AgentMode.demo) {
    return just([...DEMO_CINEMA, ...DEMO_ANIME].map((item) => ({ ...item, userName })));
  }
  const q = query(collection(db, 'watch_list'), where('userName', '==', userName), limit(max));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, WatchMediaItem[]>((next, error) => onSnapshot(q, next, error), mapWatchSnap),
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

