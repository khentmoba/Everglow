// Port of lib/features/tonight/presentation/screens/tonight_screen.dart.
import { useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, letterSpacing, lineHeight, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowCard } from '../../shared/widgets/EverglowCard';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import {
  isMatch,
  isTied,
  tonightService,
  winningOption,
  type EveningEnergy,
  type TonightDecision,
  type TonightOption,
  type TonightPreferences,
} from './tonightService';

const DEFAULT_PREFS: TonightPreferences = { minutes: null, goingOut: false, energy: 'quiet' };
// ColorScheme.fromSeed(deepRose, dark): the chip and tile colours Material picks.
const M3 = { secondaryContainer: '#5B3F45', onSecondaryContainer: '#FFD9DF' };

function defaultPlanTime(): Date {
  const now = new Date();
  const h = now.getHours() >= 20 ? now.getHours() + 1 : 20;
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, 0);
}

function slotTime(hour: number): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, 0);
}

/** DateFormat('h:mm a'). */
function hmma(d: Date): string {
  const h = d.getHours() % 12 || 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
}

function typeLabel(t: TonightOption['type']): string {
  return t === 'movie' ? 'Movie' : t === 'date' ? 'Date Idea' : 'Game';
}

export function TonightPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const { width } = useViewport();
  const currentUsername = auth.currentUser ?? 'khentsgdz';
  const partnerName = auth.partnerName;

  const decision = useSource<TonightDecision | null | undefined>(() => tonightService.watchActiveDecision(), [], undefined);

  const [shuffling, setShuffling] = useState(false);
  const [shuffleError, setShuffleError] = useState<string | null>(null);
  const [prefs, setPrefs] = useState<TonightPreferences>(DEFAULT_PREFS);
  const [prefsLoaded, setPrefsLoaded] = useState(false);
  const [planTime, setPlanTime] = useState(defaultPlanTime);
  const [makingPlan, setMakingPlan] = useState(false);

  if (!prefsLoaded && decision) {
    setPrefsLoaded(true);
    setPrefs(decision.preferences ?? DEFAULT_PREFS);
  }

  const handleShuffle = async () => {
    if (shuffling) return;
    setShuffling(true);
    setShuffleError(null);
    try {
      await tonightService.createOrShuffle(prefs, true);
    } catch {
      setShuffleError('Could not save new picks. Your previous picks are safe. Try again.');
    } finally {
      setShuffling(false);
    }
  };

  const handleVote = (optionId: string) => {
    if (!auth.currentUser) return;
    void tonightService.castVote(auth.currentUser, optionId);
  };

  const handleDecide = (optionId: string) => void tonightService.decideWinner(optionId);

  const handleFlipCoin = async (d: TonightDecision) => {
    const k = d.votes.khentsgdz;
    const c = d.votes.clairjassen;
    if (!k || !c) return;
    await tonightService.decideWinner(Math.random() < 0.5 ? k : c);
  };

  const handleMakePlan = async (option: TonightOption) => {
    setMakingPlan(true);
    const event = await tonightService.makePlan(option, planTime, currentUsername).catch(() => null);
    setMakingPlan(false);
    showSnackBar(event ? 'Tonight’s plan added to your Calendar! 📅✨' : 'Couldn’t save the plan. Please try again.', {
      background: AppColors.velvet,
      duration: 3000,
    });
  };

  const preferences = (
    <PreferencesPanel
      prefs={prefs}
      setPrefs={setPrefs}
      shuffling={shuffling}
      shuffleError={shuffleError}
      onShuffle={() => void handleShuffle()}
    />
  );

  let body: ReactNode;
  if (decision === undefined) {
    body = (
      <div style={{ height: '100%', display: 'flex', justifyContent: 'center' }}>
        <div
          style={{
            width: '100%',
            maxWidth: 880,
            padding: AppSpacing.lg,
            boxSizing: 'border-box',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
          }}
        >
          <EverglowSkeleton height={60} />
          <div style={{ height: AppSpacing.lg }} />
          <EverglowSkeleton height={220} />
        </div>
      </div>
    );
  } else if (decision == null || decision.options.length === 0) {
    body = (
      <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto' }}>
        <div
          style={{
            maxWidth: 480,
            margin: '0 auto',
            padding: AppSpacing.xl,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
          }}
        >
          <div
            style={{
              width: 72,
              height: 72,
              borderRadius: '50%',
              background: withAlpha(AppColors.auroraRose, 0.12),
              boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.auroraRose, 0.3)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="auto_awesome" size={36} color={AppColors.auroraRose} />
          </div>
          <div style={{ height: AppSpacing.lg }} />
          <div style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.moonlight, textAlign: 'center' }}>
            “What should we do tonight?”
          </div>
          <div style={{ height: AppSpacing.sm }} />
          <div style={{ ...AppTypography.bodyMedium, color: withAlpha(AppColors.moonlight, 0.7), textAlign: 'center' }}>
            Choose what suits your evening, then find three ideas.
          </div>
          <div style={{ height: AppSpacing.xl }} />
          <div style={{ alignSelf: 'stretch' }}>{preferences}</div>
          <EverglowButton
            label="Roll Suggestions"
            icon="casino"
            backgroundColor={AppColors.auroraRose}
            foregroundColor={AppColors.inkDeep}
            enabled={!shuffling}
            onPressed={() => void handleShuffle()}
          />
        </div>
      </div>
    );
  } else {
    const winner = winningOption(decision);
    const p = decision.preferences ?? DEFAULT_PREFS;
    const pageH = AppSpacing.pageH(width);
    const contentWidth = Math.min(960, width - pageH * 2);
    body = (
      <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto' }}>
        <div style={{ padding: `${AppSpacing.md}px ${pageH}px ${AppSpacing.x3}px`, display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: '100%', maxWidth: 960, display: 'flex', flexDirection: 'column' }}>
            {decision.status === 'voting' && (
              <>
                <div style={{ ...AppTypography.labelSmall, color: AppColors.blushGold, ...letterSpacing(2) }}>
                  JUST US, TONIGHT
                </div>
                <div style={{ height: AppSpacing.sm }} />
                <div
                  style={{
                    ...AppTypography.cormorantBoldWhite,
                    fontSize: 36,
                    lineHeight: lineHeight(36, 1.1),
                  }}
                >
                  A little time for us.
                </div>
                <div style={{ height: AppSpacing.sm }} />
                <div style={AppTypography.bodyMedium}>A movie, a date, or a little friendly competition.</div>
                <div style={{ height: AppSpacing.lg }} />
                <ExpansionTile
                  title="What suits tonight?"
                  subtitle={`${p.minutes == null ? 'No time limit' : `${p.minutes} minutes`} / ${p.goingOut ? 'Go out' : 'Stay in'} / ${p.energy}`}
                >
                  {preferences}
                </ExpansionTile>
              </>
            )}
            <LiveStatusBar
              decision={decision}
              currentUsername={currentUsername}
              partnerName={partnerName}
              onFlipCoin={() => void handleFlipCoin(decision)}
            />
            <div style={{ height: AppSpacing.lg }} />
            {decision.status !== 'voting' && winner ? (
              <TonightOptionCard
                option={winner}
                decision={decision}
                currentUsername={currentUsername}
                compact
                onVote={handleVote}
                onDecideDirectly={handleDecide}
              />
            ) : contentWidth >= 840 ? (
              <div style={{ display: 'flex', alignItems: 'stretch', gap: AppSpacing.md }}>
                {decision.options.map((opt) => (
                  <div key={opt.id} style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
                    <TonightOptionCard
                      option={opt}
                      decision={decision}
                      currentUsername={currentUsername}
                      compact={false}
                      onVote={handleVote}
                      onDecideDirectly={handleDecide}
                    />
                  </div>
                ))}
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                {decision.options.map((opt) => (
                  <div key={opt.id} style={{ marginBottom: AppSpacing.md }}>
                    <TonightOptionCard
                      option={opt}
                      decision={decision}
                      currentUsername={currentUsername}
                      compact
                      onVote={handleVote}
                      onDecideDirectly={handleDecide}
                    />
                  </div>
                ))}
              </div>
            )}
            <div style={{ height: AppSpacing.xl }} />
            {decision.status === 'decided' && winner ? (
              <MakePlanSection
                option={winner}
                planTime={planTime}
                setPlanTime={setPlanTime}
                makingPlan={makingPlan}
                onMakePlan={() => void handleMakePlan(winner)}
              />
            ) : decision.status === 'planned' && winner ? (
              <PlanSuccessSection
                decision={decision}
                winner={winner}
                shuffling={shuffling}
                onOpen={(route) => navigate(route)}
                onShuffle={() => void handleShuffle()}
              />
            ) : null}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraRose, alignment: [-0.85, -0.75], size: 0.9, opacity: 0.14 },
          { color: AppColors.auroraGold, alignment: [0.85, -0.4], size: 0.85, opacity: 0.12 },
          { color: AppColors.auroraTeal, alignment: [0.0, 0.9], size: 0.8, opacity: 0.1 },
        ]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          paddingTop: 'env(safe-area-inset-top)',
          paddingBottom: 'env(safe-area-inset-bottom)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <EverglowFeatureHeader
          title="Tonight"
          subtitle="An evening for two"
          hue={AppColors.auroraRose}
          actions={[
            <MaterialIconButton
              key="shuffle"
              tooltip={shuffling ? 'Finding new picks…' : 'Shuffle picks'}
              color={AppColors.roseQuartz}
              onPressed={shuffling ? undefined : () => void handleShuffle()}
            >
              {shuffling ? (
                <CircularProgress size={20} strokeWidth={2} color={AppColors.deepRose} />
              ) : (
                <Icon name="shuffle" variant="filled" size={24} color={AppColors.roseQuartz} />
              )}
            </MaterialIconButton>,
          ]}
        />
        <div style={{ flex: 1, minHeight: 0 }}>{body}</div>
      </div>
    </div>
  );
}

/** Material 3 ExpansionTile: a two-line ListTile that opens its children below. */
function ExpansionTile({ title, subtitle, children }: { title: string; subtitle: string; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const [hovered, setHovered] = useState(false);
  const line = open ? M3Scheme.outline : 'transparent';
  return (
    <div style={{ padding: '1px 0', boxShadow: `inset 0 1px 0 ${line}, inset 0 -1px 0 ${line}`, transition: 'box-shadow 200ms' }}>
      <button
        type="button"
        className="bare-button"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          width: '100%',
          height: 72,
          padding: '0 24px 2px 16px',
          display: 'flex',
          alignItems: 'center',
          textAlign: 'left',
          background: hovered ? withAlpha(M3Scheme.onSurface, 0.08) : 'transparent',
        }}
      >
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.bodyLarge,
              color: M3Scheme.onSurface,
              lineHeight: lineHeight(16, 1.5),
              ...letterSpacing(0.5),
            }}
          >
            {title}
          </div>
          <div style={{ ...AppTypography.bodyMedium, color: M3Scheme.onSurface }}>{subtitle}</div>
        </div>
        <div style={{ width: 16 }} />
        <span style={{ display: 'flex', transform: `rotate(${open ? 180 : 0}deg)`, transition: 'transform 200ms ease-in' }}>
          <Icon name="expand_more" variant="filled" size={24} color={open ? AppColors.deepRose : M3Scheme.onSurfaceVariant} />
        </span>
      </button>
      <div style={{ display: 'grid', gridTemplateRows: open ? '1fr' : '0fr', transition: 'grid-template-rows 200ms ease-in' }}>
        <div style={{ overflow: 'hidden' }}>{open && children}</div>
      </div>
    </div>
  );
}

/** Material 3 ChoiceChip with the app's chip theme, inside its 48px tap slot. */
function ChoiceChip({
  label,
  selected,
  onSelected,
  enabled = true,
  showCheckmark = true,
  selectedColor = M3.secondaryContainer,
  backgroundColor = Derived.surfaceGlass,
  labelColor = AppColors.petalWhite,
  labelWeight = 500,
  labelSize = 14,
}: {
  label: string;
  selected: boolean;
  onSelected: () => void;
  enabled?: boolean;
  showCheckmark?: boolean;
  selectedColor?: string;
  backgroundColor?: string;
  labelColor?: string;
  labelWeight?: number;
  labelSize?: number;
}) {
  const [hovered, setHovered] = useState(false);
  const check = selected && showCheckmark;
  const checkColor = M3.onSecondaryContainer;
  return (
    <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
      <button
        type="button"
        className="bare-button"
        role="radio"
        aria-checked={selected}
        disabled={!enabled}
        onClick={onSelected}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          height: 36,
          padding: `0 17px 0 ${check ? 9 : 17}px`,
          borderRadius: AppRadius.full,
          // The chip is a Material on the scheme surface, so a see-through fill sits on twilight.
          background: selected ? selectedColor : `linear-gradient(${backgroundColor}, ${backgroundColor}), ${AppColors.twilight}`,
          // The theme side is painted twice (shape outline + chip border): 0.18 twice is 0.33.
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.3276)}`,
          display: 'flex',
          alignItems: 'center',
          overflow: 'hidden',
          opacity: enabled ? 1 : 0.38,
        }}
      >
        {hovered && enabled && (
          <span aria-hidden style={{ position: 'absolute', inset: 0, background: withAlpha(M3Scheme.onSurfaceVariant, 0.08) }} />
        )}
        {check && (
          <>
            <svg width={18} height={18} viewBox="0 0 18 18" style={{ flexShrink: 0 }} aria-hidden>
              <path d="M2.7 8.1 L7.2 12.6 L15.3 4.5" fill="none" stroke={checkColor} strokeWidth={1.5} />
            </svg>
            <div style={{ width: 8 }} />
          </>
        )}
        <span
          style={{
            fontFamily: AppTypography.titleSmall.fontFamily,
            fontSize: labelSize,
            fontWeight: labelWeight,
            color: labelColor,
            lineHeight: lineHeight(labelSize),
            whiteSpace: 'nowrap',
            ...letterSpacing(0.1),
          }}
        >
          {label}
        </span>
      </button>
    </div>
  );
}

function Wrap({ children, runSpacing = 0 }: { children: ReactNode; runSpacing?: number }) {
  return <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 8, rowGap: runSpacing }}>{children}</div>;
}

function PreferencesPanel({
  prefs,
  setPrefs,
  shuffling,
  shuffleError,
  onShuffle,
}: {
  prefs: TonightPreferences;
  setPrefs: (p: TonightPreferences) => void;
  shuffling: boolean;
  shuffleError: string | null;
  onShuffle: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  const energies: Array<[EveningEnergy, string]> = [
    ['quiet', 'Quiet'],
    ['playful', 'Playful'],
    ['adventurous', 'Adventurous'],
  ];
  return (
    <div style={{ padding: '12px 8px', display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      <div>How much time do we have?</div>
      <Wrap>
        {[30, 45, 90, 180, null].map((m) => (
          <ChoiceChip
            key={String(m)}
            label={m == null ? 'No limit' : `${m} min`}
            selected={prefs.minutes === m}
            enabled={!shuffling}
            onSelected={() => setPrefs({ ...prefs, minutes: m })}
          />
        ))}
      </Wrap>
      <div style={{ height: 12 }} />
      <Wrap>
        {[false, true].map((g) => (
          <ChoiceChip
            key={String(g)}
            label={g ? 'Go out' : 'Stay in'}
            selected={prefs.goingOut === g}
            enabled={!shuffling}
            onSelected={() => setPrefs({ ...prefs, goingOut: g })}
          />
        ))}
      </Wrap>
      <div style={{ height: 12 }} />
      <div>Our energy</div>
      <Wrap>
        {energies.map(([e, label]) => (
          <ChoiceChip
            key={e}
            label={label}
            selected={prefs.energy === e}
            enabled={!shuffling}
            onSelected={() => setPrefs({ ...prefs, energy: e })}
          />
        ))}
      </Wrap>
      <div style={{ height: 8 }} />
      <div>Short evenings use nearby activities. Movies with unknown running times are left out of timed picks.</div>
      <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
        <button
          type="button"
          className="bare-button"
          disabled={shuffling}
          onClick={onShuffle}
          onMouseEnter={() => setHovered(true)}
          onMouseLeave={() => setHovered(false)}
          style={{
            height: 40,
            padding: '0 16px 0 12px',
            borderRadius: AppRadius.full,
            display: 'flex',
            alignItems: 'center',
            background: hovered && !shuffling ? withAlpha(AppColors.roseQuartz, 0.08) : 'transparent',
            opacity: shuffling ? 0.38 : 1,
          }}
        >
          <Icon name="shuffle" variant="filled" size={18} color={AppColors.roseQuartz} />
          <div style={{ width: 8 }} />
          <span
            style={{
              ...AppTypography.labelLarge,
              color: AppColors.roseQuartz,
              lineHeight: lineHeight(14),
              ...letterSpacing(0.6),
            }}
          >
            {shuffling ? 'Finding picks...' : 'Find three picks'}
          </span>
        </button>
      </div>
      {shuffleError && <div style={{ color: AppColors.error }}>{shuffleError}</div>}
    </div>
  );
}

function LiveStatusBar({
  decision,
  currentUsername,
  partnerName,
  onFlipCoin,
}: {
  decision: TonightDecision;
  currentUsername: string;
  partnerName: string;
  onFlipCoin: () => void;
}) {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const userVote = decision.votes[currentUsername];
  const partnerVote = decision.votes[currentUsername === 'khentsgdz' ? 'clairjassen' : 'khentsgdz'];

  let title: string;
  let detail: string;
  let icon = 'favorite_outline';
  let hue: string = AppColors.roseQuartz;
  let flip = false;

  if (decision.status === 'planned') {
    title = 'Our evening is set.';
    detail = decision.planTime
      ? `Tonight at ${hmma(decision.planTime)} · Saved to our calendar`
      : 'Something lovely to look forward to.';
    icon = 'check_circle_outline';
    hue = AppColors.auroraTeal;
  } else if (decision.status === 'decided') {
    const matched = isMatch(decision);
    title = matched ? 'It’s a match.' : 'Tonight, we’re doing this.';
    detail = matched ? 'Different hearts. The same little wish.' : 'One lovely choice for the two of us.';
    icon = 'favorite';
  } else if (isTied(decision)) {
    title = 'Two picks, one evening.';
    detail = 'Choose one together below, or leave it to chance.';
    icon = 'shuffle';
    hue = AppColors.blushGold;
    flip = true;
  } else if (userVote && !partnerVote) {
    title = 'Your little wish is in.';
    detail = `Waiting for ${partnerName}. You can still change your pick.`;
    icon = 'hourglass_top';
  } else if (!userVote && partnerVote) {
    title = `${partnerName} has a pick.`;
    detail = 'Your turn. Choose what sounds lovely tonight.';
  } else {
    title = 'What are we in the mood for?';
    detail = 'Pick your favorite. Choose the same one and it’s a match.';
  }

  return (
    <div
      ref={ref}
      style={{
        padding: AppSpacing.md + 1,
        borderRadius: AppRadius.xl,
        background: linear([withAlpha(hue, 0.1), Derived.panelGlass], { begin: Align.topLeft, end: Align.bottomRight, size }),
        boxShadow: `inset 0 0 0 1px ${withAlpha(hue, 0.2)}`,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start' }}>
        <Icon name={icon} size={22} color={hue} />
        <div style={{ width: AppSpacing.sm }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.titleMedium, fontWeight: 600 }}>{title}</div>
          <div style={{ height: AppSpacing.xs }} />
          <div
            style={{
              ...AppTypography.bodySmall,
              color: Derived.textMedium,
              lineHeight: lineHeight(12.5, 1.4),
              transform: 'translateY(-0.5px)',
            }}
          >
            {detail}
          </div>
        </div>
      </div>
      {flip && (
        <>
          <div style={{ height: AppSpacing.md }} />
          <div style={{ display: 'flex' }}>
            <EverglowButton label="Flip a coin" variant="glass" icon="shuffle" foregroundColor={hue} onPressed={onFlipCoin} />
          </div>
        </>
      )}
    </div>
  );
}

function OptionVisual({ option, hue, compact }: { option: TonightOption; hue: string; compact: boolean }) {
  const [failed, setFailed] = useState(false);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const icon =
    option.type === 'movie' ? 'movie_outlined' : option.type === 'date' ? 'favorite_border' : 'sports_esports_outlined';
  const showImage = Boolean(option.imageUrl) && !failed;
  return (
    <div
      ref={ref}
      style={{
        width: compact ? 76 : '100%',
        height: compact ? 114 : 144,
        flexShrink: 0,
        borderRadius: AppRadius.lg,
        overflow: 'hidden',
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: showImage
          ? AppColors.silk
          : linear([withAlpha(hue, 0.16), AppColors.silk], { begin: Align.topLeft, end: Align.bottomRight, size }),
      }}
    >
      {showImage ? (
        <img
          src={option.imageUrl}
          alt=""
          onError={() => setFailed(true)}
          style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block' }}
        />
      ) : (
        <>
          <div style={{ position: 'absolute', right: -18, bottom: -18, display: 'flex' }}>
            <Icon name={icon} size={100} color={withAlpha(hue, 0.06)} />
          </div>
          <Icon name={icon} size={compact ? 30 : 48} color={hue} />
        </>
      )}
    </div>
  );
}

function clamp(lines: number) {
  return { display: '-webkit-box', WebkitLineClamp: lines, WebkitBoxOrient: 'vertical', overflow: 'hidden' } as const;
}

function TonightOptionCard({
  option,
  decision,
  currentUsername,
  compact,
  onVote,
  onDecideDirectly,
}: {
  option: TonightOption;
  decision: TonightDecision;
  currentUsername: string;
  compact: boolean;
  onVote: (id: string) => void;
  onDecideDirectly: (id: string) => void;
}) {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const [togetherHover, setTogetherHover] = useState(false);
  const isWinner = decision.winnerOptionId === option.id;
  const selected = decision.votes[currentUsername] === option.id;
  const canChoose = decision.status === 'voting';
  const hue =
    option.type === 'movie' ? AppColors.auroraLilac : option.type === 'date' ? AppColors.roseQuartz : AppColors.blushGold;
  const voters = [
    ...(decision.votes.khentsgdz === option.id ? ['Khent'] : []),
    ...(decision.votes.clairjassen === option.id ? ['Clair'] : []),
  ];
  const label = typeLabel(option.type).toUpperCase();

  const details = (
    <div style={{ flex: compact ? 1 : undefined, minWidth: 0 }}>
      <div style={{ ...AppTypography.labelSmall, color: hue, ...letterSpacing(1.4) }}>
        {isWinner ? `OUR PICK · ${label}` : label}
      </div>
      <div style={{ height: AppSpacing.sm }} />
      <div
        style={{
          ...AppTypography.titleMedium,
          fontSize: 18,
          fontWeight: 600,
          lineHeight: lineHeight(18, 1.2),
          ...clamp(compact ? 3 : 2),
        }}
      >
        {option.title}
      </div>
      {option.subtitle && (
        <>
          <div style={{ height: AppSpacing.xs }} />
          <div style={{ ...AppTypography.bodySmall, color: hue }}>{option.subtitle}</div>
        </>
      )}
      {option.description && (
        <>
          <div style={{ height: AppSpacing.sm }} />
          <div
            style={{
              ...AppTypography.bodySmall,
              color: Derived.textMedium,
              lineHeight: lineHeight(12.5, 1.4),
              transform: 'translateY(-0.5px)',
              ...clamp(compact ? 2 : 3),
            }}
          >
            {option.description}
          </div>
        </>
      )}
      {voters.length > 0 && (
        <>
          <div style={{ height: AppSpacing.sm }} />
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <Icon name="favorite" size={12} color={hue} />
            <div style={{ width: 5 }} />
            <span style={{ ...AppTypography.labelSmall, color: hue }}>{voters.join(' + ')}’s pick</span>
          </div>
        </>
      )}
    </div>
  );

  const pickButton = (
    <EverglowButton
      label={selected ? 'Your pick' : 'Pick this'}
      icon={selected ? 'check' : undefined}
      backgroundColor={selected ? hue : withAlpha(hue, 0.12)}
      foregroundColor={selected ? AppColors.inkDeep : hue}
      stretch
      onPressed={() => onVote(option.id)}
    />
  );
  const togetherButton = (
    <button
      type="button"
      className="bare-button"
      onClick={(e) => {
        e.stopPropagation();
        onDecideDirectly(option.id);
      }}
      onMouseEnter={() => setTogetherHover(true)}
      onMouseLeave={() => setTogetherHover(false)}
      style={{
        minWidth: 48,
        height: 48,
        padding: '0 12px',
        borderRadius: AppRadius.full,
        flexShrink: 0,
        background: togetherHover ? withAlpha(Derived.textMedium, 0.08) : 'transparent',
        ...AppTypography.bodySmall,
        color: Derived.textMedium,
        lineHeight: 'normal',
        letterSpacing: 0,
      }}
    >
      Choose together
    </button>
  );

  return (
    <EverglowCard
      padding={0}
      radius={AppRadius.x2}
      fillColor={AppColors.inkDeep}
      semanticLabel={`${typeLabel(option.type)}: ${option.title}`}
      onTap={canChoose ? () => onVote(option.id) : undefined}
      style={compact ? undefined : { flex: 1, display: 'flex', flexDirection: 'column' }}
    >
      <div
        ref={ref}
        aria-selected={selected}
        style={{
          height: compact ? undefined : '100%',
          padding: AppSpacing.md + 1,
          borderRadius: AppRadius.x2,
          background: linear([withAlpha(hue, isWinner || selected ? 0.14 : 0.07), Derived.panelGlass], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size,
          }),
          boxShadow: `inset 0 0 0 1px ${isWinner || selected ? withAlpha(hue, 0.7) : Derived.border}`,
          boxSizing: 'border-box',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {compact ? (
          <div style={{ display: 'flex', alignItems: 'flex-start' }}>
            <OptionVisual option={option} hue={hue} compact />
            <div style={{ width: AppSpacing.md }} />
            {details}
          </div>
        ) : (
          <>
            <OptionVisual option={option} hue={hue} compact={false} />
            <div style={{ height: AppSpacing.md }} />
            {details}
          </>
        )}
        {canChoose && (
          <>
            {!compact && <div style={{ flex: 1 }} />}
            <div style={{ height: AppSpacing.md }} />
            {compact ? (
              <div style={{ display: 'flex', alignItems: 'center' }} onClick={(e) => e.stopPropagation()}>
                <div style={{ flex: 1, minWidth: 0, display: 'flex' }}>{pickButton}</div>
                <div style={{ width: AppSpacing.sm }} />
                {togetherButton}
              </div>
            ) : (
              <div
                style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}
                onClick={(e) => e.stopPropagation()}
              >
                {pickButton}
                {togetherButton}
              </div>
            )}
          </>
        )}
      </div>
    </EverglowCard>
  );
}

function MakePlanSection({
  option,
  planTime,
  setPlanTime,
  makingPlan,
  onMakePlan,
}: {
  option: TonightOption;
  planTime: Date;
  setPlanTime: (d: Date) => void;
  makingPlan: boolean;
  onMakePlan: () => void;
}) {
  const slots = [19, 20, 21, 22].map(slotTime);
  return (
    <EverglowCard fillColor={withAlpha(AppColors.roseQuartz, 0.06)} padding={AppSpacing.lg}>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <Icon name="calendar_today" size={20} color={AppColors.roseQuartz} />
          <div style={{ width: 10 }} />
          <div style={{ flex: 1, minWidth: 0, ...AppTypography.cormorantHeading, fontSize: 24, color: AppColors.petalWhite }}>
            Save a little time for us
          </div>
        </div>
        <div style={{ height: AppSpacing.xs }} />
        <div style={{ ...AppTypography.bodySmall, color: withAlpha(AppColors.moonlight, 0.7) }}>
          Choose a time for {option.title}. We’ll save it to our shared calendar.
        </div>
        <div style={{ height: AppSpacing.md }} />
        <div style={{ ...AppTypography.labelSmall, color: AppColors.moonlight, fontWeight: 600 }}>Tonight at</div>
        <div style={{ height: 8 }} />
        <Wrap runSpacing={8}>
          {slots.map((t) => {
            const on = planTime.getHours() === t.getHours() && planTime.getMinutes() === t.getMinutes();
            return (
              <ChoiceChip
                key={t.getHours()}
                label={hmma(t)}
                selected={on}
                showCheckmark={false}
                selectedColor={AppColors.roseQuartz}
                backgroundColor={Derived.panelGlass}
                labelColor={on ? AppColors.inkDeep : Derived.textMedium}
                labelWeight={600}
                labelSize={12.5}
                onSelected={() => setPlanTime(t)}
              />
            );
          })}
        </Wrap>
        <div style={{ height: AppSpacing.lg }} />
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <EverglowButton
            label={makingPlan ? 'Adding to Calendar...' : 'Save our plan'}
            icon="check_circle"
            backgroundColor={AppColors.roseQuartz}
            foregroundColor={AppColors.inkDeep}
            enabled={!makingPlan}
            stretch
            onPressed={onMakePlan}
          />
        </div>
      </div>
    </EverglowCard>
  );
}

function PlanSuccessSection({
  decision,
  winner,
  shuffling,
  onOpen,
  onShuffle,
}: {
  decision: TonightDecision;
  winner: TonightOption;
  shuffling: boolean;
  onOpen: (route: string) => void;
  onShuffle: () => void;
}) {
  const time = decision.planTime ? hmma(decision.planTime) : 'Tonight';
  const openLabel =
    winner.type === 'movie'
      ? 'Open Cinema'
      : winner.type === 'game'
        ? 'Play together'
        : winner.targetRoute === '/calendar'
          ? 'View Calendar'
          : 'Open activity';
  return (
    <EverglowCard fillColor={withAlpha(AppColors.auroraTeal, 0.08)} padding={AppSpacing.lg}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <Icon name="celebration" size={24} color={AppColors.auroraTeal} />
        <div style={{ width: 12 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.moonlight }}>See you at {time}</div>
          <div style={{ ...AppTypography.bodyMedium, color: AppColors.auroraTeal, fontWeight: 600 }}>{winner.title}</div>
        </div>
      </div>
      <div style={{ height: AppSpacing.lg }} />
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
        {winner.targetRoute && (
          <EverglowButton
            label={openLabel}
            icon="play_arrow"
            backgroundColor={AppColors.auroraTeal}
            foregroundColor={AppColors.inkDeep}
            onPressed={() => onOpen(winner.targetRoute!)}
          />
        )}
        {winner.targetRoute !== '/calendar' && (
          <EverglowButton
            label="View in Calendar"
            variant="glass"
            icon="calendar_month"
            foregroundColor={AppColors.moonlight}
            onPressed={() => onOpen('/calendar')}
          />
        )}
        <EverglowButton
          label="New picks"
          variant="glass"
          icon="refresh"
          foregroundColor={AppColors.blushGold}
          enabled={!shuffling}
          onPressed={onShuffle}
        />
      </div>
    </EverglowCard>
  );
}
