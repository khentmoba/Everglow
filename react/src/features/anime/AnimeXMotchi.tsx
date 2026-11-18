// Port of animex_motchi_sidebar.dart (AnimeXMotchiSidebar + AnimeXMotchiFloatingTrigger).
import { useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { boxShadow } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { copyText } from '../../shared/widgets/EverglowChatBubble';
import { EverglowMarkdown, stripMarkdown } from '../../shared/widgets/EverglowMarkdown';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import type { MediaItem } from '../cinema/cinemaTypes';
import { aiChat, useAIChat } from '../ai/aiChat';
import { MotchiReplyDetailsCard } from '../ai/MotchiReplyDetailsCard';
import { MotchiWebBridge } from '../ai/MotchiWebBridge';
import {
  aiMessage,
  detailsEmpty,
  detailsFromResults,
  motchiPetName,
  shouldAutoThink,
  visibleText,
  type AIMessage,
} from '../ai/motchiDomain';
import { LiveToolStrip, ThinkingIndicator, WebSourcesCard } from '../ai/MotchiWidgets';

type DeepThinkMode = 'auto' | 'on' | 'off';

export function AnimeXMotchiFloatingTrigger({ onTap }: { onTap: () => void }) {
  return (
    <Tooltip message="Chat with Motchi">
      <button
        type="button"
        className="bare-button"
        onClick={onTap}
        style={{
          padding: '9px 14px',
          background: 'linear-gradient(135deg, #1E1E2C, #13131D)',
          borderRadius: 28,
          border: `1.4px solid ${withAlpha(AppColors.blushGold, 0.7)}`,
          boxShadow: boxShadow([
            { color: 'rgba(0, 0, 0, 0.5)', blur: 16, offset: [0, 6] },
            { color: withAlpha(AppColors.blushGold, 0.35), blur: 20, spread: 1 },
          ]),
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: 28,
            height: 28,
            boxSizing: 'border-box',
            borderRadius: '50%',
            border: `1.2px solid ${AppColors.blushGold}`,
            overflow: 'hidden',
          }}
        >
          <img
            src="/images/motchi_avatar.webp"
            alt=""
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        </div>
        <div style={{ width: 8 }} />
        <span
          style={{
            ...AppTypography.bodyMedium,
            color: AppColors.petalWhite,
            fontSize: 13.5,
            fontWeight: 700,
            letterSpacing: 0.2,
          }}
        >
          Motchi
        </span>
        <div style={{ width: 4 }} />
        <Icon name="auto_awesome" size={14} color={AppColors.blushGold} />
      </button>
    </Tooltip>
  );
}

export function AnimeXMotchiSidebar({
  isOpen,
  onClose,
  watchItem,
  watchEpisode,
  messages,
  onAddMessage,
  onClear,
}: {
  isOpen: boolean;
  onClose: () => void;
  watchItem: MediaItem | null;
  watchEpisode?: number;
  messages: AIMessage[];
  onAddMessage: (m: AIMessage) => void;
  onClear: () => void;
}) {
  const { width } = useViewport();
  const { currentUser } = useAuth();
  const ai = useAIChat();

  const [input, setInput] = useState('');
  const [deepThink, setDeepThink] = useState<DeepThinkMode>('auto');
  const [isSending, setIsSending] = useState(false);
  const [lastSentMessage, setLastSentMessage] = useState<string | null>(null);
  const [attachedImages, setAttachedImages] = useState<string[]>([]);
  const [isListening, setIsListening] = useState(false);
  const [focused, setFocused] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [showScrollBtn, setShowScrollBtn] = useState(false);
  const [sessionId, setSessionId] = useState(() => `temp_anime_${Date.now()}`);

  const scrollRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const webBridge = useMemo(() => new MotchiWebBridge(), []);

  useEffect(() => {
    if (!isOpen) return;
    webBridge.installPasteListener((uri) => {
      setAttachedImages((prev) => [...prev, uri]);
    });
    return () => webBridge.uninstallPasteListener();
  }, [isOpen, webBridge]);

  useEffect(() => {
    if (!isOpen) return;
    const el = scrollRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [isOpen, messages.length, ai.draftResponse, ai.draftReasoning]);

  const isDesktop = width >= 900;
  const isTablet = width >= 600 && width < 900;
  const sidebarWidth = isDesktop ? 390 : isTablet ? 380 : Math.min(width * 0.9, 400);

  const send = async (opts?: { retry?: boolean; promptOverride?: string }) => {
    if (isSending) return;
    const retry = opts?.retry ?? false;
    const lastMsg = messages.at(-1);
    const retriedUserMessage =
      retry && lastMsg?.role === 'user' ? lastMsg : null;
    const text = (opts?.promptOverride ?? (retry ? lastSentMessage ?? retriedUserMessage?.content ?? '' : input)).trim();
    const images = retry ? [...(retriedUserMessage?.imageUrls ?? [])] : [...attachedImages];
    if (!text && images.length === 0) return;

    if (!retry) {
      setInput('');
      setLastSentMessage(text);
      onAddMessage(aiMessage({ role: 'user', content: text, imageUrls: images }));
    }
    const historyForRequest = retriedUserMessage ? messages.slice(0, -1) : messages;
    setAttachedImages([]);
    setIsSending(true);

    const enableThinking =
      deepThink === 'on' ? true : deepThink === 'off' ? false : shouldAutoThink(text);
    const contextOverride = watchItem
      ? `User is currently in Everglow Anime watching "${watchItem.title}" (episode ${watchEpisode ?? 1}). Provide relevant anime insights, lore, or recommendations if asked.`
      : undefined;

    try {
      const reply = await aiChat.sendTemporaryMessage({
        message: text,
        history: historyForRequest,
        callerName: currentUser,
        enableThinking,
        canvasEnabled: false,
        imageUrls: images,
        sessionId,
        contextOverride,
      });
      if (reply.content.trim()) {
        onAddMessage(reply);
      }
      setLastSentMessage(null);
    } catch {
      // ai.lastError displays banner cleanly
    } finally {
      setIsSending(false);
    }
  };

  const stop = () => {
    aiChat.cancelCurrentReply();
    setIsSending(false);
  };

  const clearChat = () => {
    stop();
    onClear();
    setSessionId(`temp_anime_${Date.now()}`);
    setLastSentMessage(null);
  };

  const pickImages = async (files: FileList | null) => {
    if (!files) return;
    for (const file of Array.from(files)) {
      const uri = await webBridge.fileToDataUri(file);
      if (uri) setAttachedImages((prev) => [...prev, uri]);
    }
  };

  const startVoice = async () => {
    if (!webBridge.isSpeechSupported || isListening) return;
    setIsListening(true);
    try {
      const result = await webBridge.recognizeOnce();
      if (result?.trim()) {
        setInput((prev) => (prev ? `${prev} ${result.trim()}` : result.trim()));
      }
    } finally {
      setIsListening(false);
    }
  };

  if (!isOpen) return null;

  const pet = motchiPetName(currentUser);
  const asks: Array<[string, string, string]> = watchItem
    ? [
        [
          'About this anime',
          `Tell me about the anime "${watchItem.title}" — synopsis, vibe, and why it is loved!`,
          'movie_filter',
        ],
        [
          'Like this one',
          `What anime are similar in vibe and genre to "${watchItem.title}"? Give 3 recommendations.`,
          'auto_awesome',
        ],
        ['Plan a watch night', 'Plan a cozy anime night for us', 'favorite_border'],
        [
          'What’s airing?',
          'What are the most popular and highly rated anime currently airing this season?',
          'calendar_month',
        ],
      ]
    : [
        [
          'Recommend an anime',
          "Recommend anime like Frieren: Beyond Journey's End with rich worldbuilding and emotional depth.",
          'auto_awesome',
        ],
        [
          'Couple romance',
          'What are the best cute, heartfelt romance anime for a couple to watch together?',
          'favorite_border',
        ],
        [
          'What’s airing?',
          'What are the most popular and highly rated anime currently airing this season?',
          'calendar_month',
        ],
        [
          'Explain lore',
          'Explain the worldline and time travel mechanics of Steins;Gate simply and clearly.',
          'psychology',
        ],
      ];

  const isStreaming = isSending && ai.isLoading;
  const canSend = input.trim().length > 0 || attachedImages.length > 0;
  const dur = orZero(260);

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 45, pointerEvents: 'auto' }}>
      <div
        onClick={onClose}
        style={{
          position: 'absolute',
          inset: 0,
          background: `rgba(0,0,0,${isDesktop ? 0.35 : 0.65})`,
          transition: `opacity ${dur}ms ease-out`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          right: 0,
          width: sidebarWidth,
          background: AppColors.inkDeep,
          borderLeft: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
          boxShadow: '-8px 0 36px rgba(0,0,0,0.5)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Header */}
        <div style={{ padding: '6px 8px', display: 'flex', alignItems: 'center' }}>
          <Tooltip message="Close">
            <button
              type="button"
              className="bare-button"
              onClick={onClose}
              aria-label="Close Motchi sidebar"
              style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}
            >
              <Icon name="close" size={20} color={Derived.textMuted} />
            </button>
          </Tooltip>
          <div style={{ width: 8 }} />
          <img
            src="/images/motchi_avatar.webp"
            alt=""
            style={{ width: 24, height: 24, borderRadius: 8, objectFit: 'cover' }}
          />
          <div style={{ width: 10 }} />
          <div
            style={{
              flex: 1,
              ...AppTypography.titleMedium,
              fontFamily: Fonts.reading,
              fontSize: 16,
              fontWeight: 500,
            }}
          >
            Motchi
          </div>
          <Tooltip message="New chat">
            <button
              type="button"
              className="bare-button"
              onClick={clearChat}
              aria-label="New chat"
              style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}
            >
              <Icon name="add_comment" variant="outlined" size={20} color={Derived.textMuted} />
            </button>
          </Tooltip>
        </div>

        {/* Body */}
        <div
          ref={scrollRef}
          onScroll={(e) => {
            const el = e.currentTarget;
            setShowScrollBtn(el.scrollHeight - el.scrollTop - el.clientHeight > 300);
          }}
          style={{ flex: 1, minHeight: 0, overflowY: 'auto', position: 'relative', display: 'flex', flexDirection: 'column' }}
        >
          {messages.length === 0 && !isStreaming ? (
            <div style={{ margin: 'auto 0', padding: '32px 28px', maxWidth: 440, width: '100%' }}>
              <div
                style={{
                  fontFamily: Fonts.display,
                  fontSize: 36,
                  fontWeight: 400,
                  color: AppColors.petalWhite,
                  lineHeight: 1.1,
                  letterSpacing: -0.5,
                }}
              >
                {pet ? `What’s on your mind, ${pet}?` : 'What’s on your mind?'}
              </div>
              <div
                style={{
                  marginTop: 16,
                  fontFamily: Fonts.reading,
                  fontSize: 14,
                  color: Derived.textMedium,
                  lineHeight: 1.6,
                }}
              >
                Anime picks, lore, or just a chat.
              </div>
              <div style={{ height: 32 }} />
              {asks.map(([label, prompt, icon]) => (
                <button
                  key={label}
                  type="button"
                  className="bare-button"
                  onClick={() => void send({ promptOverride: prompt })}
                  style={{
                    width: '100%',
                    minHeight: 48,
                    padding: '14px 4px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 14,
                    color: Derived.textMedium,
                    fontFamily: Fonts.reading,
                    fontSize: 14,
                    textAlign: 'left',
                  }}
                >
                  <Icon name={icon} variant="outlined" size={18} color={Derived.textMuted} />
                  <span style={{ flex: 1 }}>{label}</span>
                  <Icon name="arrow_outward" size={15} color={Derived.textMuted} />
                </button>
              ))}
            </div>
          ) : (
            <div style={{ padding: '20px 16px' }}>
              {messages.map((msg, i) => (
                <AnimeMsgBubble key={`${msg.timestamp.getTime()}_${i}`} msg={msg} />
              ))}
              {isStreaming && (
                <div style={{ padding: '12px 0' }}>
                  {ai.draftResponse || ai.draftReasoning || ai.activeTools.length > 0 || ai.toolResults.length > 0 ? (
                    <>
                      <AnimeMsgBubble
                        msg={aiMessage({
                          role: 'assistant',
                          content: visibleText(ai.draftResponse),
                        })}
                        streaming
                        reasoning={ai.draftReasoning || undefined}
                      />
                      <LiveToolStrip tools={ai.activeTools} />
                      {ai.toolResults.length > 0 && (
                        <div style={{ marginTop: 6 }}>
                          <MotchiReplyDetailsCard details={detailsFromResults(ai.toolResults)} />
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
          )}

          {showScrollBtn && (
            <button
              type="button"
              className="bare-button"
              onClick={() => scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' })}
              style={{
                position: 'sticky',
                bottom: 12,
                margin: '0 auto',
                display: 'flex',
                padding: '7px 14px',
                borderRadius: AppRadius.full,
                background: Derived.panelGlass,
                border: `1px solid ${Derived.border}`,
              }}
            >
              <Icon name="keyboard_arrow_down" size={18} color={Derived.textMuted} />
            </button>
          )}
        </div>

        {/* Error banner */}
        {ai.lastError && lastSentMessage && (
          <div
            style={{
              margin: '4px 16px',
              padding: '10px 14px',
              borderRadius: AppRadius.lg,
              background: withAlpha(AppColors.deepRose, 0.15),
              border: `1px solid ${withAlpha(AppColors.deepRose, 0.3)}`,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <Icon name="error_outline" size={18} color={AppColors.deepRose} />
            <span style={{ flex: 1, ...AppTypography.bodySmall, color: Derived.textMedium }}>
              {ai.lastError.includes('too large') || ai.lastError.includes('413')
                ? ai.lastError
                : 'Motchi got distracted. Try again?'}
            </span>
            <button
              type="button"
              className="bare-button"
              onClick={() => void send({ retry: true })}
              style={{
                padding: '6px 12px',
                borderRadius: AppRadius.sm,
                background: withAlpha(AppColors.deepRose, 0.2),
                ...AppTypography.bodySmall,
                color: AppColors.petalWhite,
                fontWeight: 600,
              }}
            >
              Retry
            </button>
          </div>
        )}

        {/* Composer */}
        <div style={{ padding: '8px 16px 14px' }}>
          {attachedImages.length > 0 && (
            <div style={{ display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 8 }}>
              {attachedImages.map((src, i) => (
                <div key={i} style={{ position: 'relative', width: 64, height: 64, flexShrink: 0 }}>
                  <img src={src} alt="" style={{ width: 64, height: 64, objectFit: 'cover', borderRadius: AppRadius.md }} />
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => setAttachedImages((prev) => prev.filter((_, idx) => idx !== i))}
                    style={{
                      position: 'absolute',
                      top: 2,
                      right: 2,
                      width: 22,
                      height: 22,
                      borderRadius: '50%',
                      background: AppColors.inkDeep,
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <Icon name="close" size={14} color={AppColors.petalWhite} />
                  </button>
                </div>
              ))}
            </div>
          )}

          <div
            style={{
              background: withAlpha(AppColors.silk, 0.55),
              borderRadius: AppRadius.lg,
              border: `1px solid ${focused ? withAlpha(AppColors.roseQuartz, 0.45) : withAlpha(AppColors.moonlight, 0.12)}`,
            }}
          >
            <textarea
              value={input}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey && !isSending && canSend) {
                  e.preventDefault();
                  void send();
                }
              }}
              placeholder="Message Motchi…"
              rows={1}
              style={{
                width: '100%',
                background: 'transparent',
                border: 'none',
                outline: 'none',
                resize: 'none',
                padding: '14px 16px 4px',
                fontFamily: Fonts.reading,
                fontSize: 15,
                color: AppColors.petalWhite,
                maxHeight: 130,
              }}
            />
            <div style={{ padding: '2px 8px 8px', display: 'flex', alignItems: 'center', position: 'relative' }}>
              <input
                ref={fileRef}
                type="file"
                accept="image/*"
                multiple
                style={{ display: 'none' }}
                onChange={(e) => {
                  void pickImages(e.target.files);
                  e.target.value = '';
                }}
              />
              <button
                type="button"
                className="bare-button"
                onClick={() => setMenuOpen((o) => !o)}
                aria-label="Add to message"
                style={{ width: 40, height: 40, display: 'grid', placeItems: 'center' }}
              >
                <Icon name="add" size={22} color={Derived.textMuted} />
              </button>
              {menuOpen && (
                <div
                  style={{
                    position: 'absolute',
                    left: 8,
                    bottom: 48,
                    background: AppColors.silk,
                    borderRadius: AppRadius.lg,
                    border: `1px solid ${Derived.border}`,
                    padding: 6,
                    display: 'flex',
                    flexDirection: 'column',
                    zIndex: 10,
                  }}
                >
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      setMenuOpen(false);
                      fileRef.current?.click();
                    }}
                    style={{ padding: '8px 14px', textAlign: 'left', ...AppTypography.bodyMedium }}
                  >
                    Attach images
                  </button>
                  {webBridge.isSpeechSupported && (
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => {
                        setMenuOpen(false);
                        void startVoice();
                      }}
                      style={{ padding: '8px 14px', textAlign: 'left', ...AppTypography.bodyMedium }}
                    >
                      {isListening ? 'Listening…' : 'Voice input'}
                    </button>
                  )}
                </div>
              )}

              <button
                type="button"
                className="bare-button"
                onClick={() =>
                  setDeepThink((m) => (m === 'auto' ? 'on' : m === 'on' ? 'off' : 'auto'))
                }
                style={{
                  padding: '6px 10px',
                  fontFamily: Fonts.reading,
                  fontSize: 12.5,
                  color: deepThink === 'on' ? AppColors.roseQuartz : Derived.textMuted,
                }}
              >
                {deepThink === 'auto' ? 'Auto' : deepThink === 'on' ? 'Deep' : 'Fast'}
              </button>

              <span style={{ flex: 1 }} />

              <button
                type="button"
                className="bare-button"
                aria-label={isStreaming ? 'Stop generating' : 'Send message'}
                disabled={!isStreaming && !canSend}
                onClick={isStreaming ? stop : () => void send()}
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: AppRadius.md,
                  background: isStreaming || canSend ? AppColors.roseQuartz : Derived.glassSoft,
                  color: isStreaming || canSend ? AppColors.inkDeep : Derived.textDisabled,
                  display: 'grid',
                  placeItems: 'center',
                }}
              >
                <Icon
                  name={isStreaming ? 'stop' : 'arrow_upward'}
                  size={21}
                  color={isStreaming || canSend ? AppColors.inkDeep : Derived.textDisabled}
                />
              </button>
            </div>
          </div>

          <div
            style={{
              marginTop: 10,
              textAlign: 'center',
              ...AppTypography.bodySmall,
              color: Derived.textDisabled,
            }}
          >
            Temporary anime chat · Nothing is saved
          </div>
        </div>
      </div>
    </div>
  );
}

function AnimeMsgBubble({
  msg,
  streaming = false,
  reasoning,
}: {
  msg: AIMessage;
  streaming?: boolean;
  reasoning?: string;
}) {
  const isUser = msg.role === 'user';
  const [showThoughts, setShowThoughts] = useState(true);
  const bubbleText = isUser ? msg.content : msg.content.trimStart();

  return (
    <div style={{ padding: '14px 0', display: 'flex', flexDirection: 'column', alignItems: isUser ? 'flex-end' : 'flex-start' }}>
      <div
        onClick={() => !isUser && copyText(stripMarkdown(bubbleText))}
        style={{
          maxWidth: isUser ? '85%' : '100%',
          padding: isUser ? '12px 16px' : 0,
          background: isUser ? Derived.glassSoft : 'transparent',
          borderRadius: isUser ? AppRadius.lg : 0,
        }}
      >
        {!isUser && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <img
              src="/images/motchi_avatar.webp"
              alt=""
              style={{ width: 20, height: 20, borderRadius: 7, objectFit: 'cover' }}
            />
            <span style={{ ...AppTypography.bodySmall, fontFamily: Fonts.reading, color: Derived.textMedium }}>
              Motchi
            </span>
          </div>
        )}
        {reasoning && (
          <button
            type="button"
            className="bare-button"
            onClick={() => setShowThoughts((s) => !s)}
            style={{
              width: '100%',
              marginBottom: 8,
              padding: '8px 10px',
              background: Derived.glassSoft,
              borderRadius: AppRadius.md,
              textAlign: 'left',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <Icon name="pets" size={13} color={AppColors.blushGold} />
              <span style={{ ...AppTypography.bodySmall, fontSize: 11.5, fontWeight: 700, color: AppColors.blushGold }}>
                Motchi's thoughts{streaming ? '…' : ''}
              </span>
              <Icon name={showThoughts ? 'expand_less' : 'expand_more'} size={16} color={Derived.textMuted} />
            </div>
            {showThoughts && (
              <div style={{ ...AppTypography.bodySmall, marginTop: 6, color: Derived.textMuted, whiteSpace: 'pre-wrap' }}>
                {reasoning}
              </div>
            )}
          </button>
        )}
        {msg.imageUrls.length > 0 && (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 6 }}>
            {msg.imageUrls.map((url, idx) => (
              <img key={idx} src={url} alt="" style={{ width: 88, height: 88, borderRadius: 10, objectFit: 'cover' }} />
            ))}
          </div>
        )}
        {isUser ? (
          <div style={{ fontFamily: Fonts.reading, fontSize: 14.5, color: AppColors.petalWhite, whiteSpace: 'pre-wrap' }}>
            {msg.content}
          </div>
        ) : (
          <EverglowMarkdown text={bubbleText} />
        )}
        {!isUser && msg.sources.length > 0 && (
          <div style={{ marginTop: 6 }}>
            <WebSourcesCard sources={msg.sources} />
          </div>
        )}
        {!isUser && !detailsEmpty(msg.details) && (
          <div style={{ marginTop: 6 }}>
            <MotchiReplyDetailsCard details={msg.details} />
          </div>
        )}
      </div>
    </div>
  );
}
