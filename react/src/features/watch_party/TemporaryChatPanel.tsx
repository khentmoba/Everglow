// Port of lib/features/watch_party/presentation/widgets/temporary_chat_panel.dart.
import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { NetflixColors } from '../cinema/cinemaTypes';
import {
  clearTemporaryChat,
  ensureTemporaryChatRoom,
  sendTemporaryChatMessage,
  temporaryChatStream,
  type TemporaryChatMessage,
} from './temporaryChatService';

type ChatState = { kind: 'loading' } | { kind: 'error' } | { kind: 'data'; messages: TemporaryChatMessage[] };

export function TemporaryChatPanel({ roomId, myUid, partnerUid }: { roomId: string; myUid: string; partnerUid: string }) {
  const auth = useAuth();
  const partnerName = auth.partnerName;
  const [state, setState] = useState<ChatState>({ kind: 'loading' });
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [clearing, setClearing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scroll = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let alive = true;
    let unsub: (() => void) | undefined;
    void ensureTemporaryChatRoom(roomId, myUid, partnerUid).then(() => {
      if (!alive) return;
      unsub = temporaryChatStream(roomId)({
        data: (messages) => setState({ kind: 'data', messages }),
        error: () => setState({ kind: 'error' }),
      });
    });
    return () => {
      alive = false;
      unsub?.();
    };
  }, [roomId, myUid, partnerUid]);

  // Jump to the newest message whenever the list changes.
  useLayoutEffect(() => {
    const el = scroll.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [state]);

  const send = async () => {
    const text = input.trim();
    if (!text || sending) return;
    setSending(true);
    setError(null);
    try {
      await sendTemporaryChatMessage(roomId, text, auth.currentUser ?? 'Me', auth.uid ?? myUid);
      setInput('');
      requestAnimationFrame(() => scroll.current?.scrollTo({ top: scroll.current.scrollHeight, behavior: 'smooth' }));
    } catch {
      setError('Could not send the message.');
    } finally {
      setSending(false);
    }
  };

  const clear = async () => {
    if (clearing) return;
    setClearing(true);
    setError(null);
    try {
      await clearTemporaryChat(roomId);
    } catch {
      setError('Could not clear the chat.');
    } finally {
      setClearing(false);
    }
  };

  return (
    <div
      style={{
        background: NetflixColors.surface,
        borderRadius: 14,
        border: `1px solid ${NetflixColors.hairline}`,
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div
        style={{
          padding: '10px 8px 10px 14px',
          borderBottom: `1px solid ${NetflixColors.hairline}`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <Icon name="chat_bubble" variant="filled" size={20} color={NetflixColors.accent} />
        <div style={{ width: 8 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14), color: NetflixColors.textPrimary }}
          >
            Temporary Chat
          </div>
          <div style={{ height: 2 }} />
          <div
            style={{ ...AppTypography.outfitWhite, fontSize: 10.5, lineHeight: lineHeight(10.5), color: NetflixColors.textMuted }}
          >
            Live with {partnerName} · clears anytime
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          title="Clear chat"
          aria-label="Clear chat"
          disabled={clearing}
          onClick={() => void clear()}
          style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '50%' }}
        >
          {clearing ? (
            <CircularProgress size={16} strokeWidth={2} color={NetflixColors.accent} />
          ) : (
            <Icon name="delete_sweep_outlined" size={18} color={NetflixColors.textSecondary} />
          )}
        </button>
      </div>
      <div style={{ height: state.kind === 'error' ? 80 : 240, position: 'relative' }}>
        {state.kind === 'error' ? (
          <ChatMessageState icon="cloud_off" text="Chat is unavailable. Check your connection." />
        ) : state.kind === 'loading' ? (
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <CircularProgress size={36} strokeWidth={2} color={NetflixColors.accent} />
          </div>
        ) : state.messages.length === 0 ? (
          <ChatMessageState icon="favorite_border" text={`Say hi to ${partnerName} while you pick a movie.`} />
        ) : (
          <div
            ref={scroll}
            className="no-scrollbar"
            style={{ height: '100%', overflowY: 'auto', padding: 12, boxSizing: 'border-box' }}
          >
            {state.messages.map((m) => (
              <Bubble key={m.id} message={m} isMe={m.senderUid === myUid} />
            ))}
          </div>
        )}
      </div>
      <div style={{ padding: '8px 8px 12px 10px', borderTop: `1px solid ${NetflixColors.hairline}` }}>
        {error && (
          <div
            style={{
              paddingBottom: 6,
              ...AppTypography.outfitWhite,
              fontSize: 10.5,
              lineHeight: lineHeight(10.5),
              color: NetflixColors.accent,
              textAlign: 'center',
            }}
          >
            {error}
          </div>
        )}
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div
            style={{
              flex: 1,
              minWidth: 0,
              background: withAlpha(AppColors.petalWhite, 0.06),
              borderRadius: 20,
              border: `1px solid ${withAlpha(AppColors.petalWhite, 0.14)}`,
              // InputDecorator's 48px minimum height, plus the border.
              minHeight: 50,
              boxSizing: 'border-box',
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <ChatInput value={input} placeholder={`Message ${partnerName}...`} onChange={setInput} onSubmit={() => void send()} />
          </div>
          <div style={{ width: 6 }} />
          <button
            type="button"
            className="bare-button"
            aria-label="Send"
            disabled={sending}
            onClick={() => void send()}
            style={{
              width: 38,
              height: 38,
              borderRadius: '50%',
              background: NetflixColors.accent,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            {sending ? (
              <CircularProgress size={18} strokeWidth={2} color={AppColors.petalWhite} />
            ) : (
              <Icon name="send" size={17} color={AppColors.petalWhite} />
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

/** A TextField with minLines 1 / maxLines 3 that sends on Enter. */
function ChatInput({
  value,
  placeholder,
  onChange,
  onSubmit,
}: {
  value: string;
  placeholder: string;
  onChange: (v: string) => void;
  onSubmit: () => void;
}) {
  const ref = useRef<HTMLTextAreaElement>(null);
  const line = 17;
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = `${line}px`;
    el.style.height = `${Math.min(line * 3, Math.max(line, el.scrollHeight - 20))}px`;
  }, [value]);
  return (
    <textarea
      ref={ref}
      rows={1}
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          onSubmit();
        }
      }}
      className="temp-chat-input"
      style={{
        flex: 1,
        minWidth: 0,
        resize: 'none',
        border: 'none',
        outline: 'none',
        background: 'transparent',
        padding: '10px 14px',
        boxSizing: 'content-box',
        ...AppTypography.outfitWhite,
        fontSize: 13,
        lineHeight: `${line}px`,
        height: line,
        color: NetflixColors.textPrimary,
        caretColor: NetflixColors.accent,
        overflowY: 'auto',
      }}
    />
  );
}

function Bubble({ message, isMe }: { message: TemporaryChatMessage; isMe: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: isMe ? 'flex-end' : 'flex-start' }}>
      <div
        style={{
          margin: '4px 0',
          padding: '8px 12px',
          maxWidth: 260,
          boxSizing: 'border-box',
          background: isMe ? withAlpha(NetflixColors.accent, 0.22) : NetflixColors.surfaceElevated,
          borderRadius: 12,
          border: `1px solid ${isMe ? withAlpha(NetflixColors.accent, 0.45) : NetflixColors.hairline}`,
        }}
      >
        <div
          style={{
            ...AppTypography.outfitHeading,
            fontSize: 10,
            lineHeight: lineHeight(10),
            color: isMe ? NetflixColors.accent : NetflixColors.textSecondary,
          }}
        >
          {isMe ? 'You' : message.sender}
        </div>
        <div style={{ height: 3 }} />
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 12.5,
            lineHeight: lineHeight(12.5, 1.3),
            color: NetflixColors.textPrimary,
            whiteSpace: 'pre-wrap',
            overflowWrap: 'anywhere',
          }}
        >
          {message.text}
        </div>
      </div>
    </div>
  );
}

function ChatMessageState({ icon, text }: { icon: string; text: string }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 20,
      }}
    >
      <Icon name={icon} size={28} color={NetflixColors.textMuted} />
      <div style={{ height: 10 }} />
      <div
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 12,
          lineHeight: lineHeight(12),
          color: NetflixColors.textMuted,
          textAlign: 'center',
        }}
      >
        {text}
      </div>
    </div>
  );
}
