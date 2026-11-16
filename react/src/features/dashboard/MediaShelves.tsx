// Port of CurrentlyWatchingPreview, CinemaPreview, AnimePreview,
// BooksPreview, and MangaPreview on the Dashboard.
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { withAlpha } from '../../core/theme/colors';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import {
  watchMangaLibrary,
  watchOurBooks,
  watchUserWatchList,
  type MangaLibraryItem,
  type OurBooksItem,
  type WatchMediaItem,
} from '../cinema/watchlistService';
import { PartnerSubrow, partnerEyebrowLabelFor } from './PartnerSubrow';
import { SHELF_ACCENTS, ShelfCard, ShelfHeader } from './ShelfWidgets';

const isWatching = (m: WatchMediaItem) => m.status.toLowerCase().includes('watching');
const isWatched = (m: WatchMediaItem) => m.status.toLowerCase().includes('watched');
const isCinema = (m: WatchMediaItem) => m.source !== 'jikan';
const isAnime = (m: WatchMediaItem) => m.source === 'jikan';

export function CurrentlyWatchingPreview() {
  const auth = useAuth();
  const navigate = useNavigate();
  const me = auth.currentUser ?? '';
  const partner = auth.partnerUsername ?? '';
  const myItems = useSource(() => watchUserWatchList(me), [me], []);
  const partnerItems = useSource(() => watchUserWatchList(partner), [partner], []);

  const myWatching = myItems.filter((m) => isCinema(m) && isWatching(m));
  const partnerWatching = partnerItems.filter((m) => isCinema(m) && isWatching(m));

  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader
        accent="cinema"
        title="Watching Now"
        itemCount={myWatching.length}
        onViewAll={() => navigate('/cinema')}
      />
      {auth.isCoupleUser && partner ? (
        <>
          <PartnerSubrow label="ME" accent="cinema" emptyMessage="Nothing playing right now.">
            {myWatching.map((m) => (
              <ShelfCard key={m.id} accent="cinema" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/cinema')} />
            ))}
          </PartnerSubrow>
          <PartnerSubrow label={partnerEyebrowLabelFor(me)} accent="cinema" emptyMessage="Nothing playing right now.">
            {partnerWatching.map((m) => (
              <ShelfCard key={m.id} accent="cinema" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/cinema')} />
            ))}
          </PartnerSubrow>
        </>
      ) : (
        <PartnerSubrow label="WATCHING" accent="cinema" emptyMessage="Nothing playing right now.">
          {myWatching.map((m) => (
            <ShelfCard key={m.id} accent="cinema" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/cinema')} />
          ))}
        </PartnerSubrow>
      )}
    </div>
  );
}

export function CinemaPreview() {
  const auth = useAuth();
  const navigate = useNavigate();
  const me = auth.currentUser ?? '';
  const partner = auth.partnerUsername ?? '';
  const myItems = useSource(() => watchUserWatchList(me), [me], []);
  const partnerItems = useSource(() => watchUserWatchList(partner), [partner], []);

  const myWatched = myItems.filter((m) => isCinema(m) && isWatched(m));
  const partnerWatched = partnerItems.filter((m) => isCinema(m) && isWatched(m));

  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="cinema" title="Cinema Vault" itemCount={myWatched.length} onViewAll={() => navigate('/cinema')} />
      {auth.isCoupleUser && partner ? (
        <>
          <PartnerSubrow label="ME" accent="cinema" emptyMessage="No watched titles yet.">
            {myWatched.map((m) => (
              <ShelfCard key={m.id} accent="cinema" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/cinema')} />
            ))}
          </PartnerSubrow>
          <PartnerSubrow label={partnerEyebrowLabelFor(me)} accent="cinema" emptyMessage="No watched titles yet.">
            {partnerWatched.map((m) => (
              <ShelfCard key={m.id} accent="cinema" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/cinema')} />
            ))}
          </PartnerSubrow>
        </>
      ) : (
        <PartnerSubrow label="WATCHED" accent="cinema" emptyMessage="No watched titles yet.">
          {myWatched.map((m) => (
            <ShelfCard key={m.id} accent="cinema" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/cinema')} />
          ))}
        </PartnerSubrow>
      )}
    </div>
  );
}

export function AnimePreview() {
  const auth = useAuth();
  const navigate = useNavigate();
  const me = auth.currentUser ?? '';
  const partner = auth.partnerUsername ?? '';
  const myItems = useSource(() => watchUserWatchList(me), [me], []);
  const partnerItems = useSource(() => watchUserWatchList(partner), [partner], []);

  const myWatching = myItems.filter((m) => isAnime(m) && isWatching(m));
  const partnerWatching = partnerItems.filter((m) => isAnime(m) && isWatching(m));
  const myDone = myItems.filter((m) => isAnime(m) && isWatched(m));
  const partnerDone = partnerItems.filter((m) => isAnime(m) && isWatched(m));

  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="anime" title="Anime Realm" itemCount={myWatching.length + myDone.length} onViewAll={() => navigate('/anime')} />
      <AnimeSectionLabel label="WATCHING NOW" icon="play_circle_filled" />
      {auth.isCoupleUser && partner ? (
        <>
          <PartnerSubrow label="ME" accent="anime" emptyMessage="No anime playing right now.">
            {myWatching.map((m) => (
              <ShelfCard key={m.id} accent="anime" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/anime')} />
            ))}
          </PartnerSubrow>
          <PartnerSubrow label={partnerEyebrowLabelFor(me)} accent="anime" emptyMessage="No anime playing right now.">
            {partnerWatching.map((m) => (
              <ShelfCard key={m.id} accent="anime" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/anime')} />
            ))}
          </PartnerSubrow>
        </>
      ) : (
        <PartnerSubrow label="WATCHING" accent="anime" emptyMessage="No anime playing right now.">
          {myWatching.map((m) => (
            <ShelfCard key={m.id} accent="anime" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/anime')} />
          ))}
        </PartnerSubrow>
      )}
      <AnimeSectionLabel label="FINISHED" icon="check_circle" />
      {auth.isCoupleUser && partner ? (
        <>
          <PartnerSubrow label="ME" accent="anime" emptyMessage="No finished anime yet.">
            {myDone.map((m) => (
              <ShelfCard key={m.id} accent="anime" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/anime')} />
            ))}
          </PartnerSubrow>
          <PartnerSubrow label={partnerEyebrowLabelFor(me)} accent="anime" emptyMessage="No finished anime yet.">
            {partnerDone.map((m) => (
              <ShelfCard key={m.id} accent="anime" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/anime')} />
            ))}
          </PartnerSubrow>
        </>
      ) : (
        <PartnerSubrow label="FINISHED" accent="anime" emptyMessage="No finished anime yet.">
          {myDone.map((m) => (
            <ShelfCard key={m.id} accent="anime" imageUrl={m.posterUrl} title={m.title} onTap={() => navigate('/anime')} />
          ))}
        </PartnerSubrow>
      )}
    </div>
  );
}

function AnimeSectionLabel({ label, icon }: { label: string; icon: string }) {
  const c = SHELF_ACCENTS.anime.color;
  return (
    <div style={{ padding: '16px 0 2px', display: 'flex', alignItems: 'center' }}>
      <div style={{ width: 22, height: 1, background: linear([withAlpha(c, 0), withAlpha(c, 0.35)]) }} />
      <div style={{ width: 8 }} />
      <Icon name={icon} size={13} color={c} />
      <div style={{ width: 6 }} />
      <span style={{ ...AppTypography.outfitWhite, fontSize: 10, fontWeight: 800, color: withAlpha(c, 0.85), letterSpacing: 1.4 }}>
        {label}
      </span>
      <div style={{ width: 8 }} />
      <div style={{ flex: 1, height: 1, background: linear([withAlpha(c, 0.2), withAlpha(c, 0)]) }} />
    </div>
  );
}

export function BooksPreview() {
  const auth = useAuth();
  const navigate = useNavigate();
  const me = auth.currentUser ?? '';
  const partner = auth.partnerUsername ?? '';
  const items = useSource<OurBooksItem[]>(() => watchOurBooks(24), [], []);

  const mine = items.filter((b) => b.addedBy === me);
  const theirs = items.filter((b) => b.addedBy === partner);

  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="books" title="Our Books" itemCount={items.length} onViewAll={() => navigate('/books')} />
      {auth.isCoupleUser && partner ? (
        <>
          <PartnerSubrow label="ME" accent="books" emptyMessage="No books added yet.">
            {mine.map((b) => (
              <ShelfCard key={b.id} accent="books" imageUrl={b.coverUrl} title={b.title} onTap={() => navigate('/books')} />
            ))}
          </PartnerSubrow>
          <PartnerSubrow label={partnerEyebrowLabelFor(me)} accent="books" emptyMessage="No books added yet.">
            {theirs.map((b) => (
              <ShelfCard key={b.id} accent="books" imageUrl={b.coverUrl} title={b.title} onTap={() => navigate('/books')} />
            ))}
          </PartnerSubrow>
        </>
      ) : (
        <PartnerSubrow label="BOOKS" accent="books" emptyMessage="No books added yet.">
          {items.map((b) => (
            <ShelfCard key={b.id} accent="books" imageUrl={b.coverUrl} title={b.title} onTap={() => navigate('/books')} />
          ))}
        </PartnerSubrow>
      )}
    </div>
  );
}

export function MangaPreview() {
  const auth = useAuth();
  const navigate = useNavigate();
  const me = auth.currentUser ?? '';
  const partner = auth.partnerUsername ?? '';
  const myManga = useSource<MangaLibraryItem[]>(() => watchMangaLibrary(me), [me], []);
  const partnerManga = useSource<MangaLibraryItem[]>(() => watchMangaLibrary(partner), [partner], []);

  const myFiltered = myManga.filter((m) => m.libraryStatus !== 'none');
  const partnerFiltered = partnerManga.filter((m) => m.libraryStatus !== 'none');

  return (
    <div style={{ padding: '0 24px' }}>
      <ShelfHeader accent="manga" title="Mangacelestia" itemCount={myFiltered.length} onViewAll={() => navigate('/manga')} />
      {auth.isCoupleUser && partner ? (
        <>
          <PartnerSubrow label="ME" accent="manga" emptyMessage="Nothing on your reading shelf yet.">
            {myFiltered.map((m) => (
              <ShelfCard key={m.id} accent="manga" imageUrl={m.coverUrl} title={m.title} onTap={() => navigate('/manga')} />
            ))}
          </PartnerSubrow>
          <PartnerSubrow label={partnerEyebrowLabelFor(me)} accent="manga" emptyMessage="Nothing on their reading shelf yet.">
            {partnerFiltered.map((m) => (
              <ShelfCard key={m.id} accent="manga" imageUrl={m.coverUrl} title={m.title} onTap={() => navigate('/manga')} />
            ))}
          </PartnerSubrow>
        </>
      ) : (
        <PartnerSubrow label="READING" accent="manga" emptyMessage="Nothing on your reading shelf yet.">
          {myFiltered.map((m) => (
            <ShelfCard key={m.id} accent="manga" imageUrl={m.coverUrl} title={m.title} onTap={() => navigate('/manga')} />
          ))}
        </PartnerSubrow>
      )}
    </div>
  );
}
