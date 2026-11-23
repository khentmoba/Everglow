// Port of game_board_screen.dart with score_tracker.dart, answer_button.dart
// and trivia_loading_overlay.dart.
import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { ErrorPage } from '../../core/router/ErrorPage';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, boxShadow, letterSpacing, linear, shadowLayer, sigma } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { academyService, displayNameFor, type AcademyQuestion, type GameMatch } from './academyService';
import { useRoseGold } from './SoloStudyPage';

type BoardArgs = { matchId: string; username: string; questions: AcademyQuestion[] };

export function GameBoardPage() {
  const args = useLocation().state as BoardArgs | null;
  if (!args || !args.matchId || !Array.isArray(args.questions)) return <ErrorPage />;
  return <GameBoard {...args} />;
}

const LOADING = Symbol('loading');

function GameBoard({ matchId, username, questions }: BoardArgs) {
  const navigate = useNavigate();
  const [isLocked, setIsLocked] = useState(false);
  const lockTimer = useRef<number | null>(null);
  const match = useSource<GameMatch | null | typeof LOADING>(() => academyService.watchMatch(matchId), [matchId], LOADING);

  useEffect(() => () => void (lockTimer.current != null && clearTimeout(lockTimer.current)), []);

  const finished = match !== LOADING && match != null && match.status === 'finished';
  useEffect(() => {
    if (finished) navigate('/academy/podium', { replace: true, state: { match } });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [finished]);

  const handleAnswer = async (question: AcademyQuestion, selected: number) => {
    if (isLocked) return;
    if (selected === question.correctOptionIndex) {
      await academyService.submitAnswer(matchId, username, question.id);
    } else {
      setIsLocked(true);
      lockTimer.current = window.setTimeout(() => setIsLocked(false), 2000);
    }
  };

  let body;
  if (match === LOADING) {
    body = (
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <EverglowSkeleton height={80} radius={16} />
      </div>
    );
  } else if (match == null) {
    // A deleted match reads as an empty document, which parses to a waiting match at question 0.
    body = <Board match={emptyMatch(matchId)} questions={questions} isLocked={isLocked} onAnswer={handleAnswer} />;
  } else if (match.status === 'finished') {
    body = (
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <span style={{ fontSize: 14, color: AppColors.petalWhite, ...letterSpacing(0) }}>Calculating Results...</span>
      </div>
    );
  } else {
    body = <Board match={match} questions={questions} isLocked={isLocked} onAnswer={handleAnswer} />;
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.deepRose, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.16 },
          { color: AppColors.softLavender, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
        ]}
      />
      {body}
    </div>
  );
}

function emptyMatch(matchId: string): GameMatch {
  return {
    matchId,
    hostId: '',
    participantId: null,
    hostUsername: null,
    participantUsername: null,
    hostScore: 0,
    guestScore: 0,
    status: 'waiting',
    currentQuestionId: '',
    questionIndex: 0,
    questionIds: [],
    category: 'engineering',
    createdAt: new Date(),
    winnerId: null,
    isReplenishing: false,
  };
}

function Board({
  match,
  questions,
  isLocked,
  onAnswer,
}: {
  match: GameMatch;
  questions: AcademyQuestion[];
  isLocked: boolean;
  onAnswer: (q: AcademyQuestion, i: number) => void;
}) {
  const total = questions.length;
  const inRange = total > 0 && match.questionIndex >= 0 && match.questionIndex < total;
  // The match document names the question everyone is on; a local list that is
  // short or reshuffled would otherwise show a question the server rejects.
  const current =
    questions.find((q) => q.id === match.currentQuestionId) ?? (inRange ? questions[match.questionIndex] : null);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding:
            'env(safe-area-inset-top, 0px) env(safe-area-inset-right, 0px) env(safe-area-inset-bottom, 0px) env(safe-area-inset-left, 0px)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <ScoreTracker
          hostName={match.hostUsername}
          guestName={match.participantUsername}
          hostScore={match.hostScore}
          guestScore={match.guestScore}
          questionIndex={match.questionIndex}
          totalQuestions={total === 0 ? 1 : total}
        />
        <div
          style={{
            flex: 1,
            minHeight: 0,
            padding: 24,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            overflow: 'hidden',
          }}
        >
          <span style={{ ...AppTypography.outfitBold, fontSize: 18, color: AppColors.auroraRose, ...letterSpacing(1.2) }}>
            Question {Math.min(Math.max(match.questionIndex + 1, 1), total === 0 ? 1 : total)}/{total === 0 ? '–' : total}
          </span>
          <div style={{ height: 20 }} />
          <div style={{ position: 'relative', alignSelf: 'stretch' }}>
            <div
              aria-hidden
              style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.15), blur: 22, spread: -6 }, { radius: AppRadius.x2 })}
            />
            <div
              ref={ref}
              style={{
                position: 'relative',
                padding: 21,
                background: linear([withAlpha(AppColors.velvet, 0.85), withAlpha(AppColors.inkDeep, 0.9)], {
                  begin: Align.topLeft,
                  end: Align.bottomRight,
                  size,
                }),
                borderRadius: AppRadius.x2,
                boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.16)}`,
                textAlign: 'center',
              }}
            >
              <span style={{ ...AppTypography.outfitWhite, fontSize: 22, fontWeight: 700, color: AppColors.petalWhite }}>
                {current?.questionText ?? 'Waiting for the next question...'}
              </span>
            </div>
          </div>
          <div style={{ height: 32 }} />
          {current?.options.map((text, i) => (
            <AnswerButton key={`${current.id}-${i}`} text={text} isLocked={isLocked} onTap={() => onAnswer(current, i)} />
          ))}
          {isLocked && (
            <span style={{ paddingTop: 20, ...AppTypography.outfitWhite, fontWeight: 700, color: AppColors.error }}>
              Locked out for 2 seconds...
            </span>
          )}
        </div>
      </div>
      {match.isReplenishing && <TriviaLoadingOverlay />}
    </>
  );
}

function ScoreTracker({
  hostName,
  guestName,
  hostScore,
  guestScore,
  questionIndex,
  totalQuestions,
}: {
  hostName: string | null;
  guestName: string | null;
  hostScore: number;
  guestScore: number;
  questionIndex: number;
  totalQuestions: number;
}) {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const [barRef, barGradient] = useRoseGold<HTMLDivElement>();
  const fraction = totalQuestions <= 0 ? 0 : Math.min(Math.max(questionIndex / totalQuestions, 0), 1);
  return (
    <div style={{ position: 'relative', margin: '16px 16px 0' }}>
      <div
        aria-hidden
        style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.5), blur: 18, offset: [0, 8] }, { radius: AppRadius.x2 })}
      />
      <div
        ref={ref}
        style={{
          position: 'relative',
          padding: '17px 21px',
          background: linear([withAlpha(AppColors.velvet, 0.85), withAlpha(AppColors.inkDeep, 0.9)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size,
          }),
          borderRadius: AppRadius.x2,
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.16)}`,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <PlayerScore name={displayNameFor(hostName)} score={hostScore} color={AppColors.softLavender} />
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 20, fontWeight: 900, color: AppColors.auroraRose }}>VS</span>
          <div style={{ height: 6 }} />
          <div
            style={{
              position: 'relative',
              height: 5,
              width: 64,
              background: withAlpha(AppColors.moonlight, 0.12),
              borderRadius: 3,
            }}
          >
            <div
              ref={barRef}
              style={{
                height: '100%',
                width: `${fraction * 100}%`,
                background: barGradient,
                borderRadius: 3,
                boxShadow: boxShadow([{ color: withAlpha(AppColors.auroraGold, 0.5), blur: 6 }]),
              }}
            />
          </div>
        </div>
        <PlayerScore name={displayNameFor(guestName)} score={guestScore} color={AppColors.auroraRose} />
      </div>
    </div>
  );
}

function PlayerScore({ name, score, color }: { name: string; score: number; color: string }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <span style={{ ...AppTypography.outfitBold, fontSize: 15, color: withAlpha(AppColors.petalWhite, 0.7) }}>{name}</span>
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 32,
          fontWeight: 900,
          color,
          textShadow: `0 0 ${2 * sigma(12)}px ${withAlpha(color, 0.5)}`,
        }}
      >
        {score}
      </span>
    </div>
  );
}

function AnswerButton({ text, isLocked, onTap }: { text: string; isLocked: boolean; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const enabled = !isLocked;
  const colors = isLocked
    ? [withAlpha(AppColors.moonlight, 0.06), withAlpha(AppColors.inkDeep, 0.4)]
    : hovered
      ? [withAlpha(AppColors.deepRose, 0.28), withAlpha(AppColors.velvet, 0.9)]
      : [withAlpha(AppColors.moonlight, 0.14), withAlpha(AppColors.inkDeep, 0.6)];
  const border = isLocked ? withAlpha(AppColors.moonlight, 0.12) : withAlpha(AppColors.auroraRose, hovered ? 0.7 : 0.35);
  return (
    <div
      style={{
        alignSelf: 'stretch',
        paddingBottom: 16,
        transform: `scale(${pressed ? 0.95 : 1})`,
        transition: 'transform 100ms ease-in-out',
      }}
    >
      <div
        role="button"
        tabIndex={enabled ? 0 : -1}
        aria-disabled={!enabled}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onClick={
          enabled
            ? () => {
                setPressed(true);
                window.setTimeout(() => setPressed(false), 100);
                onTap();
              }
            : undefined
        }
        style={{ position: 'relative', cursor: enabled ? 'pointer' : 'default' }}
      >
        {hovered && !isLocked && (
          <div
            aria-hidden
            style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.3), blur: 18, offset: [0, 6] }, { radius: AppRadius.xl })}
          />
        )}
        <div
          ref={ref}
          style={{
            position: 'relative',
            height: 60,
            background: linear(colors, { begin: Align.topLeft, end: Align.bottomRight, size }),
            borderRadius: AppRadius.xl,
            boxShadow: `inset 0 0 0 1.4px ${border}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
            padding: '0 1.4px',
          }}
        >
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 18,
              fontWeight: 700,
              color: isLocked ? Derived.textDisabled : AppColors.petalWhite,
            }}
          >
            {text}
          </span>
        </div>
      </div>
    </div>
  );
}

// Colors.pink, Colors.pink[400].
const PINK = '#E91E63';
const PINK_400 = '#EC407A';

function TriviaLoadingOverlay({ message = 'Downloading new study materials... 📚' }: { message?: string }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: withAlpha(PINK, 0.3),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <style>{`
        @keyframes academy-bounce-in-down {
          0% { opacity: 0; transform: translateY(-3000px); }
          60% { opacity: 1; transform: translateY(25px); }
          75% { transform: translateY(-10px); }
          90% { transform: translateY(5px); }
          100% { transform: none; }
        }
        @keyframes academy-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        @keyframes academy-indeterminate {
          0% { left: -35%; right: 100%; }
          60% { left: 100%; right: -90%; }
          100% { left: 100%; right: -90%; }
        }
      `}</style>
      <div
        style={{
          padding: '30px 40px',
          background: AppColors.petalWhite,
          borderRadius: 30,
          boxShadow: boxShadow([{ color: withAlpha(PINK, 0.2), blur: 20, offset: [0, 10] }]),
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          animation: 'academy-bounce-in-down 1000ms ease-out both',
        }}
      >
        <div style={{ display: 'flex', animation: 'academy-spin 3000ms linear infinite' }}>
          <Icon name="auto_awesome" size={50} color={PINK} />
        </div>
        <div style={{ height: 24 }} />
        <span style={{ ...AppTypography.outfitWhite, fontSize: 18, fontWeight: 700, color: PINK_400, textAlign: 'center' }}>
          {message}
        </span>
        <div style={{ height: 16 }} />
        <div
          style={{
            position: 'relative',
            alignSelf: 'stretch',
            height: 4,
            borderRadius: 10,
            overflow: 'hidden',
            background: '#FFE6F2',
          }}
        >
          <div
            style={{
              position: 'absolute',
              top: 0,
              bottom: 0,
              background: PINK,
              animation: 'academy-indeterminate 1800ms linear infinite',
            }}
          />
        </div>
      </div>
    </div>
  );
}
