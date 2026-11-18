// Port of lib/features/daily_bloom/presentation/widgets/shared_garden_view.dart.
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { useEffect } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
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
    gardenStore.watchPartner(auth.partnerUid);
  }, [auth.partnerUid]);
  useEffect(() => () => gardenStore.stopWatchingPartner(), []);

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
        }}
      >
        <EverglowFeatureHeader
          title="Our Garden"
          subtitle="a little bloom for each of us"
          icon="local_florist"
          hue={AppColors.auroraTeal}
          onBack={() => navigate('/dashboard')}
        />

        <div style={{ height: 16 }} />

        <div
          style={{
            flex: 1,
            minHeight: 0,
            overflowY: 'auto',
            display: 'flex',
            flexDirection: isWide ? 'row' : 'column',
            alignItems: isWide ? 'flex-start' : 'stretch',
            gap: 14,
            paddingBottom: 24,
          }}
        >
          <GardenCard name={myName} stats={stats} wide={isWide} />
          <GardenCard name={partnerName} stats={partnerStats} wide={isWide} />
        </div>
      </div>
    </div>
  );
}

function GardenCard({ name, stats, wide }: { name: string; stats: GardenStats | null; wide: boolean }) {
  const plantType = stats ? plantFromId(stats.plantType) : PLANT_TYPES[0];
  const stage = stats?.currentStage ?? 0;
  const effStage = effectiveStage(plantType, stage);

  const maxStage = plantType.stageDescriptions.length - 1;
  const stageLabel = plantType.stageDescriptions[Math.min(effStage, maxStage)];
  const seasonal = isPlantInSeason(plantType);
  return (
    <div
      style={{
        flex: wide ? '1 1 0' : '0 0 auto',
        margin: '0 16px',
        padding: wide ? '22px 18px' : '16px 16px 16px 10px',
        boxSizing: 'border-box',
        borderRadius: 24,
        background: `linear-gradient(160deg, ${withAlpha(AppColors.auroraTeal, 0.1)}, ${withAlpha(AppColors.inkDeep, 0.55)} 70%)`,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.auroraTeal, 0.18)}, 0 12px 28px ${withAlpha(AppColors.inkDeep, 0.45)}`,
        display: 'flex',
        flexDirection: wide ? 'column' : 'row',
        alignItems: 'center',
        gap: wide ? 14 : 12,
        overflow: 'hidden',
      }}
    >
      <div style={{ position: 'relative', width: wide ? 190 : 150, height: wide ? 190 : 150, flex: '0 0 auto' }}>
        <div
          aria-hidden
          style={{
            position: 'absolute',
            left: '8%',
            right: '8%',
            bottom: 2,
            height: '18%',
            borderRadius: '50%',
            background: `radial-gradient(ellipse at center, ${withAlpha(AppColors.auroraTeal, 0.28)}, transparent 70%)`,
          }}
        />
        <GardenPlantView plantType={plantType} stage={effStage} />
      </div>
      <div style={{ flex: 1, minWidth: 0, width: wide ? '100%' : undefined, textAlign: wide ? 'center' : 'left' }}>
        <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 24, lineHeight: 1.05 }}>{name}</div>
        <div style={{ ...AppTypography.handwrittenBody, fontSize: 17, color: withAlpha(AppColors.auroraTeal, 0.95), marginTop: 2 }}>
          {plantType.emoji} {plantType.displayName.toLowerCase()} · {stageLabel.toLowerCase()}
        </div>
        {seasonal && (
          <div style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.blushGold, marginTop: 4 }}>
            {plantType.seasonalBonusName} ✨
          </div>
        )}
        <div
          role="progressbar"
          aria-label={`${name}'s plant growth`}
          aria-valuemin={0}
          aria-valuemax={maxStage}
          aria-valuenow={effStage}
          style={{ display: 'flex', gap: 4, marginTop: 10, justifyContent: wide ? 'center' : 'flex-start' }}
        >
          {Array.from({ length: maxStage }, (_, i) => (
            <span
              key={i}
              style={{
                flex: wide ? '0 0 22px' : 1,
                maxWidth: 34,
                height: 5,
                borderRadius: 3,
                background: i < effStage ? AppColors.auroraTeal : withAlpha(AppColors.petalWhite, 0.12),
              }}
            />
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 12, justifyContent: wide ? 'center' : 'flex-start' }}>
          <GardenStat value={stats?.streakCount ?? 0} label="day streak" />
          <GardenStat value={stats?.totalInteractions ?? 0} label="visits" />
        </div>
      </div>
    </div>
  );
}

function GardenStat({ value, label }: { value: number; label: string }) {
  return (
    <div
      style={{
        padding: '6px 10px',
        borderRadius: 12,
        background: withAlpha(AppColors.petalWhite, 0.05),
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.petalWhite, 0.08)}`,
        display: 'flex',
        alignItems: 'baseline',
        gap: 5,
      }}
    >
      <span style={{ ...AppTypography.outfitBold, fontSize: 15, color: AppColors.petalWhite }}>{value}</span>
      <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.6) }}>{label}</span>
    </div>
  );
}
