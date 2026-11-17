// Port of lib/features/cinema/presentation/screens/video_player_screen_web.dart + cinema_video_sources.dart.
import { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { AppColors } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { NetflixColors } from './cinemaTypes';
import { fetchMediaDetails, fetchSeasonEpisodes, saveWatchProgress, type TvEpisode } from './tmdbService';

interface VideoSource {
  id: string;
  name: string;
  desc: string;
  sandboxSafe: boolean;
}

const PROXY_CINEMA_BASE = 'https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime';
const WRAPPER_BASE = 'https://everglow-1c6db.web.app/embed.html';

const CINEMA_SOURCES: VideoSource[] = [
  { id: 'everglow-shell', name: 'Celestia', desc: 'No ads — our player', sandboxSafe: true },
  { id: 'everglow-embed', name: 'Everglow', desc: 'No ads — Everglow player', sandboxSafe: true },
  { id: 'flux-cinesrc', name: 'CineSrc', desc: 'No ads, high quality, sometimes unstable', sandboxSafe: true },
];

function buildSourceUrl(
  source: VideoSource,
  opts: { mediaType: string; id: string; season: number; episode: number; startSeconds?: number; title?: string },
): string {
  const titleParam = opts.title?.trim() ? `&title=${encodeURIComponent(opts.title.trim())}` : '';
  let base: string;
  if (source.id === 'flux-cinesrc') {
    base =
      opts.mediaType === 'tv'
        ? `https://cinesrc.st/embed/tv/${opts.id}/${opts.season}/${opts.episode}`
        : `https://cinesrc.st/embed/movie/${opts.id}`;
  } else {
    const root = source.id === 'everglow-shell' ? WRAPPER_BASE : PROXY_CINEMA_BASE;
    base =
      opts.mediaType === 'tv'
        ? `${root}?source=cinema&type=tv&tmdbId=${opts.id}&s=${opts.season}&e=${opts.episode}${titleParam}`
        : `${root}?source=cinema&type=movie&tmdbId=${opts.id}${titleParam}`;
  }
  if (opts.startSeconds && opts.startSeconds > 0) {
    return `${base}${base.includes('?') ? '&' : '?'}start=${opts.startSeconds}`;
  }
  return base;
}

export function VideoPlayerPage() {
  const { id = '0' } = useParams();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const auth = useAuth();
  const stageRef = useRef<HTMLDivElement>(null);

  const tmdbId = Number(id) || 0;
  const mediaType = params.get('type') === 'tv' ? 'tv' : 'movie';
  const title = params.get('title') ?? '';
  const isAnime = params.get('anime') === 'true';
  const startSeconds = Number(params.get('start') ?? 0) || undefined;

  const [season, setSeason] = useState(Number(params.get('season') ?? 1) || 1);
  const [episode, setEpisode] = useState(Number(params.get('episode') ?? 1) || 1);
  const [selectedSource, setSelectedSource] = useState<VideoSource>(CINEMA_SOURCES[0]);
  const [episodes, setEpisodes] = useState<TvEpisode[]>([]);
  const [details, setDetails] = useState<Record<string, unknown> | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const accent = isAnime ? AppColors.deepRose : NetflixColors.accent;
  const srcUrl = buildSourceUrl(selectedSource, {
    mediaType,
    id: String(tmdbId),
    season,
    episode,
    startSeconds,
    title,
  });

  useEffect(() => {
    setIsLoading(true);
    let alive = true;
    void fetchMediaDetails(tmdbId, mediaType).then((d) => {
      if (alive) setDetails(d);
    });
    if (auth.currentUser) {
      void saveWatchProgress(
        {
          tmdbId,
          title: title || `Title #${tmdbId}`,
          mediaType,
          posterPath: params.get('poster') ?? '',
          backdropPath: '',
          year: '',
          isAnime,
          source: 'tmdb',
        },
        auth.currentUser,
        {
          season: mediaType === 'tv' ? season : undefined,
          episode: mediaType === 'tv' ? episode : undefined,
          timestamp: startSeconds,
        },
      );
    }
    return () => {
      alive = false;
    };
  }, [tmdbId, mediaType, season, episode]);

  useEffect(() => {
    if (mediaType !== 'tv') return;
    let alive = true;
    void fetchSeasonEpisodes(tmdbId, season).then((eps) => {
      if (alive) setEpisodes(eps);
    });
    return () => {
      alive = false;
    };
  }, [tmdbId, mediaType, season]);

  useEffect(() => {
    const onFs = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener('fullscreenchange', onFs);
    return () => document.removeEventListener('fullscreenchange', onFs);
  }, []);

  const toggleFullscreen = async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await stageRef.current?.requestFullscreen();
    } catch {
      setIsFullscreen((v) => !v);
    }
  };

  const seasons = Array.isArray(details?.seasons)
    ? (details.seasons as Array<{ season_number?: number; name?: string }>).filter((s) => (s.season_number ?? 0) > 0)
    : [{ season_number: 1, name: 'Season 1' }];

  return (
    <div
      style={{ position: 'fixed', inset: 0, background: '#000000', display: 'flex', flexDirection: 'column', overflowY: 'auto' }}
    >
      {!isFullscreen && (
        <header
          style={{
            height: 52,
            padding: '0 12px',
            background: '#0A0A0A',
            borderBottom: `1px solid ${NetflixColors.hairline}`,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            flexShrink: 0,
          }}
        >
          <button
            type="button"
            className="bare-button"
            aria-label="Back"
            onClick={() => (window.history.length > 1 ? navigate(-1) : navigate(isAnime ? '/anime' : '/cinema'))}
            style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            <Icon name="arrow_back" size={22} color="#FFFFFF" />
          </button>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div
              style={{
                ...AppTypography.outfitBold,
                fontSize: 14.5,
                color: '#FFFFFF',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {title ||
                (typeof details?.title === 'string' ? details.title : details?.name ? String(details.name) : `Title #${tmdbId}`)}
            </div>
            {mediaType === 'tv' && (
              <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: NetflixColors.textSecondary }}>
                {`Season ${season} • Episode ${episode}`}
              </div>
            )}
          </div>
          <button
            type="button"
            className="bare-button"
            aria-label="Fullscreen"
            onClick={() => void toggleFullscreen()}
            style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            <Icon name="fullscreen" size={22} color="#FFFFFF" />
          </button>
        </header>
      )}

      <div
        ref={stageRef}
        style={{
          position: 'relative',
          width: '100%',
          aspectRatio: isFullscreen ? undefined : '16 / 9',
          height: isFullscreen ? '100%' : undefined,
          maxHeight: isFullscreen ? '100vh' : '72vh',
          background: '#000000',
          flexShrink: 0,
        }}
      >
        <iframe
          key={srcUrl}
          src={srcUrl}
          title={title || 'Cinema Player'}
          allowFullScreen
          allow="autoplay; fullscreen; picture-in-picture; encrypted-media"
          sandbox={selectedSource.sandboxSafe ? 'allow-scripts allow-same-origin allow-forms allow-presentation' : undefined}
          onLoad={() => setIsLoading(false)}
          style={{ width: '100%', height: '100%', border: 'none', display: 'block' }}
        />
        {isLoading && (
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: 'rgba(0,0,0,0.6)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              pointerEvents: 'none',
            }}
          >
            <span style={{ ...AppTypography.outfitMedium, color: '#FFFFFF', fontSize: 13 }}>Loading stream…</span>
          </div>
        )}
      </div>

      <div
        style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 16, maxWidth: 980, width: '100%', margin: '0 auto' }}
      >
        <div>
          <div style={{ ...AppTypography.outfitHeading, fontSize: 12, color: NetflixColors.textSecondary, marginBottom: 8 }}>
            VIDEO SOURCE
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {CINEMA_SOURCES.map((s) => {
              const active = s.id === selectedSource.id;
              return (
                <button
                  key={s.id}
                  type="button"
                  className="bare-button"
                  onClick={() => setSelectedSource(s)}
                  style={{
                    padding: '8px 14px',
                    borderRadius: 8,
                    background: active ? accent : NetflixColors.surfaceElevated,
                    border: `1px solid ${active ? accent : NetflixColors.hairline}`,
                    ...AppTypography.outfitBold,
                    fontSize: 12.5,
                    color: '#FFFFFF',
                  }}
                >
                  {s.name}
                </button>
              );
            })}
          </div>
        </div>

        {mediaType === 'tv' && (
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
              <span style={{ ...AppTypography.outfitHeading, fontSize: 15, color: '#FFFFFF' }}>Episodes</span>
              {seasons.length > 1 && (
                <select
                  value={season}
                  onChange={(e) => {
                    setSeason(Number(e.target.value));
                    setEpisode(1);
                  }}
                  style={{
                    background: NetflixColors.surfaceElevated,
                    color: '#FFFFFF',
                    border: `1px solid ${NetflixColors.hairline}`,
                    borderRadius: 6,
                    padding: '5px 10px',
                    fontSize: 12.5,
                  }}
                >
                  {seasons.map((s) => (
                    <option key={s.season_number} value={s.season_number}>
                      {s.name ?? `Season ${s.season_number}`}
                    </option>
                  ))}
                </select>
              )}
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 8 }}>
              {episodes.map((ep) => {
                const active = ep.episodeNumber === episode;
                return (
                  <button
                    key={ep.id}
                    type="button"
                    className="bare-button"
                    onClick={() => setEpisode(ep.episodeNumber)}
                    style={{
                      padding: 12,
                      borderRadius: 8,
                      background: active ? accent : NetflixColors.surface,
                      border: `1px solid ${active ? accent : NetflixColors.hairline}`,
                      textAlign: 'left',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                    }}
                  >
                    <span style={{ ...AppTypography.outfitHeading, fontSize: 14, color: '#FFFFFF' }}>{ep.episodeNumber}</span>
                    <span
                      style={{
                        ...AppTypography.outfitMedium,
                        fontSize: 13,
                        color: '#FFFFFF',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {ep.name}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
