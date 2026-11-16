// Port of lib/features/tonight/presentation/screens/tonight_screen.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import {
  isMatch,
  isTied,
  tonightService,
  winningOption,
  type EveningEnergy,
  type TonightDecision,
  type TonightOption,
} from './tonightService';

function defaultPlanTime(): string {
  const now = new Date();
  const h = now.getHours() >= 20 ? (now.getHours() + 1) % 24 : 20;
  return `${String(h).padStart(2, '0')}:00`;
}

function planDateFromHHMM(hhmm: string): Date {
  const [hStr, mStr] = hhmm.split(':');
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), Number(hStr) || 20, Number(mStr) || 0);
}

export function TonightPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const { width } = useViewport();
  const currentUsername = auth.currentUser ?? 'khentsgdz';
  const partnerName = auth.partnerName;

  const decision = useSource<TonightDecision | null>(() => tonightService.watchActiveDecision(), [], null);

  const [shuffling, setShuffling] = useState(false);
  const [shuffleError, setShuffleError] = useState<string | null>(null);
  const [prefsOpen, setPrefsOpen] = useState(false);
  const [minutes, setMinutes] = useState<number | null>(decision?.preferences?.minutes ?? null);
  const [goingOut, setGoingOut] = useState(decision?.preferences?.goingOut ?? false);
  const [energy, setEnergy] = useState<EveningEnergy>(decision?.preferences?.energy ?? 'quiet');
  const [planTimeStr, setPlanTimeStr] = useState(defaultPlanTime);
  const [makingPlan, setMakingPlan] = useState(false);

  const handleShuffle = async () => {
    if (shuffling) return;
    setShuffling(true);
    setShuffleError(null);
    try {
      await tonightService.createOrShuffle({ minutes, goingOut, energy }, true);
    } catch {
      setShuffleError('Could not save new picks. Your previous picks are safe. Try again.');
    } finally {
      setShuffling(false);
    }
  };

  const handleFlipCoin = async (d: TonightDecision) => {
    const k = d.votes.khentsgdz;
    const c = d.votes.clairjassen;
    if (!k || !c) return;
    const winner = Math.random() < 0.5 ? k : c;
    await tonightService.decideWinner(winner);
  };

  const handleMakePlan = async (winner: TonightOption) => {
    setMakingPlan(true);
    try {
      const ev = await tonightService.makePlan(winner, planDateFromHHMM(planTimeStr), currentUsername);
      showSnackBar(
        ev ? "Tonight's plan added to your Calendar! 📅✨" : "Couldn't save the plan. Please try again.",
      );
    } finally {
      setMakingPlan(false);
    }
  };

  const winner = decision ? winningOption(decision) : null;

  return (
    <div style={{ position: 'relative', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraRose, alignment: [-0.85, -0.75], size: 0.9, opacity: 0.14 },
          { color: AppColors.auroraGold, alignment: [0.85, -0.4], size: 0.85, opacity: 0.12 },
          { color: AppColors.auroraTeal, alignment: [0.0, 0.9], size: 0.8, opacity: 0.10 },
        ]}
      />
      <div style={{ position: 'relative', zIndex: 1, flex: 1, display: 'flex', flexDirection: 'column' }}>
        <EverglowFeatureHeader
          title="Tonight"
          subtitle="An evening for two"
          hue={AppColors.auroraRose}
          actions={[
            <Tooltip key="shuffle" message={shuffling ? 'Finding new picks…' : 'Shuffle picks'}>
              <button
                type="button"
                className="bare-button"
                aria-label="Shuffle picks"
                disabled={shuffling}
                onClick={() => void handleShuffle()}
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="shuffle" size={20} color={AppColors.roseQuartz} />
              </button>
            </Tooltip>,
          ]}
        />

        {decision == null || decision.options.length === 0 ? (
          <div style={{ maxWidth: 480, margin: '20px auto', padding: AppSpacing.xl, textAlign: 'center' }}>
            <div
              style={{
                width: 72,
                height: 72,
                borderRadius: '50%',
                margin: '0 auto 20px',
                background: withAlpha(AppColors.auroraRose, 0.12),
                border: `1px solid ${withAlpha(AppColors.auroraRose, 0.3)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="auto_awesome" size={36} color={AppColors.auroraRose} />
            </div>
            <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 26 }}>“What should we do tonight?”</div>
            <div style={{ ...AppTypography.bodyMedium, color: withAlpha(AppColors.moonlight, 0.7), marginTop: 8 }}>
              Choose what suits your evening, then find three ideas.
            </div>
            <div style={{ marginTop: 22, textAlign: 'left' }}>
              <PreferencesPanel
                minutes={minutes}
                setMinutes={setMinutes}
                goingOut={goingOut}
                setGoingOut={setGoingOut}
                energy={energy}
                setEnergy={setEnergy}
                shuffling={shuffling}
                shuffleError={shuffleError}
                onShuffle={handleShuffle}
              />
            </div>
            <div style={{ marginTop: 14 }}>
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
        ) : (
          <div
            style={{
              maxWidth: 960,
              width: '100%',
              margin: '0 auto',
              padding: `${AppSpacing.md}px ${AppSpacing.pageH(width)}px ${AppSpacing.x3}px`,
            }}
          >
            {decision.status === 'voting' && (
              <div style={{ marginBottom: AppSpacing.lg }}>
                <div style={{ ...AppTypography.labelSmall, color: AppColors.blushGold, letterSpacing: 2 }}>
                  JUST US, TONIGHT
                </div>
                <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 36, lineHeight: 1.1, marginTop: AppSpacing.sm }}>
                  A little time for us.
                </div>
                <div style={{ ...AppTypography.bodyMedium, marginTop: AppSpacing.sm }}>
                  A movie, a date, or a little friendly competition.
                </div>
              </div>
            )}

            {decision.status === 'voting' && (
              <div>
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => setPrefsOpen((o) => !o)}
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    textAlign: 'left',
                  }}
                >
                  <div>
                    <div style={{ ...AppTypography.titleMedium, fontWeight: 500, color: AppColors.petalWhite }}>
                      What suits tonight?
                    </div>
                    <div style={{ ...AppTypography.bodyMedium, color: Derived.textMedium, marginTop: 2 }}>
                      {minutes == null ? 'No time limit' : `${minutes} minutes`} / {goingOut ? 'Go out' : 'Stay in'} /{' '}
                      {energy}
                    </div>
                  </div>
                  <Icon name={prefsOpen ? 'expand_less' : 'expand_more'} size={24} color={Derived.textMedium} />
                </button>
                {prefsOpen && (
                  <div style={{ padding: '0 8px 12px' }}>
                    <PreferencesPanel
                      minutes={minutes}
                      setMinutes={setMinutes}
                      goingOut={goingOut}
                      setGoingOut={setGoingOut}
                      energy={energy}
                      setEnergy={setEnergy}
                      shuffling={shuffling}
                      shuffleError={shuffleError}
                      onShuffle={handleShuffle}
                    />
                  </div>
                )}
              </div>
            )}

            <LiveStatusBar
              decision={decision}
              currentUsername={currentUsername}
              partnerName={partnerName}
              onFlipCoin={() => void handleFlipCoin(decision)}
            />

            <div style={{ height: 16 }} />

            {decision.status !== 'voting' && winner ? (
              <TonightOptionCard
                option={winner}
                decision={decision}
                currentUsername={currentUsername}
                compact
                onVote={(id) => void tonightService.castVote(currentUsername, id)}
                onDecideDirectly={(id) => void tonightService.decideWinner(id)}
              />
            ) : (
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: width >= 840 ? 'repeat(3, minmax(0, 1fr))' : '1fr',
                  gap: 14,
                }}
              >
                {decision.options.map((opt) => (
                  <TonightOptionCard
                    key={opt.id}
                    option={opt}
                    decision={decision}
                    currentUsername={currentUsername}
                    compact={width < 840}
                    onVote={(id) => void tonightService.castVote(currentUsername, id)}
                    onDecideDirectly={(id) => void tonightService.decideWinner(id)}
                  />
                ))}
              </div>
            )}

            <div style={{ height: 20 }} />

            {decision.status === 'decided' && winner && (
              <div
                style={{
                  padding: 18,
                  borderRadius: AppRadius.x2,
                  background: Derived.panelGlass,
                  border: `1px solid ${withAlpha(AppColors.auroraRose, 0.3)}`,
                  display: 'flex',
                  flexWrap: 'wrap',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                }}
              >
                <div>
                  <div style={{ ...AppTypography.titleMedium, fontWeight: 600 }}>Lock it into our evening</div>
                  <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>
                    Pick a time to save this plan on our calendar.
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input
                    type="time"
                    value={planTimeStr}
                    onChange={(e) => setPlanTimeStr(e.target.value)}
                    style={{
                      padding: '8px 12px',
                      borderRadius: 12,
                      background: AppColors.velvet,
                      border: `1px solid ${Derived.border}`,
                      color: AppColors.petalWhite,
                    }}
                  />
                  <EverglowButton
                    label={makingPlan ? 'Saving…' : 'Make a plan'}
                    icon="event_available"
                    backgroundColor={AppColors.auroraRose}
                    foregroundColor={AppColors.inkDeep}
                    enabled={!makingPlan}
                    onPressed={() => void handleMakePlan(winner)}
                  />
                </div>
              </div>
            )}

            {decision.status === 'planned' && winner && (
              <div
                style={{
                  padding: 20,
                  borderRadius: AppRadius.x2,
                  background: `linear-gradient(135deg, ${withAlpha(AppColors.auroraTeal, 0.14)}, ${Derived.panelGlass})`,
                  border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.35)}`,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <Icon name="check_circle" size={26} color={AppColors.auroraTeal} />
                  <div>
                    <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 24 }}>
                      See you at{' '}
                      {(decision.planTime ?? new Date()).toLocaleTimeString('en-US', {
                        hour: 'numeric',
                        minute: '2-digit',
                      })}
                    </div>
                    <div style={{ ...AppTypography.bodyMedium, color: AppColors.auroraTeal, fontWeight: 600 }}>
                      {winner.title}
                    </div>
                  </div>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 16 }}>
                  {winner.targetRoute && (
                    <EverglowButton
                      label={
                        winner.type === 'movie'
                          ? 'Open Cinema'
                          : winner.type === 'game'
                            ? 'Play together'
                            : winner.targetRoute === '/calendar'
                              ? 'View Calendar'
                              : 'Open activity'
                      }
                      icon="play_arrow"
                      backgroundColor={AppColors.auroraTeal}
                      foregroundColor={AppColors.inkDeep}
                      onPressed={() => navigate(winner.targetRoute!)}
                    />
                  )}
                  {winner.targetRoute !== '/calendar' && (
                    <EverglowButton
                      label="View in Calendar"
                      variant="glass"
                      icon="calendar_month"
                      onPressed={() => navigate('/calendar')}
                    />
                  )}
                  <EverglowButton
                    label="New picks"
                    variant="glass"
                    icon="refresh"
                    foregroundColor={AppColors.blushGold}
                    enabled={!shuffling}
                    onPressed={() => void handleShuffle()}
                  />
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function PreferencesPanel({
  minutes,
  setMinutes,
  goingOut,
  setGoingOut,
  energy,
  setEnergy,
  shuffling,
  shuffleError,
  onShuffle,
}: {
  minutes: number | null;
  setMinutes: (m: number | null) => void;
  goingOut: boolean;
  setGoingOut: (g: boolean) => void;
  energy: EveningEnergy;
  setEnergy: (e: EveningEnergy) => void;
  shuffling: boolean;
  shuffleError: string | null;
  onShuffle: () => Promise<void>;
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>How much time do we have?</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {[30, 45, 90, 180, null].map((m) => (
          <PrefChip
            key={String(m)}
            label={m == null ? 'No limit' : `${m} min`}
            selected={minutes === m}
            onClick={() => !shuffling && setMinutes(m)}
          />
        ))}
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 4 }}>
        <PrefChip label="Stay in" selected={!goingOut} onClick={() => !shuffling && setGoingOut(false)} />
        <PrefChip label="Go out" selected={goingOut} onClick={() => !shuffling && setGoingOut(true)} />
      </div>
      <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium, marginTop: 4 }}>Our energy</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {(
          [
            ['quiet', 'Quiet'],
            ['playful', 'Playful'],
            ['adventurous', 'Adventurous'],
          ] as const
        ).map(([val, label]) => (
          <PrefChip
            key={val}
            label={label}
            selected={energy === val}
            onClick={() => !shuffling && setEnergy(val)}
          />
        ))}
      </div>
      <div style={{ ...AppTypography.bodySmall, fontSize: 11.5, color: Derived.textMuted }}>
        Short evenings use nearby activities. Movies with unknown running times are left out of timed picks.
      </div>
      <div>
        <button
          type="button"
          className="bare-button"
          disabled={shuffling}
          onClick={() => void onShuffle()}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            padding: '8px 12px',
            ...AppTypography.labelMedium,
            color: AppColors.roseQuartz,
          }}
        >
          <Icon name="shuffle" size={16} color={AppColors.roseQuartz} />
          <span>{shuffling ? 'Finding picks...' : 'Find three picks'}</span>
        </button>
      </div>
      {shuffleError && <div style={{ ...AppTypography.bodySmall, color: AppColors.error }}>{shuffleError}</div>}
    </div>
  );
}

function PrefChip({ label, selected, onClick }: { label: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        padding: '6px 12px',
        borderRadius: AppRadius.full,
        background: selected ? withAlpha(AppColors.roseQuartz, 0.22) : withAlpha(AppColors.moonlight, 0.06),
        border: `1px solid ${selected ? AppColors.roseQuartz : Derived.border}`,
        ...AppTypography.labelSmall,
        color: selected ? AppColors.petalWhite : Derived.textMedium,
      }}
    >
      {label}
    </button>
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
  const userVote = decision.votes[currentUsername];
  const partnerVote = decision.votes[currentUsername === 'khentsgdz' ? 'clairjassen' : 'khentsgdz'];

  let title = 'What are we in the mood for?';
  let detail = 'Pick your favorite. Choose the same one and it’s a match.';
  let icon = 'favorite_border';
  let hue: string = AppColors.roseQuartz;
  let showFlip = false;

  if (decision.status === 'planned') {
    title = 'Our evening is set.';
    detail = decision.planTime
      ? `Tonight at ${decision.planTime.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })} · Saved to our calendar`
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
    showFlip = true;
  } else if (userVote && !partnerVote) {
    title = 'Your little wish is in.';
    detail = `Waiting for ${partnerName}. You can still change your pick.`;
    icon = 'hourglass_top';
  } else if (!userVote && partnerVote) {
    title = `${partnerName} has a pick.`;
    detail = 'Your turn. Choose what sounds lovely tonight.';
  }

  return (
    <div
      style={{
        padding: AppSpacing.md,
        background: `linear-gradient(135deg, ${withAlpha(hue, 0.1)}, ${Derived.panelGlass})`,
        borderRadius: AppRadius.xl,
        border: `1px solid ${withAlpha(hue, 0.2)}`,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
        <Icon name={icon} size={22} color={hue} />
        <div style={{ flex: 1 }}>
          <div style={{ ...AppTypography.titleMedium, color: AppColors.petalWhite, fontWeight: 600 }}>{title}</div>
          <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium, marginTop: 4 }}>{detail}</div>
        </div>
      </div>
      {showFlip && (
        <div style={{ marginTop: 12 }}>
          <EverglowButton label="Flip a coin" variant="glass" icon="shuffle" foregroundColor={hue} onPressed={onFlipCoin} />
        </div>
      )}
    </div>
  );
}

function TonightOptionVisual({
  option,
  hue,
  compact,
}: {
  option: TonightOption;
  hue: string;
  compact: boolean;
}) {
  const [imgErr, setImgErr] = useState(false);
  const icon = option.type === 'movie' ? 'movie' : option.type === 'date' ? 'favorite_border' : 'sports_esports';
  const showImage = Boolean(option.imageUrl) && !imgErr;

  return (
    <div
      style={{
        width: compact ? 76 : '100%',
        height: compact ? 114 : 144,
        borderRadius: AppRadius.lg,
        overflow: 'hidden',
        position: 'relative',
        flexShrink: 0,
        background: showImage
          ? AppColors.silk
          : `linear-gradient(135deg, ${withAlpha(hue, 0.16)}, ${AppColors.silk})`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {showImage ? (
        <img
          src={option.imageUrl!}
          alt={option.title}
          onError={() => setImgErr(true)}
          style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block' }}
        />
      ) : (
        <>
          <div style={{ position: 'absolute', right: -18, bottom: -18, pointerEvents: 'none' }}>
            <Icon name={icon} variant="outlined" size={100} color={withAlpha(hue, 0.06)} />
          </div>
          <Icon name={icon} variant="outlined" size={compact ? 30 : 48} color={hue} />
        </>
      )}
    </div>
  );
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
  const isWinner = decision.winnerOptionId === option.id;
  const selected = decision.votes[currentUsername] === option.id;
  const canChoose = decision.status === 'voting';
  const hue =
    option.type === 'movie'
      ? AppColors.auroraLilac
      : option.type === 'date'
        ? AppColors.roseQuartz
        : AppColors.blushGold;
  const label = option.type === 'movie' ? 'MOVIE' : option.type === 'date' ? 'DATE IDEA' : 'GAME';
  const voters = [
    ...(decision.votes.khentsgdz === option.id ? ['Khent'] : []),
    ...(decision.votes.clairjassen === option.id ? ['Clair'] : []),
  ];

  const details = (
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ ...AppTypography.labelSmall, color: hue, letterSpacing: 1.4 }}>
        {isWinner ? `OUR PICK · ${label}` : label}
      </div>
      <div style={{ ...AppTypography.titleMedium, fontSize: 18, fontWeight: 600, lineHeight: 1.2, marginTop: 8 }}>
        {option.title}
      </div>
      {option.subtitle && (
        <div style={{ ...AppTypography.bodySmall, color: hue, marginTop: 4 }}>{option.subtitle}</div>
      )}
      {option.description && (
        <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium, lineHeight: 1.4, marginTop: 8 }}>
          {option.description}
        </div>
      )}
      {voters.length > 0 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 8 }}>
          <Icon name="favorite" size={12} color={hue} />
          <span style={{ ...AppTypography.labelSmall, color: hue }}>{voters.join(' + ')}’s pick</span>
        </div>
      )}
    </div>
  );

  return (
    <div
      onClick={() => canChoose && onVote(option.id)}
      style={{
        padding: AppSpacing.md,
        borderRadius: AppRadius.x2,
        background: `linear-gradient(135deg, ${withAlpha(hue, isWinner || selected ? 0.14 : 0.07)}, ${Derived.panelGlass})`,
        border: `1px solid ${isWinner || selected ? withAlpha(hue, 0.7) : Derived.border}`,
        cursor: canChoose ? 'pointer' : 'default',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {compact ? (
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: AppSpacing.md }}>
          <TonightOptionVisual option={option} hue={hue} compact />
          {details}
        </div>
      ) : (
        <>
          <TonightOptionVisual option={option} hue={hue} compact={false} />
          <div style={{ height: AppSpacing.md }} />
          {details}
        </>
      )}

      {canChoose && (
        <div
          onClick={(e) => e.stopPropagation()}
          style={{
            marginTop: compact ? AppSpacing.md : 'auto',
            paddingTop: compact ? 0 : AppSpacing.md,
            display: 'flex',
            flexDirection: compact ? 'row' : 'column',
            gap: compact ? AppSpacing.sm : 4,
            alignItems: compact ? 'center' : 'stretch',
          }}
        >
          <div style={{ flex: compact ? 1 : undefined }}>
            <EverglowButton
              label={selected ? 'Your pick' : 'Pick this'}
              icon={selected ? 'check' : undefined}
              backgroundColor={selected ? hue : withAlpha(hue, 0.12)}
              foregroundColor={selected ? AppColors.inkDeep : hue}
              fullWidth
              onPressed={() => onVote(option.id)}
            />
          </div>
          <button
            type="button"
            className="bare-button"
            onClick={() => onDecideDirectly(option.id)}
            style={{
              minWidth: 48,
              minHeight: 48,
              padding: '0 12px',
              ...AppTypography.bodySmall,
              color: Derived.textMedium,
              textAlign: 'center',
            }}
          >
            Choose together
          </button>
        </div>
      )}
    </div>
  );
}
