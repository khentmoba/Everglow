// Port of lib/features/ai/presentation/widgets/study_artifact_sheet.dart,
// study_artifact_quiz.dart and study_artifact_flashcards.dart.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { Logger } from '../../core/system/logger';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, boxShadow, letterSpacing, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { showDialog, showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { aiChat } from './aiChat';
import { openCanvasPreview } from './CanvasPreviewSheet';
import {
  artifactsEmpty,
  type ClarificationChoice,
  type Flashcard,
  type QuizQuestion,
  type StudyArtifacts,
} from './studyArtifact';

type Tab = 'quiz' | 'flashcards';
const diag = { begin: Align.topLeft, end: Align.bottomRight };

export function openStudyArtifactSheet(artifacts: StudyArtifacts, initialTab?: Tab): Promise<unknown> {
  const tab = initialTab ?? (artifacts.quiz.length > 0 ? 'quiz' : 'flashcards');
  if (window.innerWidth >= 1024) {
    return showDialog((close) => (
      <div
        style={{
          width: 'min(720px, calc(100vw - 48px))',
          maxHeight: 'min(640px, calc(100vh - 48px))',
          margin: '0 -16px',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <SheetChrome>
          <StudyArtifactSheet artifacts={artifacts} initialTab={tab} onClose={() => close(null)} />
        </SheetChrome>
      </div>
    ));
  }
  return showModalBottomSheet((close) => (
    <div style={{ height: '92vh', display: 'flex', flexDirection: 'column' }}>
      <SheetChrome handle>
        <StudyArtifactSheet artifacts={artifacts} initialTab={tab} onClose={() => close(null)} />
      </SheetChrome>
    </div>
  ));
}

export function StudyArtifactEntry({ artifacts }: { artifacts: StudyArtifacts }) {
  const navigate = useNavigate();
  if (artifactsEmpty(artifacts)) return null;
  const buttons: ReactNode[] = [];
  const { quiz, flashcards } = artifacts;
  if (quiz.length > 0) {
    buttons.push(
      <LaunchButton
        key="quiz"
        kind="quiz"
        icon="edit_note"
        label={`Try the quiz ✍️ · ${quiz.length} question${quiz.length === 1 ? '' : 's'}`}
        onTap={() => void openStudyArtifactSheet(artifacts, 'quiz')}
      />,
    );
  }
  if (flashcards.length > 0) {
    buttons.push(
      <LaunchButton
        key="cards"
        kind="cards"
        icon="style"
        label={`Flip the cards 🃏 · ${flashcards.length} card${flashcards.length === 1 ? '' : 's'}`}
        onTap={() => void openStudyArtifactSheet(artifacts, 'flashcards')}
      />,
    );
  }
  artifacts.html.forEach((app, i) =>
    buttons.push(
      <LaunchButton
        key={`html${i}`}
        kind="game"
        icon="play_circle_filled"
        label={`Preview 🔍 · ${app.title}`}
        onTap={() => void openCanvasPreview(app)}
      />,
    ),
  );
  artifacts.links.forEach((link, i) =>
    buttons.push(
      <LaunchButton key={`link${i}`} kind="game" icon="sports_esports" label={link.label} onTap={() => navigate(link.route)} />,
    ),
  );
  artifacts.choices.forEach((choice, i) => buttons.push(<ClarificationChoicePills key={`choice${i}`} choiceGroup={choice} />));
  return (
    <div style={{ paddingBottom: 10, display: 'flex', flexDirection: 'column', alignItems: 'stretch', gap: 8 }}>{buttons}</div>
  );
}

function ClarificationChoicePills({ choiceGroup }: { choiceGroup: ClarificationChoice }) {
  const send = async (choice: string) => {
    try {
      await aiChat.sendMessage({ feature: 'assistant', message: choice, stream: true });
    } catch (e) {
      Logger.e('Failed to send clarification choice', e);
    }
  };
  return (
    <div style={{ padding: '4px 0', display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      {choiceGroup.prompt ? (
        <div
          style={{
            ...AppTypography.labelSmall,
            lineHeight: lineHeight(11),
            color: Derived.textMedium,
            fontWeight: 600,
            paddingBottom: 6,
          }}
        >
          {choiceGroup.prompt}
        </div>
      ) : null}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {choiceGroup.choices.map((choice) => (
          <button
            key={choice}
            type="button"
            className="bare-button"
            onClick={() => void send(choice)}
            style={{
              height: 32,
              padding: '0 16px',
              borderRadius: AppRadius.full,
              background: Derived.surfaceGlass,
              border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.35)}`,
              boxSizing: 'border-box',
              ...AppTypography.bodySmall,
              lineHeight: lineHeight(12.5),
              color: AppColors.petalWhite,
              fontWeight: 600,
            }}
          >
            {choice}
          </button>
        ))}
      </div>
    </div>
  );
}

const launchStyles = {
  game: {
    tag: '🐾 MINI GAME · PLAY TOGETHER',
    action: 'Play',
    badge: [AppColors.auroraRose, AppColors.auroraGold],
    actionFill: [AppColors.deepRose, AppColors.auroraRose],
    accent: AppColors.auroraRose,
    icon: 'sports_esports',
  },
  quiz: {
    tag: '🐾 MOTCHI QUIZ · TEST YOUR KNOWLEDGE',
    action: 'Quiz',
    badge: [AppColors.blushGold, AppColors.warmAmber],
    actionFill: [AppColors.blushGold, AppColors.deepRose],
    accent: AppColors.blushGold,
    icon: 'quiz',
  },
  cards: {
    tag: '🐾 FLASHCARDS · STUDY TOGETHER',
    action: 'Cards',
    badge: [AppColors.auroraLilac, AppColors.softLavender],
    actionFill: [AppColors.auroraLilac, AppColors.plum],
    accent: AppColors.auroraLilac,
    icon: 'style',
  },
};

function LaunchButton({
  kind,
  label,
  onTap,
}: {
  kind: keyof typeof launchStyles;
  icon: string;
  label: string;
  onTap: () => void;
}) {
  const [hover, setHover] = useState(false);
  const s = launchStyles[kind];
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        padding: '12px 14px',
        borderRadius: 18,
        background: linear(
          [withAlpha(AppColors.inkDeep, hover ? 0.95 : 0.88), withAlpha(AppColors.velvet, hover ? 0.82 : 0.7)],
          diag,
        ),
        border: `1.2px solid ${withAlpha(s.accent, hover ? 0.45 : 0.22)}`,
        boxShadow: boxShadow([
          { color: 'rgba(0,0,0,0.35)', blur: 16, offset: [0, 5] },
          ...(hover ? [{ color: withAlpha(s.accent, 0.22), blur: 20, offset: [0, 3] as [number, number] }] : []),
        ]),
        transition: 'background 180ms linear, border-color 180ms linear, box-shadow 180ms linear',
        display: 'flex',
        alignItems: 'center',
        textAlign: 'left',
        width: '100%',
        boxSizing: 'border-box',
      }}
    >
      <div
        style={{
          width: 38,
          height: 38,
          flexShrink: 0,
          borderRadius: 12,
          background: linear(s.badge, diag),
          boxShadow: boxShadow([{ color: withAlpha(s.badge[0], 0.4), blur: 10, offset: [0, 3] }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={s.icon} size={20} color={AppColors.petalWhite} />
      </div>
      <div style={{ width: 12, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.labelSmall,
            fontSize: 9.5,
            lineHeight: lineHeight(9.5),
            ...letterSpacing(0.7),
            color: s.accent,
            ...ellipsis,
          }}
        >
          {s.tag}
        </div>
        <div style={{ height: 3 }} />
        <div
          style={{
            ...AppTypography.bodyMedium,
            fontSize: 13.5,
            fontWeight: 700,
            lineHeight: lineHeight(13.5, 1.25),
            color: AppColors.petalWhite,
            ...ellipsis,
          }}
        >
          {label}
        </div>
      </div>
      <div style={{ width: 10, flexShrink: 0 }} />
      <div
        style={{
          padding: '6px 11px',
          borderRadius: AppRadius.full,
          background: linear(s.actionFill, diag),
          boxShadow: boxShadow([{ color: withAlpha(s.actionFill[0], 0.35), blur: 8, offset: [0, 2] }]),
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          flexShrink: 0,
        }}
      >
        <span
          style={{
            ...AppTypography.bodySmall,
            fontSize: 11.5,
            fontWeight: 700,
            lineHeight: lineHeight(11.5),
            color: AppColors.petalWhite,
          }}
        >
          {s.action}
        </span>
        <Icon name="arrow_forward" size={13} color={AppColors.petalWhite} />
      </div>
    </button>
  );
}

const ellipsis: CSSProperties = { whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' };

function SheetChrome({ handle, children }: { handle?: boolean; children: ReactNode }) {
  return (
    <div
      style={{
        flex: 1,
        minHeight: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        background: linear([withAlpha(AppColors.velvet, 0.98), withAlpha(AppColors.inkDeep, 0.99)], {
          begin: Align.topCenter,
          end: Align.bottomCenter,
        }),
        borderRadius: 24,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.28)}`,
        boxShadow: boxShadow([
          { color: 'rgba(0,0,0,0.55)', blur: 40, offset: [0, -10] },
          { color: withAlpha(AppColors.blushGold, 0.08), blur: 30, offset: [0, -2] },
        ]),
        paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        boxSizing: 'border-box',
      }}
    >
      {handle && (
        <>
          <div style={{ height: 10, flexShrink: 0 }} />
          <div
            style={{
              width: 44,
              height: 5,
              flexShrink: 0,
              borderRadius: AppRadius.full,
              background: withAlpha(AppColors.blushGold, 0.35),
            }}
          />
        </>
      )}
      <div style={{ alignSelf: 'stretch', flex: '0 1 auto', minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
    </div>
  );
}

function StudyArtifactSheet({
  artifacts,
  initialTab,
  onClose,
}: {
  artifacts: StudyArtifacts;
  initialTab: Tab;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<Tab>(initialTab);
  const showTabs = artifacts.quiz.length > 0 && artifacts.flashcards.length > 0;
  return (
    <>
      <div style={{ padding: '16px 12px 4px 20px', display: 'flex', alignItems: 'center', flexShrink: 0 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.labelSmall,
              fontSize: 10,
              lineHeight: lineHeight(10),
              ...letterSpacing(0.8),
              color: AppColors.blushGold,
            }}
          >
            🐾 MOTCHI STUDY
          </div>
          <div style={{ height: 2 }} />
          <div
            style={{
              ...AppTypography.titleLarge,
              fontSize: 21,
              fontWeight: 700,
              lineHeight: lineHeight(21),
              ...letterSpacing(-0.3),
            }}
          >
            {tab === 'quiz' ? 'Quiz time ✍️' : 'Flashcards 🃏'}
          </div>
        </div>
        <div style={{ borderRadius: '50%', background: withAlpha(AppColors.moonlight, 0.08) }}>
          <MaterialIconButton icon="close" size={19} tooltip="Back to chat" color={Derived.textMuted} onPressed={onClose} />
        </div>
      </div>
      {showTabs && (
        <div style={{ padding: '8px 20px 4px', flexShrink: 0 }}>
          <TabSwitch tab={tab} quizCount={artifacts.quiz.length} cardCount={artifacts.flashcards.length} onChanged={setTab} />
        </div>
      )}
      <div style={{ flex: '0 1 auto', minHeight: 0, overflowY: 'auto' }}>
        {tab === 'quiz' ? (
          <QuizPlayView questions={artifacts.quiz} onClose={onClose} />
        ) : (
          <FlashcardsPlayView cards={artifacts.flashcards} />
        )}
      </div>
    </>
  );
}

function TabSwitch({
  tab,
  quizCount,
  cardCount,
  onChanged,
}: {
  tab: Tab;
  quizCount: number;
  cardCount: number;
  onChanged: (t: Tab) => void;
}) {
  const option = (value: Tab, label: string) => {
    const selected = tab === value;
    return (
      <button
        type="button"
        className="bare-button"
        onClick={() => onChanged(value)}
        style={{
          flex: 1,
          padding: '10px 0',
          borderRadius: AppRadius.full,
          background: selected ? linear([AppColors.blushGold, AppColors.deepRose], diag) : 'transparent',
          transition: 'background 200ms linear',
          ...AppTypography.bodySmall,
          fontSize: 13,
          fontWeight: 700,
          lineHeight: lineHeight(13),
          color: selected ? AppColors.petalWhite : Derived.textMuted,
          textAlign: 'center',
        }}
      >
        {label}
      </button>
    );
  };
  return (
    <div
      style={{
        padding: 4,
        borderRadius: AppRadius.full,
        background: linear([withAlpha(AppColors.inkDeep, 0.9), withAlpha(AppColors.velvet, 0.7)], diag),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
        display: 'flex',
      }}
    >
      {option('quiz', `Quiz · ${quizCount}`)}
      {option('flashcards', `Cards · ${cardCount}`)}
    </div>
  );
}

const elevatedShadow = '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)';

function BigButton({ onPressed, children, filled = true }: { onPressed?: () => void; children: ReactNode; filled?: boolean }) {
  const enabled = onPressed != null;
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!enabled}
      onClick={onPressed}
      style={{
        width: '100%',
        height: 52,
        borderRadius: AppRadius.xl,
        background: filled ? (enabled ? AppColors.deepRose : withAlpha(AppColors.velvet, 0.4)) : 'transparent',
        border: filled ? undefined : `1px solid ${enabled ? Derived.border : withAlpha(AppColors.petalWhite, 0.12)}`,
        boxShadow: filled && enabled ? elevatedShadow : undefined,
        boxSizing: 'border-box',
        ...AppTypography.labelLarge,
        lineHeight: lineHeight(14),
        color: enabled ? (filled ? AppColors.petalWhite : Derived.textHigh) : withAlpha(AppColors.petalWhite, 0.38),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: enabled ? 'pointer' : 'default',
      }}
    >
      {children}
    </button>
  );
}

type OptionState = 'idle' | 'correct' | 'wrong' | 'dimmed';

export function QuizPlayView({ questions, onClose }: { questions: QuizQuestion[]; onClose: () => void }) {
  const [index, setIndex] = useState(0);
  const [picked, setPicked] = useState(-1);
  const [score, setScore] = useState(0);
  const [finished, setFinished] = useState(false);

  const pick = (option: number) => {
    if (picked !== -1) return;
    setPicked(option);
    if (option === questions[index].answerIndex) setScore((s) => s + 1);
  };
  const next = () => {
    if (index + 1 >= questions.length) {
      setFinished(true);
    } else {
      setIndex(index + 1);
      setPicked(-1);
    }
  };
  const retake = () => {
    setIndex(0);
    setPicked(-1);
    setScore(0);
    setFinished(false);
  };

  const label = { ...AppTypography.bodyMedium, fontWeight: 700, lineHeight: lineHeight(14), color: AppColors.petalWhite };

  if (finished) {
    const total = questions.length;
    const perfect = score === total;
    return (
      <div style={{ padding: '8px 20px 28px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ height: 12 }} />
        <div
          style={{
            width: 84,
            height: 84,
            borderRadius: '50%',
            background: withAlpha(AppColors.blushGold, 0.12),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
            boxShadow: boxShadow([{ color: withAlpha(AppColors.blushGold, 0.25), blur: 28 }]),
            boxSizing: 'border-box',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 36,
            lineHeight: 1,
          }}
        >
          🍡
        </div>
        <div style={{ height: 14 }} />
        <div
          style={{
            ...AppTypography.titleLarge,
            fontSize: 36,
            fontWeight: 700,
            letterSpacing: 0,
            lineHeight: lineHeight(36),
            color: AppColors.petalWhite,
          }}
        >
          {score} of {total}
        </div>
        <div style={{ height: 6 }} />
        <div style={{ ...AppTypography.bodyMedium, color: Derived.textMuted, lineHeight: 1.5, textAlign: 'center' }}>
          {perfect
            ? 'Perfect — Motchi is doing happy spins!'
            : score * 2 >= total
              ? 'So close — one more round?'
              : 'Good start — every try makes it stick.'}
        </div>
        <div style={{ height: 20 }} />
        <BigButton onPressed={retake}>
          <span style={label}>Try again 🔁</span>
        </BigButton>
        <div style={{ height: 10 }} />
        <button
          type="button"
          className="bare-button"
          onClick={onClose}
          style={{
            height: 40,
            padding: '0 12px',
            borderRadius: 20,
            ...AppTypography.bodyMedium,
            fontWeight: 600,
            color: Derived.textMuted,
          }}
        >
          Back to chat
        </button>
      </div>
    );
  }

  const q = questions[index];
  const stateFor = (i: number): OptionState =>
    picked === -1 ? 'idle' : i === q.answerIndex ? 'correct' : i === picked ? 'wrong' : 'dimmed';
  return (
    <div style={{ padding: '8px 20px 24px' }}>
      <LinearProgress
        value={questions.length === 0 ? 0 : (index + 1) / questions.length}
        height={6}
        color={AppColors.blushGold}
        background={withAlpha(AppColors.moonlight, 0.12)}
        radius={AppRadius.full}
      />
      <div style={{ height: 14 }} />
      <div
        style={{
          ...AppTypography.bodySmall,
          fontWeight: 700,
          lineHeight: lineHeight(12.5),
          color: AppColors.blushGold,
          ...letterSpacing(0.4),
        }}
      >
        Question {index + 1} of {questions.length}
      </div>
      <div style={{ height: 8 }} />
      <div style={{ ...AppTypography.titleMedium, fontSize: 17, lineHeight: 1.45, color: Derived.textHigh }}>{q.question}</div>
      <div style={{ height: 16 }} />
      {q.options.map((text, i) => (
        <OptionButton
          key={`q${index}-opt${i}`}
          letter={String.fromCharCode(65 + i)}
          text={text}
          state={stateFor(i)}
          onTap={() => pick(i)}
        />
      ))}
      {picked !== -1 && (
        <>
          <div style={{ height: 4 }} />
          <FeedbackCard correct={picked === q.answerIndex} explanation={q.explanation} />
          <div style={{ height: 14 }} />
          <BigButton onPressed={next}>
            <span style={label}>{index + 1 >= questions.length ? 'See my score 💕' : 'Next →'}</span>
          </BigButton>
        </>
      )}
    </div>
  );
}

function OptionButton({ letter, text, state, onTap }: { letter: string; text: string; state: OptionState; onTap: () => void }) {
  let border = Derived.border;
  let fill = Derived.surfaceGlass;
  let letterBg = withAlpha(AppColors.moonlight, 0.12);
  if (state === 'correct') {
    border = withAlpha(AppColors.success, 0.7);
    fill = withAlpha(AppColors.success, 0.14);
    letterBg = AppColors.success;
  } else if (state === 'wrong') {
    border = withAlpha(AppColors.error, 0.7);
    fill = withAlpha(AppColors.error, 0.12);
    letterBg = AppColors.error;
  }
  const locked = state !== 'idle';
  return (
    <div style={{ paddingBottom: 10 }}>
      <button
        type="button"
        className="bare-button"
        onClick={locked ? undefined : onTap}
        style={{
          width: '100%',
          padding: 12,
          borderRadius: AppRadius.xl,
          background: fill,
          border: `1.2px solid ${border}`,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'flex-start',
          textAlign: 'left',
          cursor: locked ? 'default' : 'pointer',
        }}
      >
        <div
          style={{
            width: 32,
            height: 32,
            flexShrink: 0,
            borderRadius: '50%',
            background: letterBg,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {state === 'correct' ? (
            <Icon name="check" size={18} color={AppColors.inkDeep} />
          ) : state === 'wrong' ? (
            <Icon name="close" size={18} color={AppColors.petalWhite} />
          ) : (
            <span style={{ ...AppTypography.bodyMedium, fontWeight: 700, lineHeight: lineHeight(14), color: Derived.textMuted }}>
              {letter}
            </span>
          )}
        </div>
        <div style={{ width: 12, flexShrink: 0 }} />
        <div
          style={{
            flex: 1,
            minWidth: 0,
            paddingTop: 5,
            ...AppTypography.bodyMedium,
            fontSize: 14.5,
            lineHeight: 1.5,
            color: state === 'dimmed' ? Derived.textMuted : Derived.textHigh,
          }}
        >
          {text}
        </div>
      </button>
    </div>
  );
}

function FeedbackCard({ correct, explanation }: { correct: boolean; explanation: string }) {
  const accent = correct ? AppColors.success : AppColors.blushGold;
  return (
    <div
      style={{
        padding: '12px 14px',
        borderRadius: AppRadius.md,
        background: linear([withAlpha(AppColors.auroraLilac, 0.16), withAlpha(AppColors.deepRose, 0.12)], diag),
        border: `1px solid ${withAlpha(accent, 0.35)}`,
      }}
    >
      <div style={{ ...AppTypography.bodyMedium, fontWeight: 700, lineHeight: lineHeight(14), color: Derived.textHigh }}>
        {correct ? 'Correct! Motchi is proud 🍡' : "Not quite — here's the gentle fix 💡"}
      </div>
      {explanation ? (
        <>
          <div style={{ height: 6 }} />
          <div style={{ ...AppTypography.bodyMedium, lineHeight: 1.55, color: Derived.textMedium }}>{explanation}</div>
        </>
      ) : null}
    </div>
  );
}

export function FlashcardsPlayView({ cards }: { cards: Flashcard[] }) {
  const [order, setOrder] = useState(cards);
  const [index, setIndex] = useState(0);
  const shuffle = () => {
    const next = [...order];
    for (let i = next.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [next[i], next[j]] = [next[j], next[i]];
    }
    setOrder(next);
    setIndex(0);
  };
  const go = (delta: number) => setIndex((i) => Math.min(order.length - 1, Math.max(0, i + delta)));
  const card = order[index];
  return (
    <div style={{ padding: '8px 20px 24px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ alignSelf: 'stretch', display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            ...AppTypography.bodySmall,
            fontWeight: 700,
            lineHeight: lineHeight(12.5),
            color: AppColors.blushGold,
            ...letterSpacing(0.4),
          }}
        >
          Card {index + 1} of {order.length}
        </span>
        <div style={{ flex: 1 }} />
        <button
          type="button"
          className="bare-button"
          onClick={shuffle}
          style={{
            height: 40,
            padding: '0 8px',
            borderRadius: 20,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            ...AppTypography.labelLarge,
            lineHeight: lineHeight(14),
            color: Derived.textMuted,
          }}
        >
          <Icon name="shuffle" size={16} color={Derived.textMuted} />
          Shuffle
        </button>
      </div>
      <div style={{ height: 8 }} />
      <FlipCard key={`card-${index}-${card.front}`} front={card.front} back={card.back} />
      <div style={{ height: 8 }} />
      <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: Derived.textDisabled }}>
        Tap the card to flip it
      </div>
      <div style={{ height: 16 }} />
      <div style={{ alignSelf: 'stretch', display: 'flex', gap: 12 }}>
        <div style={{ flex: 1 }}>
          <BigButton filled={false} onPressed={index > 0 ? () => go(-1) : undefined}>
            ← Back
          </BigButton>
        </div>
        <div style={{ flex: 1 }}>
          <BigButton onPressed={index + 1 < order.length ? () => go(1) : undefined}>
            {index + 1 < order.length ? 'Next →' : 'Done 💕'}
          </BigButton>
        </div>
      </div>
      <div style={{ height: 8 }} />
    </div>
  );
}

function FlipCard({ front, back }: { front: string; back: string }) {
  const [showingBack, setShowingBack] = useState(false);
  const [t, setT] = useState(0);
  const anim = useRef({ frame: 0, from: 0 });
  const tRef = useRef(0);
  tRef.current = t;
  useEffect(() => () => cancelAnimationFrame(anim.current.frame), []);
  const flip = () => {
    const target = showingBack ? 0 : 1;
    setShowingBack(!showingBack);
    cancelAnimationFrame(anim.current.frame);
    const from = tRef.current;
    const duration = 380 * Math.abs(target - from);
    const start = performance.now();
    const step = (now: number) => {
      const p = duration === 0 ? 1 : Math.min(1, (now - start) / duration);
      setT(from + (target - from) * p);
      if (p < 1) anim.current.frame = requestAnimationFrame(step);
    };
    anim.current.frame = requestAnimationFrame(step);
  };
  const angle = t * 180;
  const showBack = angle > 90;
  return (
    <div
      role="button"
      tabIndex={0}
      aria-label={showingBack ? 'Flashcard answer. Tap to see question.' : 'Flashcard question. Tap to see answer.'}
      onClick={flip}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          flip();
        }
      }}
      style={{ alignSelf: 'stretch', cursor: 'pointer', transform: `perspective(833px) rotateY(${angle}deg)` }}
    >
      <div style={{ transform: showBack ? 'rotateY(180deg)' : undefined }}>
        {showBack ? (
          <CardFace
            text={back}
            hint="ANSWER"
            fill={linear([AppColors.plum, AppColors.velvet], diag)}
            border={AppColors.auroraLilac}
          />
        ) : (
          <CardFace
            text={front}
            hint="QUESTION"
            fill={linear([withAlpha(AppColors.moonlight, 0.14), withAlpha(AppColors.moonlight, 0.06)], diag)}
            border={AppColors.blushGold}
          />
        )}
      </div>
    </div>
  );
}

function CardFace({ text, hint, fill, border }: { text: string; hint: string; fill: string; border: string }) {
  return (
    <div
      style={{
        minHeight: 260,
        padding: 22,
        boxSizing: 'border-box',
        background: fill,
        borderRadius: AppRadius.x2,
        border: `1px solid ${withAlpha(border, 0.35)}`,
        boxShadow: boxShadow([{ color: withAlpha(border, 0.18), blur: 24, offset: [0, 8] }]),
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div style={{ ...AppTypography.labelSmall, lineHeight: lineHeight(11), color: AppColors.blushGold, ...letterSpacing(1.2) }}>
        {hint}
      </div>
      <div style={{ height: 12 }} />
      <div style={{ ...AppTypography.titleMedium, fontSize: 17, lineHeight: 1.55, color: Derived.textHigh, textAlign: 'center' }}>
        {text}
      </div>
    </div>
  );
}
