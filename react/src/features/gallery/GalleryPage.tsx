// Port of lib/features/gallery/presentation/screens/gallery_screen.dart + map/week/viewer/add views.
import { useEffect, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint, AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { displayGalleryUrl, galleryService, gridPhotoUrl, type MemoryPhoto } from './galleryService';

type TabIdx = 0 | 1 | 2;

export function GalleryPage() {
  const auth = useAuth();
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

  const [viewerIndex, setViewerIndex] = useState<number | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  const photos = useSource<MemoryPhoto[]>(() => galleryService.getPhotosStream(40), [], []);

  useEffect(() => {
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults(null);
      setSearching(false);
      return;
    }
    setSearching(true);
    const id = window.setTimeout(() => {
      void galleryService
        .searchPhotos(q, photos)
        .then((res) => setSearchResults(res))
        .catch(() => setSearchResults([]))
        .finally(() => setSearching(false));
    }, 300);
    return () => clearTimeout(id);
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

  const activeList = searchQuery.trim() ? (searchResults ?? []) : photos;

  const handleDelete = async (photo: MemoryPhoto) => {
    try {
      await galleryService.deletePhoto(photo);
      setViewerIndex(null);
      showSnackBar('Memory removed');
    } catch {
      showSnackBar('Could not delete photo');
    }
  };

  return (
    <div style={{ position: 'relative', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.deepRose, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.16 },
          { color: AppColors.auroraLilac, alignment: [0.9, 0.7], size: 0.7, opacity: 0.10 },
        ]}
      />
      <div style={{ position: 'relative', zIndex: 1, flex: 1, display: 'flex', flexDirection: 'column' }}>
        <EverglowFeatureHeader title="Memory Gallery" subtitle="our shared album" icon="photo_library" hue={AppColors.roseQuartz} />

        {/* Segmented Control */}
        <div style={{ height: 8 }} />
        <div style={{ padding: '0 16px' }}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              background: withAlpha(AppColors.inkDeep, 0.58),
              borderRadius: 18,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
              padding: 5,
            }}
          >
            {(
              [
                ['Grid', 'grid_view'],
                ['Map', 'map'],
                ['Week', 'history'],
              ] as const
            ).map(([label, icon], idx) => {
              const selected = tab === idx;
              return (
                <button
                  key={label}
                  type="button"
                  className="bare-button"
                  onClick={() => setTab(idx as TabIdx)}
                  style={{
                    minHeight: 44,
                    padding: '13px 0',
                    borderRadius: 14,
                    background: selected ? withAlpha(AppColors.roseQuartz, 0.16) : 'transparent',
                    border: `1px solid ${selected ? withAlpha(AppColors.roseQuartz, 0.42) : 'transparent'}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: 6,
                    ...AppTypography.outfitBold,
                    fontSize: 11.5,
                    letterSpacing: 0.15,
                    color: selected ? AppColors.roseQuartz : withAlpha(AppColors.petalWhite, 0.62),
                  }}
                >
                  <Icon
                    name={icon}
                    size={14}
                    color={selected ? AppColors.roseQuartz : withAlpha(AppColors.petalWhite, 0.58)}
                  />
                  <span>{label}</span>
                </button>
              );
            })}
          </div>
        </div>
        <div style={{ height: 8 }} />

        {/* Search bar on Grid tab */}
        {tab === 0 && (
          <div style={{ padding: '8px 20px 12px' }}>
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '0 4px 0 12px',
                height: 44,
                background: withAlpha(AppColors.velvet, 0.38),
                borderRadius: AppRadius.lg,
                border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
              }}
            >
              <Icon name="search" size={19} color={withAlpha(AppColors.petalWhite, 0.42)} />
              <input
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search memories..."
                style={{
                  flex: 1,
                  background: 'transparent',
                  border: 'none',
                  outline: 'none',
                  ...AppTypography.outfitWhite,
                  fontSize: 13,
                  color: AppColors.petalWhite,
                }}
              />
              {searchQuery ? (
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => setSearchQuery('')}
                  aria-label="Clear search"
                  style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <Icon name="close" size={18} color={Derived.textMuted} />
                </button>
              ) : (
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Keep photos on this phone"
                  onClick={() => showSnackBar('Photos stay cached automatically in your browser')}
                  style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <Icon
                    name="download_for_offline"
                    variant="outlined"
                    size={20}
                    color={withAlpha(AppColors.petalWhite, 0.6)}
                  />
                </button>
              )}
            </div>
          </div>
        )}

        {/* Content */}
        <div style={{ flex: 1, paddingBottom: 90 }}>
          {tab === 0 && (
            <>
              {searching ? (
                <div style={{ padding: 32, textAlign: 'center', ...AppTypography.bodyMedium }}>Searching…</div>
              ) : activeList.length === 0 ? (
                <EmptyBox
                  icon={searchQuery.trim() ? 'search_off' : 'photo_library'}
                  title={searchQuery.trim() ? 'No matching memories' : 'No memories yet'}
                  subtitle={
                    searchQuery.trim()
                      ? 'Try a different caption or tag'
                      : 'Tap + to add your first photo'
                  }
                  cta={!searchQuery.trim() ? 'Add Photo' : undefined}
                  onCta={() => setAddOpen(true)}
                />
              ) : (
                <div
                  style={{
                    padding: '6px 16px',
                    display: 'grid',
                    gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
                    gap: 10,
                  }}
                >
                  {activeList.map((photo, index) => (
                    <PhotoCard key={photo.id} photo={photo} onClick={() => setViewerIndex(index)} />
                  ))}
                </div>
              )}
            </>
          )}

          {tab === 1 && (
            <GalleryMapView photos={mapPhotos ?? []} loading={mapLoading} />
          )}

          {tab === 2 && (
            <ThisWeekView photos={weekPhotos ?? []} loading={weekLoading} />
          )}
        </div>
      </div>

      {/* Floating Add Button */}
      <button
        type="button"
        className="bare-button"
        aria-label="Add photo"
        onClick={() => setAddOpen(true)}
        style={{
          position: 'fixed',
          right: 20,
          bottom: 24,
          width: 58,
          height: 58,
          borderRadius: '50%',
          background: `linear-gradient(135deg, ${AppColors.deepRose}, ${AppColors.blushGold})`,
          border: `1.5px solid ${withAlpha(AppColors.petalWhite, 0.4)}`,
          boxShadow: `0 6px 24px ${withAlpha(AppColors.deepRose, 0.45)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 50,
        }}
      >
        <Icon name="add_photo_alternate" size={26} color={AppColors.petalWhite} />
      </button>

      {viewerIndex != null && activeList[viewerIndex] && (
        <PhotoViewerModal
          photos={activeList}
          index={viewerIndex}
          onChangeIndex={setViewerIndex}
          onClose={() => setViewerIndex(null)}
          onDelete={handleDelete}
        />
      )}

      {addOpen && (
        <AddPhotoModal
          username={auth.currentUser ?? 'khentsgdz'}
          userId={auth.uid ?? 'agent_uid'}
          onClose={() => setAddOpen(false)}
        />
      )}
    </div>
  );
}

function PhotoCard({ photo, onClick }: { photo: MemoryPhoto; onClick: () => void }) {
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
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
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
          padding: '34px 10px 9px',
          textAlign: 'left',
        }}
      >
        {photo.caption && (
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 11,
              fontWeight: 500,
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

function GalleryMapView({ photos, loading }: { photos: MemoryPhoto[]; loading: boolean }) {
  if (loading) {
    return <div style={{ padding: 32, textAlign: 'center', ...AppTypography.bodyMedium }}>Loading map pins…</div>;
  }
  if (photos.length === 0) {
    return (
      <EmptyBox
        icon="map"
        variant="outlined"
        title="No pinned memories yet"
        subtitle="Add a location when uploading — pins will appear on your world map"
      />
    );
  }
  return (
    <div style={{ padding: '8px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
      {photos.map((p) => (
        <div
          key={p.id}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            padding: 12,
            borderRadius: AppRadius.lg,
            background: withAlpha(AppColors.inkDeep, 0.6),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
          }}
        >
          <img
            src={gridPhotoUrl(p)}
            alt={p.caption}
            style={{ width: 64, height: 64, objectFit: 'cover', borderRadius: 10 }}
          />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.outfitBold, fontSize: 14 }}>
              {p.locationName || 'Pinned Location'}
            </div>
            <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>{p.caption}</div>
          </div>
          {p.latitude != null && p.longitude != null && (
            <a
              href={`https://maps.google.com/?q=${p.latitude},${p.longitude}`}
              target="_blank"
              rel="noreferrer"
              style={{ ...AppTypography.labelSmall, color: AppColors.blushGold }}
            >
              Open Map
            </a>
          )}
        </div>
      ))}
    </div>
  );
}

function ThisWeekView({ photos, loading }: { photos: MemoryPhoto[]; loading: boolean }) {
  if (loading) {
    return <div style={{ padding: 32, textAlign: 'center', ...AppTypography.bodyMedium }}>Loading this week…</div>;
  }
  if (photos.length === 0) {
    return (
      <EmptyBox
        icon="history_toggle_off"
        title="No memories this week in past"
        subtitle="Photos from the same week in previous years will appear here — keep capturing!"
      />
    );
  }
  const currentYear = new Date().getFullYear();
  return (
    <div style={{ padding: '8px 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
      {photos.map((p) => {
        const yearsAgo = currentYear - p.uploadedAt.getFullYear();
        return (
          <div
            key={p.id}
            style={{
              display: 'flex',
              gap: 12,
              padding: 12,
              borderRadius: AppRadius.xl,
              background: Derived.panelGlass,
              border: `1px solid ${Derived.border}`,
            }}
          >
            <img
              src={gridPhotoUrl(p)}
              alt={p.caption}
              style={{ width: 88, height: 88, objectFit: 'cover', borderRadius: AppRadius.md, flexShrink: 0 }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...AppTypography.labelSmall, color: AppColors.blushGold }}>
                {yearsAgo > 0 ? `${yearsAgo} ${yearsAgo === 1 ? 'year' : 'years'} ago` : 'This year'} ·{' '}
                {p.uploadedAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
              </div>
              <div style={{ ...AppTypography.bodyMedium, color: AppColors.petalWhite, marginTop: 4 }}>
                {p.caption || 'Memory photo'}
              </div>
              {p.tags.length > 0 && (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
                  {p.tags.map((t) => (
                    <span
                      key={t}
                      style={{
                        ...AppTypography.labelSmall,
                        fontSize: 10,
                        padding: '2px 8px',
                        borderRadius: AppRadius.full,
                        background: withAlpha(AppColors.roseQuartz, 0.14),
                        color: AppColors.roseQuartz,
                      }}
                    >
                      #{t}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function PhotoViewerModal({
  photos,
  index,
  onChangeIndex,
  onClose,
  onDelete,
}: {
  photos: MemoryPhoto[];
  index: number;
  onChangeIndex: (i: number) => void;
  onClose: () => void;
  onDelete: (p: MemoryPhoto) => Promise<void>;
}) {
  const photo = photos[index];
  if (!photo) return null;
  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(8,5,14,0.94)',
        zIndex: 600,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '14px 18px',
        }}
      >
        <button type="button" className="bare-button" onClick={onClose} aria-label="Close">
          <Icon name="close" size={24} color={AppColors.petalWhite} />
        </button>
        <span style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>
          {index + 1} / {photos.length}
        </span>
        <button
          type="button"
          className="bare-button"
          onClick={() => void onDelete(photo)}
          aria-label="Delete photo"
        >
          <Icon name="delete_outline" size={22} color={AppColors.error} />
        </button>
      </div>

      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          flex: 1,
          minHeight: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          position: 'relative',
          padding: '0 16px',
        }}
      >
        {index > 0 && (
          <button
            type="button"
            className="bare-button"
            aria-label="Previous photo"
            onClick={() => onChangeIndex(index - 1)}
            style={{
              position: 'absolute',
              left: 16,
              width: 44,
              height: 44,
              borderRadius: '50%',
              background: 'rgba(0,0,0,0.5)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="chevron_left" size={26} color={AppColors.petalWhite} />
          </button>
        )}
        <img
          src={displayGalleryUrl(photo.imageUrl)}
          alt={photo.caption}
          style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', borderRadius: 12 }}
        />
        {index < photos.length - 1 && (
          <button
            type="button"
            className="bare-button"
            aria-label="Next photo"
            onClick={() => onChangeIndex(index + 1)}
            style={{
              position: 'absolute',
              right: 16,
              width: 44,
              height: 44,
              borderRadius: '50%',
              background: 'rgba(0,0,0,0.5)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="chevron_right" size={26} color={AppColors.petalWhite} />
          </button>
        )}
      </div>

      <div onClick={(e) => e.stopPropagation()} style={{ padding: '14px 20px 24px', textAlign: 'center' }}>
        <div style={{ ...AppTypography.bodyMedium, color: AppColors.petalWhite }}>
          {photo.caption || 'Memory photo'}
        </div>
        <div style={{ ...AppTypography.bodySmall, color: Derived.textMuted, marginTop: 4 }}>
          {photo.uploadedBy} ·{' '}
          {photo.uploadedAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
        </div>
      </div>
    </div>
  );
}

function AddPhotoModal({
  username,
  userId,
  onClose,
}: {
  username: string;
  userId: string;
  onClose: () => void;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [caption, setCaption] = useState('');
  const [tagsRaw, setTagsRaw] = useState('');
  const [locationName, setLocationName] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!file || saving) return;
    setSaving(true);
    try {
      const tags = tagsRaw
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
      await galleryService.uploadPhoto({
        file,
        caption: caption.trim(),
        uploadedBy: username,
        userId,
        tags,
        locationName: locationName.trim() || undefined,
      });
      showSnackBar('Memory added to Gallery');
      onClose();
    } catch {
      showSnackBar('Could not upload photo');
      setSaving(false);
    }
  };

  return (
    <div
      onClick={() => !saving && onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.65)',
        zIndex: 600,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 18,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 440,
          background: AppColors.velvet,
          borderRadius: 24,
          border: `1px solid ${Derived.border}`,
          padding: 22,
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{ ...AppTypography.titleLarge, color: AppColors.petalWhite }}>Add Memory Photo</div>
        <input
          type="file"
          accept="image/*"
          onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          style={{ ...AppTypography.bodySmall, color: AppColors.petalWhite }}
        />
        <input
          value={caption}
          onChange={(e) => setCaption(e.target.value)}
          placeholder="Write a sweet caption..."
          style={fieldStyle}
        />
        <input
          value={tagsRaw}
          onChange={(e) => setTagsRaw(e.target.value)}
          placeholder="Tags (comma-separated, e.g. date, sunset)"
          style={fieldStyle}
        />
        <input
          value={locationName}
          onChange={(e) => setLocationName(e.target.value)}
          placeholder="Place name (optional)"
          style={fieldStyle}
        />
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 6 }}>
          <EverglowButton label="Cancel" variant="ghost" onPressed={onClose} enabled={!saving} />
          <EverglowButton
            label={saving ? 'Uploading…' : 'Save Photo'}
            enabled={Boolean(file) && !saving}
            onPressed={() => void submit()}
          />
        </div>
      </div>
    </div>
  );
}

const fieldStyle = {
  width: '100%',
  padding: '11px 14px',
  borderRadius: 12,
  background: withAlpha(AppColors.inkDeep, 0.6),
  border: `1px solid ${Derived.border}`,
  color: AppColors.petalWhite,
  outline: 'none',
  fontSize: 14,
};

function EmptyBox({
  icon,
  variant = 'round',
  title,
  subtitle,
  cta,
  onCta,
}: {
  icon: string;
  variant?: 'round' | 'outlined';
  title: string;
  subtitle: string;
  cta?: string;
  onCta?: () => void;
}) {
  return (
    <div style={{ padding: 40, textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <Icon name={icon} variant={variant} size={46} color={withAlpha(AppColors.blushGold, 0.65)} />
      <div style={{ height: 12 }} />
      <div style={{ ...AppTypography.outfitBold, fontSize: 15 }}>{title}</div>
      <div style={{ height: 6 }} />
      <div style={{ ...AppTypography.bodySmall, maxWidth: 300, color: Derived.textMedium }}>{subtitle}</div>
      {cta && onCta && (
        <div style={{ marginTop: 18 }}>
          <EverglowButton label={cta} onPressed={onCta} />
        </div>
      )}
    </div>
  );
}
