// Port of lib/features/academy/presentation/screens/academy_hub_screen.dart.
import { getDocs, limit, query, collection } from 'firebase/firestore';
import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { useBoxSize } from '../../core/system/useBoxSize';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { AppMotion, CssCurves, interval, motionReduced, orZero } from '../../core/theme/motion';
import { Align, letterSpacing, linear, lineHeight, shadowLayer, type BoxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource, withGetTimeout } from '../../core/utils/liveSource';
import { AlertDialog, showDialog, showModalBottomSheet, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowCard } from '../../shared/widgets/EverglowCard';
import { ElevatedButton } from '../../shared/widgets/ElevatedButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { academyService, academySyncService, studySetService, type GameMatch, type SoloStats } from './academyService';
import { takeSoloResult } from './SoloStudyPage';

type CategoryData = { label: string; icon: string; key: string };

const categories: CategoryData[] = [
  { label: 'Engineering', icon: 'settings_suggest', key: 'engineering' },
  { label: 'Tourism', icon: 'public', key: 'tourism' },
  { label: 'Music', icon: 'music_note', key: 'music' },
  { label: 'General', icon: 'lightbulb', key: 'general' },
  { label: 'Cartoons', icon: 'face_retouching_natural', key: 'cartoons' },
  { label: 'Celebrities', icon: 'star', key: 'celebrities' },
  { label: 'Film', icon: 'movie', key: 'film' },
  { label: 'Books', icon: 'book', key: 'books' },
];

const labelFor = (key: string) => categories.find((c) => c.key === key)?.label ?? key;

function soloSubtitle(stats: SoloStats | null): string {
  const last = stats?.lastCategory;
  if (last == null) return 'Quiet questions, no timer';
  const best = stats!.bestByCategory[last];
  if (best == null) return `${labelFor(last)} · Quiet, no timer`;
  return `${labelFor(last)} · Best ${best}`;
}

export function AcademyHubPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const { width } = useViewport();
  const pageH = AppSpacing.pageH(width);
  const [isSearching, setIsSearching] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const mounted = useRef(true);
  const searching = useRef(false);
  const timeout = useRef<number | null>(null);
  const matchSub = useRef<(() => void) | null>(null);
  const pendingMatchId = useRef<string | null>(null);
  const uid = auth.uid;
  const soloStats = useSource(() => studySetService.watchSoloStats(), [uid], null);

  const setSearching = (v: boolean) => {
    searching.current = v;
    setIsSearching(v);
  };

  useEffect(() => {
    mounted.current = true;
    void (async () => {
      try {
        const snap = await withGetTimeout(getDocs(query(collection(db, 'academy_questions'), limit(1))), 'academy seed check');
        if (snap.empty) await academyService.seedQuestions();
      } catch (e) {
        Logger.e('Error checking and seeding questions', e);
      }
    })();
    if (takeSoloResult() === 'challenge') {
      showCategoryPicker(false, (picked) => startMatchmaking(picked));
    }
    return () => {
      mounted.current = false;
      if (timeout.current != null) clearTimeout(timeout.current);
      matchSub.current?.();
      matchSub.current = null;
      const pending = pendingMatchId.current;
      pendingMatchId.current = null;
      if (pending != null) void academyService.cancelWaitingMatch(pending);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const showCategoryPicker = (allowTopic: boolean, onPick: (category: string, topic: string) => void) => {
    void showModalBottomSheet<void>((close) => (
      <CategoryPickerSheet
        allowTopic={allowTopic}
        onPick={(category, topic) => {
          close(null);
          onPick(category, topic);
        }}
      />
    ));
  };

  const goToGame = async (match: GameMatch) => {
    setStatusMessage('Loading the shared questions...');
    try {
      const username = auth.currentUser ?? 'guest';
      const isHost = match.hostId === auth.uid;
      if (isHost) await academySyncService.triggerAutoFill(match.category, true, match.matchId);
      const questions =
        match.questionIds.length > 0
          ? await academyService.getQuestionsByIds(match.questionIds)
          : await academyService.getQuestions(match.category);
      if (!mounted.current) return;
      if (questions.length === 0) {
        setSearching(false);
        setStatusMessage('No questions right now — try again in a bit.');
        return;
      }
      navigate('/academy/match', { replace: true, state: { matchId: match.matchId, username, questions } });
    } catch (e) {
      if (!mounted.current) return;
      setSearching(false);
      setStatusMessage(`Sync Error: ${errorText(e)}`);
    }
  };

  const startTimeoutTimer = () => {
    if (timeout.current != null) clearTimeout(timeout.current);
    timeout.current = window.setTimeout(async () => {
      if (!mounted.current || !searching.current) return;
      const pending = pendingMatchId.current;
      pendingMatchId.current = null;
      matchSub.current?.();
      matchSub.current = null;
      if (pending != null) await academyService.cancelWaitingMatch(pending);
      if (!mounted.current) return;
      setSearching(false);
      setStatusMessage('No partner found. Try Solo Study?');
      showTimeoutDialog();
    }, 60_000);
  };

  const startMatchmaking = async (category: string) => {
    const uid = auth.uid;
    const username = auth.currentUser;
    if (uid == null || username == null) {
      setStatusMessage('Log in to race your love in 1v1.');
      return;
    }
    setSearching(true);
    setStatusMessage(`Searching for ${labelFor(category)} match...`);
    try {
      const match = await academyService.joinOrCreateMatch(uid, username, category);
      if (match.status === 'active') {
        void goToGame(match);
        return;
      }
      pendingMatchId.current = match.matchId;
      if (mounted.current) setStatusMessage('Waiting for partner...');
      startTimeoutTimer();
      studySetService
        .buildMatchSet(category)
        .then((ids) => academyService.upgradeWaitingMatchQuestions(match.matchId, ids))
        .catch(() => {});
      matchSub.current?.();
      matchSub.current = academyService.watchMatch(match.matchId)({
        data: (updated) => {
          if (!mounted.current || updated == null) return;
          if (updated.status === 'active') {
            if (timeout.current != null) clearTimeout(timeout.current);
            matchSub.current?.();
            matchSub.current = null;
            pendingMatchId.current = null;
            void goToGame(updated);
          }
        },
      });
    } catch (e) {
      if (!mounted.current) return;
      setSearching(false);
      setStatusMessage(`Error: ${errorText(e)}`);
    }
  };

  const cancelSearch = async () => {
    if (timeout.current != null) clearTimeout(timeout.current);
    matchSub.current?.();
    matchSub.current = null;
    const pending = pendingMatchId.current;
    pendingMatchId.current = null;
    if (pending != null) await academyService.cancelWaitingMatch(pending);
    if (!mounted.current) return;
    setSearching(false);
    setStatusMessage(null);
  };

  const startSoloStudy = async (category: string, topic: string) => {
    setSearching(true);
    setStatusMessage(
      topic === '' ? `Motchi is writing ${labelFor(category)} questions...` : `Motchi is writing about "${topic}"...`,
    );
    try {
      const questions = await studySetService.buildSoloSet(category, topic);
      if (!mounted.current) return;
      if (questions.length === 0) {
        setSearching(false);
        setStatusMessage('No questions right now — try again in a bit.');
        return;
      }
      setSearching(false);
      navigate('/academy/solo', { state: { questions, category, topic } });
    } catch (e) {
      if (!mounted.current) return;
      setSearching(false);
      setStatusMessage(`Error: ${errorText(e)}`);
    }
  };

  const showTimeoutDialog = () => {
    void showDialog<void>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={AppRadius.x2}
        title={<span style={{ ...AppTypography.cormorantBold, fontSize: 24 }}>Matchmaking Timeout</span>}
        content={
          <span style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.8) }}>
            We couldn't find a partner for you right now. Would you like to play Solo instead?
          </span>
        }
        actions={[
          <TextButton
            key="cancel"
            onPressed={() => close(null)}
            color={withAlpha(AppColors.roseQuartz, 0.6)}
            style={{ fontWeight: 500 }}
          >
            Cancel
          </TextButton>,
          <ElevatedButton
            key="solo"
            onPressed={() => {
              close(null);
              showCategoryPicker(true, startSoloStudy);
            }}
          >
            <span style={{ ...AppTypography.labelLarge, fontWeight: 700, lineHeight: lineHeight(14, 1.26) }}>Play Solo</span>
          </ElevatedButton>,
        ]}
      />
    ));
  };

  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.softLavender, alignment: [-0.7, -0.85], size: 0.8, opacity: 0.1 },
          { color: AppColors.deepRose, alignment: [0.85, 0.9], size: 0.7, opacity: 0.1 },
        ]}
      />
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <EverglowFeatureHeader
          title="Academy Hub"
          subtitle="play · learn · compete together"
          icon="school"
          hue={AppColors.softLavender}
        />
        <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
          <div style={{ padding: `${AppSpacing.md}px ${pageH}px ${AppSpacing.x3}px` }}>
            <div style={{ maxWidth: 600, margin: '0 auto', display: 'flex', flexDirection: 'column' }}>
              <Welcome />
              <div style={{ height: AppSpacing.xl }} />
              <EverglowSectionHeader label="Choose a mode" icon="sports_esports" hue={AppColors.auroraRose} />
              <div style={{ height: AppSpacing.md }} />
              {isSearching ? (
                <>
                  <EverglowSkeleton height={24} radius={12} />
                  <div style={{ height: AppSpacing.xl }} />
                  <span style={{ ...AppTypography.outfitWhite, fontSize: 14, color: AppColors.roseQuartz, textAlign: 'center' }}>
                    {statusMessage ?? ''}
                  </span>
                  <div style={{ height: AppSpacing.xl }} />
                  <div style={{ display: 'flex', justifyContent: 'center' }}>
                    <TextButton onPressed={() => void cancelSearch()} color={AppColors.blushGold} style={{ fontWeight: 600 }}>
                      Cancel Search
                    </TextButton>
                  </div>
                </>
              ) : (
                <>
                  <AcademyModeCard
                    title="1v1 Challenge"
                    subtitle="Race your love in real time"
                    badge="LIVE · TOGETHER"
                    icon="bolt"
                    accent={AppColors.deepRose}
                    onTap={() => showCategoryPicker(false, (category) => void startMatchmaking(category))}
                  />
                  <div style={{ height: AppSpacing.md }} />
                  <AcademyModeCard
                    title="Solo Study"
                    subtitle={soloSubtitle(soloStats)}
                    badge="CALM PRACTICE"
                    icon="menu_book"
                    accent={AppColors.auroraGold}
                    onTap={() => showCategoryPicker(true, (c, t) => void startSoloStudy(c, t))}
                  />
                  <div style={{ height: AppSpacing.md }} />
                  <AcademyModeCard
                    title="Study with Motchi"
                    subtitle="Ask about your PDFs"
                    badge="AI HELPER"
                    icon="picture_as_pdf"
                    accent={AppColors.softLavender}
                    onTap={() => navigate('/study')}
                  />
                  {statusMessage != null && (
                    <>
                      <div style={{ height: AppSpacing.xl }} />
                      <span
                        style={{ ...AppTypography.outfitWhite, fontSize: 13, color: AppColors.blushGold, textAlign: 'center' }}
                      >
                        {statusMessage}
                      </span>
                    </>
                  )}
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

const errorText = (e: unknown) => (e instanceof Error ? `Exception: ${e.message}` : String(e));

function Welcome() {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <div
      ref={ref}
      style={{
        padding: AppSpacing.xl + 1,
        background: linear([withAlpha(AppColors.velvet, 0.85), withAlpha(AppColors.inkDeep, 0.9)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
          size,
        }),
        borderRadius: AppRadius.x2,
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.22)}`,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <span
        style={{ ...AppTypography.cormorantBold, fontSize: 24, lineHeight: lineHeight(24, 1.1), color: AppColors.roseQuartz }}
      >
        What shall we learn today?
      </span>
      <div style={{ height: AppSpacing.sm }} />
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 13,
          lineHeight: lineHeight(13, 1.45),
          color: withAlpha(AppColors.petalWhite, 0.78),
        }}
      >
        Solo for quiet practice, 1v1 to race your love, Motchi for PDFs.
      </span>
    </div>
  );
}

function AcademyModeCard({
  title,
  subtitle,
  badge,
  icon,
  accent,
  onTap,
}: {
  title: string;
  subtitle: string;
  badge?: string;
  icon: string;
  accent: string;
  onTap: () => void;
}) {
  const circle = (size: number, fill: string, border: string): CSSProperties => ({
    width: size,
    height: size,
    flexShrink: 0,
    borderRadius: '50%',
    background: fill,
    boxShadow: `inset 0 0 0 1px ${border}`,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  });
  return (
    <EverglowCard onTap={onTap} semanticLabel={title} padding={AppSpacing.xl}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div style={circle(52, withAlpha(accent, 0.14), withAlpha(accent, 0.35))}>
          <Icon name={icon} size={24} color={accent} />
        </div>
        <div style={{ width: AppSpacing.lg }} />
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          {badge != null && (
            <>
              <div
                style={{
                  maxWidth: '100%',
                  boxSizing: 'border-box',
                  padding: `2px ${AppSpacing.sm}px`,
                  background: withAlpha(accent, 0.14),
                  borderRadius: AppRadius.full,
                  border: `1px solid ${withAlpha(accent, 0.3)}`,
                }}
              >
                <span
                  className="ellipsis"
                  style={{
                    display: 'block',
                    ...AppTypography.outfitHeading,
                    fontSize: 9.5,
                    ...letterSpacing(1.2),
                    color: accent,
                  }}
                >
                  {badge}
                </span>
              </div>
              <div style={{ height: AppSpacing.xs }} />
            </>
          )}
          <span
            className="ellipsis"
            style={{
              display: 'block',
              maxWidth: '100%',
              ...AppTypography.cormorantBold,
              fontSize: 21,
              lineHeight: lineHeight(21, 1.1),
            }}
          >
            {title}
          </span>
          <div style={{ height: 2 }} />
          <span
            className="clamp-2"
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 13,
              lineHeight: lineHeight(13, 1.35),
              color: withAlpha(AppColors.petalWhite, 0.78),
            }}
          >
            {subtitle}
          </span>
        </div>
        <div style={{ width: AppSpacing.md }} />
        <div style={circle(32, withAlpha(AppColors.moonlight, 0.08), withAlpha(AppColors.moonlight, 0.14))}>
          <Icon name="arrow_forward_ios" size={14} color={accent} />
        </div>
      </div>
    </EverglowCard>
  );
}

function CategoryPickerSheet({ allowTopic, onPick }: { allowTopic: boolean; onPick: (category: string, topic: string) => void }) {
  const [topic, setTopic] = useState('');
  const [focused, setFocused] = useState(false);
  const [t, setT] = useState(motionReduced() ? 1 : 0);

  useEffect(() => {
    if (motionReduced()) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const v = Math.min(1, (now - start) / 500);
      setT(v);
      if (v < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <div style={{ margin: '0 auto', maxWidth: 640, maxHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {/* The theme's M3 drag handle, drawn on the sheet's transparent surface. */}
      <div style={{ height: 48, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: 32, height: 4, borderRadius: 2, background: withAlpha(AppColors.moonlight, 0.35) }} />
      </div>
      <div
        className="no-scrollbar"
        style={{
          width: '100%',
          marginTop: AppSpacing.x5,
          minHeight: 0,
          overflowY: 'auto',
          padding: `0 ${AppSpacing.x3}px ${AppSpacing.x3}px`,
          background: AppColors.velvet,
          borderRadius: `${AppRadius.x3}px ${AppRadius.x3}px 0 0`,
          boxSizing: 'border-box',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            marginTop: AppSpacing.sm,
            width: 40,
            height: 4,
            flexShrink: 0,
            background: withAlpha(AppColors.moonlight, 0.3),
            borderRadius: AppRadius.full,
          }}
        />
        <div style={{ height: AppSpacing.lg, flexShrink: 0 }} />
        <span style={{ ...AppTypography.cormorantBold, fontSize: 26 }}>Choose Category</span>
        {allowTopic && (
          <>
            <div style={{ height: AppSpacing.sm, flexShrink: 0 }} />
            <label
              style={{
                alignSelf: 'stretch',
                height: 48,
                display: 'flex',
                alignItems: 'center',
                background: withAlpha(AppColors.moonlight, 0.07),
                borderRadius: AppRadius.lg,
                boxShadow: focused
                  ? `inset 0 0 0 1.4px ${AppColors.auroraGold}`
                  : `inset 0 0 0 1px ${withAlpha(AppColors.auroraGold, 0.25)}`,
                cursor: 'text',
                position: 'relative',
                flexShrink: 0,
              }}
            >
              <div
                style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
              >
                <Icon name="auto_awesome" size={18} color={AppColors.auroraGold} />
              </div>
              {topic === '' && (
                <span
                  aria-hidden
                  style={{
                    position: 'absolute',
                    left: 48,
                    ...AppTypography.outfitWhite,
                    fontSize: 13,
                    lineHeight: lineHeight(13, 1.5),
                    ...letterSpacing(0.5),
                    color: withAlpha(AppColors.petalWhite, 0.4),
                    pointerEvents: 'none',
                  }}
                >
                  Ask Motchi about... (optional)
                </span>
              )}
              <input
                value={topic}
                maxLength={60}
                enterKeyHint="done"
                aria-label="Ask Motchi about... (optional)"
                onFocus={() => setFocused(true)}
                onBlur={() => setFocused(false)}
                onChange={(e) => setTopic(e.target.value)}
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 14,
                  lineHeight: lineHeight(14, 1.5),
                  ...letterSpacing(0.5),
                  flex: 1,
                  minWidth: 0,
                  padding: `0 ${AppSpacing.lg}px 0 0`,
                  border: 'none',
                  outline: 'none',
                  background: 'transparent',
                  caretColor: AppColors.deepRose,
                }}
              />
            </label>
          </>
        )}
        <div style={{ height: AppSpacing.x2, flexShrink: 0 }} />
        <div
          style={{
            alignSelf: 'stretch',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: AppSpacing.lg,
            flexShrink: 0,
          }}
        >
          {categories.map((c, i) => {
            const start = Math.min(i * 0.06, 1);
            const v = interval(start, Math.min(start + 0.4, 1), AppMotion.easeOutExpo)(t);
            return (
              <div key={c.key} style={{ aspectRatio: '1 / 0.85', opacity: v, transform: `translateY(${(1 - v) * 15}%)` }}>
                <CategoryCard data={c} onTap={() => onPick(c.key, topic.trim())} />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function CategoryCard({ data, onTap }: { data: CategoryData; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const ms = orZero(AppMotion.fast);
  const ease = CssCurves.easeOutStrong;
  // Flutter paints the shadow under the whole card, so the hover glow shows through its see-through fill.
  const layer = (shadow: BoxShadow, on: boolean) => (
    <div
      aria-hidden
      style={{ ...shadowLayer(shadow, { radius: AppRadius.lg }), opacity: on ? 1 : 0, transition: `opacity ${ms}ms ${ease}` }}
    />
  );
  return (
    <div
      style={{
        position: 'relative',
        height: '100%',
        transform: `scale(${pressed ? 0.96 : 1})`,
        transition: `transform ${ms}ms ${ease}`,
      }}
    >
      {layer({ blur: 8, offset: [0, 2], color: 'rgba(0,0,0,0.2)' }, !hovered)}
      {layer({ blur: 24, color: withAlpha(AppColors.deepRose, 0.35) }, hovered)}
      <button
        type="button"
        className="bare-button"
        aria-label={data.label}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => {
          setHovered(false);
          setPressed(false);
        }}
        onPointerDown={() => setPressed(true)}
        onPointerUp={() => {
          setPressed(false);
          onTap();
        }}
        onPointerCancel={() => setPressed(false)}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') onTap();
        }}
        style={{
          width: '100%',
          height: '100%',
          boxSizing: 'border-box',
          borderRadius: AppRadius.lg,
          background: hovered ? withAlpha(AppColors.moonlight, 0.15) : AppColors.twilight,
          border: `1px solid ${hovered ? withAlpha(AppColors.roseQuartz, 0.3) : withAlpha(AppColors.moonlight, 0.12)}`,
          position: 'relative',
          transition: `background ${ms}ms ${ease}, border-color ${ms}ms ${ease}`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
        }}
      >
        <div
          style={{
            padding: AppSpacing.sm,
            borderRadius: '50%',
            background: hovered ? withAlpha(AppColors.deepRose, 0.15) : withAlpha(AppColors.roseQuartz, 0.08),
            transition: `background ${ms}ms linear`,
            display: 'flex',
          }}
        >
          <Icon
            name={data.icon}
            variant="filled"
            size={26}
            color={hovered ? AppColors.roseQuartz : withAlpha(AppColors.roseQuartz, 0.7)}
          />
        </div>
        <div style={{ height: AppSpacing.sm }} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 13,
            color: hovered ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.85),
            textAlign: 'center',
          }}
        >
          {data.label}
        </span>
      </button>
    </div>
  );
}
