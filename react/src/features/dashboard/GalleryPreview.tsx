// Port of lib/features/dashboard/presentation/widgets/gallery_preview.dart.
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { displayGalleryUrl, galleryService, type MemoryPhoto } from '../gallery/galleryService';
import { FeatureSection, SectionChevron } from './FeatureSection';
import { ShelfCard } from './ShelfWidgets';

export function GalleryPreview() {
  const navigate = useNavigate();
  const photos = useSource<MemoryPhoto[] | null>(() => galleryService.getRecentPhotos(6), [], null);

  return (
    <div style={{ padding: '6px 16px' }}>
      <FeatureSection
        icon="photo_library"
        hue={AppColors.roseQuartz}
        title="Memory Gallery"
        subtitle={
          photos == null
            ? 'loading photos…'
            : photos.length === 0
              ? 'no photos yet'
              : `${photos.length} ${photos.length === 1 ? 'photo' : 'photos'}`
        }
        trailing={<SectionChevron />}
        onTap={() => navigate('/gallery')}
      >
        {photos == null ? (
          <div style={{ height: 120, borderRadius: 14, background: AppColors.shimmerBase }} />
        ) : photos.length === 0 ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <Icon name="add_circle_outline" size={18} color={AppColors.roseQuartz} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6) }}>
              Add the first memory to the album
            </span>
          </div>
        ) : (
          <div className="no-scrollbar" style={{ overflowX: 'auto', height: 194 }}>
            <div style={{ display: 'flex', gap: 12, width: 'max-content' }}>
              {photos.slice(0, 12).map((p) => (
                <ShelfCard
                  key={p.id}
                  accent="gallery"
                  imageUrl={displayGalleryUrl(p.thumbUrl || p.imageUrl)}
                  title=""
                  onTap={() => navigate('/gallery')}
                />
              ))}
            </div>
          </div>
        )}
      </FeatureSection>
    </div>
  );
}
