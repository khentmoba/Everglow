// The Dashboard's media shelves: Watching Now, Cinema Vault, Anime Realm, Our Books, and Mangacelestia.
// Each shelf shows one shared row; a small initial on every cover says whose shelf it is on.
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowMarquee } from '../../shared/widgets/EverglowMarquee';
import {
  watchOurBooks,
  watchUserWatchList,
  type OurBooksItem,
  type WatchMediaItem,
} from '../cinema/watchlistService';
import { katanaChapterNumFromId, watchKatanaBookmarks, type KatanaBookmark } from '../manga/katanaService';
import { SHELF_ACCENTS, ShelfCard, ShelfHeader, type ShelfAccentKey, type ShelfOwner } from './ShelfWidgets';

const isSeriesCompleted = (m: WatchMediaItem) => {
  const isMovie = m.mediaType.trim().toLowerCase() !== 'tv' || m.format.trim().toLowerCase() === 'movie';
  return !isMovie && m.episodeCount != null && m.episodeCount > 1 && m.currentEpisode != null && m.currentEpisode >= m.episodeCount;
};
const isWatched = (m: WatchMediaItem) => m.status.toLowerCase().includes('watched') || isSeriesCompleted(m);
const isWatching = (m: WatchMediaItem) => !isWatched(m) && m.status.toLowerCase().includes('watching');
const isAnime = (m: WatchMediaItem) => m.isAnime || m.source === 'jikan';
const isCinema = (m: WatchMediaItem) => !isAnime(m);

const watchKey = (m: WatchMediaItem) =>
  m.anilistId && m.anilistId > 0
    ? `anilist:${m.anilistId}`
    : m.tmdbId > 0
      ? `${m.source}:${m.mediaType}:${m.tmdbId}`
      : m.title.trim().toLowerCase();

/** "khentsgdz" → "Khent", "clairjassen" → "Clair"; anyone else keeps their username. */
export function personName(userName: string): string {
  const lower = userName.toLowerCase();
  if (lower === 'khentsgdz') return 'Khent';
  if (lower === 'clairjassen') return 'Clair';
  return userName ? userName.charAt(0).toUpperCase() + userName.slice(1) : '';
}

const ownerColor = (userName: string) => (userName.toLowerCase() === 'clairjassen' ? AppColors.roseQuartz : AppColors.auroraTeal);

type Shared<T> = { key: string; item: T; owners: { user: string; item: T }[] };

/** Merges each person's list into one, keeping who has each title (first person's copy wins). */
function mergeByOwner<T>(lists: { user: string; items: T[] }[], keyOf: (t: T) => string): Shared<T>[] {
  const byKey = new Map<string, Shared<T>>();
  for (const { user, items } of lists) {
    if (!user) continue;
    for (const item of items) {
      const key = keyOf(item);
      const hit = byKey.get(key);
      if (!hit) byKey.set(key, { key, item, owners: [{ user, item }] });
      else if (!hit.owners.some((o) => o.user === user)) hit.owners.push({ user, item });
    }
  }
  return [...byKey.values()];
}

const owners = <T,>(s: Shared<T>): ShelfOwner[] => s.owners.map((o) => ({ name: personName(o.user), color: ownerColor(o.user) }));

function useCouple() {
  const auth = useAuth();
  const me = auth.currentUser ?? '';
  const partner = auth.isCoupleUser ? (auth.partnerUsername ?? '') : '';
  return { me, partner };
}

function ShelfRow({
  accent,
  label,
  emptyMessage,
  children,
}: {
  accent: ShelfAccentKey;
  label?: string;
  emptyMessage: string;
  children: ReactNode[];
}) {
  const a = SHELF_ACCENTS[accent];
  return (
    <div style={{ paddingTop: 14 }}>
      {label && (
        <div style={{ ...AppTypography.handwrittenBody, fontSize: 18, lineHeight: 1.1, color: withAlpha(a.color, 0.9), paddingBottom: 8 }}>
          {label}
        </div>
      )}
      {children.length > 0 ? (
        <EverglowMarquee height={194}>{children.slice(0, 16)}</EverglowMarquee>
      ) : (
        <div
          style={{
            padding: '14px 16px',
            borderRadius: 14,
            border: `1px dashed ${withAlpha(a.color, 0.25)}`,
            ...AppTypography.handwrittenBody,
            fontSize: 17,
            color: withAlpha(AppColors.petalWhite, 0.55),
          }}
        >
          {emptyMessage}
        </div>
      )}
    </div>
  );
}

function useWatchLists() {
  const { me, partner } = useCouple();
  const mine = useSource(() => watchUserWatchList(me), [me], []);
  const theirs = useSource(() => watchUserWatchList(partner), [partner], []);
  return (keep: (m: WatchMediaItem) => boolean) =>
    mergeByOwner(
      [
        { user: me, items: mine.filter(keep) },
        { user: partner, items: theirs.filter(keep) },
      ],
      watchKey,
    );
}

const episodeLine = (m: WatchMediaItem) =>
  m.currentEpisode != null && m.episodeCount != null && m.episodeCount > 1 ? `Ep ${m.currentEpisode} of ${m.episodeCount}` : undefined;
const episodeProgress = (m: WatchMediaItem) =>
  m.currentEpisode != null && m.episodeCount != null && m.episodeCount > 1 ? m.currentEpisode / m.episodeCount : undefined;

function watchCards(list: Shared<WatchMediaItem>[], accent: ShelfAccentKey, onTap: () => void, withProgress = false) {
  return list.map((s) => (
    <ShelfCard
      key={s.key}
      accent={accent}
      imageUrl={s.item.posterUrl}
      title={s.item.title}
      subtitle={withProgress && s.owners.length === 1 ? episodeLine(s.item) : undefined}
      progress={withProgress && s.owners.length === 1 ? episodeProgress(s.item) : undefined}
      owners={owners(s)}
      onTap={onTap}
    />
  ));
}

export function CurrentlyWatchingPreview() {
  const navigate = useNavigate();
  const watching = useWatchLists()((m) => isCinema(m) && isWatching(m));
  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="cinema" title="Watching Now" itemCount={watching.length} tagline="on our screens right now" onViewAll={() => navigate('/cinema')} />
      <ShelfRow accent="cinema" emptyMessage="Nothing playing right now.">
        {watchCards(watching, 'cinema', () => navigate('/cinema'), true)}
      </ShelfRow>
    </div>
  );
}

export function CinemaPreview() {
  const navigate = useNavigate();
  const watched = useWatchLists()((m) => isCinema(m) && isWatched(m));
  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="cinema" title="Cinema Vault" itemCount={watched.length} tagline="every film we've finished" onViewAll={() => navigate('/cinema')} />
      <ShelfRow accent="cinema" emptyMessage="No watched titles yet.">
        {watchCards(watched, 'cinema', () => navigate('/cinema'))}
      </ShelfRow>
    </div>
  );
}

export function AnimePreview() {
  const navigate = useNavigate();
  const lists = useWatchLists();
  const watching = lists((m) => isAnime(m) && isWatching(m));
  const done = lists((m) => isAnime(m) && isWatched(m));
  const open = () => navigate('/anime');
  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="anime" title="Anime Realm" itemCount={watching.length + done.length} tagline="episodes and endings" onViewAll={open} />
      <ShelfRow accent="anime" label="watching now" emptyMessage="No anime playing right now.">
        {watchCards(watching, 'anime', open, true)}
      </ShelfRow>
      <ShelfRow accent="anime" label="finished" emptyMessage="No finished anime yet.">
        {watchCards(done, 'anime', open)}
      </ShelfRow>
    </div>
  );
}

export function BooksPreview() {
  const navigate = useNavigate();
  const { me, partner } = useCouple();
  const items = useSource<OurBooksItem[]>(() => watchOurBooks(24), [], []);
  const shelf = mergeByOwner(
    [
      { user: me, items: items.filter((b) => b.addedBy === me) },
      { user: partner, items: items.filter((b) => b.addedBy === partner) },
    ],
    (b) => b.id,
  );
  const others = items.filter((b) => b.addedBy !== me && b.addedBy !== partner);
  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="books" title="Our Books" itemCount={items.length} tagline="pages we picked for each other" onViewAll={() => navigate('/books')} />
      <ShelfRow accent="books" emptyMessage="No books added yet.">
        {[
          ...shelf.map((s) => (
            <ShelfCard key={s.key} accent="books" imageUrl={s.item.coverUrl} title={s.item.title} owners={owners(s)} onTap={() => navigate('/books')} />
          )),
          ...others.map((b) => (
            <ShelfCard key={b.id} accent="books" imageUrl={b.coverUrl} title={b.title} onTap={() => navigate('/books')} />
          )),
        ]}
      </ShelfRow>
    </div>
  );
}

/** The chapter a bookmark stopped at, as a number when the chapter id carries one. */
export function chapterLabel(b: KatanaBookmark): string {
  const num = katanaChapterNumFromId(b.lastReadChapterId);
  if (num) return `Ch ${num}`;
  return b.lastReadChapterTitle || 'Started';
}

const shortDate = (d: Date) => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

export function MangaPreview() {
  const navigate = useNavigate();
  const { me, partner } = useCouple();
  const mine = useSource<KatanaBookmark[]>(() => watchKatanaBookmarks(me), [me], []);
  const theirs = useSource<KatanaBookmark[]>(() => watchKatanaBookmarks(partner), [partner], []);
  const reading = (b: KatanaBookmark) => b.finishedAt == null && b.lastReadChapterId !== '';
  const finished = (b: KatanaBookmark) => b.finishedAt != null;
  const slug = (b: KatanaBookmark) => b.slug;
  const readingShelf = mergeByOwner(
    [
      { user: me, items: mine.filter(reading) },
      { user: partner, items: theirs.filter(reading) },
    ],
    slug,
  );
  const finishedShelf = mergeByOwner(
    [
      { user: me, items: mine.filter(finished) },
      { user: partner, items: theirs.filter(finished) },
    ],
    slug,
  );
  const open = () => navigate('/manga');
  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader
        accent="manga"
        title="Mangacelestia"
        itemCount={readingShelf.length + finishedShelf.length}
        tagline="where each of us is reading"
        onViewAll={open}
      />
      <ShelfRow accent="manga" label="reading now" emptyMessage="Nothing on the reading shelf yet.">
        {readingShelf.map((s) => (
          <ShelfCard
            key={s.key}
            accent="manga"
            imageUrl={s.item.coverUrl}
            title={s.item.title}
            subtitle={
              s.owners.length === 1
                ? chapterLabel(s.item)
                : s.owners.map((o) => `${personName(o.user)} ${chapterLabel(o.item).replace('Ch ', 'ch ')}`).join(' · ')
            }
            owners={owners(s)}
            onTap={open}
          />
        ))}
      </ShelfRow>
      <ShelfRow accent="manga" label="finished reading" emptyMessage="Read a finished series to the last page and it lands here.">
        {finishedShelf.map((s) => (
          <ShelfCard
            key={s.key}
            accent="manga"
            imageUrl={s.item.coverUrl}
            title={s.item.title}
            subtitle={`finished ${shortDate(s.owners[0].item.finishedAt ?? new Date())}`}
            topBadge="Completed"
            owners={owners(s)}
            progress={1}
            onTap={open}
          />
        ))}
      </ShelfRow>
    </div>
  );
}
