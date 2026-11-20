import type { MusicStatus } from './jukeboxService';

export function normTrackText(s: string): string {
  return s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
}

export function musicStatusToMap(status: MusicStatus): Record<string, unknown> {
  return {
    username: status.username,
    trackName: status.trackName,
    artistName: status.artistName,
    albumName: status.albumName,
    imageUrl: status.imageUrl,
    isPlaying: status.isPlaying,
    spotifyUrl: status.spotifyUrl,
    timestamp: status.timestamp ? status.timestamp.toISOString() : null,
    spotifyTrackId: status.spotifyTrackId ?? null,
    spotifyEmbedUrl: status.spotifyEmbedUrl ?? null,
    previewUrl: status.previewUrl ?? null,
  };
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
      !lastfmStatus.isPlaying &&
      spotifyCurrent?.trackName &&
      (spotifyCurrent.timestamp?.getTime() ?? 0) > (lastfmStatus.timestamp?.getTime() ?? 0)
    ) {
      return spotifyCurrent;
    }
    return lastfmStatus;
  }
  return spotifyCurrent?.trackName ? spotifyCurrent : null;
}

export function shouldSyncPartnerStatus(
  existing: MusicStatus | null,
  lastfmLatest: MusicStatus | null,
  nowMs = Date.now(),
): boolean {
  if (!lastfmLatest || !lastfmLatest.trackName) return false;
  if (!existing || !existing.trackName) return true;
  if (lastfmLatest.isPlaying) {
    return musicStatusTrackKey(existing) !== musicStatusTrackKey(lastfmLatest);
  }
  const existingMs = existing.timestamp?.getTime() ?? 0;
  const latestMs = lastfmLatest.timestamp?.getTime() ?? 0;
  if (existing.isPlaying && existingMs > 0 && nowMs - existingMs < 10 * 60_000) {
    return false;
  }
  return latestMs > existingMs;
}

export function mergeRecentTracks(
  lastfmTracks: MusicStatus[],
  spotifyCurrent: MusicStatus | null,
  spotifyRecent: MusicStatus[],
  maxItems = 5,
): MusicStatus[] {
  const candidates: MusicStatus[] = [
    ...(spotifyCurrent?.trackName ? [spotifyCurrent] : []),
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
