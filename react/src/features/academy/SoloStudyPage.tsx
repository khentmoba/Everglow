// Port of lib/features/academy/presentation/screens/solo_study_screen.dart.
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { ErrorPage } from '../../core/router/ErrorPage';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, boxShadow, linear, lineHeight, letterSpacing, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { TextButton } from '../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowIconButton } from '../../shared/widgets/EverglowScaffold';
import { Icon } from '../../shared/widgets/Icon';
import { studySetService, type AcademyQuestion } from './academyService';

// `context.pop('challenge')`: the hub reads this once when it shows again.
let soloResult: string | null = null;
export function takeSoloResult(): string | null {
  const r = soloResult;
  soloResult = null;
  return r;
}

/** AppTheme.roseGoldGradient, run corner to corner in the box's own pixels. */
export function useRoseGold<T extends HTMLElement>() {
  const [ref, size] = useBoxSize<T>();
  const gradient = linear([AppColors.auroraRose, AppColors.deepRose, AppColors.blushGold], {
    begin: Align.topLeft,
    end: Align.bottomRight,
    size,
  });
  return [ref, gradient] as const;
}

type SoloArgs = { questions: AcademyQuestion[]; category: string; topic?: string };

export function SoloStudyPage() {
  const args = useLocation().state as SoloArgs | null;
  if (!args || !Array.isArray(args.questions)) return <ErrorPage />;
  return <SoloStudy questions={args.questions} category={args.category} topic={args.topic ?? ''} />;
}

function SoloStudy({ questions: initial, category, topic }: { questions: AcademyQuestion[]; category: string; topic: string }) {
  const navigate = useNavigate();
  const [questions, setQuestions] = useState(initial);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [score, setScore] = useState(0);
  const [isAnswered, setIsAnswered] = useState(false);
  const [isCorrect, setIsCorrect] = useState<boolean | null>(null);
  const [lastChosen, setLastChosen] = useState<number | null>(null);
  const [finished, setFinished] = useState(false);
  const [isNewBest, setIsNewBest] = useState(false);
  const [isReloading, setIsReloading] = useState(false);
  const mounted = useRef(true);
  const timer = useRef<number | null>(null);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      if (timer.current != null) clearTimeout(timer.current);
    };
  }, []);

  const setLabel = topic !== '' ? topic : category === '' ? 'Study' : category[0].toUpperCase() + category.slice(1);
  const pop = (result?: string) => {
    soloResult = result ?? null;
    navigate(-1);
  };

  const practiceAgain = async () => {
    setIsReloading(true);
    const fresh = await studySetService.buildSoloSet(category, topic);
    if (!mounted.current) return;
    setQuestions(fresh.length > 0 ? fresh : initial);
    setCurrentIndex(0);
    setScore(0);
    setIsAnswered(false);
    setIsCorrect(null);
    setLastChosen(null);
    setFinished(false);
    setIsNewBest(false);
    setIsReloading(false);
  };

  const finishSet = async (finalScore: number) => {
    const best = await studySetService.saveSoloResult(category, finalScore, questions.length);
    if (!mounted.current) return;
    setFinished(true);
    setIsNewBest(best);
  };

  const handleAnswer = (index: number) => {
    if (isAnswered) return;
    const correct = index === questions[currentIndex].correctOptionIndex;
    const nextScore = score + (correct ? 1 : 0);
    setIsAnswered(true);
    setIsCorrect(correct);
    setLastChosen(index);
    setScore(nextScore);
    timer.current = window.setTimeout(() => {
      if (!mounted.current) return;
      if (currentIndex + 1 < questions.length) {
        setCurrentIndex(currentIndex + 1);
        setIsAnswered(false);
        setIsCorrect(null);
        setLastChosen(null);
      } else {
        void finishSet(nextScore);
      }
    }, 2200);
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraLilac, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
        ]}
      />
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
        <Header label={setLabel} score={score} onClose={() => pop()} />
        <Progress index={currentIndex} total={questions.length} finished={finished} />
        <div
          className="no-scrollbar"
          style={{ flex: 1, minHeight: 0, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}
        >
          {questions.length === 0 ? (
            <Empty onBack={() => pop()} />
          ) : finished ? (
            <Results
              score={score}
              total={questions.length}
              isNewBest={isNewBest}
              setLabel={setLabel}
              topic={topic}
              onAgain={() => void practiceAgain()}
              onChallenge={() => pop('challenge')}
              onBack={() => pop()}
            />
          ) : (
            <div style={{ padding: '12px 24px 24px', display: 'flex', flexDirection: 'column' }}>
              <QuestionCard text={questions[currentIndex].questionText} />
              <div style={{ height: 24 }} />
              {questions[currentIndex].options.map((option, i) => (
                <Option
                  key={`${currentIndex}-${i}`}
                  text={option}
                  state={
                    !isAnswered
                      ? 'idle'
                      : i === questions[currentIndex].correctOptionIndex
                        ? 'correct'
                        : isCorrect === false && i === lastChosen
                          ? 'wrong'
                          : 'other'
                  }
                  onTap={isAnswered ? undefined : () => handleAnswer(i)}
                />
              ))}
              {isAnswered && (
                <>
                  <div style={{ height: 4 }} />
                  <Feedback question={questions[currentIndex]} correct={isCorrect === true} />
                </>
              )}
            </div>
          )}
        </div>
      </div>
      {isReloading && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.7),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <span style={{ ...AppTypography.outfitWhite, fontSize: 15, color: AppColors.auroraGold }}>
            Motchi is writing new questions... 🍡
          </span>
        </div>
      )}
    </div>
  );
}

function Header({ label, score, onClose }: { label: string; score: number; onClose: () => void }) {
  const [ref, gradient] = useRoseGold<HTMLDivElement>();
  return (
    <div style={{ padding: '12px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <EverglowIconButton icon="close" onPressed={onClose} semanticLabel="Close" tooltip="Close" />
      <span
        className="ellipsis"
        style={{
          flex: 1,
          minWidth: 0,
          ...AppTypography.outfitWhite,
          fontSize: 15,
          fontWeight: 600,
          color: withAlpha(AppColors.petalWhite, 0.85),
          textAlign: 'center',
        }}
      >
        {label}
      </span>
      <div
        ref={ref}
        style={{
          padding: '8px 14px',
          background: gradient,
          borderRadius: 20,
          boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.4), blur: 12 }]),
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <Icon name="stars" size={16} color={AppColors.petalWhite} />
        <div style={{ width: 6 }} />
        <span style={{ ...AppTypography.outfitBold, fontSize: 16, color: AppColors.petalWhite }}>{score}</span>
      </div>
    </div>
  );
}

function Progress({ index, total: count, finished }: { index: number; total: number; finished: boolean }) {
  const total = count === 0 ? 1 : count;
  const done = finished ? total : index;
  const [ref, gradient] = useRoseGold<HTMLDivElement>();
  return (
    <div style={{ padding: '0 24px 8px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 13,
            ...letterSpacing(1.2),
            color: AppColors.auroraRose,
            flexShrink: 0,
          }}
        >
          Question {Math.min(Math.max(index + 1, 1), total)}/{total}
        </span>
        <div style={{ width: 12 }} />
        <span
          className="ellipsis"
          style={{ minWidth: 0, ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.45) }}
        >
          no timer · take your time
        </span>
      </div>
      <div style={{ height: 8 }} />
      <div style={{ height: 6, borderRadius: 4, overflow: 'hidden', background: withAlpha(AppColors.moonlight, 0.12) }}>
        <div
          ref={ref}
          style={{ height: '100%', width: `${Math.min(Math.max(done / total, 0), 1) * 100}%`, background: gradient }}
        />
      </div>
    </div>
  );
}

function Empty({ onBack }: { onBack: () => void }) {
  return (
    <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ padding: 32, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <span style={{ fontSize: 48 }}>🍡</span>
        <div style={{ height: 16 }} />
        <span style={{ ...AppTypography.cormorantBold, fontSize: 24 }}>No questions right now</span>
        <div style={{ height: 8 }} />
        <span style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.7), textAlign: 'center' }}>
          Motchi is resting — try again in a bit.
        </span>
        <div style={{ height: 24 }} />
        <TextButton onPressed={onBack} color={AppColors.blushGold} style={{ fontWeight: 700 }}>
          Back to Hub
        </TextButton>
      </div>
    </div>
  );
}

function QuestionCard({ text }: { text: string }) {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <div style={{ position: 'relative' }}>
      <div
        aria-hidden
        style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.14), blur: 22, spread: -6 }, { radius: AppRadius.x2 })}
      />
      <div
        ref={ref}
        style={{
          position: 'relative',
          padding: 25,
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
        <span style={{ ...AppTypography.outfitWhite, fontSize: 20, fontWeight: 700, color: AppColors.petalWhite }}>{text}</span>
      </div>
    </div>
  );
}

function Option({ text, state, onTap }: { text: string; state: 'idle' | 'correct' | 'wrong' | 'other'; onTap?: () => void }) {
  const fill =
    state === 'correct'
      ? withAlpha(AppColors.success, 0.18)
      : state === 'wrong'
        ? withAlpha(AppColors.error, 0.18)
        : state === 'other'
          ? withAlpha(AppColors.moonlight, 0.06)
          : withAlpha(AppColors.moonlight, 0.1);
  const border =
    state === 'correct' ? AppColors.success : state === 'wrong' ? AppColors.error : withAlpha(AppColors.moonlight, 0.22);
  return (
    <div style={{ paddingBottom: 12 }}>
      <div
        role="button"
        tabIndex={onTap ? 0 : -1}
        onClick={onTap}
        onKeyDown={(e) => onTap && (e.key === 'Enter' || e.key === ' ') && onTap()}
        style={{ position: 'relative', cursor: onTap ? 'pointer' : undefined }}
      >
        <div
          aria-hidden
          style={{
            ...shadowLayer({ color: withAlpha(AppColors.success, 0.25), blur: 14 }, { radius: AppRadius.xl }),
            opacity: state === 'correct' ? 1 : 0,
            transition: 'opacity 300ms linear',
          }}
        />
        <div
          style={{
            position: 'relative',
            padding: '17.4px 15.4px',
            background: fill,
            borderRadius: AppRadius.xl,
            boxShadow: `inset 0 0 0 1.4px ${border}`,
            transition: 'background 300ms linear, box-shadow 300ms linear',
            textAlign: 'center',
          }}
        >
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 16,
              fontWeight: 500,
              color: state === 'correct' ? AppColors.petalWhite : Derived.textMedium,
            }}
          >
            {text}
          </span>
        </div>
      </div>
    </div>
  );
}

function Feedback({ question, correct }: { question: AcademyQuestion; correct: boolean }) {
  const hue = correct ? AppColors.success : AppColors.auroraGold;
  const message = correct
    ? 'Lovely — that’s right! 🍡'
    : `Almost, love — it was ${question.options[question.correctOptionIndex]}.`;
  return (
    <div
      style={{
        padding: 17,
        background: withAlpha(hue, 0.1),
        borderRadius: AppRadius.xl,
        boxShadow: `inset 0 0 0 1px ${withAlpha(hue, 0.3)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
      }}
    >
      <span style={{ ...AppTypography.outfitWhite, fontSize: 15, fontWeight: 600, color: AppColors.petalWhite }}>{message}</span>
      {question.explanation && (
        <>
          <div style={{ height: 8 }} />
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 13,
              lineHeight: lineHeight(13, 1.45),
              color: withAlpha(AppColors.petalWhite, 0.75),
            }}
          >
            🍡 {question.explanation}
          </span>
        </>
      )}
    </div>
  );
}

function Results({
  score,
  total,
  isNewBest,
  setLabel,
  topic,
  onAgain,
  onChallenge,
  onBack,
}: {
  score: number;
  total: number;
  isNewBest: boolean;
  setLabel: string;
  topic: string;
  onAgain: () => void;
  onChallenge: () => void;
  onBack: () => void;
}) {
  const ratio = total === 0 ? 0 : score / total;
  const title =
    ratio >= 1 ? 'Perfect, my love! 🍡' : ratio >= 0.7 ? 'So lovely!' : ratio >= 0.4 ? 'Good practice!' : 'Every try counts.';
  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
      <span style={{ ...AppTypography.cormorantBold, fontSize: 32 }}>{title}</span>
      <div style={{ height: 8 }} />
      <span style={{ ...AppTypography.cormorantExtraBold, fontSize: 56, color: AppColors.auroraGold }}>
        {score} / {total}
      </span>
      {isNewBest && (
        <span style={{ paddingTop: 4, ...AppTypography.outfitWhite, fontSize: 14, fontWeight: 600, color: AppColors.auroraGold }}>
          ✨ New best in {setLabel}!
        </span>
      )}
      <div style={{ height: 8 }} />
      <span style={{ ...AppTypography.outfitWhite, fontSize: 14, color: withAlpha(AppColors.petalWhite, 0.7) }}>
        {topic !== '' ? `Motchi loved writing about “${topic}”.` : 'Motchi is proud of you.'}
      </span>
      <div style={{ height: 32 }} />
      <ResultsButton label="Practice again" icon="refresh" primary onTap={onAgain} />
      <div style={{ height: 12 }} />
      <ResultsButton label="Challenge my love to 1v1" icon="bolt" onTap={onChallenge} />
      <div style={{ height: 12 }} />
      <ResultsButton label="Back to Hub" icon="home" onTap={onBack} />
    </div>
  );
}

function ResultsButton({
  label,
  icon,
  primary = false,
  onTap,
}: {
  label: string;
  icon: string;
  primary?: boolean;
  onTap: () => void;
}): ReactNode {
  const [ref, gradient] = useRoseGold<HTMLButtonElement>();
  return (
    <button
      ref={ref}
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        alignSelf: 'stretch',
        padding: '17.2px 21.2px',
        background: primary ? gradient : withAlpha(AppColors.moonlight, 0.1),
        borderRadius: AppRadius.xl,
        boxShadow: `inset 0 0 0 1.2px ${primary ? withAlpha(AppColors.petalWhite, 0.4) : withAlpha(AppColors.moonlight, 0.22)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name={icon} size={20} color={AppColors.petalWhite} />
      <div style={{ width: 10 }} />
      <span style={{ minWidth: 0, ...AppTypography.outfitWhite, fontSize: 16, fontWeight: 700, color: AppColors.petalWhite }}>
        {label}
      </span>
    </button>
  );
}
