// Port of lib/features/chat/presentation/screens/sanctuary_chat_screen.dart,
// widgets/chat_bubble.dart and widgets/pulsing_heart_loader.dart.
import { doc, serverTimestamp, setDoc } from 'firebase/firestore';
import { useCallback, useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { AgentMode } from '../../core/agent/agentMode';
import { useController } from '../../core/anim/controller';
import { useAuth } from '../../core/services/auth';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { AppSpacing } from '../../core/theme/layout';
import { Curves, motionReduced, orZero } from '../../core/theme/motion';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { displayNameFor } from '../../shared/utils/text';
import { useDraft } from '../../shared/utils/draft';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { FadeIn } from '../../shared/widgets/FadeIn';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { PartnerPresenceIndicator } from '../../shared/widgets/PartnerPresenceIndicator';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { chatService, type ChatMessage } from './chatService';

type AuthError = 'not_authenticated' | 'cinema_only' | 'not_couple_user';
type StreamState = { data: ChatMessage[] | null; error: unknown; done: boolean };

const isSameDay = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** DateFormat('h:mm a'). */
function formatTime(d: Date): string {
  const h = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
}

function dayLabel(date: Date): string {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diff = Math.round((today.getTime() - d.getTime()) / 86_400_000);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  return `${WEEKDAYS[date.getDay()]}, ${MONTHS[date.getMonth()]} ${date.getDate()}`;
}

function copyText(text: string) {
  void navigator.clipboard?.writeText(text).catch(() => {});
  showSnackBar('Copied to clipboard', { duration: 1000, background: AppColors.velvet });
}

/** `_mergeMessages`: an optimistic message disappears once the server copy (same sender + text within 45s) arrives. */
function mergeMessages(server: ChatMessage[], optimistic: ChatMessage[]): { merged: ChatMessage[]; remaining: ChatMessage[] } {
  if (optimistic.length === 0) return { merged: server, remaining: optimistic };
  const matched = new Set<string>();
  const remaining: ChatMessage[] = [];
  for (const opt of optimistic) {
    if (opt.isFailed) {
      remaining.push(opt);
      continue;
    }
    const hit = server.find(
      (srv) =>
        !matched.has(srv.id) &&
        srv.sender === opt.sender &&
        srv.text === opt.text &&
        Math.abs(srv.timestamp.getTime() - opt.timestamp.getTime()) < 45_000,
    );
    if (hit) matched.add(hit.id);
    else remaining.push(opt);
  }
  const merged = [...server, ...remaining].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
  return { merged, remaining: remaining.length === optimistic.length ? optimistic : remaining };
}

export function SanctuaryPage() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? 'unknown';
  const [text, setText, clearDraft] = useDraft('chat:sanctuary');
  const [optimistic, setOptimistic] = useState<ChatMessage[]>([]);
  const [authChecked, setAuthChecked] = useState(false);
  const [authError, setAuthError] = useState<AuthError | null>(null);
  const [connection, setConnection] = useState(0);
  const [stream, setStream] = useState<StreamState>({ data: null, error: null, done: false });
  const [showScrollButton, setShowScrollButton] = useState(false);
  const list = useRef<HTMLDivElement>(null);
  const scrollAnim = useRef(0);

  const checkAuthAndConnect = useCallback(() => {
    const fail = (e: AuthError) => {
      setAuthChecked(true);
      setAuthError(e);
    };
    if (!auth.isAuthenticated) return fail('not_authenticated');
    if (auth.isCinemaOnlyUser) return fail('cinema_only');
    if (!auth.isCoupleUser) return fail('not_couple_user');
    const uid = auth.uid;
    if (uid == null) return fail('not_authenticated');
    if (!AgentMode.isActive.value) {
      setDoc(doc(db, 'users', uid), { username: auth.currentUser, updatedAt: serverTimestamp() }, { merge: true }).catch((e) =>
        Logger.e('Sanctuary: failed to ensure user doc', e),
      );
    }
    void auth.refreshPartnerLink();
    setAuthChecked(true);
    setAuthError(null);
    setConnection((c) => c + 1);
  }, [auth]);

  useEffect(() => {
    checkAuthAndConnect();
    // Like initState: checked once; Reset & Retry checks again.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (connection === 0) return;
    setStream({ data: null, error: null, done: false });
    return chatService.watchMessages()({
      data: (data) => setStream({ data, error: null, done: false }),
      error: (error) => setStream({ data: null, error, done: false }),
      done: () => setStream((s) => ({ ...s, done: true })),
    });
  }, [connection]);

  const resetAndRetry = async () => {
    setAuthChecked(false);
    setAuthError(null);
    try {
      await auth.user?.getIdToken(true);
    } catch (e) {
      Logger.e('Token refresh failed', e);
    }
    checkAuthAndConnect();
  };

  const scrollToBottom = useCallback((animated = true) => {
    const el = list.current;
    if (!el) return;
    cancelAnimationFrame(scrollAnim.current);
    const target = el.scrollHeight - el.clientHeight;
    if (!animated || orZero(300) === 0) {
      el.scrollTop = target;
      return;
    }
    const from = el.scrollTop;
    const start = performance.now();
    const step = (now: number) => {
      const t = Math.min(1, (now - start) / 300);
      el.scrollTop = from + (el.scrollHeight - el.clientHeight - from) * Curves.easeOut(t);
      if (t < 1) scrollAnim.current = requestAnimationFrame(step);
    };
    scrollAnim.current = requestAnimationFrame(step);
  }, []);
  useEffect(() => () => cancelAnimationFrame(scrollAnim.current), []);

  const { merged: messages, remaining } = mergeMessages(stream.data ?? [], optimistic);
  useEffect(() => {
    if (remaining !== optimistic) setOptimistic(remaining);
  }, [remaining, optimistic]);

  const lastId = messages.length > 0 ? messages[messages.length - 1].id : '';
  useLayoutEffect(() => {
    if (messages.length > 0) scrollToBottom();
    // A new message (or the first batch) brings the list to the bottom.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [messages.length, lastId]);

  const markFailed = (id: string, failed: boolean) =>
    setOptimistic((list) => list.map((m) => (m.id === id ? { ...m, isFailed: failed, isOptimistic: !failed } : m)));

  const sendMessage = () => {
    const words = text.trim();
    if (words === '') return;
    const tempId = `optimistic_${Date.now()}`;
    setOptimistic((list) => [
      ...list,
      {
        id: tempId,
        sender: currentUser,
        senderUid: auth.uid ?? 'anonymous',
        text: words,
        timestamp: new Date(),
        isOptimistic: true,
      },
    ]);
    clearDraft();
    chatService.sendMessage(words, currentUser, auth.uid ?? 'anonymous').catch(() => markFailed(tempId, true));
  };

  const retryMessage = (msg: ChatMessage) => {
    markFailed(msg.id, false);
    chatService.sendMessage(msg.text, msg.sender, auth.uid ?? 'anonymous').catch(() => markFailed(msg.id, true));
  };

  const canSend = authChecked && authError == null && text.trim() !== '';

  let body: ReactNode;
  if (!authChecked) {
    body = (
      <Centered>
        <PulsingHeartLoader />
        <div style={{ height: 20 }} />
        <div style={{ ...AppTypography.bodyLarge, lineHeight: lineHeight(16), color: AppColors.roseQuartz }}>
          Verifying access...
        </div>
      </Centered>
    );
  } else if (authError != null) {
    body = <AuthErrorState error={authError} onRetry={() => void resetAndRetry()} />;
  } else if (stream.done && stream.data == null && stream.error == null) {
    body = (
      <ErrorState
        icon="cloud_off"
        title="Sanctuary is taking too long to respond"
        subtitle="Check your connection and try again."
        onRetry={() => void resetAndRetry()}
      />
    );
  } else if (stream.data == null && stream.error == null) {
    body = (
      <Centered>
        <PulsingHeartLoader />
        <div style={{ height: 20 }} />
        <div style={{ ...AppTypography.bodyLarge, lineHeight: lineHeight(16), color: AppColors.roseQuartz }}>
          Opening our sanctuary...
        </div>
        <div style={{ height: 10 }} />
        <TextButton onPressed={() => void resetAndRetry()}>
          <span style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: withAlpha(AppColors.roseQuartz, 0.6) }}>
            Taking too long? Tap to retry
          </span>
        </TextButton>
      </Centered>
    );
  } else if (stream.error != null) {
    const error = String(stream.error);
    let title = 'Something went wrong';
    let detail = error.length > 120 ? `${error.slice(0, 120)}...` : error;
    if (error.includes('permission-denied')) {
      title = 'Access requires a linked account';
      detail = 'Please log out and log back in to refresh your session.';
    } else if (error.includes('unavailable') || error.includes('deadline-exceeded')) {
      title = 'The sanctuary is temporarily unavailable';
      detail = 'Please check your connection and try again.';
    }
    body = <ErrorState icon="cloud_off" title={title} subtitle={detail} onRetry={() => void resetAndRetry()} />;
  } else if (messages.length === 0) {
    body = (
      <Centered>
        <FadeIn direction="up" duration={250}>
          <div style={{ padding: AppSpacing.x2, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <div style={{ width: 80, height: 80, borderRadius: '50%', boxShadow: `0 0 32px 4px ${Derived.glowRose}` }}>
              <Icon name="favorite" size={80} color={AppColors.roseQuartz} />
            </div>
            <div style={{ height: 20 }} />
            <div style={{ ...AppTypography.titleLarge, lineHeight: lineHeight(22), color: AppColors.roseQuartz }}>
              Our sanctuary is empty...
            </div>
            <div style={{ height: 8 }} />
            <div style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14), color: withAlpha(AppColors.roseQuartz, 0.6) }}>
              Send the first message to start blooming
            </div>
          </div>
        </FadeIn>
      </Centered>
    );
  } else {
    body = (
      <div
        ref={list}
        aria-live="polite"
        onScroll={(e) => {
          const el = e.currentTarget;
          const show = el.scrollHeight - el.clientHeight - el.scrollTop > 400;
          if (show !== showScrollButton) setShowScrollButton(show);
        }}
        className="no-scrollbar"
        style={{ position: 'absolute', inset: 0, overflowY: 'auto', padding: '20px 16px 24px', boxSizing: 'border-box' }}
      >
        {messages.map((message, index) => {
          const isMe = message.sender === currentUser;
          const prev = index > 0 ? messages[index - 1] : null;
          const isGrouped =
            prev != null && prev.sender === message.sender && message.timestamp.getTime() - prev.timestamp.getTime() < 5 * 60_000;
          const showDayHeader = prev == null || !isSameDay(message.timestamp, prev.timestamp);
          return (
            <div key={message.id}>
              {showDayHeader && <DayHeader date={message.timestamp} />}
              <div style={{ paddingTop: isGrouped ? 2 : 8 }}>
                <ChatBubble
                  message={message}
                  isMe={isMe}
                  showSender={!isGrouped}
                  onRetry={() => retryMessage(message)}
                  onDismiss={() => setOptimistic((list) => list.filter((m) => m.id !== message.id))}
                />
              </div>
            </div>
          );
        })}
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', height: '100vh', overflow: 'hidden' }}>
      <EverglowBackground baseColor={AppColors.inkDeep} />
      <div
        style={{
          position: 'relative',
          height: '100%',
          maxWidth: 860,
          margin: '0 auto',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <EverglowFeatureHeader
          title="Sanctuary"
          subtitle="our quiet corner"
          icon="favorite_border"
          hue={AppColors.auroraRose}
          actions={[
            <MaterialIconButton
              key="diag"
              icon="wifi_tethering"
              size={18}
              color={AppColors.blushGold}
              tooltip="Connection"
              onPressed={() => void showDiagnostics(auth.uid)}
            />,
          ]}
        />
        <div
          style={{
            padding: '2px 28px 14px',
            display: 'flex',
            flexWrap: 'wrap',
            justifyContent: 'center',
            alignItems: 'center',
            gap: '6px 16px',
          }}
        >
          <span style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: Derived.textMedium }}>
            A place for just the two of us
          </span>
          <PartnerPresenceIndicator />
        </div>
        <div style={{ position: 'relative', flex: 1, minHeight: 0 }}>
          {body}
          {showScrollButton && (
            <FadeInPlain duration={200} style={{ position: 'absolute', right: 8, bottom: 8 }}>
              <button
                type="button"
                className="bare-button"
                aria-label="Scroll to bottom"
                onClick={() => scrollToBottom()}
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: '50%',
                  background: Derived.surfaceGlass,
                  border: `1px solid ${Derived.border}`,
                  boxSizing: 'border-box',
                  boxShadow: '0 6px 16px #40000000',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="keyboard_arrow_down" size={20} color={Derived.textMuted} />
              </button>
            </FadeInPlain>
          )}
        </div>
        <InputArea text={text} onChange={setText} canSend={canSend} onSend={sendMessage} />
      </div>
    </div>
  );
}

function Centered({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
      }}
    >
      {children}
    </div>
  );
}

/** animate_do FadeIn: opacity 0→1 with easeOut. */
function FadeInPlain({
  duration = 500,
  delay = 0,
  children,
  style,
}: {
  duration?: number;
  delay?: number;
  children: ReactNode;
  style?: React.CSSProperties;
}) {
  const controller = useController(duration);
  useEffect(() => {
    const timer = window.setTimeout(() => void controller.forward(), delay);
    return () => window.clearTimeout(timer);
  }, [controller, delay]);
  return <div style={{ ...style, opacity: Curves.easeOut(controller.value) }}>{children}</div>;
}

/** PulsingHeartLoader: animate_do Pulse (1 → 1.5 → 1, easeOut halves, 1500ms, forever) and a late fade-in caption. */
function PulsingHeartLoader() {
  const reduced = motionReduced();
  const [t, setT] = useState(0);
  useEffect(() => {
    if (reduced) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      setT(((now - start) % 1500) / 1500);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduced]);
  const scale = t < 0.5 ? 1 + 0.5 * Curves.easeOut(t / 0.5) : 1.5 - 0.5 * Curves.easeOut((t - 0.5) / 0.5);
  const caption = (
    <div style={{ ...AppTypography.outfitWhite, lineHeight: lineHeight(14), color: AppColors.roseQuartz, letterSpacing: 0.5 }}>
      Opening our sanctuary...
    </div>
  );
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ transform: reduced ? undefined : `scale(${scale})` }}>
        <Icon name="favorite" size={60} color={AppColors.deepRose} />
      </div>
      <div style={{ height: 16 }} />
      {reduced ? caption : <FadeInPlain delay={500}>{caption}</FadeInPlain>}
    </div>
  );
}

function ErrorState({ icon, title, subtitle, onRetry }: { icon: string; title: string; subtitle: string; onRetry: () => void }) {
  return (
    <Centered>
      <FadeIn direction="up" duration={400}>
        <div style={{ padding: AppSpacing.x2, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <Icon name={icon} size={64} color={withAlpha(AppColors.roseQuartz, 0.4)} />
          <div style={{ height: 20 }} />
          <div style={{ ...AppTypography.bodyLarge, lineHeight: lineHeight(16), color: AppColors.roseQuartz }}>{title}</div>
          <div style={{ height: 8 }} />
          <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: withAlpha(AppColors.roseQuartz, 0.6) }}>
            {subtitle}
          </div>
          <div style={{ height: 16 }} />
          <TextButton onPressed={onRetry} color={AppColors.roseQuartz}>
            Reset &amp; Retry
          </TextButton>
        </div>
      </FadeIn>
    </Centered>
  );
}

function AuthErrorState({ error, onRetry }: { error: AuthError; onRetry: () => void }) {
  const info =
    error === 'not_authenticated'
      ? { icon: 'lock_outline', title: 'You need to sign in', detail: 'Please go back and sign in with your passcode.' }
      : error === 'cinema_only'
        ? {
            icon: 'movie_filter',
            title: 'Cinema-only access',
            detail: "Your account doesn't have access to Sanctuary Chat. This feature is for Khent and Clair only.",
          }
        : { icon: 'heart_broken', title: 'Access restricted', detail: 'Sanctuary Chat is only available to linked partners.' };
  return <ErrorState icon={info.icon} title={info.title} subtitle={info.detail} onRetry={onRetry} />;
}

function DayHeader({ date }: { date: Date }) {
  const line = <div style={{ flex: 1, height: 1, background: Derived.divider }} />;
  return (
    <div style={{ padding: '24px 0', display: 'flex', alignItems: 'center' }}>
      {line}
      <span
        style={{
          padding: '0 16px',
          ...AppTypography.bodySmall,
          fontSize: 12,
          lineHeight: lineHeight(12),
          color: Derived.textMuted,
        }}
      >
        {dayLabel(date)}
      </span>
      {line}
    </div>
  );
}

function ChatBubble({
  message,
  isMe,
  showSender,
  onRetry,
  onDismiss,
}: {
  message: ChatMessage;
  isMe: boolean;
  showSender: boolean;
  onRetry: () => void;
  onDismiss: () => void;
}) {
  const press = useRef(0);
  const timeStr = formatTime(message.timestamp);
  const cancelPress = () => clearTimeout(press.current);
  return (
    <div style={{ display: 'flex', justifyContent: isMe ? 'flex-end' : 'flex-start' }}>
      <div
        aria-label={isMe ? `You at ${timeStr}` : `${message.sender} at ${timeStr}`}
        style={{
          maxWidth: '84%',
          padding: '3px 0',
          display: 'flex',
          flexDirection: 'column',
          alignItems: isMe ? 'flex-end' : 'flex-start',
        }}
      >
        {!isMe && showSender && (
          <div
            style={{
              padding: '0 0 7px 16px',
              ...AppTypography.bodySmall,
              lineHeight: lineHeight(12.5),
              color: AppColors.blushGold,
              fontWeight: 600,
            }}
          >
            {displayNameFor(message.sender)}
          </div>
        )}
        <div
          onPointerDown={(e) => {
            if (e.pointerType === 'mouse') return;
            cancelPress();
            press.current = window.setTimeout(() => copyText(message.text), 500);
          }}
          onPointerUp={cancelPress}
          onPointerCancel={cancelPress}
          onPointerMove={cancelPress}
          style={{
            padding: '12px 16px 5px',
            background: isMe ? AppColors.roseDepths : AppColors.silk,
            boxShadow: message.isFailed ? `inset 0 0 0 1px ${AppColors.error}` : undefined,
            borderRadius: isMe ? '20px 20px 5px 20px' : '20px 20px 20px 5px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
            boxSizing: 'border-box',
            maxWidth: '100%',
          }}
        >
          <div
            style={{
              ...AppTypography.bodyMedium,
              color: AppColors.petalWhite,
              fontSize: 16,
              fontWeight: 500,
              lineHeight: lineHeight(16, 1.5),
              whiteSpace: 'pre-wrap',
              overflowWrap: 'anywhere',
              userSelect: 'text',
              cursor: 'text',
            }}
          >
            {message.text}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center' }}>
            <span
              style={{
                ...AppTypography.bodySmall,
                fontSize: 11,
                lineHeight: lineHeight(11),
                color: isMe ? withAlpha(AppColors.petalWhite, 0.8) : Derived.textMedium,
              }}
            >
              {timeStr}
            </span>
            {message.isOptimistic && (
              <>
                <div style={{ width: 6 }} />
                <Tooltip message="Sending">
                  <Icon name="schedule" size={14} color={AppColors.roseQuartz} />
                </Tooltip>
              </>
            )}
            <MessageActions onCopy={() => copyText(message.text)} />
          </div>
        </div>
        {message.isFailed && (
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center' }}>
            <span style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: AppColors.error }}>Not sent</span>
            <TextButton onPressed={onRetry}>Retry</TextButton>
            <TextButton onPressed={onDismiss}>Delete</TextButton>
          </div>
        )}
      </div>
    </div>
  );
}

/** PopupMenuButton with one "Copy message" item: a 44px button in a 48px tap slot, an M3 menu over it. */
function MessageActions({ onCopy }: { onCopy: () => void }) {
  const button = useRef<HTMLButtonElement>(null);
  const [menu, setMenu] = useState<{ left: number; top: number } | null>(null);
  const [hovered, setHovered] = useState(false);
  return (
    <>
      <Tooltip message="Message actions">
        <div style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <button
            ref={button}
            type="button"
            className="bare-button"
            aria-label="Message actions"
            onMouseEnter={() => setHovered(true)}
            onMouseLeave={() => setHovered(false)}
            onClick={() => {
              const r = button.current!.getBoundingClientRect();
              const left = Math.min(Math.max(8, r.left), window.innerWidth - 8 - 112);
              const top = Math.min(Math.max(8, r.top), window.innerHeight - 8 - 64);
              setMenu({ left, top });
            }}
            style={{
              width: 44,
              height: 44,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: hovered ? withAlpha(AppColors.petalWhite, 0.08) : 'transparent',
            }}
          >
            <Icon name="more_horiz" size={18} color={withAlpha(AppColors.petalWhite, 0.8)} />
          </button>
        </div>
      </Tooltip>
      {menu &&
        createPortal(
          <div onClick={() => setMenu(null)} style={{ position: 'fixed', inset: 0, zIndex: 850 }}>
            <div
              onClick={(e) => e.stopPropagation()}
              style={{
                position: 'fixed',
                left: menu.left,
                top: menu.top,
                minWidth: 112,
                padding: '8px 0',
                borderRadius: 4,
                background: '#271D1F',
                boxShadow: '0 1px 3px rgba(0,0,0,0.3), 0 4px 8px 3px rgba(0,0,0,0.15)',
              }}
            >
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  setMenu(null);
                  onCopy();
                }}
                style={{
                  width: '100%',
                  height: 48,
                  padding: '0 12px',
                  display: 'flex',
                  alignItems: 'center',
                  ...AppTypography.labelLarge,
                  lineHeight: lineHeight(14),
                  color: M3Scheme.onSurface,
                  whiteSpace: 'nowrap',
                }}
              >
                Copy message
              </button>
            </div>
          </div>,
          document.body,
        )}
    </>
  );
}

/** The input bar: a silk pill holding a 1–4 line field and IconButton.filled. */
function InputArea({
  text,
  onChange,
  canSend,
  onSend,
}: {
  text: string;
  onChange: (t: string) => void;
  canSend: boolean;
  onSend: () => void;
}) {
  const field = useRef<HTMLTextAreaElement>(null);
  useLayoutEffect(() => {
    const el = field.current;
    if (!el) return;
    el.style.height = '0px';
    el.style.height = `${Math.min(Math.max(el.scrollHeight, 52), 4 * 24 + 28)}px`;
  }, [text]);
  return (
    <div style={{ padding: '8px 16px 16px' }}>
      <div
        style={{
          padding: 6,
          background: AppColors.silk,
          borderRadius: 28,
          border: `1px solid ${Derived.border}`,
          display: 'flex',
          alignItems: 'flex-end',
        }}
      >
        <textarea
          ref={field}
          value={text}
          maxLength={1000}
          rows={1}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Leave a little love..."
          className="money-input"
          style={
            {
              flex: 1,
              minWidth: 0,
              height: 52,
              padding: '14px 16px',
              boxSizing: 'border-box',
              background: 'transparent',
              border: 'none',
              outline: 'none',
              resize: 'none',
              overflowY: 'auto',
              ...AppTypography.bodyMedium,
              fontSize: 16,
              lineHeight: '24px',
              letterSpacing: 0.5,
              color: Derived.textHigh,
              caretColor: AppColors.roseQuartz,
              '--hint-color': Derived.textMedium,
              '--hint-size': '14px',
            } as React.CSSProperties
          }
        />
        <Tooltip message="Send message">
          <button
            type="button"
            className="bare-button"
            aria-label="Send message"
            disabled={!canSend}
            onClick={onSend}
            style={{
              width: 48,
              height: 48,
              flexShrink: 0,
              borderRadius: '50%',
              background: canSend ? AppColors.roseDepths : withAlpha(AppColors.moonlight, 0.06),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="arrow_upward" size={24} color={canSend ? AppColors.petalWhite : Derived.textDisabled} />
          </button>
        </Tooltip>
      </div>
    </div>
  );
}

async function showDiagnostics(uid: string | null) {
  let closeSpinner: ((v: null) => void) | null = null;
  void showDialog<null>(
    (close) => {
      closeSpinner = close;
      return (
        <AlertDialog
          background={AppColors.velvet}
          radius={24}
          content={
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <CircularProgress size={36} strokeWidth={4} color={AppColors.roseQuartz} />
              <div style={{ height: 16 }} />
              <div style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>
                Testing connection to our sanctuary...
              </div>
            </div>
          }
        />
      );
    },
    { barrierDismissible: false },
  );
  let result: string;
  try {
    await chatService.sendMessage('DIAGNOSTIC_CHECK', 'System', uid ?? 'no-id');
    result =
      "[OK] Connection Successful!\n\nYour device can reach the server. If you still can't see messages, please check if your partner has a stable connection too.";
  } catch (e) {
    result = `[FAIL] Connection Failed!\n\nError: ${String(e)}\n\nThis is usually due to Firestore Security Rules. Please make sure your database allows access for authenticated users.`;
  }
  (closeSpinner as ((v: null) => void) | null)?.(null);
  void showDialog<null>((close) => (
    <AlertDialog
      background={AppColors.velvet}
      radius={22}
      title={<span style={{ ...AppTypography.titleLarge, color: AppColors.roseQuartz }}>Sanctuary Status</span>}
      content={
        <div
          style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14), color: Derived.textMedium, whiteSpace: 'pre-wrap' }}
        >
          {result}
        </div>
      }
      actions={[
        <TextButton key="ok" onPressed={() => close(null)} color={AppColors.roseQuartz}>
          OK
        </TextButton>,
      ]}
    />
  ));
}
