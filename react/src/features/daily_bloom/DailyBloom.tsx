// Port of lib/features/daily_bloom/presentation/widgets/daily_bloom.dart
// + daily_bloom_cards.dart + daily_bloom_scene.dart + daily_bloom_stats.dart.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, letterSpacing, linear, radial, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { GardenPlantView } from './GardenPlantView';
import {
  PLANT_TYPES,
  effectiveStage,
  gardenStore,
  isPlantInSeason,
  plantFromId,
  type GardenStats,
  type PlantType,
} from './gardenService';

const STARS: Array<[number, number, number, number]> = [
  [0.08, 0.1, 1.6, 0.7], [0.18, 0.28, 1.2, 0.4], [0.3, 0.08, 1.9, 0.8], [0.42, 0.22, 1.1, 0.35],
  [0.55, 0.07, 1.5, 0.6], [0.66, 0.26, 1.2, 0.4], [0.76, 0.12, 1.8, 0.75], [0.88, 0.3, 1.3, 0.45],
  [0.93, 0.08, 1.5, 0.6], [0.24, 0.45, 1.0, 0.3], [0.62, 0.44, 1.0, 0.3], [0.84, 0.48, 1.1, 0.32],
];

export function DailyBloom() {
  const auth = useAuth();
  const navigate = useNavigate();
  const stats = useValue(gardenStore.stats);
  const partnerStats = useValue(gardenStore.partnerStats);
  const [tooltipSide, setTooltipSide] = useState<string | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);

  useEffect(() => {
    gardenStore.updateUserId(auth.uid);
    gardenStore.watchPartner(auth.partnerUid);
  }, [auth.uid, auth.partnerUid]);

  // dashboard_screen.dart `_syncGarden`: count today's visit 1.5s after the uid arrives.
  useEffect(() => {
    if (!auth.uid) return;
    const timer = window.setTimeout(() => void gardenStore.recordInteraction(), 1500);
    return () => window.clearTimeout(timer);
  }, [auth.uid]);

  const showTip = (side: string) => {
    setTooltipSide((cur) => (cur === side ? null : side));
    window.setTimeout(() => setTooltipSide((cur) => (cur === side ? null : cur)), 3000);
  };

  const isCouple = auth.isCoupleUser && auth.currentUser != null;
  const isKhent = auth.currentUser === 'khentsgdz';
  const khentStats = isCouple ? (isKhent ? stats : partnerStats) : null;
  const clairStats = isCouple ? (isKhent ? partnerStats : stats) : null;

  const khentPlant = khentStats ? plantFromId(khentStats.plantType) : PLANT_TYPES[0];
  const clairPlant = clairStats ? plantFromId(clairStats.plantType) : PLANT_TYPES[0];
  const khentStage = effectiveStage(khentPlant, khentStats?.currentStage ?? 0);
  const clairStage = effectiveStage(clairPlant, clairStats?.currentStage ?? 0);

  const singlePlant = stats ? plantFromId(stats.plantType) : PLANT_TYPES[0];
  const singleStage = effectiveStage(singlePlant, stats?.currentStage ?? 0);
  const singleStageName = singlePlant.stageDescriptions[Math.max(0, Math.min(5, singleStage))];

  return (
    <div style={{ padding: '6px 16px' }}>
      <div style={{ position: 'relative' }}>
        <div
          style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.35), blur: 24, offset: [0, 12] }, { radius: AppRadius.x2 })}
          aria-hidden
        />
        <div
          style={shadowLayer({ color: withAlpha(AppColors.auroraTeal, 0.06), blur: 30, offset: [0, 4] }, { radius: AppRadius.x2 })}
          aria-hidden
        />
        <div
          style={{
            position: 'relative',
            overflow: 'hidden',
            borderRadius: AppRadius.x2,
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.09)}`,
            background: linear([withAlpha(AppColors.velvet, 0.5), withAlpha(AppColors.inkDeep, 0.9)], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
          }}
        >
          <div style={{ padding: '18px 20px 0', display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: AppRadius.md,
                background: withAlpha(AppColors.auroraTeal, 0.12),
                border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.24)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="spa" size={19} color={AppColors.auroraTeal} />
            </div>
            <div style={{ width: 12 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...AppTypography.cormorantBold, fontSize: 20, lineHeight: 1 }}>Our Garden</div>
              <div style={{ height: 3 }} />
              <div
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 11,
                  color: withAlpha(AppColors.petalWhite, 0.48),
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {isCouple
                  ? khentStats || clairStats
                    ? `Clair's ${clairPlant.displayName} · Khent's ${khentPlant.displayName}`
                    : 'waking up…'
                  : stats
                    ? `${singlePlant.displayName} · ${singleStageName}`
                    : 'waking up…'}
              </div>
            </div>
          </div>

          <div style={{ padding: '14px 16px 0' }}>
            <div
              style={{
                position: 'relative',
                height: 240,
                borderRadius: AppRadius.lg,
                overflow: 'hidden',
                background: linear(
                  [AppColors.inkDeep, withAlpha(AppColors.plum, 0.55), withAlpha(AppColors.velvet, 0.85)],
                  { begin: Align.topCenter, end: Align.bottomCenter },
                ),
                border: `1px solid ${withAlpha(AppColors.moonlight, 0.07)}`,
              }}
            >
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: radial([withAlpha(AppColors.blushGold, 0.14), AppColors.transparent], {
                    center: [0.75, -0.75],
                    radius: 0.9,
                    size: [480, 240],
                  }),
                  pointerEvents: 'none',
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: radial([withAlpha(AppColors.auroraTeal, 0.13), AppColors.transparent], {
                    center: [0, 0.95],
                    radius: 0.75,
                    size: [480, 240],
                  }),
                  pointerEvents: 'none',
                }}
              />
              {STARS.map(([sx, sy, sr, sa], i) => (
                <div
                  key={i}
                  style={{
                    position: 'absolute',
                    left: `${sx * 100}%`,
                    top: `${sy * 100}%`,
                    width: sr * 2,
                    height: sr * 2,
                    borderRadius: '50%',
                    background: withAlpha(AppColors.petalWhite, sa * 0.6),
                    pointerEvents: 'none',
                  }}
                />
              ))}

              {isCouple ? (
                <div style={{ position: 'absolute', inset: 0, padding: '40px 0 34px', display: 'flex' }}>
                  <DualPlantSlot
                    name="Clair"
                    plant={clairPlant}
                    stage={clairStage}
                    ready={clairStats != null}
                    onTap={() => showTip('clair')}
                  />
                  <div
                    style={{
                      width: 1,
                      margin: '24px 0',
                      background: linear([AppColors.transparent, withAlpha(AppColors.moonlight, 0.18), AppColors.transparent], {
                        begin: Align.topCenter,
                        end: Align.bottomCenter,
                      }),
                    }}
                  />
                  <DualPlantSlot
                    name="Khent"
                    plant={khentPlant}
                    stage={khentStage}
                    ready={khentStats != null}
                    onTap={() => showTip('khent')}
                  />
                </div>
              ) : (
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => showTip('single')}
                  style={{ position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)', width: 190, height: 190 }}
                >
                  <GardenPlantView plantType={singlePlant} stage={singleStage} />
                </button>
              )}

              {tooltipSide != null && (
                <div
                  style={{
                    position: 'absolute',
                    top: 8,
                    left: 12,
                    right: 12,
                    display: 'flex',
                    justifyContent: 'center',
                    pointerEvents: 'none',
                  }}
                >
                  <div
                    style={{
                      maxWidth: 240,
                      padding: '10px 16px',
                      background: withAlpha(AppColors.inkDeep, 0.92),
                      borderRadius: 20,
                      border: `1.5px solid ${withAlpha(AppColors.blushGold, 0.65)}`,
                      textAlign: 'center',
                    }}
                  >
                    {(() => {
                      const p = tooltipSide === 'khent' ? khentPlant : tooltipSide === 'clair' ? clairPlant : singlePlant;
                      const st = tooltipSide === 'khent' ? khentStage : tooltipSide === 'clair' ? clairStage : singleStage;
                      return (
                        <>
                          <div style={{ ...AppTypography.outfitHeading, color: AppColors.blushGold, fontSize: 13 }}>
                            {p.stageDescriptions[Math.max(0, Math.min(5, st))]}
                          </div>
                          {isPlantInSeason(p) && (
                            <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.7), marginTop: 4 }}>
                              {p.seasonalBonusName} bonus active ✨
                            </div>
                          )}
                        </>
                      );
                    })()}
                  </div>
                </div>
              )}
            </div>
          </div>

          <div style={{ height: 12 }} />
          {isCouple ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
              <DualGrowthRow name="Clair" stage={clairStage} ready={clairStats != null} />
              <DualGrowthRow name="Khent" stage={khentStage} ready={khentStats != null} />
            </div>
          ) : (
            <SingleGrowthRow stage={singleStage} stageName={singleStageName} />
          )}

          <div style={{ height: 12 }} />
          <div style={{ padding: '0 20px 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
            {isCouple ? (
              <div style={{ display: 'flex', gap: 10 }}>
                <PersonStatTile name="Clair" isYou={!isKhent} stats={clairStats} />
                <PersonStatTile name="Khent" isYou={isKhent} stats={khentStats} />
              </div>
            ) : stats ? (
              <div style={{ display: 'flex', gap: 10 }}>
                <StatTile icon="local_fire_department" hue={AppColors.warmAmber} value={String(stats.streakCount)} label="day streak" />
                <StatTile icon="favorite" hue={AppColors.auroraRose} value={String(stats.totalInteractions)} label="visits" />
              </div>
            ) : null}

            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => navigate('/garden')}
                style={{
                  flex: 1,
                  height: 46,
                  borderRadius: 999,
                  background: linear([AppColors.deepRose, AppColors.roseDark], { begin: Align.topLeft, end: Align.bottomRight }),
                  border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 7,
                }}
              >
                <Icon name="park" size={16} color={AppColors.petalWhite} />
                <span style={{ ...AppTypography.outfitBold, fontSize: 13 }}>Our Garden</span>
                <Icon name="chevron_right" size={16} color={AppColors.petalWhite} />
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={() => setPickerOpen(true)}
                style={{
                  height: 46,
                  padding: '0 18px',
                  borderRadius: 999,
                  background: withAlpha(AppColors.moonlight, 0.05),
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                }}
              >
                <Icon name="swap_horiz" size={15} color={withAlpha(AppColors.petalWhite, 0.8)} />
                <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.85) }}>Change</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {pickerOpen && (
        <div
          onClick={() => setPickerOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'flex-end',
            justifyContent: 'center',
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 520,
              background: AppColors.velvet,
              borderRadius: '24px 24px 0 0',
              padding: 24,
            }}
          >
            <div style={{ ...AppTypography.cormorantBold, fontSize: 22, marginBottom: 14 }}>Choose your plant</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {PLANT_TYPES.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  className="bare-button"
                  onClick={() => {
                    void gardenStore.setPlantType(p.id);
                    setPickerOpen(false);
                  }}
                  style={{
                    padding: '12px 14px',
                    borderRadius: 14,
                    background: withAlpha(AppColors.moonlight, stats?.plantType === p.id ? 0.14 : 0.06),
                    border: `1px solid ${withAlpha(AppColors.blushGold, stats?.plantType === p.id ? 0.45 : 0.12)}`,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                  }}
                >
                  <span style={{ fontSize: 22 }}>{p.emoji}</span>
                  <span style={{ ...AppTypography.outfitBold, fontSize: 14 }}>{p.displayName}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function DualPlantSlot({
  name,
  plant,
  stage,
  ready,
  onTap,
}: {
  name: string;
  plant: PlantType;
  stage: number;
  ready: boolean;
  onTap: () => void;
}) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end' }}>
      <button
        type="button"
        className="bare-button"
        onClick={onTap}
        style={{ flex: 1, width: '100%', opacity: ready ? 1 : 0.45 }}
      >
        <GardenPlantView plantType={plant} stage={stage} />
      </button>
      <div style={{ height: 2 }} />
      <div
        style={{
          padding: '4px 12px',
          background: withAlpha(AppColors.inkDeep, 0.6),
          borderRadius: 999,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
        }}
      >
        <span style={{ ...AppTypography.outfitBold, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.85) }}>
          {ready ? `${name} · ${plant.displayName}` : `${name} · …`}
        </span>
      </div>
    </div>
  );
}

function SingleGrowthRow({ stage, stageName }: { stage: number; stageName: string }) {
  const filled = Math.max(0, Math.min(5, stage));
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      {[1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          style={{
            width: 8,
            height: 8,
            marginRight: i < 5 ? 7 : 0,
            borderRadius: '50%',
            background: i <= filled ? AppColors.auroraGold : withAlpha(AppColors.moonlight, 0.15),
            boxShadow: i <= filled ? `0 0 4px ${withAlpha(AppColors.auroraGold, 0.5)}` : undefined,
          }}
        />
      ))}
      <div style={{ width: 10 }} />
      <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.6) }}>
        Stage {filled} of 5 · {stageName}
      </span>
    </div>
  );
}

function DualGrowthRow({ name, stage, ready }: { name: string; stage: number; ready: boolean }) {
  const filled = ready ? Math.max(0, Math.min(5, stage)) : 0;
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <span style={{ width: 44, textAlign: 'right', ...AppTypography.outfitBold, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.55) }}>
        {name}
      </span>
      <div style={{ width: 8 }} />
      {[1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          style={{
            width: 7,
            height: 7,
            marginRight: i < 5 ? 5 : 0,
            borderRadius: '50%',
            background: i <= filled ? AppColors.auroraGold : withAlpha(AppColors.moonlight, 0.15),
            boxShadow: i <= filled ? `0 0 3.5px ${withAlpha(AppColors.auroraGold, 0.5)}` : undefined,
          }}
        />
      ))}
      <div style={{ width: 8 }} />
      <span style={{ width: 64, ...AppTypography.outfitBold, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.6) }}>
        {ready ? `Stage ${filled} of 5` : 'waking…'}
      </span>
    </div>
  );
}

function StatTile({ icon, hue, value, label }: { icon: string; hue: string; value: string; label: string }) {
  return (
    <div
      style={{
        flex: 1,
        padding: '11px 0',
        background: withAlpha(AppColors.moonlight, 0.06),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.09)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <Icon name={icon} size={15} color={hue} />
        <span style={{ ...AppTypography.outfitHeading, fontSize: 18, lineHeight: 1 }}>{value}</span>
      </div>
      <div style={{ height: 3 }} />
      <span style={{ ...AppTypography.outfitBold, fontSize: 10, ...letterSpacing(1.1), color: withAlpha(hue, 0.85) }}>
        {label}
      </span>
    </div>
  );
}

function PersonStatTile({ name, isYou, stats }: { name: string; isYou: boolean; stats: GardenStats | null }) {
  return (
    <div
      style={{
        flex: 1,
        padding: '10px 8px',
        background: withAlpha(AppColors.moonlight, 0.06),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.09)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ ...AppTypography.outfitBold, fontSize: 11, ...letterSpacing(1), color: withAlpha(AppColors.petalWhite, 0.75) }}>
          {name}
        </span>
        {isYou && (
          <span
            style={{
              padding: '1px 6px',
              borderRadius: 999,
              background: withAlpha(AppColors.auroraTeal, 0.16),
              ...AppTypography.outfitBold,
              fontSize: 9,
              color: AppColors.auroraTeal,
            }}
          >
            you
          </span>
        )}
      </div>
      <div style={{ height: 8 }} />
      {stats == null ? (
        <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.5) }}>
          waking…
        </span>
      ) : (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            <Icon name="local_fire_department" size={14} color={AppColors.warmAmber} />
            <span style={{ ...AppTypography.outfitHeading, fontSize: 16, lineHeight: 1 }}>{stats.streakCount}</span>
            <span style={{ ...AppTypography.outfitBold, fontSize: 9, color: withAlpha(AppColors.warmAmber, 0.85) }}>day streak</span>
          </div>
          <div style={{ height: 5 }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            <Icon name="favorite" size={13} color={AppColors.auroraRose} />
            <span style={{ ...AppTypography.outfitHeading, fontSize: 16, lineHeight: 1 }}>{stats.totalInteractions}</span>
            <span style={{ ...AppTypography.outfitBold, fontSize: 9, color: withAlpha(AppColors.auroraRose, 0.85) }}>visits</span>
          </div>
        </>
      )}
    </div>
  );
}
