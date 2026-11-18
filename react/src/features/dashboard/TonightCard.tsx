// Port of lib/features/dashboard/presentation/widgets/tonight_card.dart.
import { useNavigate } from 'react-router';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import {
  isMatch,
  isTied,
  tonightService,
  winningOption,
  type TonightDecision,
  type TonightOption,
} from '../tonight/tonightService';
import { FeatureSection } from './FeatureSection';

export function TonightCard() {
  const navigate = useNavigate();
  const decision = useSource(() => tonightService.watchActiveDecision(), [], null);

  return (
    <FeatureSection
      icon="bedtime"
      hue={AppColors.roseQuartz}
      title="Tonight"
      subtitle="A little time for us"
      onTap={() => navigate('/tonight')}
      trailing={
        <Tooltip message="Choose tonight">
          <button
            type="button"
            className="bare-button"
            aria-label="Choose tonight"
            onClick={(e) => {
              e.stopPropagation();
              navigate('/tonight');
            }}
            style={{ padding: 8, borderRadius: '50%', display: 'flex' }}
          >
            <Icon name="arrow_forward" size={24} color={AppColors.roseQuartz} />
          </button>
        </Tooltip>
      }
    >
      {!decision || decision.options.length === 0 ? (
        <ReadyState onStart={() => navigate('/tonight')} />
      ) : decision.status !== 'voting' && winningOption(decision) ? (
        <WinnerState decision={decision} onGo={(r) => navigate(r)} />
      ) : (
        <VotingState decision={decision} />
      )}
    </FeatureSection>
  );
}

function ReadyState({ onStart }: { onStart: () => void }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      <span style={{ ...AppTypography.bodyMedium, lineHeight: 1.4 }}>
        A movie, a date, or a little friendly competition. Let&rsquo;s find our evening.
      </span>
      <div style={{ height: AppSpacing.md }} />
      <EverglowButton
        label="Find our tonight"
        icon="auto_awesome"
        backgroundColor={AppColors.roseQuartz}
        foregroundColor={AppColors.inkDeep}
        onPressed={onStart}
      />
    </div>
  );
}

function VotingState({ decision }: { decision: TonightDecision }) {
  const voteCount = Object.keys(decision.votes).length;
  const status =
    voteCount === 0
      ? 'Three ideas. Which one feels like us?'
      : isTied(decision)
        ? 'Two different picks · Choose together'
        : voteCount === 1
          ? 'One wish is in · Waiting for the other'
          : 'Both wishes are in';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
      <span style={{ ...AppTypography.bodySmall, color: AppColors.blushGold }}>{status}</span>
      <div style={{ height: AppSpacing.md }} />
      {decision.options.map((opt) => (
        <div key={opt.id} style={{ marginBottom: AppSpacing.sm }}>
          <OptionSummary option={opt} decision={decision} />
        </div>
      ))}
    </div>
  );
}

function WinnerState({ decision, onGo }: { decision: TonightDecision; onGo: (route: string) => void }) {
  const winner = winningOption(decision)!;
  const planned = decision.status === 'planned';
  const hue = planned ? AppColors.auroraTeal : AppColors.blushGold;
  const time = decision.planTime
    ? decision.planTime.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
    : 'Tonight';
  const label = !planned
    ? 'Save our plan'
    : winner.type === 'movie'
      ? 'Open Cinema'
      : winner.type === 'game'
        ? 'Play together'
        : 'View Calendar';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      <span style={{ ...AppTypography.labelMedium, color: hue }}>
        {planned ? `Our evening · ${time}` : isMatch(decision) ? 'It’s a match.' : 'Our pick for tonight'}
      </span>
      <div style={{ height: AppSpacing.sm }} />
      <span style={{ ...AppTypography.cormorantHeading, fontSize: 24, color: AppColors.petalWhite }}>
        {winner.title}
      </span>
      <div style={{ height: AppSpacing.md }} />
      <EverglowButton
        label={label}
        icon={planned ? 'arrow_forward' : 'calendar_month'}
        backgroundColor={hue}
        foregroundColor={AppColors.inkDeep}
        onPressed={() => onGo(planned ? (winner.targetRoute ?? '/calendar') : '/tonight')}
      />
    </div>
  );
}

function OptionSummary({ option, decision }: { option: TonightOption; decision: TonightDecision }) {
  const votes = Object.values(decision.votes).filter((v) => v === option.id).length;
  const hue =
    option.type === 'movie'
      ? AppColors.auroraLilac
      : option.type === 'date'
        ? AppColors.roseQuartz
        : AppColors.blushGold;
  const icon =
    option.type === 'movie' ? 'movie' : option.type === 'date' ? 'favorite_border' : 'sports_esports';

  return (
    <div
      style={{
        padding: '10px 12px',
        background: withAlpha(hue, 0.06),
        borderRadius: AppRadius.md,
        border: `1px solid ${votes > 0 ? withAlpha(hue, 0.45) : Derived.border}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={icon} variant="outlined" size={18} color={hue} />
      <div style={{ width: AppSpacing.sm }} />
      <span
        className="clamp-2"
        style={{
          ...AppTypography.bodySmall,
          color: Derived.textHigh,
          flex: 1,
        }}
      >
        {option.title}
      </span>
      {votes > 0 && (
        <>
          <div style={{ width: AppSpacing.sm }} />
          <span style={{ ...AppTypography.labelSmall, color: hue }}>{votes}</span>
        </>
      )}
    </div>
  );
}
