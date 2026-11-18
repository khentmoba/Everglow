// Port of lib/features/subs/presentation/screens/subs_screen.dart.
import { useState, type ReactNode } from 'react';
import { authService } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { formatPeso } from '../../shared/utils/text';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { AddSubSheet } from './AddSubSheet';
import { SubCard } from './SubCard';
import { daysUntilRenewal, monthlyCost, subsService, type Subscription } from './subsService';

function showAddSheet(existing: Subscription | null) {
  const createdBy = authService.currentUser ?? 'unknown';
  void showModalBottomSheet<void>((close) => <AddSubSheet createdBy={createdBy} existing={existing} close={() => close(null)} />);
}

function Constrained({ children }: { children: ReactNode }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div style={{ width: '100%', maxWidth: 720, display: 'flex', flexDirection: 'column' }}>{children}</div>
    </div>
  );
}

export function SubsPage() {
  const [retry, setRetry] = useState(0);
  return (
    <EverglowScaffold backgroundColor={AppColors.inkDeep} floatingActionButton={<TrackFab onTap={() => showAddSheet(null)} />}>
      <EverglowFeatureHeader title="Subscriptions" subtitle="where the money goes" icon="subscriptions" hue={AppColors.blushGold} />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <EverglowStreamView
          source={() => subsService.watchAll()}
          sourceKey={[retry]}
          label="subs"
          errorMessage="Could not load subscriptions"
          onRetry={() => setRetry((r) => r + 1)}
          loadingView={<LoadingSubs />}
          builder={(all) => {
            const items = [...all].sort((a, b) => daysUntilRenewal(a) - daysUntilRenewal(b));
            return (
              <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                <Constrained>
                  <SubsMoneyHero all={all} />
                </Constrained>
                <div style={{ height: 4, flexShrink: 0 }} />
                <div style={{ flex: 1, minHeight: 0 }}>
                  {all.length === 0 ? (
                    <EverglowEmptyState
                      icon="subscriptions_outlined"
                      title="No subscriptions yet"
                      subtitle="Track Netflix, Spotify, iCloud…"
                      ctaLabel="Track one"
                      onCta={() => showAddSheet(null)}
                    />
                  ) : (
                    <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto', overflowX: 'hidden' }}>
                      <Constrained>
                        <div style={{ padding: '4px 16px 96px' }}>
                          {items.map((s) => (
                            <SubCard key={s.id} sub={s} onTap={() => showAddSheet(s)} />
                          ))}
                        </div>
                      </Constrained>
                    </div>
                  )}
                </div>
              </div>
            );
          }}
        />
      </div>
    </EverglowScaffold>
  );
}

function heroSubtitle(count: number, soonest: Subscription | null) {
  if (count === 0) return 'Nothing tracked yet — add your first sub below';
  const noun = count === 1 ? 'subscription' : 'subscriptions';
  if (soonest == null) return `across ${count} ${noun}`;
  const days = daysUntilRenewal(soonest);
  const when = days <= 0 ? 'renews today' : days === 1 ? 'renews tomorrow' : `renews in ${days} days`;
  return `across ${count} ${noun} · ${soonest.name} ${when}`;
}

export function SubsMoneyHero({ all }: { all: Subscription[] }) {
  const monthly = all.reduce((sum, s) => sum + monthlyCost(s), 0);
  const soonest = all.length === 0 ? null : all.reduce((a, b) => (daysUntilRenewal(a) <= daysUntilRenewal(b) ? a : b));
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <div style={{ padding: '4px 16px 10px' }}>
      <div
        ref={ref}
        style={{
          padding: '18px 20px 16px',
          background: linear([AppColors.silk, AppColors.velvet, AppColors.inkDeep], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            stops: [0, 0.45, 1],
            size,
          }),
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div style={{ ...AppTypography.handwrittenBody, fontSize: 19, lineHeight: 1.1, color: withAlpha(AppColors.blushGold, 0.9) }}>every month</div>
        <div style={{ height: 4 }} />
        <div style={{ ...AppTypography.cormorantBold, fontSize: 38, lineHeight: '38px', color: AppColors.petalWhite }}>
          {formatPeso(Math.round(monthly))}
        </div>
        <div style={{ height: 4 }} />
        <div style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: withAlpha(AppColors.petalWhite, 0.62) }}>
          {heroSubtitle(all.length, soonest)}
        </div>
      </div>
    </div>
  );
}

function TrackFab({ onTap }: { onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Track a new subscription"
      onClick={onTap}
      style={{
        padding: '14px 20px',
        background: linear([AppColors.deepRose, AppColors.rosePressed]),
        borderRadius: AppRadius.full,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.35), blur: 20, offset: [0, 8] }]),
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name="add" size={18} color={AppColors.petalWhite} />
      <div style={{ width: 6 }} />
      <span style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14), color: AppColors.petalWhite }}>Track</span>
    </button>
  );
}

function LoadingSubs() {
  return (
    <div style={{ padding: '4px 16px 24px', display: 'flex', flexDirection: 'column' }}>
      <EverglowSkeleton height={150} radius={24} />
      <div style={{ height: 12 }} />
      <EverglowSkeleton height={76} radius={20} />
      <div style={{ height: 10 }} />
      <EverglowSkeleton height={76} radius={20} />
      <div style={{ height: 10 }} />
      <EverglowSkeleton height={76} radius={20} />
    </div>
  );
}
