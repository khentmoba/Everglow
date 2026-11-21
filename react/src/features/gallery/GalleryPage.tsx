// Port of lib/features/gallery/presentation/screens/gallery_screen.dart + map/week/viewer/add views.
import { useCallback, useEffect, useRef, useState } from 'react';
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint, AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { Logger } from '../../core/system/logger';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { linear, Align, boxShadow, insetBorder, lineHeight } from '../../core/theme/paint';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowSegmentedControl } from '../../shared/widgets/EverglowSegmentedControl';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { OfflinePhotos } from './offlinePhotos';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { openSharedMemory } from '../journal/openSharedMemory';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { displayGalleryUrl, galleryService, gridPhotoUrl, type MemoryPhoto } from './galleryService';

type TabIdx = 0 | 1 | 2;

export function GalleryPage() {
  const { width } = useViewport();
  const cols = width >= AppBreakpoint.tablet ? 6 : width >= AppBreakpoint.mobile ? 5 : 3;

  const [tab, setTab] = useState<TabIdx>(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<MemoryPhoto[] | null>(null);
  const [searching, setSearching] = useState(false);

  const [mapPhotos, setMapPhotos] = useState<MemoryPhoto[] | null>(null);
  const [mapLoading, setMapLoading] = useState(false);

  const [weekPhotos, setWeekPhotos] = useState<MemoryPhoto[] | null>(null);
  const [weekLoading, setWeekLoading] = useState(false);

  const [viewer, setViewer] = useState<{ photos: MemoryPhoto[]; index: number } | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [retryKey, setRetryKey] = useState(0);
  const [older, setOlder] = useState<MemoryPhoto[]>([]);
  const [olderCursor, setOlderCursor] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [olderDone, setOlderDone] = useState(false);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [keepingOffline, setKeepingOffline] = useState(false);
  const livePhotos = useRef<MemoryPhoto[]>([]);
  const photos = livePhotos.current;

  const loadOlder = async () => {
    const live = livePhotos.current;
    if (loadingOlder || live.length === 0) return;
    setLoadingOlder(true);
    try {
      const page = await galleryService.fetchOlderPhotos(
        olderCursor,
        (older.length === 0 ? live : older)[(older.length === 0 ? live : older).length - 1].uploadedAt,
      );
      setOlder((o) => [...o, ...page.items]);
      setOlderCursor(page.nextCursor);
      setOlderDone(!page.hasMore);
    } catch (e) {
      Logger.e('Gallery: older photos failed', e);
      showSnackBar('Could not load older photos');
    } finally {
      setLoadingOlder(false);
    }
  };

  const openKeepOffline = async () => {
    const live = livePhotos.current;
    const liveIds = new Set(live.map((p) => p.id));
    const all = [...live, ...older.filter((p) => !liveIds.has(p.id))];
    const saved = await OfflinePhotos.savedCount();
    const muted = { ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.75) };
    const choice = await showDialog<string>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={20}
        borderColor={withAlpha(AppColors.blushGold, 0.25)}
        title={<span style={AppTypography.cormorantBold}>Keep photos on this phone</span>}
        content={
          <div style={muted}>
            Saves small versions of the {all.length} photos in the grid so they open without internet.{' '}
            {saved > 0 ? `${saved} already kept. ` : ''}They are removed when you log out.
          </div>
        }
        actions={[
          ...(saved > 0
            ? [
                <TextButton key="clear" onPressed={() => close('clear')}>
                  Remove kept photos
                </TextButton>,
              ]
            : []),
          <TextButton key="cancel" onPressed={() => close(null)}>
            Cancel
          </TextButton>,
          ...(all.length > 0
            ? [
                <TextButton key="keep" onPressed={() => close('keep')}>
                  Keep {all.length}
                </TextButton>,
              ]
            : []),
        ]}
      />
    ));
    if (choice == null) return;
    if (choice === 'clear') {
      await OfflinePhotos.clear();
      showSnackBar('Kept photos removed from this phone');
      return;
    }
    setKeepingOffline(true);
    try {
      const kept = await OfflinePhotos.save(all.map(gridPhotoUrl));
      showSnackBar(
        kept === all.length
          ? `Kept ${kept} photos on this phone`
          : `Kept ${kept} of ${all.length} photos. Try again for the rest.`,
      );
    } catch (e) {
      Logger.e('Gallery: keeping photos offline failed', e);
      showSnackBar("Couldn't keep photos on this phone");
    } finally {
      setKeepingOffline(false);
    }
  };

  useEffect(() => {
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults(null);
      setSearching(false);
      return;
    }
    let cancelled = false;
    setSearching(true);
    const id = window.setTimeout(() => {
      void galleryService
        .searchPhotos(q, photos)
        .then((res) => {
          if (!cancelled) setSearchResults(res);
        })
        .catch(() => {
          if (!cancelled) setSearchResults([]);
        })
        .finally(() => {
          if (!cancelled) setSearching(false);
        });
    }, 300);
    return () => {
      cancelled = true;
      clearTimeout(id);
    };
  }, [searchQuery, photos]);

  useEffect(() => {
    if (tab === 1 && mapPhotos == null && !mapLoading) {
      setMapLoading(true);
      void galleryService
        .getPhotosWithLocation(100)
        .then(setMapPhotos)
        .catch(() => setMapPhotos([]))
        .finally(() => setMapLoading(false));
    }
    if (tab === 2 && weekPhotos == null && !weekLoading) {
      setWeekLoading(true);
      void galleryService
        .getPhotosFromThisWeek()
        .then(setWeekPhotos)
        .catch(() => setWeekPhotos([]))
        .finally(() => setWeekLoading(false));
    }
  }, [tab, mapPhotos, mapLoading, weekPhotos, weekLoading]);

  const handleDelete = async (photo: MemoryPhoto) => {
    await galleryService.deletePhoto(photo);
    setOlder((o) => o.filter((p) => p.id !== photo.id));
  };
  const closeViewer = useCallback(() => setViewer(null), []);
  const closeAdd = useCallback(() => setAddOpen(false), []);

  return (
    <EverglowScaffold
      backgroundColor={AppColors.inkDeep}
      glows={[
        { color: AppColors.deepRose, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.16 },
        { color: AppColors.auroraLilac, alignment: [0.9, 0.7], size: 0.7, opacity: 0.1 },
      ]}
      floatingActionButton={<FloatingAddButton onPressed={() => setAddOpen(true)} />}
    >
      <EverglowFeatureHeader title="Memory Gallery" subtitle="our shared album" icon="photo_library" hue={AppColors.roseQuartz} />
      <div style={{ height: 8 }} />
      <div style={{ padding: '0 16px' }}>
        <EverglowSegmentedControl
          selectedIndex={tab}
          onChanged={(i) => setTab(i as TabIdx)}
          activeColor={AppColors.roseQuartz}
          items={[
            { label: 'Grid', icon: 'grid_view' },
            { label: 'Map', icon: 'map' },
            { label: 'Week', icon: 'history' },
          ]}
        />
      </div>
      <div style={{ height: 8 }} />
      {tab === 0 && (
        <div style={{ padding: '8px 20px' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              minHeight: 48,
              background: withAlpha(AppColors.velvet, 0.38),
              borderRadius: AppRadius.lg,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
            }}
          >
            <div
              style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
            >
              <Icon name="search" size={19} color={withAlpha(AppColors.petalWhite, 0.42)} />
            </div>
            <input
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search memories..."
              className="money-input"
              style={{
                flex: 1,
                minWidth: 0,
                padding: '12px 0 16px 4px',
                background: 'transparent',
                border: 'none',
                outline: 'none',
                ...AppTypography.outfitWhite,
                fontSize: 13,
                letterSpacing: 0.5,
                color: AppColors.petalWhite,
                ['--hint-color' as string]: withAlpha(AppColors.petalWhite, 0.5),
                ['--hint-size' as string]: '13px',
              }}
            />
            <Tooltip message="Keep photos on this phone">
              <button
                type="button"
                className="bare-button"
                aria-label="Keep photos on this phone"
                disabled={keepingOffline}
                onClick={() => void openKeepOffline()}
                style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
              >
                {keepingOffline ? (
                  <CircularProgress size={16} strokeWidth={2} color={AppColors.roseQuartz} />
                ) : (
                  <Icon name="download_for_offline" variant="outlined" size={20} color={withAlpha(AppColors.petalWhite, 0.6)} />
                )}
              </button>
            </Tooltip>
          </div>
        </div>
      )}
      {tab === 0 && <div style={{ height: 4 }} />}

      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        {tab === 1 ? (
          <GalleryMapView photos={mapPhotos ?? []} loading={mapLoading} />
        ) : tab === 2 ? (
          <ThisWeekView photos={weekPhotos ?? []} loading={weekLoading} />
        ) : searchQuery.trim() ? (
          searching ? (
            <SkeletonGrid cols={cols} />
          ) : (searchResults ?? []).length === 0 ? (
            <EverglowEmptyState icon="search_off" title="No matches" subtitle="Try a different keyword" />
          ) : (
            <PhotoGrid
              photos={searchResults ?? []}
              cols={cols}
              onOpen={(i) => setViewer({ photos: searchResults ?? [], index: i })}
            />
          )
        ) : (
          <EverglowStreamView<MemoryPhoto[]>
            source={() => galleryService.getPhotosStream(40)}
            sourceKey={[retryKey]}
            label="gallery-grid"
            errorMessage="Could not load photos"
            errorIcon="photo_library_outlined"
            onRetry={() => setRetryKey((k) => k + 1)}
            loadingView={<SkeletonGrid cols={cols} />}
            isEmpty={(p) => p.length === 0}
            emptyView={
              <EverglowEmptyState
                icon="photo_library_outlined"
                title="No memories yet"
                subtitle="Tap + to add your first photo"
                ctaLabel="Add Photo"
                onCta={() => setAddOpen(true)}
              />
            }
            builder={(live) => {
              const liveIds = new Set(live.map((p) => p.id));
              const all = [...live, ...older.filter((p) => !liveIds.has(p.id))];
              livePhotos.current = live;
              return (
                <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                  <PhotoGrid photos={all} cols={cols} onOpen={(i) => setViewer({ photos: all, index: i })} />
                  {live.length === 40 && !olderDone && (
                    <TextButton onPressed={loadingOlder ? undefined : () => void loadOlder()}>
                      {loadingOlder ? 'Loading older photos...' : 'Load older photos'}
                    </TextButton>
                  )}
                </div>
              );
            }}
          />
        )}
      </div>

      {viewer && (
        <PhotoViewerScreen photos={viewer.photos} initialIndex={viewer.index} onClose={closeViewer} onDelete={handleDelete} />
      )}

      {addOpen && <AddPhotoDialog onClose={closeAdd} />}
    </EverglowScaffold>
  );
}

function PhotoGrid({ photos, cols, onOpen }: { photos: MemoryPhoto[]; cols: number; onOpen: (index: number) => void }) {
  const newest = photos[0]?.uploadedAt;
  return (
    <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
      {photos.length > 0 && (
        <div style={{ padding: '2px 18px 8px', display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <span style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22, lineHeight: 1 }}>{photos.length}</span>
          <span style={{ ...AppTypography.handwrittenBody, fontSize: 16, color: withAlpha(AppColors.blushGold, 0.85) }}>
            {photos.length === 1 ? 'memory kept' : 'memories kept'}
          </span>
          {newest && (
            <span style={{ marginLeft: 'auto', ...AppTypography.outfitWhite, fontSize: 11.5, color: withAlpha(AppColors.petalWhite, 0.5) }}>
              newest {newest.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
            </span>
          )}
        </div>
      )}
      <div
        style={{
          padding: '0 16px 96px',
          display: 'grid',
          gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
          gridAutoFlow: 'dense',
          gap: 10,
        }}
      >
        {photos.map((photo, index) => (
          <PhotoCard key={photo.id} photo={photo} featured={index === 0 && photos.length > 2} onClick={() => onOpen(index)} />
        ))}
      </div>
    </div>
  );
}

/** EverglowSkeletonGrid(count: 6, spacing: 10, childAspectRatio: 0.82). */
function SkeletonGrid({ cols }: { cols: number }) {
  return (
    <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
      {Array.from({ length: 6 }, (_, i) => (
        <div key={i} style={{ aspectRatio: '0.82' }}>
          <EverglowSkeleton height={undefined} radius={14} />
        </div>
      ))}
    </div>
  );
}

function FloatingAddButton({ onPressed }: { onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  const scale = hovered ? 1.08 : 1;
  return (
    <Tooltip message="Add a photo">
      <button
        type="button"
        className="bare-button"
        aria-label="Add a photo"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: 58,
          height: 58,
          borderRadius: '50%',
          background: linear([AppColors.auroraRose, AppColors.deepRose, AppColors.blushGold], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          border: `1.5px solid ${withAlpha(AppColors.petalWhite, 0.4)}`,
          boxShadow: `0 0 24px -2px ${withAlpha(AppColors.deepRose, 0.45)}`,
          transform: `scale(${scale})`,
          transition: `transform ${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxSizing: 'border-box',
        }}
      >
        <Icon name="add_photo_alternate" size={26} color={AppColors.petalWhite} />
      </button>
    </Tooltip>
  );
}

function PhotoCard({ photo, featured = false, onClick }: { photo: MemoryPhoto; featured?: boolean; onClick: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      aria-label={photo.caption || 'Memory photo'}
      style={{
        aspectRatio: '0.82',
        gridColumn: featured ? 'span 2' : undefined,
        gridRow: featured ? 'span 2' : undefined,
        borderRadius: AppRadius.lg,
        overflow: 'hidden',
        position: 'relative',
        border: `1px solid ${withAlpha(AppColors.blushGold, hovered ? 0.6 : 0.18)}`,
        boxShadow: hovered
          ? `0 10px 22px ${withAlpha(AppColors.inkDeep, 0.65)}, 0 0 18px ${withAlpha(AppColors.deepRose, 0.25)}`
          : `0 6px 14px ${withAlpha(AppColors.inkDeep, 0.5)}`,
        transform: hovered ? 'translateY(-4px) scale(1.03)' : 'none',
        transition: 'transform 180ms cubic-bezier(0.22, 1, 0.36, 1), box-shadow 180ms ease, border-color 180ms ease',
        background: AppColors.velvet,
        display: 'block',
        width: '100%',
      }}
    >
      <img
        src={gridPhotoUrl(photo)}
        alt={photo.caption || 'Memory photo'}
        loading="lazy"
        style={{ position: featured ? 'absolute' : undefined, inset: 0, width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          background: 'linear-gradient(to bottom, transparent, rgba(0,0,0,0.72))',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          padding: featured ? '48px 14px 13px' : '34px 10px 9px',
          textAlign: 'left',
        }}
      >
        {featured && (
          <span style={{ ...AppTypography.handwrittenBody, fontSize: 14, color: AppColors.blushGold, marginBottom: 2 }}>latest memory</span>
        )}
        {photo.caption && (
          <div
            style={{
              ...(featured ? { ...AppTypography.cormorantBoldWhite, fontSize: 19 } : AppTypography.outfitWhite),
              fontSize: featured ? 19 : 11,
              fontWeight: featured ? 700 : 500,
              lineHeight: 1.25,
              color: AppColors.petalWhite,
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}
          >
            {photo.caption}
          </div>
        )}
        <div style={{ height: 3 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, width: '100%' }}>
          <Icon name="favorite" size={9} color={AppColors.auroraRose} />
          <span
            style={{
              ...AppTypography.outfitBold,
              fontSize: 9,
              color: withAlpha(AppColors.petalWhite, 0.42),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {photo.uploadedBy}
          </span>
        </div>
      </div>
    </button>
  );
}

function thumbOf(p: MemoryPhoto): string {
  return displayGalleryUrl(p.thumbUrl && p.thumbUrl.length > 0 ? p.thumbUrl : p.imageUrl, true);
}

function GalleryMapView({ photos, loading }: { photos: MemoryPhoto[]; loading: boolean }) {
  if (loading) {
    return (
      <div style={{ padding: 20 }}>
        <EverglowSkeleton width="100%" height={200} radius={16} />
      </div>
    );
  }
  const located = photos.filter((p) => p.latitude != null && p.longitude != null);
  if (located.length === 0) {
    return (
      <div style={{ flex: 1, minHeight: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ padding: 32, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <Icon name="map" variant="outlined" size={48} color={withAlpha(AppColors.blushGold, 0.6)} />
          <div style={{ height: 12 }} />
          <div style={{ ...AppTypography.outfitBold, fontSize: 14 }}>No pinned memories yet</div>
          <div style={{ height: 6 }} />
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 12,
              color: withAlpha(AppColors.petalWhite, 0.6),
              textAlign: 'center',
            }}
          >
            Add a location when uploading — pins will appear on your world map
          </div>
        </div>
      </div>
    );
  }
  const lats = located.map((p) => p.latitude!);
  const lngs = located.map((p) => p.longitude!);
  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLng = Math.min(...lngs);
  const maxLng = Math.max(...lngs);
  const latRange = Math.abs(maxLat - minLat) < 0.001 ? 1 : maxLat - minLat;
  const lngRange = Math.abs(maxLng - minLng) < 0.001 ? 1 : maxLng - minLng;
  return (
    <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
      <div
        style={{
          margin: '0 16px',
          padding: '10px 14px',
          display: 'flex',
          alignItems: 'center',
          background: withAlpha(AppColors.inkDeep, 0.6),
          borderRadius: 12,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
        }}
      >
        <Icon name="place" size={16} color={AppColors.warmAmber} />
        <div style={{ width: 8 }} />
        <span style={{ ...AppTypography.outfitBold, fontSize: 12 }}>
          {`${located.length} pinned ${located.length === 1 ? 'memory' : 'memories'}`}
        </span>
        <div style={{ flex: 1 }} />
        <TextButton
          onPressed={() => {}}
          color={AppColors.blushGold}
          icon={<Icon name="open_in_new" size={14} color={AppColors.blushGold} />}
          style={{ ...AppTypography.outfitWhite, fontSize: 11, color: AppColors.blushGold }}
        >
          How it works
        </TextButton>
      </div>
      <div style={{ height: 12 }} />
      <div
        style={{
          flex: 1,
          minHeight: 0,
          margin: '0 16px',
          position: 'relative',
          overflow: 'hidden',
          borderRadius: 16,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
          background: `linear-gradient(to bottom right, ${AppColors.twilight}, ${AppColors.inkDeep})`,
        }}
      >
        <MapGrid />
        {located.map((p) => {
          const x = 0.08 + ((p.longitude! - minLng) / lngRange) * 0.84;
          const y = 0.1 + (1 - (p.latitude! - minLat) / latRange) * 0.8;
          return <MapPin key={p.id} photo={p} x={x} y={y} />;
        })}
      </div>
      <div style={{ height: 12 }} />
      <div style={{ height: 92, flexShrink: 0, display: 'flex', overflowX: 'auto', padding: '0 16px' }}>
        {located.map((p) => (
          <button
            key={p.id}
            type="button"
            className="bare-button"
            onClick={() => openMapPhoto(p)}
            style={{
              width: 140,
              flexShrink: 0,
              marginRight: 10,
              display: 'flex',
              flexDirection: 'column',
              textAlign: 'left',
              background: AppColors.twilight,
              borderRadius: 12,
              border: `1px solid ${Derived.border}`,
              overflow: 'hidden',
            }}
          >
            <div style={{ flex: 1, minHeight: 0, width: '100%', background: AppColors.velvet, overflow: 'hidden' }}>
              <img
                src={thumbOf(p)}
                alt=""
                loading="lazy"
                style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
              />
            </div>
            <div
              style={{
                padding: '6px 8px',
                width: '100%',
                boxSizing: 'border-box',
                ...AppTypography.outfitWhite,
                fontSize: 10,
                color: withAlpha(AppColors.petalWhite, 0.7),
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {p.locationName ?? `${p.latitude!.toFixed(2)}, ${p.longitude!.toFixed(2)}`}
            </div>
          </button>
        ))}
      </div>
      <div style={{ height: 8 }} />
    </div>
  );
}

function MapGrid() {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const draw = () => {
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.strokeStyle = withAlpha(AppColors.moonlight, 0.06);
      ctx.lineWidth = 0.6;
      ctx.beginPath();
      for (let x = 0; x < w; x += 36) {
        ctx.moveTo(x, 0);
        ctx.lineTo(x, h);
      }
      for (let y = 0; y < h; y += 36) {
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
      }
      ctx.stroke();
      ctx.fillStyle = withAlpha(AppColors.deepRose, 0.07);
      ctx.beginPath();
      ctx.arc(w * 0.3, h * 0.4, 80, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = withAlpha(AppColors.warmAmber, 0.05);
      ctx.beginPath();
      ctx.arc(w * 0.7, h * 0.65, 65, 0, Math.PI * 2);
      ctx.fill();
    };
    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(canvas);
    return () => ro.disconnect();
  }, []);
  return <canvas ref={ref} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} />;
}

function MapPin({ photo, x, y }: { photo: MemoryPhoto; x: number; y: number }) {
  const [hovered, setHovered] = useState(false);
  const size = hovered ? 38 : 32;
  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => showSnackBar(photo.locationName ?? photo.caption, { background: AppColors.velvet, duration: 2000 })}
      style={{
        position: 'absolute',
        left: `${x * 100}%`,
        top: `${y * 100}%`,
        transform: `translate(${-x * 100}%, ${-y * 100}%)`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <div
        style={{
          padding: hovered ? 3 : 2,
          borderRadius: '50%',
          background: AppColors.petalWhite,
          border: `1.2px solid ${AppColors.deepRose}`,
          boxShadow: `0 0 8px ${withAlpha(AppColors.deepRose, 0.3)}`,
          transition: `padding ${orZero(150)}ms linear`,
        }}
      >
        <div
          style={{
            width: size,
            height: size,
            borderRadius: '50%',
            overflow: 'hidden',
            background: AppColors.blushGold,
            transition: `width ${orZero(150)}ms linear, height ${orZero(150)}ms linear`,
          }}
        >
          <img
            src={thumbOf(photo)}
            alt=""
            loading="lazy"
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        </div>
      </div>
      <div style={{ width: 2, height: 8, background: AppColors.deepRose }} />
      <div style={{ width: 8, height: 8, borderRadius: '50%', background: AppColors.deepRose }} />
    </div>
  );
}

function openMapPhoto(p: MemoryPhoto) {
  const osm = `https://www.openstreetmap.org/?mlat=${p.latitude}&mlon=${p.longitude}#map=15/${p.latitude}/${p.longitude}`;
  void showDialog<void>((close) => (
    <div style={{ width: '100%', maxWidth: 420, background: AppColors.velvet, borderRadius: 16, overflow: 'hidden' }}>
      <img
        src={thumbOf(p)}
        alt=""
        style={{ width: '100%', display: 'block', objectFit: 'cover', minHeight: 200, background: AppColors.twilight }}
      />
      <div style={{ padding: 14 }}>
        {p.locationName != null && (
          <>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <Icon name="place" size={14} color={AppColors.warmAmber} />
              <div style={{ width: 6 }} />
              <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.warmAmber }}>{p.locationName}</span>
            </div>
            <div style={{ height: 6 }} />
          </>
        )}
        <div style={{ ...AppTypography.outfitWhite, fontSize: 13 }}>{p.caption === '' ? 'No caption' : p.caption}</div>
        <div style={{ height: 8 }} />
        <div style={{ ...AppTypography.outfitWhite, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.5) }}>
          {`${p.latitude!.toFixed(4)}, ${p.longitude!.toFixed(4)} • by ${p.uploadedBy}`}
        </div>
        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <a
            href={osm}
            target="_blank"
            rel="noreferrer"
            style={{
              flex: 1,
              height: 40,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
              borderRadius: 20,
              border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.3)}`,
              textDecoration: 'none',
              ...AppTypography.outfitWhite,
              fontSize: 11,
              color: AppColors.auroraTeal,
            }}
          >
            <Icon name="map" size={14} color={AppColors.auroraTeal} />
            Open in OSM
          </a>
          <div style={{ width: 8 }} />
          <TextButton onPressed={() => close(null)} style={{ ...AppTypography.outfitWhite, fontSize: 11 }}>
            Close
          </TextButton>
        </div>
      </div>
    </div>
  ));
}

function ThisWeekView({ photos, loading }: { photos: MemoryPhoto[]; loading: boolean }) {
  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: 32 }}>
        <CircularProgress size={36} color={AppColors.deepRose} strokeWidth={2} />
      </div>
    );
  }
  if (photos.length === 0) {
    return (
      <div style={{ flex: 1, minHeight: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ padding: 32, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <Icon name="history_toggle_off" size={42} color={withAlpha(AppColors.blushGold, 0.6)} />
          <div style={{ height: 10 }} />
          <div style={{ ...AppTypography.outfitBold, fontSize: 13 }}>No memories this week in past</div>
          <div style={{ height: 6 }} />
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 11,
              color: withAlpha(AppColors.petalWhite, 0.6),
              textAlign: 'center',
            }}
          >
            Photos from the same week in previous years will appear here — keep capturing!
          </div>
        </div>
      </div>
    );
  }
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  return (
    <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '8px 16px 16px' }}>
      {photos.map((p) => {
        const at = p.uploadedAt;
        const yearsAgo = now.getFullYear() - at.getFullYear();
        const dayDiff = Math.trunc((new Date(now.getFullYear(), at.getMonth(), at.getDate()).getTime() - today) / 86_400_000);
        const label =
          dayDiff === 0
            ? `Today • ${yearsAgo} ${yearsAgo === 1 ? 'year' : 'years'} ago`
            : `${dayDiff > 0 ? `+${dayDiff}` : `${dayDiff}`} days • ${yearsAgo} y ago`;
        const thumb = thumbOf(p);
        return (
          <div
            key={p.id}
            style={{
              marginBottom: 12,
              display: 'flex',
              alignItems: 'center',
              background: withAlpha(AppColors.moonlight, 0.08),
              borderRadius: 14,
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.12)}`,
            }}
          >
            <div
              style={{
                width: 90,
                height: 90,
                flexShrink: 0,
                borderRadius: '14px 0 0 14px',
                overflow: 'hidden',
                background: AppColors.twilight,
              }}
            >
              {thumb && (
                <img
                  src={thumb}
                  alt=""
                  loading="lazy"
                  onError={(e) => (e.currentTarget.style.visibility = 'hidden')}
                  style={{ width: 90, height: 90, objectFit: 'cover', display: 'block' }}
                />
              )}
            </div>
            <div
              style={{
                flex: 1,
                minWidth: 0,
                padding: '10px 12px',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'flex-start',
              }}
            >
              <div
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 9,
                  fontWeight: 700,
                  color: AppColors.warmAmber,
                  padding: '2px 6px',
                  borderRadius: 6,
                  background: withAlpha(AppColors.warmAmber, 0.15),
                }}
              >
                {label}
              </div>
              <div style={{ height: 6 }} />
              <div
                style={{
                  ...AppTypography.outfitBold,
                  fontSize: 13,
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                }}
              >
                {p.caption === '' ? 'Untitled memory' : p.caption}
              </div>
              <div style={{ height: 4 }} />
              <div
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 10,
                  color: withAlpha(AppColors.petalWhite, 0.5),
                  width: '100%',
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {`${at.getMonth() + 1}/${at.getDate()}/${at.getFullYear()} • by ${p.uploadedBy}${p.locationName != null ? ` • 📍 ${p.locationName}` : ''}`}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function ViewerIconButton({
  icon,
  size = 24,
  color,
  label,
  onPressed,
  variant,
}: {
  icon: string;
  size?: number;
  color: string;
  label: string;
  onPressed: () => void;
  variant?: 'round' | 'outlined';
}) {
  return (
    <Tooltip message={label}>
      <button
        type="button"
        className="bare-button"
        aria-label={label}
        onClick={onPressed}
        style={{ width: 48, height: 48, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        <Icon name={icon} variant={variant} size={size} color={color} />
      </button>
    </Tooltip>
  );
}

function ZoomableImage({ photo }: { photo: MemoryPhoto }) {
  const [view, setView] = useState({ scale: 1, x: 0, y: 0 });
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const pinch = useRef<{ dist: number; scale: number } | null>(null);
  const [fullFailed, setFullFailed] = useState(false);
  const [fullLoaded, setFullLoaded] = useState(false);
  const thumb = photo.thumbUrl && photo.thumbUrl.length > 0 ? displayGalleryUrl(photo.thumbUrl) : '';

  const onPointerDown = (e: React.PointerEvent) => {
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()];
      pinch.current = { dist: Math.hypot(a.x - b.x, a.y - b.y), scale: view.scale };
    }
  };
  const onPointerMove = (e: React.PointerEvent) => {
    const prev = pointers.current.get(e.pointerId);
    if (!prev) return;
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.current.size === 2 && pinch.current) {
      const [a, b] = [...pointers.current.values()];
      const scale = Math.min(4, Math.max(0.5, (pinch.current.scale * Math.hypot(a.x - b.x, a.y - b.y)) / pinch.current.dist));
      setView((v) => ({ ...v, scale }));
    } else if (pointers.current.size === 1 && view.scale > 1) {
      setView((v) => ({ ...v, x: v.x + e.clientX - prev.x, y: v.y + e.clientY - prev.y }));
    }
  };
  const onPointerUp = (e: React.PointerEvent) => {
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) pinch.current = null;
    if (pointers.current.size === 0 && view.scale <= 1) setView({ scale: view.scale, x: 0, y: 0 });
  };

  const fill: React.CSSProperties = {
    position: 'absolute',
    inset: 0,
    width: '100%',
    height: '100%',
    objectFit: 'contain',
    display: 'block',
  };
  return (
    <div
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onWheel={(e) => {
        if (!e.ctrlKey) return;
        const scale = Math.min(4, Math.max(0.5, view.scale * Math.exp(-e.deltaY / 200)));
        setView((v) => ({ ...v, scale }));
      }}
      style={{
        width: '100%',
        height: '100%',
        flexShrink: 0,
        scrollSnapAlign: 'start',
        position: 'relative',
        overflow: 'hidden',
        touchAction: view.scale > 1 ? 'none' : 'pan-x',
      }}
    >
      <div style={{ position: 'absolute', inset: 0, transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})` }}>
        {thumb && !fullLoaded && (
          <img src={thumb} alt="" aria-hidden onError={(e) => (e.currentTarget.style.display = 'none')} style={fill} />
        )}
        {!fullFailed && (
          <img
            src={displayGalleryUrl(photo.imageUrl)}
            alt={photo.caption}
            onLoad={() => setFullLoaded(true)}
            onError={() => setFullFailed(true)}
            style={{ ...fill, opacity: fullLoaded ? 1 : 0 }}
          />
        )}
        {!thumb && !fullLoaded && !fullFailed && (
          <div style={{ ...fill, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CircularProgress size={36} strokeWidth={4} color={AppColors.blushGold} />
          </div>
        )}
        {!thumb && fullFailed && (
          <div style={{ ...fill, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="broken_image" size={48} color={AppColors.roseQuartz} />
          </div>
        )}
      </div>
    </div>
  );
}

export function PhotoViewerScreen({
  photos: initial,
  initialIndex,
  onClose,
  onDelete,
}: {
  photos: MemoryPhoto[];
  initialIndex: number;
  onClose: () => void;
  onDelete: (p: MemoryPhoto) => Promise<void>;
}) {
  const auth = useAuth();
  const [photos, setPhotos] = useState(() => [...initial]);
  const [index, setIndex] = useState(initialIndex);
  const [shown, setShown] = useState(false);
  const pager = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = pager.current;
    if (el) el.scrollLeft = initialIndex * el.clientWidth;
    const raf = requestAnimationFrame(() => setShown(true));
    const onKey = (ev: KeyboardEvent) => {
      if (ev.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', onKey);
    };
  }, [initialIndex, onClose]);

  const current = photos[index];
  const canDelete = current != null && (current.uploadedBy === auth.uid || current.uploadedBy === auth.currentUser);

  const confirmDelete = (photo: MemoryPhoto) => {
    void showDialog<boolean>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={20}
        borderColor={withAlpha(AppColors.blushGold, 0.25)}
        title="Delete Photo?"
        content={
          <span
            style={{
              ...AppTypography.bodyMedium,
              ...AppTypography.outfitWhite,
              color: withAlpha(AppColors.petalWhite, 0.7),
              letterSpacing: 0.25,
            }}
          >
            This action cannot be undone.
          </span>
        }
        actions={[
          <MaterialIconButton
            key="keep"
            icon="auto_stories_outlined"
            tooltip="Keep this memory"
            onPressed={() =>
              void openSharedMemory({
                title: photo.caption === '' ? 'A memory together' : photo.caption,
                date: photo.takenAt ?? photo.uploadedAt,
                photoId: photo.id,
              })
            }
          />,
          <TextButton
            key="cancel"
            onPressed={() => close(false)}
            style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.6) }}
          >
            Cancel
          </TextButton>,
          <TextButton
            key="delete"
            onPressed={() => close(true)}
            style={{ ...AppTypography.outfitWhite, color: AppColors.deepRose, fontWeight: 700 }}
          >
            Delete
          </TextButton>,
        ]}
      />
    )).then(async (ok) => {
      if (!ok) return;
      const removedIndex = index;
      const isLast = photos.length <= 1;
      if (!isLast) {
        setPhotos((list) => list.filter((_, i) => i !== removedIndex));
        setIndex((i) => Math.min(i, photos.length - 2));
      }
      try {
        await onDelete(photo);
        if (isLast) onClose();
      } catch (e) {
        Logger.e('Optimistic action failed and rolled back', e);
        if (!isLast) {
          setPhotos((list) => {
            const next = [...list];
            next.splice(Math.min(removedIndex, next.length), 0, photo);
            return next;
          });
        }
        showSnackBar('Could not finish deleting. Please try again.', {
          duration: 5000,
          action: { label: 'Retry', onPressed: () => confirmDelete(photo) },
        });
      }
    });
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 600,
        background: '#000',
        display: 'flex',
        flexDirection: 'column',
        opacity: shown ? 1 : 0,
        transform: `scale(${shown ? 1 : 0.85})`,
        transition: `opacity ${orZero(300)}ms cubic-bezier(0.4, 0, 0.2, 1), transform ${orZero(300)}ms cubic-bezier(0.4, 0, 0.2, 1)`,
      }}
    >
      <div style={{ height: 56, flexShrink: 0, display: 'flex', alignItems: 'center', position: 'relative' }}>
        <div style={{ width: 56, display: 'flex', justifyContent: 'center' }}>
          <ViewerIconButton icon="arrow_back_ios_new" size={20} color={AppColors.petalWhite} label="Back" onPressed={onClose} />
        </div>
        <div
          style={{
            position: 'absolute',
            left: '50%',
            transform: 'translateX(-50%)',
            ...AppTypography.outfitWhite,
            fontSize: 14,
            lineHeight: lineHeight(14),
            whiteSpace: 'nowrap',
          }}
        >
          {`${index + 1} / ${photos.length}`}
        </div>
        <div style={{ flex: 1 }} />
        {canDelete && (
          <ViewerIconButton
            icon="delete_outline"
            size={22}
            color={AppColors.deepRose}
            label="Delete"
            onPressed={() => confirmDelete(current)}
          />
        )}
      </div>
      <div
        ref={pager}
        onScroll={(e) => {
          const el = e.currentTarget;
          const i = Math.round(el.scrollLeft / Math.max(1, el.clientWidth));
          if (i !== index && i >= 0 && i < photos.length) setIndex(i);
        }}
        className="no-scrollbar"
        style={{ flex: 1, minHeight: 0, display: 'flex', overflowX: 'auto', overflowY: 'hidden', scrollSnapType: 'x mandatory' }}
      >
        {photos.map((p) => (
          <ZoomableImage key={p.id} photo={p} />
        ))}
      </div>
      {current && (
        <div
          style={{ padding: '12px 20px 20px', background: 'linear-gradient(to bottom, rgba(0,0,0,0.8), #000)', flexShrink: 0 }}
        >
          {current.caption !== '' && (
            <div style={{ ...AppTypography.cormorantRegular, fontSize: 18, fontStyle: 'italic' }}>{current.caption}</div>
          )}
          <div style={{ height: 4 }} />
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <span
              style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.blushGold, whiteSpace: 'pre' }}
            >{` ${current.uploadedBy}`}</span>
            <div style={{ width: 12 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.65) }}>
              {`${current.uploadedAt.getMonth() + 1}/${current.uploadedAt.getDate()}/${current.uploadedAt.getFullYear()}`}
            </span>
          </div>
          {current.tags.length > 0 && (
            <>
              <div style={{ height: 6 }} />
              <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 6 }}>
                {current.tags.map((tag) => (
                  <span
                    key={tag}
                    style={{
                      padding: '2px 6px',
                      borderRadius: 6,
                      background: withAlpha(AppColors.softLavender, 0.2),
                      ...AppTypography.outfitWhite,
                      fontSize: 10,
                      color: AppColors.softLavender,
                    }}
                  >
                    {`#${tag}`}
                  </span>
                ))}
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}

function AddPhotoField({
  value,
  onChange,
  hint,
  fontSize = 16,
  hintSize = 16,
  hintAlpha,
  radius,
  padding,
  borderColor,
  focusColor,
  focusWidth = 1,
  prefixIcon,
  numeric,
  expanded,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  fontSize?: number;
  hintSize?: number;
  hintAlpha: number;
  radius: number;
  padding: [number, number];
  borderColor: string | null;
  focusColor?: string;
  focusWidth?: number;
  prefixIcon?: string;
  numeric?: boolean;
  expanded?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  const [hovered, setHovered] = useState(false);
  // M3 filled field: hover blends onSurface 8% over the fill and lightens the outline.
  const border = focused && focusColor ? focusColor : borderColor && hovered ? M3Scheme.onSurface : borderColor;
  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        ...(expanded ? { flex: '1 1 0', minWidth: 0 } : { width: '100%' }),
        cursor: 'text',
        // InputDecorator keeps fields at least 48 tall.
        minHeight: 48,
        display: 'flex',
        alignItems: 'center',
        background: hovered
          ? `linear-gradient(${withAlpha(M3Scheme.onSurface, 0.08)}, ${withAlpha(M3Scheme.onSurface, 0.08)}), ${AppColors.twilight}`
          : AppColors.twilight,
        borderRadius: radius,
        boxShadow: border ? `inset 0 0 0 ${focused && focusColor ? focusWidth : 1}px ${border}` : undefined,
        boxSizing: 'border-box',
      }}
    >
      {prefixIcon && (
        <div style={{ width: 48, height: 48, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={prefixIcon} size={16} color={withAlpha(AppColors.petalWhite, 0.5)} />
        </div>
      )}
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        placeholder={hint}
        inputMode={numeric ? 'decimal' : undefined}
        className="money-input"
        style={
          {
            flex: 1,
            minWidth: 0,
            padding: `${padding[1]}px ${padding[0]}px`,
            // Measured against Flutter: OutlineInputBorder text sits 4px further in.
            paddingLeft: prefixIcon ? 4 : padding[0] + 4,
            textOverflow: 'ellipsis',
            background: 'transparent',
            border: 'none',
            outline: 'none',
            ...AppTypography.outfitWhite,
            fontSize,
            lineHeight: lineHeight(fontSize, 1.5),
            letterSpacing: 0.5,
            '--hint-color': withAlpha(AppColors.petalWhite, hintAlpha),
            '--hint-size': `${hintSize}px`,
          } as React.CSSProperties
        }
      />
    </div>
  );
}

export function AddPhotoDialog({ onClose }: { onClose: (photo?: MemoryPhoto) => void }) {
  const auth = useAuth();
  const [image, setImage] = useState<{ file: File; url: string } | null>(null);
  const [fileName, setFileName] = useState('');
  const [caption, setCaption] = useState('');
  const [location, setLocation] = useState('');
  const [lat, setLat] = useState('');
  const [lng, setLng] = useState('');
  const [addLocation, setAddLocation] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState<number | null>(null);
  const [shown, setShown] = useState(false);
  const picker = useRef<HTMLInputElement>(null);
  const uploadingRef = useRef(false);

  useEffect(() => {
    const raf = requestAnimationFrame(() => setShown(true));
    const onKey = (ev: KeyboardEvent) => {
      if (ev.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', onKey);
    };
  }, [onClose]);
  useEffect(
    () => () => {
      if (image) URL.revokeObjectURL(image.url);
    },
    [image],
  );

  const pick = (file: File | undefined) => {
    if (!file) return;
    const ext = file.name.includes('.') ? file.name.split('.').pop()!.toLowerCase() : 'jpg';
    setImage({ file, url: URL.createObjectURL(file) });
    setFileName(`photo_${Date.now()}.${ext}`);
  };

  const upload = async () => {
    if (!image || uploadingRef.current) return;
    uploadingRef.current = true;
    setUploading(true);
    setProgress(null);
    try {
      const latN = Number.parseFloat(lat.trim());
      const lngN = Number.parseFloat(lng.trim());
      const loc = location.trim();
      const photo = await galleryService.uploadPhoto({
        file: image.file,
        fileName,
        caption: caption.trim(),
        uploadedBy: auth.currentUser ?? 'unknown',
        userId: auth.uid ?? '',
        latitude: addLocation && Number.isFinite(latN) ? latN : undefined,
        longitude: addLocation && Number.isFinite(lngN) ? lngN : undefined,
        locationName: addLocation && loc !== '' ? loc : undefined,
        takenAt: new Date(),
        onProgress: setProgress,
      });
      onClose(photo);
    } catch (e) {
      Logger.e('Gallery upload failed', e);
      showSnackBar("Couldn't upload the photo. It's still here — try again.", {
        background: AppColors.deepRose,
        duration: 6000,
        action: { label: 'Retry', onPressed: () => void upload() },
      });
    } finally {
      uploadingRef.current = false;
      setUploading(false);
    }
  };

  const enabled = image != null && !uploading;
  const on = addLocation;
  const tint = on ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.6);
  return (
    <div
      onClick={() => onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 800,
        background: 'rgba(0,0,0,0.54)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: shown ? 1 : 0,
        transition: `opacity ${orZero(150)}ms cubic-bezier(0, 0, 0.58, 1)`,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: 'calc(100% - 64px)',
          maxHeight: '80vh',
          boxSizing: 'border-box',
          // Flutter pads a decorated Container by its border too.
          padding: 25.5,
          background: AppColors.velvet,
          borderRadius: 24,
          boxShadow: `${insetBorder(withAlpha(AppColors.blushGold, 0.25), 1.5).boxShadow}, ${boxShadow([
            { color: withAlpha(AppColors.deepRose, 0.3), blur: 20, spread: 5 },
          ])}`,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div
          className="no-scrollbar"
          style={{ overflowY: 'auto', display: 'flex', flexDirection: 'column', alignItems: 'center' }}
        >
          <div style={{ ...AppTypography.cormorantBold, fontSize: 26, lineHeight: '32px' }}>Add Memory 📸</div>
          <div style={{ height: 20, flexShrink: 0 }} />
          <input ref={picker} type="file" accept="image/*" hidden onChange={(e) => pick(e.target.files?.[0])} />
          <button
            type="button"
            className="bare-button"
            onClick={() => picker.current?.click()}
            style={{
              width: '100%',
              height: 200,
              flexShrink: 0,
              background: AppColors.twilight,
              borderRadius: 16,
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
              boxSizing: 'border-box',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {image ? (
              <img src={image.url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 16 }} />
            ) : (
              <>
                <Icon name="add_photo_alternate" variant="outlined" size={48} color={withAlpha(AppColors.blushGold, 0.65)} />
                <div style={{ height: 12 }} />
                <span style={{ ...AppTypography.outfitWhite, fontSize: 14, color: withAlpha(AppColors.petalWhite, 0.5) }}>
                  Tap to choose a photo
                </span>
              </>
            )}
          </button>
          <div style={{ height: 16, flexShrink: 0 }} />
          <AddPhotoField
            value={caption}
            onChange={setCaption}
            hint="Add a caption…"
            hintAlpha={0.65}
            radius={16}
            padding={[16, 16]}
            borderColor={M3Scheme.onSurfaceVariant}
            focusColor={AppColors.blushGold}
          />
          <div style={{ height: 12, flexShrink: 0 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => setAddLocation((v) => !v)}
            style={{
              width: '100%',
              padding: '10px 12px',
              display: 'flex',
              alignItems: 'center',
              background: on ? withAlpha(AppColors.blushGold, 0.12) : AppColors.twilight,
              borderRadius: 12,
              border: `1px solid ${on ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.12)}`,
              boxSizing: 'border-box',
            }}
          >
            <Icon name={on ? 'check_box' : 'check_box_outline_blank'} size={18} color={tint} />
            <div style={{ width: 8 }} />
            <Icon name="place" size={16} color={tint} />
            <div style={{ width: 6 }} />
            <span
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 12,
                color: on ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.7),
                fontWeight: on ? 700 : 500,
              }}
            >
              Pin location (Immich map)
            </span>
          </button>
          {on && (
            <>
              <div style={{ height: 10, flexShrink: 0 }} />
              <AddPhotoField
                value={location}
                onChange={setLocation}
                hint="Place name — e.g., Kyoto, Our bench"
                fontSize={13}
                hintSize={12}
                hintAlpha={0.4}
                radius={12}
                padding={[14, 12]}
                borderColor={M3Scheme.onSurfaceVariant}
                focusColor={AppColors.deepRose}
                focusWidth={2}
                prefixIcon="label"
              />
              <div style={{ height: 8, flexShrink: 0 }} />
              <div style={{ width: '100%', display: 'flex' }}>
                <AddPhotoField
                  value={lat}
                  onChange={setLat}
                  hint="Latitude"
                  fontSize={12}
                  hintSize={11}
                  hintAlpha={0.35}
                  radius={12}
                  padding={[12, 10]}
                  borderColor={null}
                  numeric
                  expanded
                />
                <div style={{ width: 8, flexShrink: 0 }} />
                <AddPhotoField
                  value={lng}
                  onChange={setLng}
                  hint="Longitude"
                  fontSize={12}
                  hintSize={11}
                  hintAlpha={0.35}
                  radius={12}
                  padding={[12, 10]}
                  borderColor={null}
                  numeric
                  expanded
                />
              </div>
              <div style={{ height: 6, flexShrink: 0 }} />
              <div
                style={{
                  textAlign: 'left',
                  ...AppTypography.outfitWhite,
                  fontSize: 10,
                  lineHeight: '13px',
                  color: withAlpha(AppColors.petalWhite, 0.4),
                }}
              >
                Tip: paste from Google Maps • leave empty to save without coords
              </div>
            </>
          )}
          <div style={{ height: 24, flexShrink: 0 }} />
          <div style={{ width: '100%', display: 'flex', justifyContent: 'flex-end', alignItems: 'center' }}>
            <TextButton onPressed={onClose} style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.6) }}>
              Cancel
            </TextButton>
            <div style={{ width: 12 }} />
            <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
              <button
                type="button"
                className="bare-button"
                disabled={!enabled}
                onClick={() => void upload()}
                style={{
                  minWidth: 64,
                  minHeight: 40,
                  padding: '12px 24px',
                  borderRadius: 24,
                  background: enabled ? AppColors.deepRose : withAlpha(AppColors.deepRose, 0.3),
                  boxShadow: enabled ? '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)' : 'none',
                  display: 'flex',
                  alignItems: 'center',
                  ...AppTypography.labelLarge,
                  lineHeight: lineHeight(14),
                  color: uploading ? withAlpha(M3Scheme.onSurface, 0.38) : AppColors.petalWhite,
                }}
              >
                {uploading ? (
                  <>
                    <CircularProgress size={16} strokeWidth={2} value={progress} color={AppColors.petalWhite} />
                    <div style={{ width: 10 }} />
                    {progress == null ? 'Preparing...' : progress >= 1 ? 'Saving...' : `Uploading ${Math.round(progress * 100)}%`}
                  </>
                ) : (
                  <span style={{ ...AppTypography.outfitWhite, fontWeight: 700, letterSpacing: 0.6 }}>Upload</span>
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
