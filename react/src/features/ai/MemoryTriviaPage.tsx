// Port of lib/features/ai/presentation/screens/memory_trivia_screen.dart.
import { useEffect, useRef, useState } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { FilledButton } from '../../shared/widgets/MaterialFields';
import { AIMemoryRepository } from './aiMemoryRepo';
import { generateMemoryTrivia, type MemoryTriviaQuestion } from './memory';

type ChoiceState = 'idle' | 'correct' | 'wrong' | 'dimmed';
const medium = { ...AppTypography.outfitMedium, fontSize: 14, lineHeight: lineHeight(14) };

export function MemoryTriviaPage() {
  const repo = useRef(new AIMemoryRepository()).current;
  const [questions, setQuestions] = useState<MemoryTriviaQuestion[]>([]);
  const [index, setIndex] = useState(0);
  const [score, setScore] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [revealed, setRevealed] = useState(false);

  const start = async () => {
    setLoading(true);
    setIndex(0);
    setScore(0);
    setSelected(null);
    setRevealed(false);
    await repo.load();
    setQuestions(generateMemoryTrivia(repo.facts, 6));
    setLoading(false);
  };
  useEffect(() => {
    void start();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const current = index < questions.length ? questions[index] : null;

  const choose = (choice: number) => {
    if (revealed || !current) return;
    setSelected(choice);
    setRevealed(true);
    if (choice === current.answerIndex) setScore((s) => s + 1);
  };

  const next = () => {
    if (index + 1 >= questions.length) {
      setIndex(questions.length);
      return;
    }
    setIndex(index + 1);
    setSelected(null);
    setRevealed(false);
  };

  const stateOf = (i: number): ChoiceState => {
    if (!revealed || !current) return 'idle';
    if (i === current.answerIndex) return 'correct';
    if (i === selected) return 'wrong';
    return 'dimmed';
  };

  let body;
  if (loading) {
    body = (
      <div style={{ padding: 16 }}>
        <EverglowSkeleton height={120} radius={16} />
      </div>
    );
  } else if (questions.length === 0) {
    body = (
      <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ ...medium, padding: 24, textAlign: 'center' }}>
          Not enough memories yet. Ask Motchi to remember something first!
        </div>
      </div>
    );
  } else if (current == null) {
    const perfect = score === questions.length;
    body = (
      <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ ...AppTypography.cormorantHeading, fontSize: 30, lineHeight: lineHeight(30) }}>
            {perfect ? '🐱 Perfect! Motchi is proud' : '🌙 Nice try'}
          </div>
          <div style={{ height: 16 }} />
          <div style={{ ...AppTypography.outfitHeading, fontSize: 22, lineHeight: lineHeight(22), color: AppColors.auroraGold }}>
            {score} / {questions.length} memories
          </div>
          <div style={{ height: 20 }} />
          <FilledButton icon="refresh" label="Play again" onPressed={() => void start()} />
        </div>
      </div>
    );
  } else {
    const progress = Math.min(1, Math.max(0, index / questions.length));
    body = (
      <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto' }}>
        <div style={{ padding: 16, display: 'flex', flexDirection: 'column' }}>
          <div style={{ height: 6, borderRadius: AppRadius.full, background: Derived.surfaceGlass, overflow: 'hidden' }}>
            <div style={{ width: `${progress * 100}%`, height: '100%', background: AppColors.auroraRose }} />
          </div>
          <div style={{ height: 20 }} />
          <div style={{ ...AppTypography.outfitMuted, fontSize: 12, lineHeight: lineHeight(12) }}>
            Memory {index + 1} of {questions.length}
          </div>
          <div style={{ height: 8 }} />
          <div
            style={{ ...AppTypography.cormorantHeading, fontSize: 26, lineHeight: lineHeight(26), color: AppColors.petalWhite }}
          >
            {current.question}
          </div>
          <div style={{ height: 24 }} />
          {current.choices.map((choice, i) => (
            <div key={i} style={{ paddingBottom: 8 }}>
              <ChoiceButton label={choice} state={stateOf(i)} onTap={() => choose(i)} />
            </div>
          ))}
          {revealed && (
            <>
              <div style={{ height: 8 }} />
              <div
                style={{
                  padding: 17,
                  borderRadius: AppRadius.lg,
                  background: withAlpha(AppColors.auroraGold, 0.12),
                  boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.auroraGold, 0.5)}`,
                  ...medium,
                }}
              >
                {current.explanation}
              </div>
              <div style={{ height: 16 }} />
              <FilledButton
                stretch
                icon="arrow_forward"
                label={index + 1 >= questions.length ? 'See score' : 'Next memory'}
                onPressed={next}
              />
            </>
          )}
        </div>
      </div>
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.twilight }}>
      <EverglowBackground
        glows={[
          { color: AppColors.auroraRose, alignment: [-0.7, -0.8], size: 0.7, opacity: 0.14 },
          { color: AppColors.auroraTeal, alignment: [0.9, 0.85], size: 0.55, opacity: 0.1 },
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
          title="Memory Trivia"
          subtitle="how well do you know your own story?"
          icon="quiz"
          hue={AppColors.auroraRose}
        />
        <div style={{ flex: 1, minHeight: 0 }}>{body}</div>
      </div>
    </div>
  );
}

function ChoiceButton({ label, state, onTap }: { label: string; state: ChoiceState; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [border, fill] =
    state === 'correct'
      ? [AppColors.success, withAlpha(AppColors.success, 0.14)]
      : state === 'wrong'
        ? [AppColors.error, withAlpha(AppColors.error, 0.12)]
        : state === 'dimmed'
          ? [Derived.border, Derived.surfaceGlass]
          : [withAlpha(AppColors.softLavender, 0.5), Derived.surfaceGlass];
  const idle = state === 'idle';
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!idle}
      onClick={onTap}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        position: 'relative',
        width: '100%',
        padding: 17,
        borderRadius: AppRadius.lg,
        background: fill,
        boxShadow: `inset 0 0 0 1px ${border}`,
        display: 'flex',
        alignItems: 'center',
        transition: 'background 180ms, box-shadow 180ms',
        cursor: idle ? 'pointer' : 'default',
      }}
    >
      {idle && hovered && (
        <span
          aria-hidden
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: AppRadius.lg,
            background: withAlpha(AppColors.petalWhite, 0.04),
          }}
        />
      )}
      {state === 'correct' && <Icon name="check_circle" size={18} color={AppColors.success} />}
      {state === 'wrong' && <Icon name="cancel" size={18} color={AppColors.error} />}
      {(state === 'correct' || state === 'wrong') && <div style={{ width: 8 }} />}
      <span style={{ ...AppTypography.outfitWhite, fontSize: 14, lineHeight: lineHeight(14), flex: 1 }}>{label}</span>
    </button>
  );
}
