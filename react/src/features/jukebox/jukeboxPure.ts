import type { MusicStatus } from './jukeboxService';

export function normTrackText(s: string): string {
  return s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
}

export function musicStatusTrackKey(status: MusicStatus): string {
  const stamp =
    status.timestamp != null && !Number.isNaN(status.timestamp.getTime())
      ? String(status.timestamp.getTime())
      : status.isPlaying
        ? 'live'
        : '';
  return `${status.trackName}\u241f${status.artistName}\u241f${stamp}\u241f${status.isPlaying ? '1' : '0'}`;
}

export function pickPreferredMusicStatus(
  lastfmStatus: MusicStatus | null,
  spotifyCurrent: MusicStatus | null,
): MusicStatus | null {
  if (spotifyCurrent?.isPlaying && spotifyCurrent.trackName) return spotifyCurrent;
  if (lastfmStatus && lastfmStatus.trackName) {
    if (
      spotifyCurrent?.trackName &&
      (spotifyCurrent.timestamp?.getTime() ?? 0) > (lastfmStatus.timestamp?.getTime() ?? 0)
    ) {
      return spotifyCurrent;
    }
    return lastfmStatus;
  }
  return spotifyCurrent?.trackName ? spotifyCurrent : null;
}

export function mergeRecentTracks(
  lastfmTracks: MusicStatus[],
  spotifyCurrent: MusicStatus | null,
  spotifyRecent: MusicStatus[],
  maxItems = 5,
): MusicStatus[] {
  const candidates: MusicStatus[] = [
    ...(spotifyCurrent?.isPlaying && spotifyCurrent.trackName ? [spotifyCurrent] : []),
    ...spotifyRecent.filter((t) => Boolean(t.trackName)),
    ...lastfmTracks.filter((t) => Boolean(t.trackName)),
  ];

  candidates.sort((a, b) => {
    if (a.isPlaying !== b.isPlaying) return a.isPlaying ? -1 : 1;
    return (b.timestamp?.getTime() ?? 0) - (a.timestamp?.getTime() ?? 0);
  });

  const out: MusicStatus[] = [];
  const seen = new Set<string>();
  for (const item of candidates) {
    const key = `${normTrackText(item.artistName)}|${normTrackText(item.trackName)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(item);
    if (out.length >= maxItems) break;
  }
  return out;
}
