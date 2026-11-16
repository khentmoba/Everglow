// Port of lib/features/daily_bloom/presentation/widgets/shared_garden_view.dart.
import { useEffect } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { letterSpacing } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { Icon } from '../../shared/widgets/Icon';
import { GardenPlantView } from './GardenPlantView';
import {
  PLANT_TYPES,
  effectiveStage,
  gardenStore,
  isPlantInSeason,
  plantFromId,
  type GardenStats,
} from './gardenService';

export function GardenPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const { width } = useViewport();
  const stats = useValue(gardenStore.stats);
  const partnerStats = useValue(gardenStore.partnerStats);

  useEffect(() => {
    gardenStore.updateUserId(auth.uid);
    gardenStore.watchPartner(auth.partnerUid);
  }, [auth.uid, auth.partnerUid]);

  const myName = auth.currentUser === 'khentsgdz' ? 'Khent' : 'Clair';
  const partnerName = auth.partnerName || (auth.currentUser === 'khentsgdz' ? 'Clair' : 'Khent');
  const isWide = width > 500;

  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden' }}>
      <EverglowBackground baseColor={AppColors.inkDeep} />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          overflowY: 'auto',
          paddingBottom: 24,
        }}
      >
        <div
          style={{
            padding: '8px 16px 0',
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <button
            type="button"
            className="bare-button"
            aria-label="Back to dashboard"
            onClick={() => navigate('/dashboard')}
            style={{
              width: 48,
              height: 48,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="arrow_back_ios_new" size={20} color={AppColors.roseQuartz} />
          </button>
          <div style={{ flex: 1 }} />
          <div
            style={{
              ...AppTypography.cormorantBold,
              fontSize: 22,
              ...letterSpacing(1.5),
            }}
          >
            Our Garden
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ width: 48 }} />
        </div>

        <div style={{ height: 16 }} />

        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: isWide ? 'row' : 'column',
            gap: 16,
            padding: '0 16px',
            minHeight: isWide ? 360 : 520,
          }}
        >
          <GardenCard name={myName} stats={stats} />
          <GardenCard name={partnerName} stats={partnerStats} />
        </div>
      </div>
    </div>
  );
}

function GardenCard({ name, stats }: { name: string; stats: GardenStats | null }) {
  const plantType = stats ? plantFromId(stats.plantType) : PLANT_TYPES[0];
  const stage = stats?.currentStage ?? 0;
  const effStage = effectiveStage(plantType, stage);

  return (
    <div
      style={{
        flex: 1,
        background: withAlpha(AppColors.moonlight, 0.08),
        borderRadius: 20,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px 16px',
      }}
    >
      <div style={{ ...AppTypography.cormorantBold, fontSize: 18 }}>{name}</div>
      <div style={{ height: 4 }} />
      {isPlantInSeason(plantType) && (
        <div
          style={{
            padding: '2px 8px',
            borderRadius: 10,
            background: withAlpha(AppColors.blushGold, 0.15),
            ...AppTypography.outfitHeading,
            fontSize: 10,
            color: AppColors.blushGold,
          }}
        >
          {plantType.seasonalBonusName} ✨
        </div>
      )}
      <div style={{ height: 12 }} />
      <div style={{ width: 150, height: 150 }}>
        <GardenPlantView plantType={plantType} stage={effStage} />
      </div>
      <div style={{ height: 8 }} />
      {stats && (
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 11,
            color: withAlpha(AppColors.petalWhite, 0.6),
          }}
        >
          {stats.streakCount} day streak · {stats.totalInteractions} visits
        </div>
      )}
    </div>
  );
}
