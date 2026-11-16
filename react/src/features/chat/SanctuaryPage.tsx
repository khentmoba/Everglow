// Port of lib/features/chat/presentation/screens/sanctuary_chat_screen.dart + chat_bubble.dart.
import { useEffect, useMemo, useRef, useState } from 'react';
import { AgentMode } from '../../core/agent/agentMode';
import { useAuth } from '../../core/services/auth';
import { auth as fbAuth } from '../../core/services/firebase';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppSpacing } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { PartnerPresenceIndicator } from '../../shared/widgets/PartnerPresenceIndicator';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { chatService, type ChatMessage } from './chatService';

const DRAFT_KEY = 'everglow_draft_chat:sanctuary';

function displayNameFor(username: string): string {
  const lower = username.toLowerCase();
  if (lower === 'khentsgdz') return 'Khent';
  if (lower === 'clairjassen') return 'Clair';
  return username || 'Partner';
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function formatDayLabel(d: Date): string {
  const now = new Date();
  if (isSameDay(d, now)) return 'Today';
  const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
  if (isSameDay(d, yesterday)) return 'Yesterday';
  return d.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' });
}

function formatTime(d: Date): string {
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

export function SanctuaryPage() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? 'unknown';
  const [draft, setDraft] = useState(() => localStorage.getItem(DRAFT_KEY) ?? '');
  const [optimistic, setOptimistic] = useState<ChatMessage[]>([]);
  const [showScrollBtn, setShowScrollBtn] = useState(false);
  const [diagOpen, setDiagOpen] = useState(false);
  const [diagLoading, setDiagLoading] = useState(false);
  const [diagText, setDiagText] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  const authError = useMemo(() => {
    if (!auth.isAuthenticated) return 'not_authenticated';
    if (auth.isCinemaOnlyUser) return 'cinema_only';
    if (!auth.isCoupleUser) return 'not_couple_user';
    if (!auth.uid) return 'missing_uid';
    return null;
  }, [auth.isAuthenticated, auth.isCinemaOnlyUser, auth.isCoupleUser, auth.uid]);

  const serverMessages = useSource<ChatMessage[]>(
    () => (authError == null ? chatService.watchMessages(100) : null),
    [authError, currentUser],
    [],
  );

  const messages = useMemo(() => {
    const remaining = optimistic.filter(
      (opt) =>
        !serverMessages.some(
          (srv) =>
            srv.text === opt.text &&
            srv.sender === opt.sender &&
            Math.abs(srv.timestamp.getTime() - opt.timestamp.getTime()) < 30_000,
        ),
    );
    return [...serverMessages, ...remaining].sort(
      (a, b) => a.timestamp.getTime() - b.timestamp.getTime(),
    );
  }, [serverMessages, optimistic]);

  useEffect(() => {
    localStorage.setItem(DRAFT_KEY, draft);
  }, [draft]);

  const scrollToBottom = () => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' });
  };

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages.length]);

  const sendMessage = async (textOverride?: string, retryId?: string) => {
    const text = (textOverride ?? draft).trim();
    if (!text || authError) return;
    const tempId = retryId ?? `opt_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
    if (!textOverride) {
      setDraft('');
      localStorage.removeItem(DRAFT_KEY);
    }
    const optMsg: ChatMessage = {
      id: tempId,
      sender: currentUser,
      senderUid: auth.uid ?? '',
      text,
      timestamp: new Date(),
      isOptimistic: true,
      isFailed: false,
    };
    setOptimistic((prev) => [...prev.filter((m) => m.id !== tempId), optMsg]);
    try {
      await chatService.sendMessage(text, currentUser, auth.uid ?? '');
      if (AgentMode.demo) {
        setOptimistic((prev) => prev.filter((m) => m.id !== tempId));
      }
    } catch {
      setOptimistic((prev) =>
        prev.map((m) => (m.id === tempId ? { ...m, isOptimistic: false, isFailed: true } : m)),
      );
    }
  };

  const runDiagnostics = async () => {
    setDiagOpen(true);
    setDiagLoading(true);
    setDiagText(null);
    try {
      await chatService.sendMessage('DIAGNOSTIC_CHECK', 'System', auth.uid ?? 'no-id');
      setDiagText(
        '[OK] Connection Successful!\n\nYour device can reach the server. If you still can\'t see messages, please check if your partner has a stable connection too.',
      );
    } catch (e) {
      setDiagText(
        `[FAIL] Connection Failed!\n\nError: ${e}\n\nThis is usually due to Firestore Security Rules. Please make sure your database allows access for authenticated users.`,
      );
    } finally {
      setDiagLoading(false);
    }
  };

  return (
    <div style={{ position: 'relative', height: '100vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <EverglowBackground baseColor={AppColors.inkDeep} />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          flex: 1,
          minHeight: 0,
          maxWidth: 860,
          width: '100%',
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
            <Tooltip key="diag" message="Connection">
              <button
                type="button"
                className="bare-button"
                aria-label="Connection"
                onClick={() => void runDiagnostics()}
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="wifi_tethering" size={18} color={AppColors.blushGold} />
              </button>
            </Tooltip>,
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
          <span style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>
            A place for just the two of us
          </span>
          <PartnerPresenceIndicator />
        </div>

        <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {authError ? (
            <AuthErrorView
              error={authError}
              onRetry={() => {
                void fbAuth.currentUser?.getIdToken(true);
              }}
            />
          ) : messages.length === 0 ? (
            <div
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                padding: AppSpacing.x2,
                textAlign: 'center',
              }}
            >
              <div
                style={{
                  borderRadius: '50%',
                  padding: 16,
                  boxShadow: `0 0 32px 4px ${withAlpha(AppColors.deepRose, 0.45)}`,
                  marginBottom: 20,
                }}
              >
                <Icon name="favorite" size={64} color={AppColors.roseQuartz} />
              </div>
              <div style={{ ...AppTypography.titleLarge, color: AppColors.roseQuartz }}>
                Our sanctuary is empty...
              </div>
              <div style={{ height: 8 }} />
              <div style={{ ...AppTypography.bodyMedium, color: withAlpha(AppColors.roseQuartz, 0.6) }}>
                Send the first message to start blooming
              </div>
            </div>
          ) : (
            <div
              ref={scrollRef}
              onScroll={(e) => {
                const el = e.currentTarget;
                setShowScrollBtn(el.scrollHeight - el.scrollTop - el.clientHeight > 400);
              }}
              style={{
                flex: 1,
                overflowY: 'auto',
                padding: '20px 16px 24px',
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              {messages.map((msg, i) => {
                const isMe = msg.sender === currentUser;
                const prev = i > 0 ? messages[i - 1] : null;
                const isGrouped =
                  prev != null &&
                  prev.sender === msg.sender &&
                  msg.timestamp.getTime() - prev.timestamp.getTime() < 5 * 60_000;
                const showSender = !isGrouped;
                const showDayHeader = prev == null || !isSameDay(msg.timestamp, prev.timestamp);

                return (
                  <div key={msg.id} style={{ display: 'flex', flexDirection: 'column' }}>
                    {showDayHeader && (
                      <div
                        style={{
                          padding: '24px 0',
                          display: 'flex',
                          alignItems: 'center',
                        }}
                      >
                        <div style={{ flex: 1, height: 1, background: Derived.divider }} />
                        <span
                          style={{
                            padding: '0 16px',
                            ...AppTypography.bodySmall,
                            color: Derived.textMuted,
                            fontSize: 12,
                          }}
                        >
                          {formatDayLabel(msg.timestamp)}
                        </span>
                        <div style={{ flex: 1, height: 1, background: Derived.divider }} />
                      </div>
                    )}
                    <div
                      style={{
                        marginTop: isGrouped ? 2 : 8,
                        display: 'flex',
                        justifyContent: isMe ? 'flex-end' : 'flex-start',
                      }}
                    >
                      <div
                        style={{
                          maxWidth: '84%',
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: isMe ? 'flex-end' : 'flex-start',
                          padding: '3px 0',
                        }}
                      >
                        {!isMe && showSender && (
                          <span
                            style={{
                              ...AppTypography.bodySmall,
                              color: AppColors.blushGold,
                              fontWeight: 600,
                              paddingLeft: 16,
                              paddingBottom: 7,
                            }}
                          >
                            {displayNameFor(msg.sender)}
                          </span>
                        )}
                        <div
                          onClick={() => {
                            if (navigator.clipboard?.writeText) {
                              void navigator.clipboard.writeText(msg.text);
                              showSnackBar('Copied to clipboard', { duration: 1000 });
                            }
                          }}
                          title="Tap to copy"
                          style={{
                            padding: '12px 16px 5px',
                            background: isMe ? AppColors.roseDepths : AppColors.silk,
                            border: msg.isFailed ? `1px solid ${AppColors.error}` : undefined,
                            borderRadius: isMe ? '20px 20px 5px 20px' : '20px 20px 20px 5px',
                            cursor: 'pointer',
                            opacity: msg.isOptimistic ? 0.78 : 1,
                          }}
                        >
                          <div
                            style={{
                              ...AppTypography.bodyMedium,
                              color: AppColors.petalWhite,
                              fontSize: 16,
                              fontWeight: 500,
                              lineHeight: 1.5,
                              whiteSpace: 'pre-wrap',
                              wordBreak: 'break-word',
                            }}
                          >
                            {msg.text}
                          </div>
                          <div
                            style={{
                              display: 'flex',
                              flexWrap: 'wrap',
                              alignItems: 'center',
                            }}
                          >
                            <span
                              style={{
                                ...AppTypography.bodySmall,
                                fontSize: 11,
                                color: isMe
                                  ? withAlpha(AppColors.petalWhite, 0.8)
                                  : Derived.textMedium,
                              }}
                            >
                              {formatTime(msg.timestamp)}
                            </span>
                            {msg.isOptimistic && (
                              <span style={{ marginLeft: 6, display: 'inline-flex', alignItems: 'center' }} title="Sending">
                                <Icon name="schedule" size={14} color={AppColors.roseQuartz} />
                              </span>
                            )}
                            {msg.isFailed && (
                              <span style={{ marginLeft: 6, fontSize: 11, color: AppColors.error }}>Failed</span>
                            )}
                            <Tooltip message="Message actions">
                              <button
                                type="button"
                                className="bare-button"
                                aria-label="Message actions"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  if (navigator.clipboard?.writeText) {
                                    void navigator.clipboard.writeText(msg.text);
                                    showSnackBar('Copied to clipboard', { duration: 1000 });
                                  }
                                }}
                                style={{
                                  minWidth: 44,
                                  minHeight: 44,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  padding: 0,
                                }}
                              >
                                <Icon name="more_horiz" size={18} color={withAlpha(AppColors.petalWhite, 0.8)} />
                              </button>
                            </Tooltip>
                          </div>
                        </div>
                        {msg.isFailed && (
                          <div style={{ display: 'flex', gap: 10, marginTop: 4 }}>
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => void sendMessage(msg.text, msg.id)}
                              style={{ ...AppTypography.labelSmall, color: AppColors.roseQuartz }}
                            >
                              Retry
                            </button>
                            <button
                              type="button"
                              className="bare-button"
                              onClick={() => setOptimistic((p) => p.filter((x) => x.id !== msg.id))}
                              style={{ ...AppTypography.labelSmall, color: Derived.textMuted }}
                            >
                              Dismiss
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {showScrollBtn && (
            <button
              type="button"
              className="bare-button"
              onClick={scrollToBottom}
              aria-label="Scroll to bottom"
              style={{
                position: 'absolute',
                bottom: 8,
                right: 16,
                width: 36,
                height: 36,
                borderRadius: '50%',
                background: Derived.surfaceGlass,
                border: `1px solid ${Derived.border}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 4px 12px rgba(0,0,0,0.35)',
              }}
            >
              <Icon name="keyboard_arrow_down" size={20} color={Derived.textMuted} />
            </button>
          )}
        </div>

        {/* Input bar */}
        <div style={{ padding: '8px 16px 16px' }}>
          <div
            style={{
              padding: 6,
              background: AppColors.silk,
              borderRadius: 28,
              border: `1px solid ${Derived.border}`,
              display: 'flex',
              alignItems: 'flex-end',
              gap: 6,
            }}
          >
            <textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value.slice(0, 1000))}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  void sendMessage();
                }
              }}
              placeholder="Leave a little love..."
              rows={1}
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                resize: 'none',
                padding: '13px 16px',
                ...AppTypography.bodyMedium,
                fontSize: 16,
                color: Derived.textHigh,
                maxHeight: 112,
              }}
            />
            <Tooltip message="Send message">
              <button
                type="button"
                className="bare-button"
                aria-label="Send message"
                disabled={Boolean(authError) || draft.trim().length === 0}
                onClick={() => void sendMessage()}
                style={{
                  width: 48,
                  height: 48,
                  borderRadius: '50%',
                  background:
                    !authError && draft.trim().length > 0
                      ? AppColors.roseDepths
                      : withAlpha(AppColors.moonlight, 0.06),
                  color:
                    !authError && draft.trim().length > 0
                      ? AppColors.petalWhite
                      : Derived.textDisabled,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Icon
                  name="arrow_upward"
                  size={24}
                  color={
                    !authError && draft.trim().length > 0
                      ? AppColors.petalWhite
                      : Derived.textDisabled
                  }
                />
              </button>
            </Tooltip>
          </div>
        </div>
      </div>

      {diagOpen && (
        <div
          onClick={() => !diagLoading && setDiagOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.6)',
            zIndex: 500,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 420,
              background: AppColors.velvet,
              borderRadius: 22,
              border: `1px solid ${Derived.border}`,
              padding: 22,
            }}
          >
            {diagLoading ? (
              <div style={{ textAlign: 'center', padding: 12 }}>
                <div style={{ ...AppTypography.bodyMedium, color: AppColors.roseQuartz }}>
                  Testing connection to our sanctuary...
                </div>
              </div>
            ) : (
              <>
                <div style={{ ...AppTypography.titleLarge, color: AppColors.roseQuartz, marginBottom: 10 }}>
                  Sanctuary Status
                </div>
                <div style={{ ...AppTypography.bodyMedium, color: Derived.textMedium, whiteSpace: 'pre-wrap' }}>
                  {diagText}
                </div>
                <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 18 }}>
                  <EverglowButton label="OK" variant="ghost" onPressed={() => setDiagOpen(false)} />
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function AuthErrorView({ error, onRetry }: { error: string; onRetry: () => void }) {
  const info =
    error === 'not_authenticated'
      ? {
          icon: 'lock_outline',
          title: 'You need to sign in',
          detail: 'Please go back and sign in with your passcode.',
        }
      : error === 'cinema_only'
        ? {
            icon: 'movie_filter',
            title: 'Cinema-only access',
            detail: "Your account doesn't have access to Sanctuary Chat. This feature is for Khent and Clair only.",
          }
        : error === 'not_couple_user'
          ? {
              icon: 'heart_broken',
              title: 'Access restricted',
              detail: 'Sanctuary Chat is only available to linked partners.',
            }
          : {
              icon: 'cloud_off',
              title: 'Access requires a linked account',
              detail: 'Please log out and log back in to refresh your session.',
            };

  return (
    <div
      style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 32,
        textAlign: 'center',
      }}
    >
      <Icon name={info.icon} size={52} color={AppColors.roseQuartz} />
      <div style={{ height: 14 }} />
      <div style={{ ...AppTypography.titleLarge, color: AppColors.petalWhite }}>{info.title}</div>
      <div style={{ height: 8 }} />
      <div style={{ ...AppTypography.bodyMedium, maxWidth: 340, color: Derived.textMedium }}>{info.detail}</div>
      <div style={{ height: 20 }} />
      <EverglowButton label="Retry" variant="glass" icon="refresh" onPressed={onRetry} />
    </div>
  );
}
