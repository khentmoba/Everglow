import assert from 'node:assert/strict';
import test from 'node:test';
import {
  mergeRecentTracks,
  musicStatusTrackKey,
  pickPreferredMusicStatus,
} from '../src/features/jukebox/jukeboxPure.ts';

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

  assert.equal(pickPreferredMusicStatus(stale, null)?.trackName, 'Stale');
});

test('musicStatusTrackKey changes when timestamp or playing state changes', () => {
  const a = track({ isPlaying: false, timestamp: new Date(1000) });
  const b = track({ isPlaying: true, timestamp: new Date(1000) });
  const c = track({ isPlaying: false, timestamp: new Date(2000) });
  assert.notEqual(musicStatusTrackKey(a), musicStatusTrackKey(b));
  assert.notEqual(musicStatusTrackKey(a), musicStatusTrackKey(c));
});
