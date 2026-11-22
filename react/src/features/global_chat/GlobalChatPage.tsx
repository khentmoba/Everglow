import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router';
import { displayNameFor, useAuth } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSourceState } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { MediaSectionMenuButton } from '../cinema/NetflixUi';
import {
  deleteGlobalChatMessage,
  sendGlobalChatMessage,
  watchGlobalChat,
  type GlobalChatMessage,
} from './globalChatService';

function formatMessageTime(date: Date): string {
  return date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

function roleTag(username: string): string | null {
  if (username === 'khentsgdz') return 'Host';
  if (username === 'clairjassen') return 'Co-Host';
  return null;
}

export function GlobalChatPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const myUid = auth.uid ?? '';
  const myUsername = auth.currentUser ?? '';
  const [retryKey, setRetryKey] = useState(0);
  const { value: messages, error: streamError } = useSourceState(
    () => watchGlobalChat(100),
    [myUid, myUsername, retryKey],
    [],
  );
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const lastMessageId = messages.length > 0 ? messages[messages.length - 1].id : null;

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [lastMessageId]);

  const handleSend = async (e: FormEvent) => {
    e.preventDefault();
    const text = draft.trim();
    if (!text || !myUid || !myUsername || sending) return;
    setSending(true);
    try {
      await sendGlobalChatMessage({ senderUid: myUid, senderName: myUsername, text });
      setDraft('');
    } catch (err) {
      showSnackBar(err instanceof Error ? err.message : 'Could not send message.');
    } finally {
      setSending(false);
    }
  };

  const handleDelete = async (msg: GlobalChatMessage) => {
    try {
      await deleteGlobalChatMessage(msg.id);
    } catch {
      showSnackBar('Could not delete message.');
    }
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep, display: 'flex', flexDirection: 'column' }}>
      <header
        style={{
          padding: '12px 16px',
          paddingTop: 'calc(12px + env(safe-area-inset-top))',
          background: withAlpha(AppColors.inkDeep, 0.96),
          borderBottom: `1px solid ${Derived.border}`,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          flexShrink: 0,
        }}
      >
        <button
          type="button"
          className="bare-button"
          aria-label="Back"
          onClick={() => ((window.history.state?.idx ?? 0) > 0 ? navigate(-1) : navigate(auth.isCoupleUser ? '/dashboard' : '/cinema'))}
          style={{
            width: 38,
            height: 38,
            borderRadius: '50%',
            background: withAlpha(AppColors.petalWhite, 0.07),
            border: `1px solid ${Derived.border}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="arrow_back" size={20} color={AppColors.petalWhite} />
        </button>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="forum" size={18} color={AppColors.blushGold} />
            <span style={{ ...AppTypography.outfitHeading, fontSize: 17, color: AppColors.petalWhite }}>
              Global Chat
            </span>
          </div>
          <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: Derived.textMuted }}>
            Signed in as <strong>{displayNameFor(myUsername)}</strong> · Everyone in Everglow
          </div>
        </div>

        <button
          type="button"
          className="bare-button"
          aria-label="Open Watch Party Hub"
          onClick={() => navigate('/watch-party')}
          style={{
            padding: '8px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.deepRose, 0.2),
            border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.35)}`,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 12,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name="live_tv" size={15} color={AppColors.blushGold} />
          <span>Watch Party</span>
        </button>

        <MediaSectionMenuButton currentRoute="/global-chat" />
      </header>

      <div
        className="no-scrollbar"
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: `${AppSpacing.md}px 16px`,
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
          maxWidth: 780,
          width: '100%',
          margin: '0 auto',
          boxSizing: 'border-box',
        }}
      >
        {streamError && messages.length === 0 ? (
          <div
            role="alert"
            style={{
              margin: 'auto',
              padding: 28,
              borderRadius: AppRadius.md,
              background: Derived.surfaceGlass,
              border: `1px solid ${Derived.border}`,
              textAlign: 'center',
              maxWidth: 340,
            }}
          >
            <Icon name="cloud_off" size={32} color={AppColors.roseQuartz} />
            <div style={{ height: 8 }} />
            <div style={{ ...AppTypography.outfitHeading, fontSize: 15, color: AppColors.petalWhite }}>
              Could not load messages
            </div>
            <div style={{ height: 4 }} />
            <div style={{ fontSize: 12.5, color: Derived.textMuted }}>
              Check your connection or tap retry.
            </div>
            <button
              type="button"
              className="bare-button"
              onClick={() => setRetryKey((k) => k + 1)}
              style={{
                marginTop: 12,
                padding: '8px 16px',
                borderRadius: 999,
                background: AppColors.deepRose,
                color: AppColors.petalWhite,
                ...AppTypography.outfitBold,
                fontSize: 12.5,
              }}
            >
              Retry
            </button>
          </div>
        ) : messages.length === 0 ? (
          <div
            style={{
              margin: 'auto',
              padding: 28,
              borderRadius: AppRadius.md,
              background: Derived.surfaceGlass,
              border: `1px solid ${Derived.border}`,
              textAlign: 'center',
              maxWidth: 340,
            }}
          >
            <Icon name="forum" size={32} color={AppColors.roseQuartz} />
            <div style={{ height: 8 }} />
            <div style={{ ...AppTypography.outfitHeading, fontSize: 15, color: AppColors.petalWhite }}>
              No messages yet
            </div>
            <div style={{ height: 4 }} />
            <div style={{ fontSize: 12.5, color: Derived.textMuted }}>
              Say hi, share a movie or anime recommendation, or invite everyone to a Watch Party.
            </div>
          </div>
        ) : (
          messages.map((msg) => {
            const mine = Boolean(myUid) && msg.senderUid === myUid;
            const label = displayNameFor(msg.senderName);
            const badge = roleTag(msg.senderName);
            const canDelete = mine || auth.isCoupleUser;

            return (
              <div
                key={msg.id}
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: mine ? 'flex-end' : 'flex-start',
                  gap: 4,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '0 4px' }}>
                  <span style={{ ...AppTypography.outfitBold, fontSize: 11.5, color: mine ? AppColors.blushGold : AppColors.roseQuartz }}>
                    {label}
                  </span>
                  {badge && (
                    <span
                      style={{
                        padding: '1px 6px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.blushGold, 0.16),
                        border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
                        color: AppColors.blushGold,
                        fontSize: 9.5,
                        fontWeight: 700,
                      }}
                    >
                      {badge}
                    </span>
                  )}
                  <span style={{ fontSize: 10.5, color: Derived.textMuted }}>{formatMessageTime(msg.createdAt)}</span>
                </div>

                <div
                  style={{
                    maxWidth: '82%',
                    padding: '10px 14px',
                    borderRadius: mine ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                    background: mine
                      ? linear([withAlpha(AppColors.deepRose, 0.86), withAlpha(AppColors.rosePressed, 0.92)])
                      : Derived.surfaceGlass,
                    border: `1px solid ${mine ? withAlpha(AppColors.roseQuartz, 0.35) : Derived.border}`,
                    color: AppColors.petalWhite,
                    fontSize: 14,
                    lineHeight: 1.45,
                    whiteSpace: 'pre-wrap',
                    wordBreak: 'break-word',
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: 8,
                  }}
                >
                  <span style={{ flex: 1 }}>{msg.text}</span>
                  {canDelete && (
                    <button
                      type="button"
                      className="bare-button"
                      aria-label="Delete message"
                      onClick={() => void handleDelete(msg)}
                      style={{
                        padding: 2,
                        opacity: 0.65,
                        flexShrink: 0,
                      }}
                    >
                      <Icon name="close" size={14} color={AppColors.petalWhite} />
                    </button>
                  )}
                </div>
              </div>
            );
          })
        )}
        <div ref={bottomRef} />
      </div>

      <form
        onSubmit={(e) => void handleSend(e)}
        style={{
          padding: '10px 16px',
          paddingBottom: 'calc(12px + env(safe-area-inset-bottom))',
          background: withAlpha(AppColors.inkDeep, 0.96),
          borderTop: `1px solid ${Derived.border}`,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          maxWidth: 780,
          width: '100%',
          margin: '0 auto',
          boxSizing: 'border-box',
        }}
      >
        <input
          type="text"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="Message Global Chat…"
          maxLength={2000}
          style={{
            flex: 1,
            padding: '11px 14px',
            borderRadius: 999,
            background: AppColors.shimmerBase,
            border: `1px solid ${Derived.border}`,
            color: AppColors.petalWhite,
            outline: 'none',
            fontSize: 14,
            fontFamily: 'inherit',
          }}
        />
        <button
          type="submit"
          className="bare-button"
          aria-label="Send message"
          disabled={sending || !draft.trim()}
          style={{
            width: 42,
            height: 42,
            borderRadius: '50%',
            background: linear([AppColors.deepRose, AppColors.rosePressed]),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            opacity: sending || !draft.trim() ? 0.5 : 1,
            flexShrink: 0,
          }}
        >
          <Icon name="send" size={19} color={AppColors.petalWhite} />
        </button>
      </form>
    </div>
  );
}
