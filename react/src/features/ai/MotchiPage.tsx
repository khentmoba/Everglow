// Port of lib/features/ai/presentation/widgets/motchi_screen.dart.
import { useCallback, useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { canPop } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { aiChat, useAIChat } from './aiChat';
import { companionOperation } from './aiService';
import { detailsEmpty, detailsFromResults, shouldAutoThink, visibleText, type Json } from './motchiDomain';
import { MotchiReplyDetailsCard } from './MotchiReplyDetailsCard';
import { MotchiSidebar } from './MotchiSidebar';
import { MotchiWebBridge } from './MotchiWebBridge';
import {
  ComposerInput,
  ErrorBanner,
  GreetingEmptyState,
  LiveToolStrip,
  MessageBubble,
  MotchiHeader,
  ThinkingIndicator,
  WebSourcesCard,
  type DeepThinkMode,
} from './MotchiWidgets';
import { motchiWantsArtifact, userAskedForVisibleQuiz } from './studyArtifact';

const UNDOABLE_DELETE_TOOLS = new Set([
  'delete_memory',
  'remove_from_watchlist',
  'delete_calendar_event',
  'delete_journal_entry',
  'delete_bucket_item',
]);

function restoreMessage(last: Json): string {
  const tool = typeof last.tool === 'string' ? last.tool : '';
  if (tool === 'delete_memory') return `Please remember this again: ${last.fact ?? ''}`;
  if (tool === 'remove_from_watchlist') return `Please add "${last.title ?? ''}" back to our watchlist`;
  const deleted = last.deleted;
  const detail =
    deleted && typeof deleted === 'object' && !Array.isArray(deleted)
      ? Object.entries(deleted as Json)
          .filter(([, v]) => v != null && `${v}` !== '')
          .map(([k, v]) => `${k}: ${v}`)
          .join(', ')
      : `${last.title ?? ''}`;
  if (tool === 'delete_calendar_event') return `Please recreate this calendar event (${detail})`;
  if (tool === 'delete_journal_entry') return `Please recreate this journal entry (${detail})`;
  return `Please add this back to our bucket list (${detail})`;
}

export function MotchiPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const auth = useAuth();
  const ai = useAIChat();
  const { width } = useViewport();
  const isDesktop = width >= 1024;
  const draftRevision = useValue(ai.draftRevision);
  const toolResults = useValue(ai.toolResultsNotifier);

  const [inputText, setInputText] = useState(() => (typeof location.state === 'string' ? location.state : ''));
  const [conversationLoading, setConversationLoading] = useState(true);
  const [conversationFailed, setConversationFailed] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [savingFeedback, setSavingFeedback] = useState(false);
  const [startingChat, setStartingChat] = useState(false);
  const [deepThinkMode, setDeepThinkMode] = useState<DeepThinkMode>('auto');
  const [canvasEnabled, setCanvasEnabled] = useState(false);
  const [lastSentMessage, setLastSentMessage] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(() => window.innerWidth >= 1024);
  const [attachedImages, setAttachedImages] = useState<string[]>([]);
  const [showScrollButton, setShowScrollButton] = useState(false);

  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const userScrolledUpRef = useRef(false);
  const lastToolCountRef = useRef(0);
  const bridgeRef = useRef<MotchiWebBridge | null>(null);
  if (!bridgeRef.current) bridgeRef.current = new MotchiWebBridge();

  const scrollToBottom = useCallback((animated = true) => {
    requestAnimationFrame(() => {
      const el = scrollRef.current;
      if (!el) return;
      el.scrollTo({ top: el.scrollHeight, behavior: animated ? 'smooth' : 'auto' });
    });
  }, []);

  const loadConversation = useCallback(async () => {
    setConversationLoading(true);
    setConversationFailed(false);
    try {
      await aiChat.loadAssistantConversation();
      setConversationLoading(false);
      scrollToBottom(false);
    } catch (e) {
      Logger.e('Motchi conversation failed to load', e);
      setConversationLoading(false);
      setConversationFailed(true);
    }
  }, [scrollToBottom]);

  useEffect(() => {
    void loadConversation();
  }, [loadConversation]);

  useEffect(() => {
    const bridge = bridgeRef.current!;
    bridge.installPasteListener((uri) => setAttachedImages((prev) => [...prev, uri]));
    return () => bridge.uninstallPasteListener();
  }, []);

  useEffect(() => {
    if (ai.isLoading && !userScrolledUpRef.current) {
      scrollToBottom(false);
    }
  }, [ai.isLoading, draftRevision, scrollToBottom]);

  const sendMessage = useCallback(
    async ({
      retry = false,
      actionScopeId,
      overrideText,
    }: { retry?: boolean; actionScopeId?: string | null; overrideText?: string } = {}) => {
      if (isSending || conversationLoading || conversationFailed || startingChat || ai.isNavigating) return;
      const msgs = ai.assistantConversation?.messages ?? [];
      const lastReply = msgs.at(-1);
      const text =
        overrideText != null
          ? overrideText.trim()
          : retry && lastReply && lastReply.details.steps.length > 0
            ? `Help finish only the unfinished steps from this request: ${lastSentMessage ?? ''}. Check existing records for any unconfirmed action first; do not repeat completed saves or sends.`
            : retry
              ? (lastSentMessage ?? '').trim()
              : inputText.trim();
      const hasImages = !retry && attachedImages.length > 0;
      if (!text && !hasImages) return;

      const autoCanvas = !canvasEnabled && motchiWantsArtifact(text);
      setIsSending(true);
      setLastSentMessage(text);
      if (overrideText == null && !retry) setInputText('');
      if (autoCanvas) setCanvasEnabled(true);
      inputRef.current?.focus();
      userScrolledUpRef.current = false;
      scrollToBottom(true);

      const imagesToSend = retry ? [] : [...attachedImages];
      if (!retry) setAttachedImages([]);

      const enableThinking = deepThinkMode === 'auto' ? shouldAutoThink(text) : deepThinkMode === 'on';

      try {
        await aiChat.sendMessage({
          feature: 'assistant',
          message: text,
          callerName: auth.currentUser,
          stream: true,
          canvasEnabled: autoCanvas || canvasEnabled,
          enableThinking,
          imageUrls: imagesToSend,
          actionScopeId: actionScopeId ?? (retry ? (lastReply?.actionScopeId ?? ai.currentActionScopeId) : null),
        });
        setLastSentMessage(null);
        scrollToBottom(true);
      } catch (e) {
        Logger.d(`[Motchi] send failed: ${e}`);
      } finally {
        setIsSending(false);
      }
    },
    [
      ai.assistantConversation,
      ai.currentActionScopeId,
      ai.isNavigating,
      attachedImages,
      auth.currentUser,
      canvasEnabled,
      conversationFailed,
      conversationLoading,
      deepThinkMode,
      inputText,
      isSending,
      lastSentMessage,
      scrollToBottom,
      startingChat,
    ],
  );

  const sendQuick = useCallback(
    (text: string, actionScopeId?: string | null) => {
      if (startingChat || ai.isNavigating) return;
      void sendMessage({ overrideText: text, actionScopeId });
    },
    [ai.isNavigating, sendMessage, startingChat],
  );

  useEffect(() => {
    if (toolResults.length === 0) {
      lastToolCountRef.current = 0;
      return;
    }
    if (toolResults.length <= lastToolCountRef.current) return;
    lastToolCountRef.current = toolResults.length;
    const last = toolResults[toolResults.length - 1];
    const tool = typeof last.tool === 'string' ? last.tool : '';
    if (last.success === true && UNDOABLE_DELETE_TOOLS.has(tool)) {
      const title = `${last.fact ?? last.title ?? 'item'}`;
      const short = title.length > 30 ? `${title.slice(0, 30)}…` : title;
      showSnackBar(`Removed "${short}" — tap Undo to restore`, {
        background: AppColors.velvet,
        duration: 5000,
        action: {
          label: 'Undo',
          onPressed: () => {
            const msg = restoreMessage(last);
            if (msg) sendQuick(msg);
          },
        },
      });
    }
    if (last.needs_confirmation === true) {
      showSnackBar(typeof last.message === 'string' ? last.message : 'Motchi needs your confirmation to proceed', {
        background: Derived.panelGlass,
        duration: 6000,
      });
    }
  }, [sendQuick, toolResults]);

  const pickImages = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.multiple = true;
    input.onchange = async () => {
      const files = Array.from(input.files ?? []);
      for (const file of files) {
        try {
          const uri = await bridgeRef.current!.fileToDataUri(file);
          if (uri) setAttachedImages((prev) => [...prev, uri]);
        } catch (e) {
          showSnackBar(`Failed to attach images: ${e}`, { background: withAlpha(AppColors.deepRose, 0.9) });
        }
      }
    };
    input.click();
  };

  const newChat = async () => {
    if (ai.isLoading || ai.isNavigating || isSending || startingChat || conversationLoading) return;
    setStartingChat(true);
    setConversationFailed(false);
    setSidebarOpen(false);
    try {
      await aiChat.clearConversation('assistant', true);
      setInputText('');
      setAttachedImages([]);
      setLastSentMessage(null);
      userScrolledUpRef.current = false;
      setConversationFailed(false);
      inputRef.current?.focus();
    } catch (e) {
      showSnackBar(`Failed to start new chat: ${e}`, { background: withAlpha(AppColors.deepRose, 0.9) });
    } finally {
      setStartingChat(false);
      setSidebarOpen(false);
    }
    scrollToBottom(false);
  };

  const saveRecommendationFeedback = async (feedback: Record<string, unknown>) => {
    if (savingFeedback) return;
    setSavingFeedback(true);
    try {
      await companionOperation('feedback', feedback);
      showSnackBar(`Motchi saved your feedback for ${feedback.title}.`);
    } catch (e) {
      Logger.e('Motchi recommendation feedback failed', e);
      showSnackBar('Could not save your feedback. Try again.');
    } finally {
      setSavingFeedback(false);
    }
  };

  const handleScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    const dist = el.scrollHeight - el.clientHeight - el.scrollTop;
    if (dist <= 16) userScrolledUpRef.current = false;
    else if (dist > 32) userScrolledUpRef.current = true;
    setShowScrollButton(dist > 300);
  };

  const allMsgs = ai.assistantConversation?.messages ?? [];
  const loading = ai.isLoading;
  const busy = loading || ai.isNavigating || startingChat;
  const prevUserText = (beforeIndex: number) => {
    for (let k = beforeIndex - 1; k >= 0; k--) {
      if (allMsgs[k].role === 'user') return allMsgs[k].content;
    }
    return '';
  };

  const hasStream = ai.draftResponse !== '' || ai.draftReasoning !== '' || ai.activeTools.length > 0 || toolResults.length > 0;
  const draftDetails = detailsFromResults(toolResults);

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: AppColors.inkDeep,
        paddingTop: 'env(safe-area-inset-top)',
        paddingBottom: 'env(safe-area-inset-bottom)',
        display: 'flex',
      }}
    >
      {isDesktop && (
        <div
          style={{
            width: sidebarOpen ? 320 : 0,
            overflow: 'hidden',
            flexShrink: 0,
            transition: `width ${orZero(220)}ms cubic-bezier(0.32, 0.72, 0, 1)`,
          }}
        >
          <div style={{ width: 320, height: '100%' }}>
            <MotchiSidebar
              isOpen={sidebarOpen}
              onClose={() => setSidebarOpen(false)}
              onNewChat={() => void newChat()}
              navigationBusy={conversationLoading || startingChat || ai.isNavigating}
              onSessionOpened={() => {
                setConversationFailed(false);
                userScrolledUpRef.current = false;
                scrollToBottom(false);
              }}
            />
          </div>
        </div>
      )}

      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', position: 'relative' }}>
        <MotchiHeader
          onBack={() => (canPop() ? navigate(-1) : navigate('/dashboard'))}
          onSidebarToggle={() => setSidebarOpen((v) => !v)}
          onNewChat={loading || ai.isNavigating || startingChat || conversationLoading ? undefined : () => void newChat()}
          sidebarOpen={sidebarOpen}
        />

        <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
          {conversationLoading ? (
            <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <CircularProgress size={32} strokeWidth={2} color={AppColors.roseQuartz} />
            </div>
          ) : conversationFailed ? (
            <div
              style={{
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                padding: 24,
                textAlign: 'center',
              }}
            >
              <div style={{ ...AppTypography.titleMedium }}>Your conversation couldn’t load.</div>
              <div style={{ height: 8 }} />
              <div style={{ ...AppTypography.bodyMedium }}>Try again to pick up where you left off.</div>
              <div style={{ height: 16 }} />
              <TextButton
                onPressed={() => void loadConversation()}
                icon={<Icon name="refresh" size={18} color={AppColors.deepRose} />}
              >
                Try again
              </TextButton>
            </div>
          ) : allMsgs.length === 0 && !loading ? (
            <GreetingEmptyState
              onTap={(prompt) => {
                setInputText(prompt);
                inputRef.current?.focus();
              }}
              centered={isDesktop}
              callerName={auth.currentUser}
            />
          ) : (
            <div
              ref={scrollRef}
              onScroll={handleScroll}
              className={isDesktop ? undefined : 'no-scrollbar'}
              style={{
                height: '100%',
                overflowY: 'auto',
                padding: `20px ${isDesktop ? 24 : 16}px 32px`,
                boxSizing: 'border-box',
              }}
            >
              <div style={{ maxWidth: 720, margin: '0 auto' }}>
                {allMsgs.map((msg, i) => {
                  const isUserMsg = msg.role === 'user';
                  return (
                    <div key={`msg_${msg.timestamp.getTime()}_${i}`}>
                      <MessageBubble
                        text={msg.content}
                        isUser={isUserMsg}
                        showArtifacts
                        keepFullText={!isUserMsg && userAskedForVisibleQuiz(prevUserText(allMsgs.length === 0 ? 0 : i))}
                        timestamp={msg.timestamp}
                        imageUrls={msg.imageUrls}
                        onUseAsDraft={isUserMsg && !busy && msg.content ? () => setInputText(msg.content) : undefined}
                      />
                      {!isUserMsg && msg.sources.length > 0 && (
                        <div style={{ paddingTop: 10 }}>
                          <WebSourcesCard sources={msg.sources} />
                        </div>
                      )}
                      {!isUserMsg && !detailsEmpty(msg.details) && (
                        <div style={{ paddingTop: 6 }}>
                          <MotchiReplyDetailsCard
                            details={msg.details}
                            onRecommendationFeedback={
                              busy || savingFeedback ? undefined : (f) => void saveRecommendationFeedback(f)
                            }
                            onOpenMemoryBook={() => navigate('/motchi-memory')}
                            onCorrectMemory={busy ? undefined : (p) => sendQuick(p)}
                            onContinue={
                              busy
                                ? undefined
                                : () =>
                                    sendQuick(
                                      `Help finish only the unfinished steps from this request: ${prevUserText(i)}. Check existing records for any unconfirmed action first; do not repeat completed saves or sends.`,
                                      msg.actionScopeId,
                                    )
                            }
                          />
                        </div>
                      )}
                    </div>
                  );
                })}

                {loading && (
                  <div>
                    {hasStream ? (
                      <>
                        <MessageBubble
                          text={visibleText(ai.draftResponse)}
                          isUser={false}
                          isStreaming
                          showArtifacts
                          keepFullText={userAskedForVisibleQuiz(prevUserText(allMsgs.length))}
                          reasoning={ai.draftReasoning || null}
                        />
                        <LiveToolStrip tools={ai.activeTools} />
                        {toolResults.length > 0 && (
                          <div style={{ paddingTop: 6 }}>
                            <MotchiReplyDetailsCard details={draftDetails} />
                          </div>
                        )}
                      </>
                    ) : (
                      <>
                        <ThinkingIndicator />
                        <LiveToolStrip tools={ai.activeTools} />
                      </>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}

          {showScrollButton && (
            <div
              style={{
                position: 'absolute',
                bottom: 16,
                left: 0,
                right: 0,
                display: 'flex',
                justifyContent: 'center',
                pointerEvents: 'none',
              }}
            >
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  userScrolledUpRef.current = false;
                  scrollToBottom(true);
                }}
                style={{
                  pointerEvents: 'auto',
                  minHeight: 48,
                  padding: '0 20px',
                  borderRadius: AppRadius.full,
                  background: AppColors.silk,
                  border: `1px solid ${Derived.border}`,
                  color: Derived.textHigh,
                  ...AppTypography.labelLarge,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 8,
                }}
              >
                <Icon name="arrow_downward" size={18} color={Derived.textHigh} />
                <span>Latest message</span>
              </button>
            </div>
          )}
        </div>

        <ErrorBanner lastSentMessage={lastSentMessage} onRetry={() => void sendMessage({ retry: true })} />

        <ComposerInput
          enabled={!conversationLoading && !conversationFailed && !startingChat && !ai.isNavigating}
          text={inputText}
          onTextChange={setInputText}
          inputRef={inputRef}
          onSend={() => void sendMessage()}
          onStop={() => {
            aiChat.cancelCurrentReply();
            setIsSending(false);
          }}
          onPickImages={pickImages}
          attachedImages={attachedImages}
          onRemoveImage={(idx) => setAttachedImages((prev) => prev.filter((_, i) => i !== idx))}
          centered={isDesktop}
          deepThinkMode={deepThinkMode}
          onSelectDeepThink={setDeepThinkMode}
          canvasEnabled={canvasEnabled}
          onToggleCanvas={() => setCanvasEnabled((v) => !v)}
        />
      </div>

      {!isDesktop && (
        <MotchiSidebar
          isOpen={sidebarOpen}
          onClose={() => setSidebarOpen(false)}
          onNewChat={() => void newChat()}
          navigationBusy={conversationLoading || startingChat || ai.isNavigating}
          onSessionOpened={() => {
            setConversationFailed(false);
            userScrolledUpRef.current = false;
            scrollToBottom(false);
          }}
        />
      )}
    </div>
  );
}
