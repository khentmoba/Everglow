// Port of lib/features/ai/presentation/screens/study_screen.dart,
// study_screen_builders.dart and study_screen_bubbles.dart.
import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { Align, boxShadow, letterSpacing, linear, lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowAssistantBubble, EverglowUserBubble, GlassBox } from '../../shared/widgets/EverglowChatBubble';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowMarkdown } from '../../shared/widgets/EverglowMarkdown';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { canPop } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { aiChat, useAIChat } from './aiChat';
import {
  artifactsEmpty,
  motchiWantsArtifact,
  parseStudyArtifacts,
  stripArtifactBlocks,
  stripStreamingArtifacts,
  userAskedForVisibleQuiz,
} from './studyArtifact';
import { StudyArtifactEntry } from './StudyArtifactSheet';
import {
  buildSourcesBlock,
  kMaxStudyDocs,
  pickAndExtractPdf,
  StudyDocException,
  studyHistory,
  StudyPrompts,
  type StudyDoc,
  type StudySession,
  type StudyTurn,
} from './studyDocs';
import { StudyHistoryPanel } from './StudyHistoryPanel';

export function StudyPage() {
  const navigate = useNavigate();
  const auth = useAuth();
  const ai = useAIChat();
  const { width } = useViewport();
  const isDesktop = width >= 1024;
  const draftResponse = useValue(ai.draftRevision);
  void draftResponse;

  const [inputText, setInputText] = useState('');
  const [sources, setSources] = useState<StudyDoc[]>([]);
  const [turns, setTurns] = useState<StudyTurn[]>([]);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyRefreshKey, setHistoryRefreshKey] = useState(0);
  const [restoring, setRestoring] = useState(false);
  const [sending, setSending] = useState(false);
  const [picking, setPicking] = useState(false);
  const [canvasEnabled, setCanvasEnabled] = useState(false);
  const [showJumpButton, setShowJumpButton] = useState(false);

  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const userScrolledUpRef = useRef(false);

  const scrollToBottom = useCallback((animated = true) => {
    requestAnimationFrame(() => {
      const el = scrollRef.current;
      if (!el) return;
      el.scrollTo({ top: el.scrollHeight, behavior: animated ? 'smooth' : 'auto' });
    });
  }, []);

  useEffect(() => {
    if (sending && !userScrolledUpRef.current) scrollToBottom(false);
  }, [ai.draftResponse, sending, scrollToBottom]);

  useEffect(() => {
    const el = inputRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 144)}px`;
  }, [inputText]);

  const snack = (message: string, isError = false) => {
    showSnackBar(message, {
      background: isError ? withAlpha(AppColors.deepRose, 0.9) : AppColors.velvet,
    });
  };

  const persistSession = async (nextSources: StudyDoc[], nextTurns: StudyTurn[], currentSessionId: string | null) => {
    if (nextSources.length === 0 && nextTurns.length === 0) return;
    try {
      const id = await studyHistory.saveSession(currentSessionId, nextSources, nextTurns);
      if (id && !currentSessionId) setSessionId(id);
      setHistoryRefreshKey((k) => k + 1);
    } catch {
      // History must never break the chat.
    }
  };

  const addSource = async () => {
    if (picking || sources.length >= kMaxStudyDocs) return;
    setPicking(true);
    try {
      const doc = await pickAndExtractPdf();
      if (!doc) return;
      const nextSources = [...sources, doc];
      setSources(nextSources);
      void persistSession(nextSources, turns, sessionId);
      inputRef.current?.focus();
    } catch (e) {
      if (e instanceof StudyDocException) snack(e.message, true);
    } finally {
      setPicking(false);
    }
  };

  const removeSource = (index: number) => {
    const nextSources = sources.filter((_, i) => i !== index);
    setSources(nextSources);
    void persistSession(nextSources, turns, sessionId);
  };

  const newStudy = () => {
    if (sources.length === 0 && turns.length === 0) {
      setHistoryOpen(false);
      return;
    }
    setSessionId(null);
    setSources([]);
    setTurns([]);
    setHistoryOpen(false);
    snack('Fresh page — shelf cleared. History kept on the left.');
    inputRef.current?.focus();
  };

  const restoreSession = async (session: StudySession) => {
    if (restoring) return;
    setRestoring(true);
    setHistoryOpen(false);
    try {
      const full = (await studyHistory.loadSession(session.id)) ?? session;
      setSessionId(full.id);
      setSources(full.sources);
      setTurns(full.turns);
      scrollToBottom(false);
    } finally {
      setRestoring(false);
    }
  };

  const ask = async (prompt: string) => {
    const question = prompt.trim();
    if (!question || sources.length === 0 || sending) return;
    const prior = turns.map((t) => ({ role: t.fromUser ? 'user' : 'assistant', content: t.text }));
    const block = buildSourcesBlock(sources);
    const nextTurnsWithUser: StudyTurn[] = [...turns, { fromUser: true, text: question }];
    const useCanvas = canvasEnabled || motchiWantsArtifact(question);
    setTurns(nextTurnsWithUser);
    setSending(true);
    if (!canvasEnabled && motchiWantsArtifact(question)) setCanvasEnabled(true);
    setInputText('');
    scrollToBottom(true);

    try {
      const reply = await aiChat.streamStudyReply({
        history: prior,
        sourcesBlock: block,
        question,
        callerName: auth.currentUser,
        canvasEnabled: useCanvas,
      });
      if (!reply.trim()) {
        snack('Motchi came back empty-handed — try asking another way.');
        return;
      }
      const finalTurns: StudyTurn[] = [...nextTurnsWithUser, { fromUser: false, text: reply.trim() }];
      setTurns(finalTurns);
      scrollToBottom(true);
      void persistSession(sources, finalTurns, sessionId);
    } catch {
      snack('Motchi had trouble — check connection and retry.', true);
    } finally {
      setSending(false);
    }
  };

  const handleScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    const distance = el.scrollHeight - el.clientHeight - el.scrollTop;
    userScrolledUpRef.current = distance > 120;
    setShowJumpButton(distance > 320);
  };

  const canSend = inputText.trim().length > 0 && sources.length > 0 && !sending;

  const mainColumn = (
    <div style={{ flex: 1, minWidth: 0, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <EverglowFeatureHeader
        title="Study"
        subtitle="your PDFs, Motchi on top"
        icon="school"
        hue={AppColors.softLavender}
        onBack={() => (canPop() ? navigate(-1) : navigate('/motchi'))}
        actions={[
          <HeaderIconButton key="history" icon="history" tooltip="Study history" onTap={() => setHistoryOpen((v) => !v)} />,
          <HeaderIconButton key="new" icon="add" tooltip="New study" onTap={newStudy} />,
        ]}
      />
      {restoring && <LinearProgress height={2} color={AppColors.blushGold} />}

      {/* Horizontal sources shelf */}
      <div
        className="no-scrollbar"
        style={{
          height: 118,
          flexShrink: 0,
          display: 'flex',
          alignItems: 'stretch',
          gap: 10,
          padding: '10px 16px 12px',
          overflowX: 'auto',
          boxSizing: 'border-box',
        }}
      >
        {sources.map((doc, i) => (
          <SourceCard key={`${doc.fileName}_${i}`} doc={doc} onRemove={() => removeSource(i)} />
        ))}
        <AddCard full={sources.length >= kMaxStudyDocs} picking={picking} onTap={() => void addSource()} />
      </div>

      <div style={{ height: 1, background: withAlpha(AppColors.blushGold, 0.06), flexShrink: 0 }} />

      {/* Chat area */}
      <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
        {turns.length === 0 && !sending ? (
          <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
            <div
              style={{
                margin: 'auto',
                padding: 32,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
              }}
            >
              <GlassBox
                radius={24}
                shadows={[
                  { color: withAlpha(AppColors.softLavender, 0.25), blur: 28, spread: 2 },
                  { color: withAlpha(AppColors.blushGold, 0.12), blur: 36, spread: 4 },
                ]}
                style={{ width: 76, height: 76 }}
              >
                <div
                  style={{
                    position: 'relative',
                    width: 76,
                    height: 76,
                    borderRadius: 24,
                    border: `1.5px solid ${withAlpha(AppColors.softLavender, 0.45)}`,
                    overflow: 'hidden',
                    boxSizing: 'border-box',
                  }}
                >
                  <img
                    src="/images/motchi_avatar.webp"
                    alt=""
                    style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', borderRadius: 22 }}
                  />
                </div>
              </GlassBox>
              <div style={{ height: 14 }} />
              <div
                style={{
                  padding: '5px 12px',
                  background: withAlpha(AppColors.softLavender, 0.12),
                  borderRadius: AppRadius.full,
                  border: `0.8px solid ${withAlpha(AppColors.softLavender, 0.28)}`,
                  ...AppTypography.labelSmall,
                  fontSize: 11,
                  fontWeight: 700,
                  lineHeight: mixedLineHeight(11),
                  color: AppColors.softLavender,
                }}
              >
                {sources.length === 0 ? '📚 Shelf is empty' : '✨ Sources ready'}
              </div>
              <div style={{ height: 14 }} />
              <div
                style={{
                  ...AppTypography.titleLarge,
                  fontSize: 20,
                  fontWeight: 700,
                  lineHeight: lineHeight(20),
                  ...letterSpacing(-0.3),
                  textAlign: 'center',
                }}
              >
                {sources.length === 0 ? 'Add a class PDF above' : 'Sources ready — ask away'}
              </div>
              <div style={{ height: 6 }} />
              <div
                style={{
                  ...AppTypography.bodyMedium,
                  color: Derived.textMuted,
                  lineHeight: lineHeight(14, 1.5),
                  textAlign: 'center',
                  whiteSpace: 'pre-line',
                }}
              >
                {sources.length === 0
                  ? 'Motchi will read it with you, then answer\nonly from your pages.'
                  : 'Ask anything, or tap Summarize, Quiz,\nFlashcards below to start.'}
              </div>
            </div>
          </div>
        ) : (
          <div
            ref={scrollRef}
            onScroll={handleScroll}
            className="no-scrollbar"
            style={{ height: '100%', overflowY: 'auto', padding: '12px 16px 16px', boxSizing: 'border-box' }}
          >
            <div style={{ maxWidth: 700, margin: '0 auto' }}>
              {turns.map((turn, i) => {
                if (turn.fromUser) {
                  return (
                    <div key={i} style={{ paddingLeft: 56, paddingBottom: 12 }}>
                      <EverglowUserBubble text={turn.text} />
                    </div>
                  );
                }
                let keepFull = false;
                for (let k = i - 1; k >= 0; k--) {
                  if (turns[k].fromUser) {
                    keepFull = userAskedForVisibleQuiz(turns[k].text);
                    break;
                  }
                }
                const artifacts = parseStudyArtifacts(turn.text);
                const displayText = artifactsEmpty(artifacts) ? turn.text : stripArtifactBlocks(turn.text, !keepFull);
                return (
                  <div key={i} style={{ paddingRight: 8, paddingBottom: 12 }}>
                    <EverglowAssistantBubble
                      text={displayText}
                      title="Motchi"
                      subtitle="from your PDFs"
                      timeLabel="Motchi • grounded only on your pages"
                      leadingReasoning={artifactsEmpty(artifacts) ? undefined : <StudyArtifactEntry artifacts={artifacts} />}
                    />
                  </div>
                );
              })}
              {sending && <StreamingStudyBubble draft={ai.draftResponse} />}
            </div>
          </div>
        )}

        {showJumpButton && (
          <div style={{ position: 'absolute', bottom: 12, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
            <button
              type="button"
              className="bare-button"
              aria-label="Scroll to bottom"
              onClick={() => scrollToBottom(true)}
              style={{
                padding: '8px 14px',
                borderRadius: AppRadius.full,
                background: Derived.panelGlass,
                border: `1px solid ${Derived.border}`,
                boxShadow: '0 4px 12px rgba(0,0,0,0.25)',
                display: 'flex',
              }}
            >
              <Icon name="keyboard_arrow_down" size={20} color={Derived.textMuted} />
            </button>
          </div>
        )}
      </div>

      {/* Study prompt chips */}
      {sources.length > 0 && !sending && (
        <div
          className="no-scrollbar"
          style={{
            width: '100%',
            maxWidth: 700,
            margin: '0 auto',
            padding: '6px 12px',
            boxSizing: 'border-box',
            display: 'flex',
            gap: 8,
            overflowX: 'auto',
          }}
        >
          {StudyPrompts.chipsFor(canvasEnabled).map(([label, prompt]) => (
            <button
              key={label}
              type="button"
              className="bare-button"
              onClick={() => void ask(prompt)}
              style={{
                flexShrink: 0,
                padding: '8px 13px',
                borderRadius: 20,
                background: linear([withAlpha(AppColors.inkDeep, 0.88), withAlpha(AppColors.velvet, 0.68)], {
                  begin: Align.topLeft,
                  end: Align.bottomRight,
                }),
                border: `0.9px solid ${withAlpha(AppColors.softLavender, 0.26)}`,
                ...AppTypography.bodySmall,
                fontSize: 12.5,
                fontWeight: 600,
                color: Derived.textMedium,
                lineHeight: 1.3,
              }}
            >
              {label}
            </button>
          ))}
        </div>
      )}

      {/* Composer */}
      <div
        style={{
          padding: `${10}px ${AppSpacing.lg}px 14px`,
          borderTop: `1px solid ${withAlpha(AppColors.blushGold, 0.06)}`,
          flexShrink: 0,
        }}
      >
        <div
          style={{
            maxWidth: 700,
            margin: '0 auto',
            borderRadius: 22,
            background: linear([withAlpha(AppColors.inkDeep, 0.92), withAlpha(AppColors.velvet, 0.78)], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            border: `1.1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
            boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.35)', blur: 20, offset: [0, 8] }]),
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <div style={{ paddingLeft: 6 }}>
            <Tooltip message={canvasEnabled ? 'Canvas: on — quizzes open as interactive cards' : 'Canvas: off — plain text only'}>
              <button
                type="button"
                className="bare-button"
                onClick={() => setCanvasEnabled((v) => !v)}
                style={{
                  padding: '7px 8px',
                  borderRadius: 12,
                  background: canvasEnabled ? withAlpha(AppColors.blushGold, 0.18) : 'transparent',
                  border: `0.8px solid ${canvasEnabled ? withAlpha(AppColors.blushGold, 0.4) : 'transparent'}`,
                  transition: `all ${orZero(200)}ms ease`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 4,
                }}
              >
                <Icon
                  name={canvasEnabled ? 'dashboard_customize' : 'dashboard_customize_outlined'}
                  size={20}
                  color={canvasEnabled ? AppColors.blushGold : Derived.textMuted}
                />
                {canvasEnabled && (
                  <span style={{ ...AppTypography.labelSmall, fontSize: 10.5, fontWeight: 700, color: AppColors.blushGold }}>
                    Canvas
                  </span>
                )}
              </button>
            </Tooltip>
          </div>
          <textarea
            ref={inputRef}
            value={inputText}
            disabled={sending}
            rows={1}
            placeholder={sources.length === 0 ? 'Add a PDF first…' : 'Ask about your sources…'}
            className="money-input"
            onChange={(e) => setInputText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                e.preventDefault();
                void ask(inputText);
              }
            }}
            style={{
              flex: 1,
              minWidth: 0,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              resize: 'none',
              padding: '14px 16px',
              ...AppTypography.bodyMedium,
              fontSize: 14.5,
              letterSpacing: 0.25,
              ['--hint-color' as string]: Derived.textMuted,
              ['--hint-size' as string]: '14px',
              fontWeight: 500,
              lineHeight: 1.5,
              color: Derived.textHigh,
              maxHeight: 144,
            }}
          />
          <div style={{ padding: '0 8px 4px 0' }}>
            <button
              type="button"
              className="bare-button"
              aria-label="Send"
              disabled={!canSend}
              onClick={() => void ask(inputText)}
              style={{
                width: 40,
                height: 40,
                borderRadius: 14,
                background: canSend
                  ? linear([AppColors.deepRose, AppColors.auroraRose], {
                      begin: Align.topLeft,
                      end: Align.bottomRight,
                    })
                  : withAlpha(AppColors.velvet, 0.55),
                border: canSend ? `1px solid ${withAlpha(AppColors.petalWhite, 0.22)}` : undefined,
                boxShadow: canSend
                  ? boxShadow([{ color: withAlpha(AppColors.deepRose, 0.45), blur: 14, offset: [0, 4] }])
                  : undefined,
                transition: `all ${orZero(220)}ms ease`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: canSend ? 'pointer' : 'default',
              }}
            >
              {sending ? (
                <CircularProgress size={18} strokeWidth={2} color={AppColors.blushGold} />
              ) : (
                <Icon name="arrow_upward" size={20} color={canSend ? AppColors.petalWhite : Derived.textDisabled} />
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }}>
      <EverglowBackground baseColor={AppColors.inkDeep} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          paddingTop: 'env(safe-area-inset-top)',
          paddingBottom: 'env(safe-area-inset-bottom)',
          display: 'flex',
        }}
      >
        {isDesktop ? (
          <>
            <div
              style={{
                width: historyOpen ? 320 : 0,
                overflow: 'hidden',
                flexShrink: 0,
                transition: `width ${orZero(250)}ms cubic-bezier(0.215, 0.61, 0.355, 1)`,
              }}
            >
              <div style={{ width: 320, height: '100%' }}>
                <StudyHistoryPanel
                  isOpen
                  activeSessionId={sessionId}
                  refreshKey={historyRefreshKey}
                  onClose={() => setHistoryOpen(false)}
                  onNewStudy={newStudy}
                  onSelect={(s) => void restoreSession(s)}
                />
              </div>
            </div>
            {mainColumn}
          </>
        ) : (
          <div style={{ flex: 1, minWidth: 0, position: 'relative', display: 'flex' }}>
            {mainColumn}
            <StudyHistoryPanel
              isOpen={historyOpen}
              activeSessionId={sessionId}
              refreshKey={historyRefreshKey}
              onClose={() => setHistoryOpen(false)}
              onNewStudy={newStudy}
              onSelect={(s) => void restoreSession(s)}
            />
          </div>
        )}
      </div>
    </div>
  );
}

function HeaderIconButton({ icon, tooltip, onTap }: { icon: string; tooltip: string; onTap: () => void }) {
  return (
    <Tooltip message={tooltip}>
      <button
        type="button"
        className="bare-button"
        aria-label={tooltip}
        onClick={onTap}
        style={{
          width: 36,
          height: 36,
          borderRadius: AppRadius.full,
          background: Derived.surfaceGlass,
          border: `0.5px solid ${Derived.border}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={icon} size={18} color={Derived.textMuted} />
      </button>
    </Tooltip>
  );
}

function AddCard({ full, picking, onTap }: { full: boolean; picking: boolean; onTap: () => void }) {
  const enabled = !full && !picking;
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!enabled}
      onClick={enabled ? onTap : undefined}
      style={{
        width: 132,
        padding: 12,
        borderRadius: 18,
        background: linear(
          [withAlpha(AppColors.inkDeep, enabled ? 0.92 : 0.7), withAlpha(AppColors.velvet, enabled ? 0.75 : 0.55)],
          { begin: Align.topLeft, end: Align.bottomRight, size: [132, 96] },
        ),
        border: `1.1px solid ${withAlpha(AppColors.softLavender, enabled ? 0.38 : 0.15)}`,
        boxShadow: enabled
          ? boxShadow([{ color: withAlpha(AppColors.softLavender, 0.12), blur: 16, offset: [0, 4] }])
          : undefined,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        cursor: enabled ? 'pointer' : 'default',
      }}
    >
      {picking ? (
        <CircularProgress size={22} strokeWidth={2} color={AppColors.softLavender} />
      ) : (
        <div
          style={{
            width: 36,
            height: 36,
            flexShrink: 0,
            borderRadius: 12,
            background: withAlpha(AppColors.softLavender, 0.14),
            border: `0.8px solid ${withAlpha(AppColors.softLavender, 0.3)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="add" size={20} color={enabled ? AppColors.softLavender : Derived.textDisabled} />
        </div>
      )}
      <div style={{ height: 6 }} />
      <div
        style={{
          ...AppTypography.bodySmall,
          fontSize: 13,
          fontWeight: 600,
          lineHeight: lineHeight(13),
          color: enabled ? AppColors.petalWhite : Derived.textMuted,
        }}
      >
        {full ? 'Shelf full (3)' : 'Add PDF'}
      </div>
      <div
        style={{
          ...AppTypography.bodySmall,
          fontSize: 11,
          fontWeight: 500,
          lineHeight: lineHeight(11),
          color: Derived.textMuted,
        }}
      >
        Motchi reads it
      </div>
    </button>
  );
}

function SourceCard({ doc, onRemove }: { doc: StudyDoc; onRemove: () => void }) {
  return (
    <div
      style={{
        width: 200,
        padding: 12,
        borderRadius: 18,
        background: linear([withAlpha(AppColors.inkDeep, 0.92), withAlpha(AppColors.velvet, 0.72)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
          size: [200, 96],
        }),
        border: `1px solid ${withAlpha(AppColors.softLavender, 0.22)}`,
        boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.28)', blur: 14, offset: [0, 5] }]),
        display: 'flex',
        flexDirection: 'column',
        flexShrink: 0,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div
          style={{
            padding: 6,
            borderRadius: 9,
            background: linear([AppColors.blushGold, AppColors.deepRose], {
              begin: Align.topLeft,
              end: Align.bottomRight,
              size: [26, 26],
            }),
            display: 'flex',
          }}
        >
          <Icon name="picture_as_pdf" size={14} color={AppColors.petalWhite} />
        </div>
        <div style={{ width: 8 }} />
        <div
          style={{
            padding: '2.5px 7px',
            borderRadius: AppRadius.full,
            background: withAlpha(AppColors.success, 0.12),
            ...AppTypography.labelSmall,
            fontSize: 9,
            fontWeight: 700,
            color: AppColors.success,
            ...letterSpacing(0.6),
          }}
        >
          PDF
        </div>
        <div style={{ flex: 1 }} />
        <button
          type="button"
          className="bare-button"
          aria-label="Remove PDF"
          onClick={onRemove}
          style={{
            padding: 4,
            borderRadius: '50%',
            background: withAlpha(AppColors.moonlight, 0.08),
            display: 'flex',
          }}
        >
          <Icon name="close" size={14} color={Derived.textMuted} />
        </button>
      </div>
      <div style={{ height: 6 }} />
      <div
        className="clamp-2"
        style={{
          flex: 1,
          ...AppTypography.bodySmall,
          fontSize: 13,
          fontWeight: 500,
          color: AppColors.petalWhite,
          lineHeight: 1.35,
        }}
      >
        {doc.fileName}
      </div>
      <div
        style={{
          ...AppTypography.bodySmall,
          fontSize: 11,
          fontWeight: 500,
          color: Derived.textMuted,
        }}
      >
        {(doc.text.length / 1000).toFixed(1)}k chars{doc.truncated ? ' · start only' : ''}
      </div>
    </div>
  );
}

function StreamingStudyBubble({ draft }: { draft: string }) {
  const clean = stripStreamingArtifacts(draft);
  const radius = '6px 22px 22px 22px';
  return (
    <div style={{ paddingRight: 8, paddingBottom: 12, display: 'flex', alignItems: 'flex-start' }}>
      <GlassBox
        radius={12}
        shadows={[{ color: withAlpha(AppColors.blushGold, 0.25), blur: 14, spread: 1 }]}
        style={{ width: 36, height: 36, flexShrink: 0 }}
      >
        <div
          style={{
            position: 'relative',
            width: 36,
            height: 36,
            borderRadius: 12,
            border: `1.2px solid ${withAlpha(AppColors.blushGold, 0.45)}`,
            overflow: 'hidden',
            boxSizing: 'border-box',
          }}
        >
          <img
            src="/images/motchi_avatar.webp"
            alt=""
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', borderRadius: 11 }}
          />
        </div>
      </GlassBox>
      <div style={{ width: 10, flexShrink: 0 }} />
      <GlassBox
        radius={radius}
        shadows={[
          { color: 'rgba(0,0,0,0.35)', blur: 22, offset: [0, 8] },
          { color: withAlpha(AppColors.auroraLilac, 0.09), blur: 24, offset: [0, 2] },
        ]}
        style={{ flex: '0 1 auto', minWidth: 0 }}
      >
        <div
          style={{
            position: 'relative',
            padding: '13px 16px 12px',
            borderRadius: radius,
            background: linear([withAlpha(AppColors.velvet, 0.68), withAlpha(AppColors.inkDeep, 0.88)], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
          }}
        >
          {clean === '' ? (
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <span
                style={{ ...AppTypography.bodyMedium, color: Derived.textMuted, fontSize: 14, fontWeight: 500, lineHeight: 1.5 }}
              >
                Motchi is reading
              </span>
              <CircularProgress size={14} strokeWidth={2} color={AppColors.blushGold} />
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <EverglowMarkdown
                text={clean}
                baseStyle={{
                  ...AppTypography.bodyMedium,
                  color: Derived.textHigh,
                  lineHeight: 1.6,
                  fontSize: 14.5,
                  fontWeight: 500,
                }}
              />
              <LinearProgress
                height={2}
                color={AppColors.blushGold}
                background={withAlpha(AppColors.moonlight, 0.14)}
                radius={2}
              />
            </div>
          )}
        </div>
      </GlassBox>
    </div>
  );
}
