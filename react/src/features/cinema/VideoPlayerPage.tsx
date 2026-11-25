// Port of lib/features/cinema/presentation/screens/video_player_screen_web.dart and
// video_player_state_base.dart: the Cinema player page. The iframe (or the offline
// <video>) is built once and moved between hosts by hand, like Flutter's platform view.
import { useCallback, useEffect, useReducer, useState } from 'react';
import { useLocation, useNavigate, useParams, useSearchParams } from 'react-router';
import { authService } from '../../core/services/auth';
import { OfflineIds, offlineMedia, type OfflineMediaItem } from '../../core/services/offlineMedia';
import { Logger } from '../../core/system/logger';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { boxShadow, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { fetchAniZipTmdbId } from '../../shared/utils/catalogProxy';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { isEditableTarget, resolveEverglowPlayerKey } from '../../shared/widgets/everglowPlayerKeys';
import { Icon } from '../../shared/widgets/Icon';
import { OfflineVideoHud } from '../../shared/widgets/OfflineVideoHud';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { cinemaPreferences } from './cinemaPreferences';
import { NetflixColors, resumeSecondsOf, type MediaItem } from './cinemaTypes';
import { checkMovieStreamDuration, formatMinutesShort } from './movieDurationGuard';
import {
  buildVideoSourceUrl,
  decodeMessage,
  nextEpisodeLabel,
  parseEverglowHlsProgress,
  PlaybackProgressWriter,
  PlayerMemoryService,
  PROXY_CINEMA_ORIGIN,
  resolveNextEpisode,
  selectableSources,
  shouldAutoplayNext,
  trustsCinesrcEpisodeEvent,
  trustsCinesrcProgressEvent,
  videoSourcesRevision,
  VideoSourceService,
  type NextEpisode,
  type VideoSourceConfig,
} from './playerServices';
import { fetchMediaDetails, getSavedProgress, heartbeatProgress, isWatchedItem, updateProgress } from './tmdbService';
import {
  CinematicLoader,
  CompactViewingPreferences,
  EpisodeNavigator,
  PlayerIconButton,
  PlayerPillButton,
  playerDisplayTitle,
  PulsingDot,
  SheetDragHandle,
  TorrentDownloadSheet,
  UpNextOverlay,
} from './VideoPlayerWidgets';

interface PlayerProps {
  tmdbId: number;
  mediaType: string;
  season?: number;
  episode?: number;
  startSeconds?: number;
  title: string;
  isAnime: boolean;
  malId?: number;
  posterPath: string;
  allEpisodesWatched: boolean;
  currentEpisodeCompleted: boolean;
  originalLanguage?: string;
}

const intParam = (v: string | null) => {
  if (v == null) return undefined;
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? n : undefined;
};

/** The `/cinema/video/:id` route: reads the query like cinema_routes.dart. */
export function VideoPlayerPage() {
  const { id = '0' } = useParams();
  const [params] = useSearchParams();
  const location = useLocation();
  const props: PlayerProps = {
    tmdbId: intParam(id) ?? 0,
    mediaType: params.get('type') ?? 'movie',
    season: intParam(params.get('season')),
    episode: intParam(params.get('episode')),
    startSeconds: intParam(params.get('start')),
    title: params.get('title') ?? '',
    isAnime: params.get('anime') === 'true',
    malId: intParam(params.get('malId')),
    posterPath: params.get('poster') ?? '',
    allEpisodesWatched: params.get('watched') === 'true',
    currentEpisodeCompleted: params.get('completed') === 'true',
    originalLanguage: params.get('lang')?.trim().toLowerCase() || undefined,
  };
  return <VideoPlayerScreen key={location.pathname + location.search} {...props} />;
}

const LOAD_TIMEOUT = 15000;
const CONTENT_CHECK = 8000;
const CINESRC_CONTENT_CHECK = 14000;
const UP_NEXT_SECONDS = 10;

/** `parseEverglowEmbedScrollDelta`. */
function parseEmbedScrollDelta(data: unknown): number | null {
  const d = decodeMessage(data) as Record<string, unknown> | null;
  if (!d || typeof d !== 'object' || d.type !== 'everglow-embed-scroll') return null;
  const rawY = d.deltaY;
  if (typeof rawY !== 'number' || !Number.isFinite(rawY)) return null;
  const mode = typeof d.deltaMode === 'number' && Number.isFinite(d.deltaMode) ? Math.trunc(d.deltaMode) : 0;
  const dy = rawY * (mode === 1 ? 40 : mode === 2 ? 600 : 1);
  return dy === 0 || !Number.isFinite(dy) ? null : dy;
}

/** animex_videasy_progress.dart `parseVideasyProgress`. */
function parseVideasyProgress(origin: string, data: unknown): [number, number] | null {
  if (origin !== 'https://player.videasy.to' && origin !== 'https://player.videasy.net') return null;
  if (typeof data !== 'string') return null;
  const json = decodeMessage(data) as Record<string, unknown> | null;
  if (!json || typeof json !== 'object') return null;
  const position = json.timestamp;
  const duration = json.duration;
  if (typeof position !== 'number' || !Number.isFinite(position) || position < 0) return null;
  if (typeof duration !== 'number' || !Number.isFinite(duration) || duration <= 0 || position > duration) return null;
  return [Math.round(position), Math.round(duration)];
}

/** `_extractPlayback`: finds currentTime/position/time plus duration anywhere in a payload. */
function extractPlayback(value: unknown): [number, number] | null {
  if (Array.isArray(value)) {
    for (const child of value) {
      const found = extractPlayback(child);
      if (found) return found;
    }
    return null;
  }
  if (!value || typeof value !== 'object') return null;
  let position = -1;
  let duration = 0;
  for (const [key, child] of Object.entries(value)) {
    const name = key.replace(/_/g, '').toLowerCase();
    if (typeof child === 'number' && child >= 0) {
      if (name === 'currenttime' || name === 'position' || name === 'time') position = Math.round(child);
      else if (name === 'duration') duration = Math.round(child);
    }
  }
  if (position >= 0 && duration > 0) return [position, duration];
  for (const child of Object.values(value)) {
    const found = extractPlayback(child);
    if (found) return found;
  }
  return null;
}

const originOf = (url: string) => {
  try {
    return new URL(url).origin;
  } catch {
    return '';
  }
};

/** The page's mutable state and timers (Flutter's `_VideoPlayerScreenStateBase`). */
class PlayerController {
  p: PlayerProps;
  private rerender: () => void;
  mounted = true;

  isLoading = true;
  iframeFailed = false;
  readonly iframe: HTMLIFrameElement;
  private loadTimer: number | null = null;
  private contentCheckTimer: number | null = null;
  private readonly writer = new PlaybackProgressWriter();
  private restoreRevision = 0;
  private memoryRevision = 0;
  positionSeconds = 0;
  durationSeconds = 0;
  expectedRuntimeMinutes: number | null = null;
  durationWarning: { actualMinutes: number; expectedMinutes: number; providerId: string } | null = null;
  private durationWarningDismissed = false;

  nextEpisode: NextEpisode | null = null;
  upNextVisible = false;
  upNextLeft = UP_NEXT_SECONDS;
  private upNextTimer: number | null = null;
  private upNextDismissed = false;

  private hasSavedWatchProgress = false;
  currentEpisodeCompleted: boolean;
  currentSeason: number;
  currentEpisode: number;
  userName: string;

  selectedProvider: VideoSourceConfig;
  resolvedStartSeconds: number | undefined;
  private restoreDone: Promise<void> = Promise.resolve();
  private readonly failedProviderIds = new Set<string>();

  isFullscreen = false;
  hostHidden = false;
  private preFullscreenScroll = 0;
  scrollEl: HTMLDivElement | null = null;
  playerAreaHeight = 0;
  playerHost: HTMLDivElement | null = null;
  private video: HTMLVideoElement | null = null;
  private isOfflinePlayback = false;
  private exitButton: HTMLDivElement | null = null;
  private exitFadeTimer: number | null = null;
  private exitWakeListener: (() => void) | null = null;
  private bodyOverflowPrev: string | null = null;
  private externalTmdbId: number | undefined;
  private originalLanguage: string | undefined;
  private unsubscribers: Array<() => void> = [];
  onShowEpisodesSheet?: () => void;
  onShowProviderSheet?: () => void;

  get offlinePlayback() {
    return this.isOfflinePlayback;
  }

  get videoElement() {
    return this.video;
  }

  setHostHidden(hidden: boolean) {
    if (this.hostHidden === hidden) return;
    if (this.exitButton) this.exitButton.style.display = hidden ? 'none' : 'flex';
    this.setState(() => (this.hostHidden = hidden));
  }

  constructor(p: PlayerProps, rerender: () => void) {
    this.p = p;
    this.rerender = rerender;
    const list = this.selectableProviders;
    this.selectedProvider = list[0];
    this.resolvedStartSeconds = p.startSeconds;
    this.userName = authService.currentUser ?? '';
    this.currentSeason = p.season ?? 1;
    this.currentEpisode = p.episode ?? 1;
    this.currentEpisodeCompleted = p.currentEpisodeCompleted;
    this.positionSeconds = p.startSeconds ?? 0;
    this.originalLanguage = p.originalLanguage;

    const f = document.createElement('iframe');
    f.allow =
      'autoplay *; fullscreen *; encrypted-media *; picture-in-picture *; accelerometer *; gyroscope *; clipboard-write *';
    f.setAttribute('allowfullscreen', 'true');
    f.setAttribute('webkitallowfullscreen', 'true');
    f.setAttribute('mozallowfullscreen', 'true');
    f.setAttribute('referrerpolicy', 'no-referrer');
    f.setAttribute('frameborder', '0');
    f.setAttribute('scrolling', 'no');
    Object.assign(f.style, { border: '0', width: '100%', height: '100%', backgroundColor: '#000', display: 'block' });
    this.iframe = f;
  }

  private setState(fn?: () => void) {
    fn?.();
    if (this.mounted) this.rerender();
  }

  get selectableProviders(): VideoSourceConfig[] {
    return selectableSources(VideoSourceService.providers, this.p.isAnime);
  }

  private providerById(id: string) {
    return this.selectableProviders.find((p) => p.id === id) ?? null;
  }

  get externalId() {
    return this.p.isAnime ? (this.p.malId ?? this.p.tmdbId) : this.p.tmdbId;
  }

  private get activeTmdbId() {
    return this.p.isAnime ? this.externalTmdbId : this.p.tmdbId;
  }

  private get memoryKey() {
    return PlayerMemoryService.cinemaKey({ id: this.externalId, mediaType: this.p.mediaType, isAnime: this.p.isAnime });
  }

  buildPlayerUrl(provider: VideoSourceConfig) {
    const id = this.p.isAnime ? (this.activeTmdbId ?? this.externalId) : this.externalId;
    return buildVideoSourceUrl(provider, {
      mediaType: this.p.mediaType,
      id: String(id),
      season: this.currentSeason,
      episode: this.currentEpisode,
      startSeconds: this.resolvedStartSeconds,
      title: playerDisplayTitle(this.p.title),
      originalLanguage: this.originalLanguage,
    });
  }

  init() {
    offlineMedia.init();
    cinemaPreferences.setUser(this.userName);
    this.restoreDone = this.restorePlayerMemory();
    this.applySandbox(this.selectedProvider);
    const onLoad = () => {
      this.clearLoadTimer();
      this.setState(() => (this.isLoading = false));
      this.startContentCheck();
      this.saveWatchProgress();
      this.sendCinemaPlayerState();
    };
    const onError = () => this.onIframeLoadError();
    this.iframe.addEventListener('load', onLoad);
    this.iframe.addEventListener('error', onError);
    this.unsubscribers.push(() => {
      this.iframe.removeEventListener('load', onLoad);
      this.iframe.removeEventListener('error', onError);
    });
    if (!this.isOfflinePlayback) this.startLoadTimer();

    const onMessage = (e: MessageEvent) => this.onMessage(e);
    window.addEventListener('message', onMessage);
    const onKey = (e: KeyboardEvent) => this.onKey(e);
    document.addEventListener('keydown', onKey);
    this.unsubscribers.push(
      () => window.removeEventListener('message', onMessage),
      () => document.removeEventListener('keydown', onKey),
      cinemaPreferences.subscribe(() => this.onPreferencesChanged()),
      videoSourcesRevision.subscribe(() => this.onProvidersUpdated()),
    );
    const onHide = () => {
      if (document.visibilityState !== 'hidden') return;
      this.startProgressHeartbeat();
      this.persistPlayerMemory();
      void this.writer.flush();
    };
    document.addEventListener('visibilitychange', onHide);
    this.unsubscribers.push(() => document.removeEventListener('visibilitychange', onHide));

    void this.resolveNext();
    if (!this.isOfflinePlayback) {
      if (this.p.isAnime) void this.bootstrapAnime();
      else if (!this.originalLanguage && this.p.tmdbId > 0 && this.selectedProvider.id === 'everglow-embed') {
        void this.bootstrapCinema();
      } else {
        void this.resolveExpectedRuntime();
        this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
      }
    } else {
      void this.resolveExpectedRuntime();
    }
  }

  dispose() {
    this.mounted = false;
    this.clearUpNextTimer();
    this.startProgressHeartbeat();
    this.persistPlayerMemory();
    this.clearLoadTimer();
    this.clearContentCheck();
    void this.writer.flush();
    for (const u of this.unsubscribers) u();
    this.unsubscribers = [];
    if (this.isFullscreen) this.restoreHostStyle();
    this.setBodyOverflowHidden(false);
    this.hideExitButton();
    offlineMedia.flushPlaybackPosition();
    if (this.video) {
      this.video.pause();
      const prevSrc = this.video.src;
      this.video.removeAttribute('src');
      offlineMedia.revokeBlobUrl(prevSrc);
      this.video = null;
    }
    this.iframe.src = 'about:blank';
    this.iframe.remove();
  }

  private onProvidersUpdated() {
    if (!this.mounted) return;
    const list = this.selectableProviders;
    if (!list.length || !this.iframeFailed) return;
    this.failedProviderIds.clear();
    this.selectedProvider = list[0];
    this.setState(() => {
      this.iframeFailed = false;
      this.isLoading = true;
    });
    this.restartLoadTimer();
    this.applySandbox(this.selectedProvider);
    this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
  }

  // --- timers ---

  private clearLoadTimer() {
    if (this.loadTimer != null) clearTimeout(this.loadTimer);
    this.loadTimer = null;
  }

  private clearContentCheck() {
    if (this.contentCheckTimer != null) clearTimeout(this.contentCheckTimer);
    this.contentCheckTimer = null;
  }

  private clearUpNextTimer() {
    if (this.upNextTimer != null) clearInterval(this.upNextTimer);
    this.upNextTimer = null;
  }

  private startLoadTimer() {
    this.loadTimer = window.setTimeout(() => {
      if (this.mounted && this.isLoading) this.onIframeLoadError();
    }, LOAD_TIMEOUT);
  }

  private restartLoadTimer() {
    this.clearLoadTimer();
    this.clearContentCheck();
    this.startLoadTimer();
  }

  private startContentCheck() {
    const id = this.selectedProvider.id;
    const timeout =
      id === 'vidlink' ? CONTENT_CHECK : id === 'everglow-shell' || id === 'flux-cinesrc' ? CINESRC_CONTENT_CHECK : null;
    if (timeout == null) return;
    this.clearContentCheck();
    this.contentCheckTimer = window.setTimeout(() => {
      if (!this.mounted) return;
      if (this.selectedProvider.id === 'everglow-shell') this.failedProviderIds.add('flux-cinesrc');
      this.onIframeLoadError();
    }, timeout);
  }

  // --- host mounting ---

  private get currentDownloadId() {
    if (this.p.isAnime) return OfflineIds.animeEpisodeId(this.p.malId ?? this.p.tmdbId, this.currentEpisode);
    if (this.p.mediaType === 'tv') return OfflineIds.cinemaEpisodeId(this.p.tmdbId, this.currentSeason, this.currentEpisode);
    return OfflineIds.cinemaMovieId(this.p.tmdbId);
  }

  mountPlayerHost(host: HTMLDivElement) {
    this.playerHost = host;
    offlineMedia.init();
    const item = offlineMedia.getItem(this.currentDownloadId);
    if (item && item.status === 'completed') this.mountOfflineVideo(host, item);
    else this.mountOnlineIframe(host);
  }

  private mountOfflineVideo(host: HTMLDivElement, item: OfflineMediaItem) {
    this.clearLoadTimer();
    this.clearContentCheck();
    this.isOfflinePlayback = true;
    if (!this.video) {
      const v = document.createElement('video');
      v.controls = false;
      v.autoplay = true;
      Object.assign(v.style, { width: '100%', height: '100%', backgroundColor: '#000', display: 'block' });
      v.setAttribute('playsinline', 'true');
      v.setAttribute('webkit-playsinline', 'true');
      v.addEventListener('loadeddata', () => {
        this.setState(() => (this.isLoading = false));
        this.saveWatchProgress();
      });
      v.addEventListener('timeupdate', () => {
        if (!this.mounted || this.video !== v) return;
        const pos = Math.round(v.currentTime);
        const dur = Number.isFinite(v.duration) ? Math.round(v.duration) : 0;
        this.positionSeconds = pos;
        if (dur > 0) this.durationSeconds = dur;
        const current = offlineMedia.getItem(this.currentDownloadId);
        if (current) offlineMedia.updatePlaybackPosition(current.id, pos);
        this.saveWatchProgress();
      });
      v.addEventListener('ended', () => {
        if (this.mounted && this.p.mediaType === 'tv' && this.nextEpisode) this.playNextEpisode();
      });
      v.addEventListener('error', () => {
        this.setState(() => {
          this.isLoading = false;
          this.iframeFailed = true;
        });
      });
      v.addEventListener('wheel', (e) => {
        const dy = parseEmbedScrollDelta({ type: 'everglow-embed-scroll', deltaY: e.deltaY, deltaMode: e.deltaMode });
        if (dy != null) this.applyEmbedScroll(dy);
      });
      this.video = v;
    }
    const video = this.video;
    void offlineMedia.getPlayableUrl(item).then((url) => {
      if (!this.mounted || this.video !== video) {
        offlineMedia.revokeBlobUrl(url);
        return;
      }
      if (url) {
        const prevSrc = video.src;
        video.src = url;
        if (prevSrc && prevSrc !== url) offlineMedia.revokeBlobUrl(prevSrc);
        const start = this.resolvedStartSeconds ?? item.lastPositionSeconds ?? 0;
        if (start > 0) video.currentTime = start;
        void video.play().catch(() => undefined);
      } else {
        this.mountOnlineIframe(host);
        this.restartLoadTimer();
        if (this.p.isAnime) void this.bootstrapAnime();
        else if (!this.originalLanguage && this.p.tmdbId > 0 && this.selectedProvider.id === 'everglow-embed') {
          void this.bootstrapCinema();
        } else {
          this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
        }
      }
    });
    host.replaceChildren(video);
    this.setState();
  }

  private tryPlayOfflineEpisode(season: number, episode: number): boolean {
    const animeId = this.p.malId ?? this.p.tmdbId;
    const id = this.p.isAnime
      ? OfflineIds.animeEpisodeId(animeId, episode)
      : OfflineIds.cinemaEpisodeId(this.p.tmdbId, season, episode);
    const item = offlineMedia.getItem(id);
    if (item && item.status === 'completed' && this.playerHost) {
      this.currentSeason = season;
      this.currentEpisode = episode;
      this.mountOfflineVideo(this.playerHost, item);
      void this.resolveNext();
      this.persistPlayerMemory(true);
      return true;
    }
    if (this.isOfflinePlayback && this.playerHost) this.mountOnlineIframe(this.playerHost);
    return false;
  }

  private mountOnlineIframe(host: HTMLDivElement) {
    const wasOffline = this.isOfflinePlayback;
    this.isOfflinePlayback = false;
    this.video?.pause();
    if (this.iframe.parentElement !== host || host.childNodes.length !== 1) host.replaceChildren(this.iframe);
    if (wasOffline) this.setState();
  }

  private applySandbox(provider: VideoSourceConfig) {
    if (provider.sandboxSafe) {
      this.iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock');
    } else {
      this.iframe.removeAttribute('sandbox');
    }
  }

  setIframePointerEvents(on: boolean) {
    this.iframe.style.pointerEvents = on ? 'auto' : 'none';
  }

  // --- anime ---

  private async bootstrapCinema() {
    const startRev = this.restoreRevision;
    const detailsPromise = fetchMediaDetails(this.p.tmdbId, this.p.mediaType).catch((e) => {
      Logger.e('Cinema: metadata lookup failed', e);
      return null;
    });
    const details = await Promise.race([
      detailsPromise,
      new Promise<null>((resolve) => window.setTimeout(() => resolve(null), 1200)),
    ]);
    if (!this.mounted) return;
    const applyDetails = (d: Record<string, unknown> | null): boolean => {
      if (!d || !this.mounted) return false;
      let langAdded = false;
      const lang = typeof d.original_language === 'string' ? d.original_language.trim().toLowerCase() : '';
      if (lang && !this.originalLanguage) {
        this.originalLanguage = lang;
        langAdded = true;
      }
      if (this.p.mediaType === 'movie') {
        const rt = d.runtime;
        if (typeof rt === 'number' && Number.isFinite(rt) && rt > 0) {
          this.expectedRuntimeMinutes = rt;
          if (this.durationSeconds > 0) this.handleMovieDuration(this.durationSeconds);
        }
      }
      return langAdded;
    };
    if (details) {
      applyDetails(details);
    } else {
      void detailsPromise.then((d) => {
        if (!applyDetails(d)) return;
        if (
          !this.mounted ||
          this.isOfflinePlayback ||
          this.restoreRevision !== startRev ||
          this.selectedProvider.id !== 'everglow-embed'
        ) {
          return;
        }
        this.resolvedStartSeconds = this.positionSeconds || this.resolvedStartSeconds;
        this.restartLoadTimer();
        this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
      });
    }
    this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
  }

  private async bootstrapAnime() {
    const tmdbId = await fetchAniZipTmdbId(this.p.malId ?? this.p.tmdbId);
    if (!this.mounted) return;
    if (tmdbId == null) {
      this.setState(() => (this.iframeFailed = true));
      this.clearLoadTimer();
      return;
    }
    this.externalTmdbId = tmdbId;
    this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
    void this.resolveNext();
  }

  // --- provider switching ---

  private onIframeLoadError() {
    this.clearLoadTimer();
    this.clearContentCheck();
    if (!this.mounted) return;
    this.failedProviderIds.add(this.selectedProvider.id);
    this.tryNextProvider();
  }

  private tryNextProvider() {
    ++this.restoreRevision;
    this.resolvedStartSeconds = this.positionSeconds;
    this.cancelUpNext();
    this.durationSeconds = 0;
    this.durationWarning = null;
    this.durationWarningDismissed = false;
    const next = this.selectableProviders.find((p) => !this.failedProviderIds.has(p.id));
    if (next) {
      this.setState(() => {
        this.selectedProvider = next;
        this.isLoading = true;
        this.iframeFailed = false;
      });
      this.startLoadTimer();
      this.applySandbox(next);
      this.iframe.src = this.buildPlayerUrl(next);
    } else {
      this.setState(() => (this.iframeFailed = true));
    }
    this.syncExitButton();
  }

  selectProvider(provider: VideoSourceConfig, retry = false) {
    if (provider.id === this.selectedProvider.id && !retry) return;
    ++this.restoreRevision;
    this.resolvedStartSeconds = this.positionSeconds;
    this.cancelUpNext();
    this.failedProviderIds.clear();
    this.durationSeconds = 0;
    this.durationWarning = null;
    this.durationWarningDismissed = false;
    this.setState(() => {
      this.selectedProvider = provider;
      this.isLoading = true;
      this.iframeFailed = false;
    });
    this.restartLoadTimer();
    this.applySandbox(provider);
    if (!this.p.isAnime && !this.originalLanguage && this.p.tmdbId > 0 && provider.id === 'everglow-embed') {
      void this.bootstrapCinema();
    } else {
      this.iframe.src = this.buildPlayerUrl(provider);
    }
    this.persistPlayerMemory();
    this.syncExitButton();
  }

  get nextAlternativeProvider(): VideoSourceConfig | null {
    return (
      this.selectableProviders.find(
        (p) => p.id !== this.selectedProvider.id && !this.failedProviderIds.has(p.id),
      ) ??
      this.selectableProviders.find((p) => p.id !== this.selectedProvider.id) ??
      null
    );
  }

  dismissDurationWarning = () => {
    this.setState(() => {
      this.durationWarning = null;
      this.durationWarningDismissed = true;
    });
  };

  private async resolveExpectedRuntime() {
    if (this.p.mediaType !== 'movie' || this.p.isAnime || this.p.tmdbId <= 0) return;
    try {
      const details = await fetchMediaDetails(this.p.tmdbId, 'movie');
      if (!this.mounted) return;
      const rt = details?.runtime;
      if (typeof rt === 'number' && Number.isFinite(rt) && rt > 0) {
        this.expectedRuntimeMinutes = rt;
        if (this.durationSeconds > 0) this.handleMovieDuration(this.durationSeconds);
      }
    } catch (e) {
      Logger.e('Cinema: runtime lookup failed', e);
    }
  }

  private handleMovieDuration(durationSeconds: number): boolean {
    if (!this.mounted || this.isOfflinePlayback || this.p.mediaType !== 'movie' || this.p.isAnime) return false;
    const check = checkMovieStreamDuration(durationSeconds, this.expectedRuntimeMinutes);
    if (check.kind === 'ok') {
      if (this.durationWarning) this.setState(() => (this.durationWarning = null));
      return false;
    }
    if (check.kind === 'decoy') {
      const hasFallback = this.selectableProviders.some(
        (p) => p.id !== this.selectedProvider.id && !this.failedProviderIds.has(p.id),
      );
      if (hasFallback) {
        const prev = this.selectedProvider.name;
        Logger.e(
          `[VideoPlayerScreen] ${prev} returned a short clip (${check.actualMinutes}m vs expected ${check.expectedMinutes}m); failing over`,
        );
        showSnackBar(`${prev} returned a short clip — trying next server`, { duration: 3000 });
        if (this.selectedProvider.id === 'everglow-shell') this.failedProviderIds.add('flux-cinesrc');
        this.onIframeLoadError();
        return true;
      }
    }
    if (
      !this.durationWarningDismissed &&
      (this.durationWarning?.providerId !== this.selectedProvider.id ||
        this.durationWarning?.actualMinutes !== check.actualMinutes)
    ) {
      this.setState(() => {
        this.durationWarning = {
          actualMinutes: check.actualMinutes,
          expectedMinutes: check.expectedMinutes,
          providerId: this.selectedProvider.id,
        };
      });
    }
    return false;
  }

  // --- episodes ---

  private switchEpisode(season: number, episode: number) {
    ++this.restoreRevision;
    void this.writer.flush();
    this.resetUpNextForNewEpisode();
    this.positionSeconds = 0;
    this.durationSeconds = 0;
    this.setState(() => {
      this.currentSeason = season;
      this.currentEpisode = episode;
      this.currentEpisodeCompleted = false;
      this.isLoading = true;
      this.iframeFailed = false;
    });
    this.failedProviderIds.clear();
    this.clearLoadTimer();
    this.clearContentCheck();
    if (this.tryPlayOfflineEpisode(season, episode)) return;
    this.startLoadTimer();
    this.applySandbox(this.selectedProvider);
    this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
    void this.resolveNext();
    this.persistPlayerMemory(true);
  }

  onEpisodeChanged = (episode: number) => {
    if (episode !== this.currentEpisode) this.switchEpisode(this.currentSeason, episode);
  };

  onSeasonChanged = (season: number) => {
    if (season !== this.currentSeason) this.switchEpisode(season, 1);
  };

  private onPlayerEpisodeChanged(season: number, episode: number) {
    if (!this.mounted || this.p.mediaType !== 'tv' || this.p.isAnime) return;
    if (season <= 0 || episode <= 0) return;
    if (season === this.currentSeason && episode === this.currentEpisode) return;
    ++this.restoreRevision;
    void this.writer.flush();
    this.resetUpNextForNewEpisode();
    this.positionSeconds = 0;
    this.durationSeconds = 0;
    this.setState(() => {
      this.currentSeason = season;
      this.currentEpisode = episode;
      this.currentEpisodeCompleted = false;
    });
    this.saveWatchProgress();
    void this.resolveNext();
    this.persistPlayerMemory(true);
  }

  // --- progress ---

  private watchingStatus() {
    return this.userName === 'khentsgdz'
      ? 'watching-khent'
      : this.userName === 'clairjassen'
        ? 'watching-clair'
        : 'watching-self';
  }

  private saveWatchProgress() {
    if (this.hasSavedWatchProgress) return;
    this.hasSavedWatchProgress = true;
    void this.restoreDone.finally(() => this.writeWatchProgress());
  }

  private writeWatchProgress() {
    if (!this.mounted) return;
    const userName = this.userName || authService.currentUser || '';
    if (!userName) return;
    const status = this.watchingStatus();
    const tv = this.p.mediaType === 'tv';
    const item: MediaItem = {
      id: '',
      tmdbId: this.p.tmdbId,
      title: playerDisplayTitle(this.p.title),
      mediaType: this.p.mediaType,
      posterPath: this.p.posterPath,
      backdropPath: '',
      year: '',
      status,
      isAnime: this.p.isAnime,
      userName,
      addedAt: new Date(),
      source: this.p.isAnime ? 'jikan' : 'tmdb',
      synopsis: '',
      airingStatus: '',
      format: '',
      studio: '',
      genres: [],
      remindMe: false,
    };
    const opts = {
      season: tv ? this.currentSeason : undefined,
      episode: tv ? this.currentEpisode : undefined,
      timestamp: this.positionSeconds,
      durationSeconds: this.durationSeconds > 0 ? this.durationSeconds : undefined,
      status,
    };
    void this.writer.writeNow(() => updateProgress(item, userName, opts));
    this.persistPlayerMemory();
  }

  private startProgressHeartbeat() {
    if (!this.userName) return;
    const user = this.userName;
    const tv = this.p.mediaType === 'tv';
    const season = tv ? this.currentSeason : undefined;
    const episode = tv ? this.currentEpisode : undefined;
    const position = this.positionSeconds;
    const duration = this.durationSeconds > 0 ? this.durationSeconds : undefined;
    const provider = this.selectedProvider.id;
    const key = this.memoryKey;
    const memoryRevision = this.memoryRevision;
    this.writer.schedule(async () => {
      await heartbeatProgress(this.p.tmdbId, user, {
        source: this.p.isAnime ? 'jikan' : 'tmdb',
        mediaType: this.p.mediaType,
        season,
        episode,
        timestamp: position,
        durationSeconds: duration,
      });
      if (memoryRevision !== this.memoryRevision) return;
      if (
        season !== (tv ? this.currentSeason : undefined) ||
        episode !== (tv ? this.currentEpisode : undefined) ||
        provider !== this.selectedProvider.id ||
        key !== this.memoryKey
      ) {
        return;
      }
      PlayerMemoryService.save(key, { providerId: provider, season, episode, positionSeconds: position });
    });
  }

  private onPlaybackTick(position: number, duration: number) {
    if (!this.mounted) return;
    if (duration > 0 && this.handleMovieDuration(duration)) return;
    if (position !== this.positionSeconds || duration !== this.durationSeconds) {
      this.setState(() => {
        this.positionSeconds = position;
        this.durationSeconds = duration;
      });
      this.startProgressHeartbeat();
    }
    this.checkUpNext();
  }

  private onPreferencesChanged() {
    if (!this.mounted) return;
    if (!cinemaPreferences.value.autoplayNext && this.upNextVisible) this.cancelUpNext();
    this.setState();
    this.sendCinemaPlayerState();
  }

  // --- up next ---

  private async resolveNext() {
    if (this.p.mediaType !== 'tv') return;
    const tmdbId = this.p.isAnime ? this.activeTmdbId : this.p.tmdbId;
    if (tmdbId == null) return;
    const season = this.currentSeason;
    const episode = this.currentEpisode;
    let next: NextEpisode | null = null;
    try {
      next = await resolveNextEpisode(tmdbId, season, episode);
    } catch (e) {
      Logger.e('Cinema: next episode lookup failed', e);
    }
    if (!this.mounted || season !== this.currentSeason || episode !== this.currentEpisode) return;
    this.setState(() => (this.nextEpisode = next));
    this.checkUpNext();
    this.sendCinemaPlayerState();
  }

  private sendCinemaPlayerState() {
    if (this.isOfflinePlayback || this.selectedProvider.id !== 'everglow-embed' || this.isLoading) return;
    const displayTitle = playerDisplayTitle(this.p.title);
    const hudTitle =
      this.p.mediaType === 'tv' ? `${displayTitle} · S${this.currentSeason} E${this.currentEpisode}` : displayTitle;
    const next = this.nextEpisode;
    const rawPoster = this.p.posterPath.trim();
    const posterUrl = rawPoster.startsWith('https://')
      ? rawPoster
      : rawPoster.startsWith('/')
        ? `https://image.tmdb.org/t/p/w780${rawPoster}`
        : '';
    try {
      this.iframe.contentWindow?.postMessage(
        {
          type: 'animex-player-state',
          ...(next ? { next: `S${next.season} E${next.episode}`, nextKind: 'episode' } : {}),
          ...(this.p.mediaType === 'tv' && !this.p.isAnime ? { hasEpisodes: true } : {}),
          theater: this.isFullscreen,
          autoNext: cinemaPreferences.value.autoplayNext,
          ...(posterUrl ? { poster: posterUrl } : {}),
          ...(hudTitle.trim() ? { title: hudTitle.trim() } : {}),
        },
        PROXY_CINEMA_ORIGIN,
      );
    } catch {
      // Ignore transient detached iframe state before load settles.
    }
  }

  private checkUpNext() {
    if (this.p.mediaType !== 'tv' || !this.nextEpisode) return;
    const completed = shouldAutoplayNext({
      enabled: cinemaPreferences.value.autoplayNext,
      positionSeconds: this.positionSeconds,
      durationSeconds: this.durationSeconds,
    });
    if (this.upNextVisible) {
      if (!completed) {
        this.clearUpNextTimer();
        this.setState(() => (this.upNextVisible = false));
      }
      return;
    }
    if (this.upNextDismissed) return;
    if (completed) this.showUpNext();
  }

  get safeNextEpisode(): NextEpisode | null {
    const n = this.nextEpisode;
    if (!n) return null;
    return cinemaPreferences.value.hideSpoilers ? { season: n.season, episode: n.episode } : n;
  }

  private showUpNext() {
    if (this.upNextVisible || this.upNextDismissed || !this.nextEpisode || !this.mounted) return;
    this.setState(() => {
      this.upNextVisible = true;
      this.upNextLeft = UP_NEXT_SECONDS;
    });
    this.clearUpNextTimer();
    this.upNextTimer = window.setInterval(() => {
      if (!this.mounted || !cinemaPreferences.value.autoplayNext) {
        this.clearUpNextTimer();
        return;
      }
      // Hold the countdown while the tab is hidden so the next episode never
      // starts playing behind whatever Clair switched to.
      if (document.hidden) return;
      if (this.upNextLeft <= 1) {
        this.clearUpNextTimer();
        this.playNextEpisode();
        return;
      }
      this.setState(() => this.upNextLeft--);
    }, 1000);
  }

  cancelUpNext = () => {
    this.clearUpNextTimer();
    this.setState(() => {
      this.upNextVisible = false;
      this.upNextDismissed = true;
    });
  };

  playNextEpisode = () => {
    const next = this.nextEpisode;
    if (!next) return;
    ++this.restoreRevision;
    this.clearUpNextTimer();
    void this.writer.flush();
    this.hasSavedWatchProgress = false;
    this.resolvedStartSeconds = undefined;
    this.setState(() => {
      this.currentSeason = next.season;
      this.currentEpisode = next.episode;
      this.currentEpisodeCompleted = false;
      this.isLoading = true;
      this.iframeFailed = false;
      this.upNextVisible = false;
      this.upNextDismissed = false;
      this.nextEpisode = null;
      this.positionSeconds = 0;
      this.durationSeconds = 0;
    });
    this.failedProviderIds.clear();
    this.clearLoadTimer();
    this.clearContentCheck();
    if (this.tryPlayOfflineEpisode(next.season, next.episode)) return;
    this.startLoadTimer();
    this.applySandbox(this.selectedProvider);
    this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
    void this.resolveNext();
  };

  private resetUpNextForNewEpisode() {
    this.clearUpNextTimer();
    this.hasSavedWatchProgress = false;
    this.upNextVisible = false;
    this.upNextDismissed = false;
    this.nextEpisode = null;
    this.resolvedStartSeconds = undefined;
  }

  // --- memory ---

  private async restorePlayerMemory() {
    const revision = this.restoreRevision;
    const memory = PlayerMemoryService.load(this.memoryKey);
    const p = this.p;
    const routeNamedSpot = p.season != null || p.episode != null || p.startSeconds != null;
    const saved =
      routeNamedSpot || !this.userName
        ? null
        : await getSavedProgress(p.tmdbId, this.userName, { source: p.isAnime ? 'jikan' : 'tmdb', mediaType: p.mediaType });
    if (!this.mounted || revision !== this.restoreRevision) return;
    const live = saved == null || isWatchedItem(saved) ? null : saved;
    const cloudSeason = live?.currentSeason;
    const cloudEpisode = live?.currentEpisode;
    const cloudSeconds = live ? resumeSecondsOf(live) : null;
    let needsReload = false;

    let match = memory.providerId ? this.providerById(memory.providerId) : null;
    if (!match && !p.isAnime) {
      const savedId = VideoSourceService.loadDefaultSourceId();
      match = savedId ? this.providerById(savedId) : null;
    }
    if (match && !this.failedProviderIds.has(match.id) && match.id !== this.selectedProvider.id) {
      this.selectedProvider = match;
      this.applySandbox(match);
      needsReload = true;
    }

    const tv = p.mediaType === 'tv';
    const hasCloudEpisode = tv && cloudSeason != null && cloudSeason > 0 && cloudEpisode != null && cloudEpisode > 0;
    if (tv) {
      const season = hasCloudEpisode ? cloudSeason : memory.season;
      const episode = hasCloudEpisode ? cloudEpisode : memory.episode;
      if (p.season == null && season != null && season > 0) {
        if (season !== this.currentSeason) needsReload = true;
        this.currentSeason = season;
      }
      if (p.episode == null && episode != null && episode > 0) {
        if (episode !== this.currentEpisode) needsReload = true;
        this.currentEpisode = episode;
      }
    }
    const cloudSameEpisode = !tv
      ? live != null
      : hasCloudEpisode && cloudSeason === this.currentSeason && cloudEpisode === this.currentEpisode;
    const localSameEpisode = memory.season === this.currentSeason && memory.episode === this.currentEpisode;
    const resume =
      cloudSameEpisode && cloudSeconds != null ? cloudSeconds : localSameEpisode ? memory.positionSeconds : undefined;
    if (p.startSeconds == null && this.resolvedStartSeconds == null && resume != null && resume > 0) {
      this.resolvedStartSeconds = resume;
      this.positionSeconds = resume;
      needsReload = true;
    }
    if (!needsReload) return;
    this.setState();
    if (this.iframe.src && this.iframe.src !== 'about:blank') this.iframe.src = this.buildPlayerUrl(this.selectedProvider);
  }

  private persistPlayerMemory(resetPosition = false) {
    ++this.memoryRevision;
    const tv = this.p.mediaType === 'tv';
    PlayerMemoryService.save(this.memoryKey, {
      providerId: this.selectedProvider.id,
      season: tv ? this.currentSeason : undefined,
      episode: tv ? this.currentEpisode : undefined,
      positionSeconds: this.positionSeconds > 0 ? this.positionSeconds : undefined,
      clearPosition: resetPosition,
    });
  }

  // --- messages and keys ---

  private onMessage(e: MessageEvent) {
    try {
      const origin = e.origin;
      const data: unknown = e.data;
      if (data == null || e.source !== this.iframe.contentWindow) return;
      if (origin !== originOf(this.iframe.src)) return;
      const id = this.selectedProvider.id;
      const dy = parseEmbedScrollDelta(data);
      if (dy != null) {
        this.applyEmbedScroll(dy);
        return;
      }
      const obj = decodeMessage(data) as Record<string, unknown> | string | null;
      if (id === 'everglow-embed' && obj && typeof obj === 'object' && !Array.isArray(obj)) {
        const msg = obj as Record<string, unknown>;
        if (msg.type === 'animex-action') {
          const action = msg.action;
          if (action === 'next-episode') {
            if (this.mounted) this.playNextEpisode();
          } else if (action === 'episodes') {
            if (this.mounted && this.p.mediaType === 'tv' && !this.p.isAnime) this.onShowEpisodesSheet?.();
          } else if (action === 'exit-theater') {
            if (this.mounted && this.isFullscreen) this.toggleFullScreen();
          }
          return;
        }
        if (msg.type === 'animex-pref' && msg.key === 'autoNext' && typeof msg.value === 'boolean') {
          if (this.mounted) cinemaPreferences.setAutoplayNext(msg.value);
          return;
        }
      }
      if (
        (id === 'everglow-embed' || id === 'everglow-shell') &&
        (obj === 'animex-content-error' || (obj && typeof obj === 'object' && obj.type === 'everglow-embed-failed'))
      ) {
        if (id === 'everglow-shell') this.failedProviderIds.add('flux-cinesrc');
        this.onIframeLoadError();
        return;
      }
      const hls = parseEverglowHlsProgress(id, origin, data, this.p.mediaType === 'tv' ? this.currentEpisode : undefined);
      if (hls) {
        this.clearContentCheck();
        this.onPlaybackTick(hls[0], hls[1]);
        return;
      }
      const videasy = parseVideasyProgress(origin, data);
      if (videasy) {
        this.clearContentCheck();
        this.onPlaybackTick(videasy[0], videasy[1]);
        return;
      }
      const map = data && typeof data === 'object' && !Array.isArray(data) ? (data as Record<string, unknown>) : null;
      if (map?.type === 'cinesrc:nextepisode') {
        if (trustsCinesrcEpisodeEvent(id, origin)) {
          const season = typeof map.season === 'number' ? Math.trunc(map.season) : null;
          const episode = typeof map.episode === 'number' ? Math.trunc(map.episode) : null;
          if (season != null && episode != null && this.mounted) this.onPlayerEpisodeChanged(season, episode);
        }
        return;
      }
      if (map?.type === 'cinesrc:loadedmetadata' && trustsCinesrcProgressEvent(id, origin)) {
        const d = map.duration;
        if (typeof d === 'number' && Number.isFinite(d) && d > 0) {
          this.durationSeconds = Math.round(d);
          if (this.handleMovieDuration(this.durationSeconds)) return;
          this.clearContentCheck();
        }
        return;
      }
      if (map?.type === 'cinesrc:timeupdate') {
        const pos = map.currentTime;
        const dur = map.duration;
        if (
          trustsCinesrcProgressEvent(id, origin) &&
          typeof pos === 'number' &&
          typeof dur === 'number' &&
          Number.isFinite(pos) &&
          Number.isFinite(dur) &&
          pos >= 0 &&
          dur > 0 &&
          pos <= dur
        ) {
          const ps = Math.round(pos);
          const ds = Math.round(dur);
          if (ds > 0 && ps <= ds) {
            this.clearContentCheck();
            this.onPlaybackTick(ps, ds);
          }
        }
        return;
      }
      const cfg = this.providerById(id);
      if (!cfg || origin !== originOf(cfg.movieUrl)) return;
      if (!map) return;
      if (map.type === 'MEDIA_DATA' || map.type === 'PLAYER_EVENT') {
        this.clearContentCheck();
        const playback = extractPlayback(map);
        if (playback && this.mounted) this.onPlaybackTick(playback[0], playback[1]);
      }
    } catch (err) {
      Logger.e('[VideoPlayerScreen] Cross-origin postMessage parse error', err);
    }
  }

  private onKey(event: KeyboardEvent) {
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    const raw = event.key;
    if (this.isFullscreen && (raw === 'Escape' || raw === 'GoBack' || raw === 'BrowserBack')) {
      this.toggleFullScreen();
      event.preventDefault();
      return;
    }
    if (this.isOfflinePlayback || this.selectedProvider.id !== 'everglow-embed') return;
    if (this.scrollEl && this.playerAreaHeight > 0 && this.scrollEl.scrollTop > this.playerAreaHeight) return;
    if (isEditableTarget(event.target)) return;
    const key = resolveEverglowPlayerKey(raw);
    if (!key) return;
    try {
      this.iframe.contentWindow?.postMessage({ type: 'everglow-key', key }, PROXY_CINEMA_ORIGIN);
      event.preventDefault();
    } catch {
      // A detached frame drops the key.
    }
  }

  private applyEmbedScroll(dy: number) {
    if (!this.mounted || this.isFullscreen || document.fullscreenElement != null) return;
    const el = this.scrollEl;
    if (!el) return;
    const max = el.scrollHeight - el.clientHeight;
    const next = Math.min(max, Math.max(0, el.scrollTop + dy));
    if (next !== el.scrollTop) el.scrollTop = next;
  }

  // --- theater mode ---

  toggleFullScreen = () => {
    const entering = !this.isFullscreen;
    if (entering) {
      this.preFullscreenScroll = this.scrollEl?.scrollTop ?? 0;
      if (this.scrollEl) this.scrollEl.scrollTop = 0;
      this.setState(() => (this.isFullscreen = true));
      this.animateTheaterTransition();
      if (this.selectedProvider.id !== 'everglow-embed' || this.isOfflinePlayback) {
        this.showExitButton();
      } else {
        this.hideExitButton();
      }
      this.sendCinemaPlayerState();
      this.setBodyOverflowHidden(true);
    } else {
      this.restoreHostStyle();
      this.setState(() => (this.isFullscreen = false));
      this.animateTheaterTransition();
      const saved = this.preFullscreenScroll;
      requestAnimationFrame(() => {
        if (!this.mounted || this.isFullscreen || !this.scrollEl || saved <= 0) return;
        this.scrollEl.scrollTop = saved;
      });
      this.hideExitButton();
      this.sendCinemaPlayerState();
      this.setBodyOverflowHidden(false);
    }
  };

  private animateTheaterTransition() {
    const host = this.playerHost;
    if (!host) return;
    Object.assign(host.style, {
      transition: 'opacity 0.22s cubic-bezier(0.22, 1, 0.36, 1), transform 0.22s cubic-bezier(0.22, 1, 0.36, 1)',
      opacity: '0.88',
      transform: 'scale(0.985)',
    });
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        if (!this.mounted) return;
        host.style.opacity = '1';
        host.style.transform = 'scale(1)';
      }),
    );
  }

  private restoreHostStyle() {
    // The fixed theater box is drawn from React state; nothing extra to undo.
  }

  private setBodyOverflowHidden(hidden: boolean) {
    const body = document.body;
    if (hidden) {
      this.bodyOverflowPrev ??= body.style.overflow;
      body.style.overflow = 'hidden';
    } else {
      body.style.overflow = this.bodyOverflowPrev ?? '';
      this.bodyOverflowPrev = null;
    }
  }

  private syncExitButton() {
    if (!this.isFullscreen) {
      this.hideExitButton();
    } else if (this.selectedProvider.id !== 'everglow-embed' || this.isOfflinePlayback) {
      this.showExitButton();
    } else {
      this.hideExitButton();
    }
  }

  private showExitButton() {
    if (this.exitButton) return;
    const bar = document.createElement('div');
    Object.assign(bar.style, {
      position: 'fixed',
      top: 'calc(10px + env(safe-area-inset-top, 0px))',
      left: '50%',
      transform: 'translateX(-50%)',
      zIndex: '10000',
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      transition: 'opacity 0.25s ease',
    });
    const pillStyle = {
      padding: '8px 14px',
      background: this.p.isAnime ? 'rgba(20, 14, 28, 0.88)' : 'rgba(12, 12, 14, 0.88)',
      border: '1px solid rgba(255, 255, 255, 0.28)',
      borderRadius: '999px',
      boxShadow: '0 6px 22px rgba(0, 0, 0, 0.5)',
      cursor: 'pointer',
      color: '#FFFFFF',
      fontSize: '13px',
      fontWeight: '700',
      fontFamily: 'system-ui, sans-serif',
      userSelect: 'none',
      whiteSpace: 'nowrap',
    };
    if (!this.isOfflinePlayback) {
      const sv = document.createElement('button');
      sv.type = 'button';
      sv.textContent = 'Switch server';
      sv.setAttribute('aria-label', 'Switch server');
      Object.assign(sv.style, pillStyle);
      sv.addEventListener('click', () => this.onShowProviderSheet?.());
      bar.appendChild(sv);
    }
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = 'Exit theater';
    b.setAttribute('aria-label', 'Exit theater');
    Object.assign(b.style, pillStyle);
    b.addEventListener('click', () => this.toggleFullScreen());
    bar.appendChild(b);
    document.body.appendChild(bar);
    this.exitButton = bar;

    const wakeExitButton = () => {
      const btn = this.exitButton;
      if (!btn) return;
      btn.style.opacity = '1';
      btn.style.pointerEvents = 'auto';
      if (this.exitFadeTimer != null) window.clearTimeout(this.exitFadeTimer);
      this.exitFadeTimer = window.setTimeout(() => {
        if (this.exitButton === btn) {
          btn.style.opacity = '0';
          btn.style.pointerEvents = 'none';
        }
      }, 3000);
    };

    this.exitWakeListener = wakeExitButton;
    window.addEventListener('mousemove', wakeExitButton, { passive: true });
    window.addEventListener('touchstart', wakeExitButton, { passive: true });
    window.addEventListener('keydown', wakeExitButton);
    wakeExitButton();
  }

  private hideExitButton() {
    if (this.exitFadeTimer != null) {
      window.clearTimeout(this.exitFadeTimer);
      this.exitFadeTimer = null;
    }
    if (this.exitWakeListener) {
      window.removeEventListener('mousemove', this.exitWakeListener);
      window.removeEventListener('touchstart', this.exitWakeListener);
      window.removeEventListener('keydown', this.exitWakeListener);
      this.exitWakeListener = null;
    }
    this.exitButton?.remove();
    this.exitButton = null;
  }
}

function VideoPlayerScreen(props: PlayerProps) {
  const [, bump] = useReducer((x: number) => x + 1, 0);
  const [c] = useState(() => new PlayerController(props, bump));
  const navigate = useNavigate();
  const { width, height } = useViewport();
  useValue(videoSourcesRevision);

  useEffect(() => {
    c.mounted = true;
    c.init();
    return () => c.dispose();
  }, [c]);

  const hostRef = useCallback(
    (el: HTMLDivElement | null) => {
      if (el) c.mountPlayerHost(el);
    },
    [c],
  );
  const scrollRef = useCallback(
    (el: HTMLDivElement | null) => {
      c.scrollEl = el;
    },
    [c],
  );

  const full = c.isFullscreen;
  const compact = width < 560;
  const title = playerDisplayTitle(props.title);
  const isTv = props.mediaType === 'tv';
  const accent = props.isAnime ? AppColors.deepRose : NetflixColors.accent;
  const secondary = props.isAnime ? AppColors.softLavender : NetflixColors.textSecondary;
  const surface = props.isAnime ? AppColors.inkDeep : NetflixColors.surface;
  const surfaceElevated = props.isAnime ? Derived.surfaceGlass : NetflixColors.surfaceElevated;
  const hairline = props.isAnime ? Derived.border : NetflixColors.hairline;

  const maxPlayerHeight = full ? height : Math.max(240, height - 296);
  c.playerAreaHeight = Math.min(maxPlayerHeight, (width * 9) / 16);

  const goBack = () => {
    if (window.history.length > 1) navigate(-1);
    else void navigate('/cinema');
  };

  const showDownloadSheet = () => {
    c.setIframePointerEvents(false);
    void showModalBottomSheet<void>((close) => (
      <TorrentDownloadSheet
        tmdbId={props.tmdbId}
        mediaType={props.mediaType}
        title={title}
        season={isTv ? c.currentSeason : undefined}
        episode={isTv ? c.currentEpisode : undefined}
        close={() => close(null)}
      />
    )).then(() => c.mounted && c.setIframePointerEvents(true));
  };

  const showEpisodesSheet = () => {
    if (!c.mounted || !isTv || props.isAnime) return;
    if (document.fullscreenElement != null) void document.exitFullscreen().catch(() => undefined);
    const wasFullscreen = c.isFullscreen;
    c.setIframePointerEvents(false);
    if (wasFullscreen) c.setHostHidden(true);
    void showModalBottomSheet<void>((close) => (
      <div style={{ maxWidth: 640, margin: '0 auto' }}>
        <div
          style={{
            background: surface,
            borderRadius: `${AppRadius.x2}px ${AppRadius.x2}px 0 0`,
            maxHeight: 'calc(92dvh - env(safe-area-inset-top, 0px))',
            overflowY: 'auto',
            paddingBottom: 'env(safe-area-inset-bottom, 0px)',
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <SheetDragHandle />
            <div style={{ height: 10 }} />
            <div style={{ width: 40, height: 4, borderRadius: AppRadius.full, background: hairline }} />
          </div>
          <EpisodeNavigator
            key={`sheet-ep-${c.currentSeason}-${c.currentEpisode}`}
            tmdbId={props.tmdbId}
            initialSeason={c.currentSeason}
            initialEpisode={c.currentEpisode}
            title={props.title}
            positionSeconds={c.positionSeconds}
            durationSeconds={c.durationSeconds}
            allEpisodesWatched={props.allEpisodesWatched}
            currentEpisodeCompleted={c.currentEpisodeCompleted}
            initiallyExpanded={true}
            onSeasonChanged={c.onSeasonChanged}
            onEpisodeChanged={(ep) => {
              close(null);
              c.onEpisodeChanged(ep);
            }}
          />
        </div>
      </div>
    )).then(() => {
      if (!c.mounted) return;
      c.setIframePointerEvents(true);
      if (wasFullscreen) c.setHostHidden(false);
    });
  };
  c.onShowEpisodesSheet = showEpisodesSheet;

  const showProviderSheet = () => {
    if (!c.mounted) return;
    if (document.fullscreenElement != null) void document.exitFullscreen().catch(() => undefined);
    const wasFullscreen = c.isFullscreen;
    c.setIframePointerEvents(false);
    if (wasFullscreen) c.setHostHidden(true);
    void showModalBottomSheet<VideoSourceConfig>((close) => (
      <ProviderSheet
        providers={c.selectableProviders}
        selectedId={c.selectedProvider.id}
        accent={accent}
        secondary={secondary}
        surface={surface}
        surfaceElevated={surfaceElevated}
        hairline={hairline}
        onPick={(p) => close(p)}
      />
    )).then((provider) => {
      if (!c.mounted) return;
      c.setIframePointerEvents(true);
      if (wasFullscreen) c.setHostHidden(false);
      if (provider) c.selectProvider(provider);
    });
  };
  c.onShowProviderSheet = showProviderSheet;

  const metaBadge = (icon: string, label: string) => (
    <div
      style={{
        padding: '5px 10px',
        background: surfaceElevated,
        borderRadius: AppRadius.xs,
        border: `1px solid ${hairline}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={icon} size={13} color={secondary} />
      <div style={{ width: 5 }} />
      <span style={{ ...AppTypography.outfitHeading, color: secondary, fontSize: 11, lineHeight: lineHeight(11) }}>{label}</span>
    </div>
  );

  const upNext = c.safeNextEpisode;
  const hostStyle: React.CSSProperties = full
    ? {
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100vw',
        height: '100dvh',
        zIndex: 9999,
        overflow: 'hidden',
        background: '#000',
        visibility: c.hostHidden ? 'hidden' : 'visible',
      }
    : { position: 'absolute', inset: 0 };

  return (
    <div
      style={{
        height: '100dvh',
        background: '#000',
        display: 'flex',
        flexDirection: 'column',
        boxSizing: 'border-box',
        padding: full
          ? 0
          : 'env(safe-area-inset-top, 0px) env(safe-area-inset-right, 0px) env(safe-area-inset-bottom, 0px) env(safe-area-inset-left, 0px)',
      }}
    >
      {!full && (
        <div
          style={{
            height: 56,
            flexShrink: 0,
            boxSizing: 'border-box',
            padding: `8px ${compact ? 10 : 16}px`,
            background: surface,
            borderBottom: `1px solid ${hairline}`,
            boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.35)', blur: 18, offset: [0, 6] }]),
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <PlayerPillButton icon="arrow_back_ios_new" label="Back" compact={compact} onTap={goBack} />
          <div style={{ width: compact ? 8 : 14, flexShrink: 0 }} />
          <div
            style={{
              flex: 1,
              minWidth: 0,
              ...AppTypography.cormorantSemiBoldWhite,
              fontSize: compact ? 15 : 18,
              lineHeight: lineHeight(compact ? 15 : 18),
              letterSpacing: 0.3,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {title}
          </div>
          <div style={{ width: compact ? 8 : 12, flexShrink: 0 }} />
          {!c.offlinePlayback && (
            <>
              <Tooltip message="Switch server">
                <PlayerPillButton
                  icon="swap_horiz"
                  label={compact ? 'Source' : `Source · ${c.selectedProvider.shortName}`}
                  compact={compact}
                  onTap={showProviderSheet}
                />
              </Tooltip>
              <div style={{ width: compact ? 6 : 8, flexShrink: 0 }} />
            </>
          )}
          <Tooltip message="Download">
            {compact ? (
              <PlayerIconButton icon="download" compact onTap={showDownloadSheet} />
            ) : (
              <PlayerPillButton icon="download" label="Download" onTap={showDownloadSheet} />
            )}
          </Tooltip>
          <div style={{ width: compact ? 6 : 8, flexShrink: 0 }} />
          <Tooltip message="Theater mode">
            <PlayerIconButton icon="fullscreen" compact={compact} onTap={c.toggleFullScreen} />
          </Tooltip>
        </div>
      )}
      <div ref={scrollRef} style={{ flex: 1, minHeight: 0, overflowY: full ? 'hidden' : 'auto', overflowX: 'hidden' }}>
        {c.iframeFailed ? (
          <div style={{ maxHeight: maxPlayerHeight, overflow: 'hidden' }}>
            <ErrorCard
              active={c.selectedProvider}
              others={c.selectableProviders.filter((p) => p.id !== c.selectedProvider.id)}
              accent={accent}
              secondary={secondary}
              onRetry={() => c.selectProvider(c.selectedProvider, true)}
              onPick={(p) => c.selectProvider(p)}
              openUrl={() => c.buildPlayerUrl(c.selectedProvider)}
            />
          </div>
        ) : (
          <div style={{ height: full ? height : c.playerAreaHeight, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div
              style={{
                position: 'relative',
                width: Math.min(width, (maxPlayerHeight * 16) / 9),
                aspectRatio: '16 / 9',
                maxHeight: '100%',
                background: '#000',
              }}
            >
              <div style={hostStyle}>
                <div ref={hostRef} style={{ position: 'absolute', inset: 0 }} />
                {c.offlinePlayback && !c.isLoading && c.videoElement && (
                  <OfflineVideoHud
                    video={c.videoElement}
                    host={c.playerHost}
                    title={isTv ? `${title} · S${c.currentSeason} E${c.currentEpisode}` : title}
                    nextLabel={upNext ? `Next: ${nextEpisodeLabel(upNext)}` : undefined}
                    onNextEpisode={isTv && c.nextEpisode ? c.playNextEpisode : undefined}
                    onShowEpisodes={isTv && !props.isAnime ? showEpisodesSheet : undefined}
                    accentColor={accent}
                  />
                )}
              </div>
              {c.isLoading && <CinematicLoader providerName={c.selectedProvider.shortName} resumeAt={c.resolvedStartSeconds ?? c.positionSeconds} />}
              {!c.isLoading &&
                !c.iframeFailed &&
                c.upNextVisible &&
                isTv &&
                upNext &&
                !c.offlinePlayback &&
                c.selectedProvider.id !== 'everglow-embed' && (
                  <div style={{ position: 'absolute', right: 12, bottom: 68 }}>
                    <UpNextOverlay
                      next={upNext}
                      secondsLeft={c.upNextLeft}
                      totalSeconds={UP_NEXT_SECONDS}
                      onPlayNow={c.playNextEpisode}
                      onCancel={c.cancelUpNext}
                    />
                  </div>
                )}
            </div>
          </div>
        )}
        <div hidden={full}>
          {isTv && !props.isAnime && (
            <EpisodeNavigator
              key={`ep-nav-${c.currentSeason}-${c.currentEpisode}`}
              tmdbId={props.tmdbId}
              initialSeason={c.currentSeason}
              initialEpisode={c.currentEpisode}
              title={props.title}
              positionSeconds={c.positionSeconds}
              durationSeconds={c.durationSeconds}
              allEpisodesWatched={props.allEpisodesWatched}
              currentEpisodeCompleted={c.currentEpisodeCompleted}
              onSeasonChanged={c.onSeasonChanged}
              onEpisodeChanged={c.onEpisodeChanged}
            />
          )}
          {isTv && <CompactViewingPreferences />}
          {c.durationWarning && (
            <div style={{ padding: '12px 20px 0' }}>
              <div
                role="status"
                style={{
                  padding: '10px 12px',
                  borderRadius: AppRadius.x2,
                  background: withAlpha(accent, 0.14),
                  border: `1px solid ${withAlpha(accent, 0.45)}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  flexWrap: 'wrap',
                }}
              >
                <Icon name="warning_amber" size={18} color={accent} />
                <div style={{ flex: '1 1 180px', minWidth: 0 }}>
                  <div style={{ ...AppTypography.outfitHeading, color: '#fff', fontSize: 12, lineHeight: lineHeight(12) }}>
                    This stream is {formatMinutesShort(c.durationWarning.actualMinutes)} (expected ~
                    {formatMinutesShort(c.durationWarning.expectedMinutes)}) — it may be the wrong movie.
                  </div>
                </div>
                <button
                  type="button"
                  className="bare-button player-focusable"
                  onClick={() => {
                    const alt = c.nextAlternativeProvider;
                    if (alt) c.selectProvider(alt);
                    else showProviderSheet();
                  }}
                  style={{
                    padding: '6px 12px',
                    borderRadius: AppRadius.full,
                    background: accent,
                    color: '#fff',
                    cursor: 'pointer',
                    ...AppTypography.outfitBold,
                    fontSize: 11,
                    lineHeight: lineHeight(11),
                  }}
                >
                  {c.nextAlternativeProvider ? `Try ${c.nextAlternativeProvider.name}` : 'Switch server'}
                </button>
                <button
                  type="button"
                  className="bare-button player-focusable"
                  aria-label="Dismiss stream warning"
                  onClick={c.dismissDurationWarning}
                  style={{ display: 'flex', padding: 4, cursor: 'pointer', color: secondary }}
                >
                  <Icon name="close" size={16} color={secondary} />
                </button>
              </div>
            </div>
          )}
          <div style={{ padding: '16px 20px 0' }}>
            {/* One way to change the source, in the top bar. This row only says
                which one is playing. */}
            <div
              data-testid="player-source"
              style={{
                borderRadius: AppRadius.x2,
                background: surfaceElevated,
                border: `1px solid ${hairline}`,
              }}
            >
              <div
                style={{
                  padding: `${compact ? 8 : 12}px 8px ${compact ? 8 : 12}px ${compact ? 12 : 16}px`,
                  background: surface,
                  borderRadius: AppRadius.x2,
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <PulsingDot />
                <div style={{ width: 12, flexShrink: 0 }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ ...AppTypography.outfitHeading, fontSize: 13, lineHeight: lineHeight(13), letterSpacing: 0.2 }}>
                    {c.selectedProvider.name}
                  </div>
                  {(!compact || c.selectedProvider.id !== 'everglow-embed') && (
                    <>
                      <div style={{ height: 2 }} />
                      <div style={{ ...AppTypography.outfitWhite, color: secondary, fontSize: 11, lineHeight: lineHeight(11) }}>
                        {c.selectedProvider.desc}
                      </div>
                    </>
                  )}
                </div>
                <div style={{ width: 8, flexShrink: 0 }} />
              </div>
            </div>
          </div>
          <div style={{ padding: '16px 20px 0', display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {metaBadge(isTv ? 'tv' : 'movie', isTv ? 'TV Show' : 'Movie')}
            {isTv && metaBadge('layers', `S${c.currentSeason} E${c.currentEpisode}`)}
          </div>
          <div style={{ height: 40 }} />
        </div>
      </div>
    </div>
  );
}

function ProviderSheet({
  providers,
  selectedId,
  accent,
  secondary,
  surface,
  surfaceElevated,
  hairline,
  onPick,
}: {
  providers: VideoSourceConfig[];
  selectedId: string;
  accent: string;
  secondary: string;
  surface: string;
  surfaceElevated: string;
  hairline: string;
  onPick: (p: VideoSourceConfig) => void;
}) {
  return (
    <div style={{ maxWidth: 640, margin: '0 auto' }}>
      <div
        style={{
          background: surface,
          borderRadius: `${AppRadius.x2}px ${AppRadius.x2}px 0 0`,
          maxHeight: 'calc(100dvh - env(safe-area-inset-top, 0px))',
          overflowY: 'auto',
          paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <SheetDragHandle />
          <div style={{ height: 10 }} />
          <div style={{ width: 40, height: 4, borderRadius: AppRadius.full, background: hairline }} />
          <div style={{ height: 18 }} />
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: '50%',
              background: accent,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="swap_horiz" size={22} color="#fff" />
          </div>
          <div style={{ height: 12 }} />
          <div style={{ ...AppTypography.outfitWhite, color: '#fff', fontSize: 17, fontWeight: 700, lineHeight: lineHeight(17) }}>
            Switch Provider
          </div>
          <div style={{ height: 4 }} />
          <div
            style={{ ...AppTypography.outfitMuted, color: 'rgba(255,255,255,0.54)', fontSize: 12, lineHeight: lineHeight(12) }}
          >
            Wrong movie or won't play? Try another server
          </div>
          <div style={{ height: 16 }} />
          <div style={{ alignSelf: 'stretch', padding: '0 16px' }}>
            {providers.map((p) => {
              const on = p.id === selectedId;
              return (
                <div key={p.id} style={{ paddingBottom: 10 }}>
                  <div
                    role="button"
                    onClick={() => onPick(p)}
                    style={{
                      padding: '12px 14px',
                      background: on ? withAlpha(accent, 0.12) : surfaceElevated,
                      borderRadius: AppRadius.sm,
                      border: `1px solid ${on ? withAlpha(accent, 0.65) : hairline}`,
                      display: 'flex',
                      alignItems: 'center',
                      cursor: 'pointer',
                    }}
                  >
                    <div
                      style={{
                        width: 30,
                        height: 30,
                        flexShrink: 0,
                        borderRadius: '50%',
                        background: on ? withAlpha(accent, 0.16) : withAlpha(hairline, 0.35),
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Icon name={on ? 'check' : 'live_tv'} size={16} color={on ? accent : secondary} />
                    </div>
                    <div style={{ width: 12, flexShrink: 0 }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div
                        style={{
                          ...AppTypography.outfitWhite,
                          color: '#fff',
                          fontSize: 14,
                          fontWeight: 700,
                          lineHeight: lineHeight(14),
                        }}
                      >
                        {p.name}
                      </div>
                      <div style={{ height: 2 }} />
                      <div
                        style={{
                          ...AppTypography.outfitMuted,
                          color: 'rgba(255,255,255,0.54)',
                          fontSize: 11,
                          lineHeight: lineHeight(11),
                        }}
                      >
                        {p.desc}
                      </div>
                    </div>
                    {on ? (
                      <Icon name="radio_button_checked" variant="filled" size={18} color={accent} />
                    ) : (
                      <Tooltip message="Set as default source">
                        <button
                          type="button"
                          className="bare-button player-focusable"
                          aria-label="Set as default source"
                          onClick={(e) => {
                            e.stopPropagation();
                            VideoSourceService.saveDefaultSourceId(p.id);
                            showSnackBar(`${p.name} set as default`, { background: accent, duration: 2000 });
                          }}
                          style={{ display: 'flex', padding: 4, borderRadius: 6 }}
                        >
                          <Icon name="star_border" size={20} color="rgba(255,255,255,0.38)" />
                        </button>
                      </Tooltip>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
          <div style={{ height: 12 }} />
        </div>
      </div>
    </div>
  );
}

function ErrorCard({
  active,
  others,
  accent,
  secondary,
  onRetry,
  onPick,
  openUrl,
}: {
  active: VideoSourceConfig;
  others: VideoSourceConfig[];
  accent: string;
  secondary: string;
  onRetry: () => void;
  onPick: (p: VideoSourceConfig) => void;
  openUrl: () => string;
}) {
  return (
    <div
      style={{
        background: '#000',
        padding: '32px 24px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
      }}
    >
      <div
        style={{
          width: 72,
          height: 72,
          boxSizing: 'border-box',
          borderRadius: '50%',
          background: withAlpha(accent, 0.12),
          border: `1.5px solid ${withAlpha(accent, 0.55)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="error_outline" size={34} color={accent} />
      </div>
      <div style={{ height: 16 }} />
      <div style={{ ...AppTypography.outfitHeading, color: '#fff', fontSize: 15, lineHeight: lineHeight(15) }}>
        This title isn't available on {active.shortName}.
      </div>
      <div style={{ height: 6 }} />
      <div style={{ ...AppTypography.outfitMuted, color: 'rgba(255,255,255,0.6)', fontSize: 12, lineHeight: lineHeight(12) }}>
        This source could not start playback. Retry it or choose another source below. Resume support depends on the source.
      </div>
      <div style={{ height: 24 }} />
      <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
        <button
          type="button"
          className="bare-button"
          onClick={onRetry}
          style={{
            height: 40,
            padding: '0 16px 0 12px',
            borderRadius: 20,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            cursor: 'pointer',
            ...AppTypography.labelLarge,
            lineHeight: lineHeight(14),
            color: AppColors.petalWhite,
          }}
        >
          <Icon name="refresh" size={18} color={AppColors.petalWhite} variant="filled" />
          Retry this source
        </button>
      </div>
      {others.length > 0 && (
        <>
          <div
            style={{
              ...AppTypography.outfitWhite,
              color: secondary,
              fontSize: 11,
              fontWeight: 800,
              letterSpacing: 1.5,
              lineHeight: lineHeight(11),
            }}
          >
            Try another source
          </div>
          <div style={{ height: 10 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, justifyContent: 'center' }}>
            {others.map((p) => (
              <button
                key={p.id}
                type="button"
                className="bare-button"
                onClick={() => onPick(p)}
                style={{
                  padding: '10px 16px',
                  background: withAlpha(accent, 0.12),
                  borderRadius: AppRadius.full,
                  border: `1px solid ${withAlpha(accent, 0.6)}`,
                  display: 'flex',
                  alignItems: 'center',
                  cursor: 'pointer',
                }}
              >
                <Icon name="play_circle_outline" size={17} color={accent} />
                <div style={{ width: 7 }} />
                <span style={{ ...AppTypography.outfitHeading, color: '#fff', fontSize: 12, lineHeight: lineHeight(12) }}>
                  {p.name}
                </span>
              </button>
            ))}
          </div>
        </>
      )}
      <div style={{ height: 28 }} />
      <a
        href={openUrl()}
        target="_blank"
        rel="noopener noreferrer"
        style={{
          padding: '13px 20px',
          background: accent,
          borderRadius: AppRadius.full,
          display: 'flex',
          alignItems: 'center',
          textDecoration: 'none',
        }}
      >
        <Icon name="open_in_new" size={16} color="#fff" />
        <div style={{ width: 9 }} />
        <span
          style={{ ...AppTypography.outfitBold, color: '#fff', fontSize: 12, letterSpacing: 0.3, lineHeight: lineHeight(12) }}
        >
          Open in browser
        </span>
      </a>
    </div>
  );
}
