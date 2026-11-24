import assert from 'node:assert/strict';
import test from 'node:test';
import {
  mergeRecentTracks,
  musicStatusToMap,
  musicStatusTrackKey,
  pickPreferredMusicStatus,
  resolvedSpotifyUrl,
  shouldSyncPartnerStatus,
} from '../src/features/jukebox/jukeboxPure.ts';
import { dedupeMilestones } from '../src/features/dashboard/milestonePure.ts';

function track(overrides = {}) {
  return {
    username: 'khentsgdz',
    trackName: 'Default Track',
    artistName: 'Default Artist',
    albumName: 'Default Album',
    imageUrl: null,
    isPlaying: false,
    spotifyUrl: 'https://open.spotify.com',
    timestamp: new Date('2026-11-12T10:00:00.000Z'),
    ...overrides,
  };
}

test('mergeRecentTracks puts live Spotify track first even when Last.fm is 6 days old', () => {
  const sixDaysAgo = new Date('2026-11-12T10:00:00.000Z');
  const now = new Date('2026-11-18T15:00:00.000Z');
  const lastfm = [
    track({ trackName: 'Old Song A', artistName: 'Artist A', timestamp: sixDaysAgo }),
    track({ trackName: 'Old Song B', artistName: 'Artist B', timestamp: new Date(sixDaysAgo.getTime() - 60_000) }),
  ];
  const spotifyCurrent = track({
    trackName: 'Old Song A',
    artistName: 'Artist A',
    isPlaying: true,
    timestamp: now,
  });
  const spotifyRecent = [
    track({ trackName: 'Fresh Spotify', artistName: 'Artist C', timestamp: new Date(now.getTime() - 180_000) }),
  ];

  const merged = mergeRecentTracks(lastfm, spotifyCurrent, spotifyRecent, 5);
  assert.equal(merged.length, 3);
  assert.equal(merged[0].trackName, 'Old Song A');
  assert.equal(merged[0].isPlaying, true);
  assert.equal(merged[1].trackName, 'Fresh Spotify');
  assert.equal(merged[2].trackName, 'Old Song B');
});

test('mergeRecentTracks caps at maxItems and keeps Last.fm order when Spotify is empty', () => {
  const base = Date.parse('2026-11-18T15:00:00.000Z');
  const lastfm = Array.from({ length: 5 }, (_, i) =>
    track({ trackName: `Track ${i}`, artistName: `Artist ${i}`, timestamp: new Date(base - i * 60_000) }),
  );
  const spotifyRecent = [
    track({ trackName: 'Spotify New', artistName: 'Artist S', timestamp: new Date(base + 60_000) }),
  ];
  const merged = mergeRecentTracks(lastfm, null, spotifyRecent, 5);
  assert.equal(merged.length, 5);
  assert.equal(merged[0].trackName, 'Spotify New');
  assert.equal(merged[4].trackName, 'Track 3');
});

test('pickPreferredMusicStatus prefers live or newer Spotify over stale Last.fm', () => {
  const stale = track({ trackName: 'Stale', timestamp: new Date('2026-11-12T10:00:00.000Z') });
  const liveSpotify = track({ trackName: 'Live', isPlaying: true, timestamp: new Date('2026-11-18T15:00:00.000Z') });
  assert.equal(pickPreferredMusicStatus(stale, liveSpotify)?.trackName, 'Live');

  const newerSpotify = track({ trackName: 'Newer', isPlaying: false, timestamp: new Date('2026-11-18T14:00:00.000Z') });
  assert.equal(pickPreferredMusicStatus(stale, newerSpotify)?.trackName, 'Newer');

  const liveLastfm = track({ trackName: 'Live Lastfm', isPlaying: true, timestamp: null });
  assert.equal(pickPreferredMusicStatus(liveLastfm, newerSpotify)?.trackName, 'Live Lastfm');

  assert.equal(pickPreferredMusicStatus(stale, null)?.trackName, 'Stale');
});

test('musicStatusTrackKey changes when timestamp or playing state changes', () => {
  const a = track({ isPlaying: false, timestamp: new Date(1000) });
  const b = track({ isPlaying: true, timestamp: new Date(1000) });
  const c = track({ isPlaying: false, timestamp: new Date(2000) });
  assert.notEqual(musicStatusTrackKey(a), musicStatusTrackKey(b));
  assert.notEqual(musicStatusTrackKey(a), musicStatusTrackKey(c));
});

test('mergeRecentTracks includes paused Spotify track when fresher than stale Last.fm', () => {
  const stale = track({ trackName: 'Nov 11 Track', artistName: 'Old', timestamp: new Date('2026-11-11T16:48:00.000Z') });
  const pausedSpotify = track({
    trackName: 'Paused Recent',
    artistName: 'Fresh Artist',
    isPlaying: false,
    timestamp: new Date('2026-11-19T14:00:00.000Z'),
  });
  const merged = mergeRecentTracks([stale], pausedSpotify, [], 5);
  assert.equal(merged[0].trackName, 'Paused Recent');
  assert.equal(merged[1].trackName, 'Nov 11 Track');
});

test('shouldSyncPartnerStatus updates stale partner jukebox without clobbering live Spotify', () => {
  const now = Date.parse('2026-11-19T14:00:00.000Z');
  const staleExisting = track({
    username: 'clairjassen',
    trackName: 'chemtrails',
    artistName: 'Lizzy McAlpine',
    isPlaying: false,
    timestamp: new Date('2026-11-15T11:40:00.000Z'),
  });
  const fresherLastfm = track({
    username: 'clairjassen',
    trackName: 'wonder wander',
    artistName: 'Bella Kay',
    isPlaying: false,
    timestamp: new Date('2026-11-19T10:00:00.000Z'),
  });
  assert.equal(shouldSyncPartnerStatus(staleExisting, fresherLastfm, now), true);
  assert.equal(shouldSyncPartnerStatus(fresherLastfm, staleExisting, now), false);

  const liveSpotify = track({
    username: 'clairjassen',
    trackName: 'Live Now',
    artistName: 'Artist',
    isPlaying: true,
    timestamp: new Date(now - 2 * 60_000),
  });
  assert.equal(shouldSyncPartnerStatus(liveSpotify, fresherLastfm, now), false);
});

test('dedupeMilestones collapses duplicate archive docs and keeps richer photo list', () => {
  const d = new Date(2026, 1, 14);
  const items = [
    { id: 'doc1', title: 'First Date', description: 'Valentines', date: d, author: 'Khent', category: 'memory', imageUrls: ['a.jpg', 'b.jpg'] },
    { id: 'doc2', title: 'First Date ', description: 'Valentines', date: d, author: 'Khent', category: 'memory', imageUrls: ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg'] },
    { id: 'doc3', title: 'First Date', description: 'Valentines', date: d, author: 'Khent', category: 'memory', imageUrls: ['a.jpg'] },
    { id: 'doc4', title: 'Birthday', description: 'Butuan', date: new Date(2026, 1, 20), author: 'Khent', category: 'other', imageUrls: ['x.jpg'] },
  ];
  const deduped = dedupeMilestones(items);
  assert.equal(deduped.length, 2);
  assert.equal(deduped[0].id, 'doc2');
  assert.equal(deduped[0].imageUrls.length, 4);
  assert.equal(deduped[1].id, 'doc4');
});

test('musicStatusToMap clears stale Spotify IDs when Last.fm overwrites a Spotify doc', () => {
  const existingSpotifyDoc = musicStatusToMap(
    track({
      trackName: 'Old Spotify Song',
      spotifyTrackId: 'oldTrack123',
      spotifyEmbedUrl: 'https://open.spotify.com/embed/track/oldTrack123',
      previewUrl: 'https://p.scdn.co/mp3-preview/old',
    }),
  );
  assert.equal(existingSpotifyDoc.spotifyTrackId, 'oldTrack123');
  assert.equal(existingSpotifyDoc.spotifyEmbedUrl, 'https://open.spotify.com/embed/track/oldTrack123');
  assert.equal(existingSpotifyDoc.previewUrl, 'https://p.scdn.co/mp3-preview/old');

  const lastfmUpdate = musicStatusToMap(
    track({
      trackName: 'New Last.fm Song',
    }),
  );
  const merged = { ...existingSpotifyDoc, ...lastfmUpdate };
  assert.equal(merged.trackName, 'New Last.fm Song');
  assert.equal(merged.spotifyTrackId, null);
  assert.equal(merged.spotifyEmbedUrl, null);
  assert.equal(merged.previewUrl, null);
});

test('resolvedSpotifyUrl encodes track IDs and rejects non-http fallback URLs', () => {
  assert.equal(
    resolvedSpotifyUrl(track({ spotifyTrackId: 'abc/../../evil?x=1' })),
    'https://open.spotify.com/track/abc%2F..%2F..%2Fevil%3Fx%3D1',
  );
  assert.equal(
    resolvedSpotifyUrl(track({ spotifyTrackId: null, spotifyUrl: 'javascript:alert(1)' })),
    'https://open.spotify.com/',
  );
  assert.equal(
    resolvedSpotifyUrl(track({ spotifyTrackId: null, spotifyUrl: 'https://open.spotify.com/search/test' })),
    'https://open.spotify.com/search/test',
  );
});
