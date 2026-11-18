// Port of lib/features/ai/presentation/widgets/motchi_widgets.dart,
// motchi_widgets_streaming.dart, motchi_widgets_extra.dart,
// motchi_widgets_markdown.dart and motchi_widgets_tools.dart.
import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { Logger } from '../../core/system/logger';
import { useViewport } from '../../core/system/viewport';
import { WebTts } from '../../core/system/webTts';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { orZero } from '../../core/theme/motion';
import { letterSpacing, lineHeight } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { copyText } from '../../shared/widgets/EverglowChatBubble';
import { EverglowMarkdown, stripMarkdown } from '../../shared/widgets/EverglowMarkdown';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { useAIChat } from './aiChat';
import { motchiPetName } from './motchiDomain';
import { MotchiVoiceWaveform } from './MotchiVoiceWaveform';
import { MotchiWebBridge } from './MotchiWebBridge';
import { artifactsEmpty, parseStudyArtifacts, stripArtifactBlocks, stripStreamingArtifacts } from './studyArtifact';
import { StudyArtifactEntry } from './StudyArtifactSheet';

export type DeepThinkMode = 'auto' | 'on' | 'off';

export function MotchiPageAvatar({ size = 28 }: { size?: number }) {
  return (
    <img
      src="/images/motchi_avatar.webp"
      alt=""
      width={size}
      height={size}
      style={{
        display: 'block',
        width: size,
        height: size,
        borderRadius: size * 0.35,
        objectFit: 'cover',
        flexShrink: 0,
      }}
    />
  );
}

const HEADER_ROUTES: Array<[route: string, label: string]> = [
  ['/motchi-preferences', 'Preferences'],
  ['/motchi-memory', 'Memory Book'],
  ['/motchi-trivia', 'Memory Trivia'],
  ['/motchi-today', 'Motchi Today'],
];

export function MotchiHeader({
  onBack,
  onSidebarToggle,
  onNewChat,
  sidebarOpen,
}: {
  onBack: () => void;
  onSidebarToggle: () => void;
  onNewChat?: () => void;
  sidebarOpen: boolean;
}) {
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header
      style={{
        padding: '6px 8px',
        borderBottom: `1px solid ${Derived.divider}`,
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
      }}
    >
      <MaterialIconButton icon="arrow_back" size={20} tooltip="Back" color={Derived.textMuted} onPressed={onBack} />
      <MaterialIconButton
        icon={sidebarOpen ? 'close' : 'menu'}
        size={20}
        tooltip={sidebarOpen ? 'Close history' : 'History'}
        color={Derived.textMuted}
        onPressed={onSidebarToggle}
      />
      <div style={{ width: 8 }} />
      <MotchiPageAvatar size={32} />
      <div style={{ width: 10 }} />
      <div
        className="ellipsis"
        style={{
          flex: 1,
          minWidth: 0,
          fontFamily: Fonts.reading,
          fontSize: 16,
          fontWeight: 500,
          lineHeight: lineHeight(16),
          color: AppColors.petalWhite,
        }}
      >
        Motchi
      </div>
      <MaterialIconButton
        icon="add_comment_outlined"
        size={20}
        tooltip="New chat"
        color={Derived.textMuted}
        onPressed={onNewChat}
      />
      <div style={{ position: 'relative' }}>
        <MaterialIconButton
          icon="more_horiz"
          size={24}
          tooltip="More from Motchi"
          color={Derived.textMuted}
          onPressed={() => setMenuOpen((v) => !v)}
        />
        {menuOpen && (
          <>
            <div onClick={() => setMenuOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 999 }} />
            <div
              style={{
                position: 'absolute',
                right: 4,
                top: 48,
                minWidth: 168,
                padding: 6,
                borderRadius: AppRadius.lg,
                background: AppColors.silk,
                border: `1px solid ${Derived.border}`,
                boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
                zIndex: 1000,
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              {HEADER_ROUTES.map(([route, label]) => (
                <button
                  key={route}
                  type="button"
                  className="bare-button"
                  onClick={() => {
                    setMenuOpen(false);
                    navigate(route);
                  }}
                  style={{
                    padding: '10px 14px',
                    borderRadius: AppRadius.sm,
                    ...AppTypography.bodyMedium,
                    color: Derived.textMedium,
                    textAlign: 'left',
                  }}
                >
                  {label}
                </button>
              ))}
            </div>
          </>
        )}
      </div>
    </header>
  );
}

const STARTER_PROMPTS: Array<[label: string, prompt: string, icon: string]> = [
  ['Pick a movie', 'What should we watch tonight from our watchlist?', 'movie_outlined'],
  ['Plan a date', 'Plan a cozy date night for us', 'favorite_border'],
  ['Quiz us', 'Quiz us with 5 fun questions', 'quiz_outlined'],
  ['Make a game', 'Build us a tiny game', 'sports_esports_outlined'],
];

export function GreetingEmptyState({
  onTap,
  centered = false,
  callerName,
}: {
  onTap: (prompt: string) => void;
  centered?: boolean;
  callerName?: string | null;
}) {
  const pet = motchiPetName(callerName);
  const headlineSize = centered ? 40 : 36;
  return (
    <div
      className="no-scrollbar"
      style={{
        height: '100%',
        overflowY: 'auto',
        padding: '32px 28px',
        boxSizing: 'border-box',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div
        style={{
          margin: 'auto',
          width: '100%',
          maxWidth: 440,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
        }}
      >
        <MotchiPageAvatar size={56} />
        <div style={{ height: 24 }} />
        <div
          style={{
            fontFamily: Fonts.display,
            fontSize: headlineSize,
            fontWeight: 400,
            color: AppColors.petalWhite,
            lineHeight: lineHeight(headlineSize, 1.1),
            ...letterSpacing(-0.5),
          }}
        >
          {pet === '' ? 'What’s on your mind?' : `What’s on your mind, ${pet}?`}
        </div>
        <div style={{ height: 16 }} />
        <div
          style={{
            fontFamily: Fonts.reading,
            fontWeight: 400,
            fontSize: 14,
            color: Derived.textMedium,
            lineHeight: lineHeight(14, 1.6),
          }}
        >
          A small plan, a good film, or just a chat.
        </div>
        <div style={{ height: 24 }} />
        <div
          style={{
            fontFamily: Fonts.reading,
            fontWeight: 500,
            fontSize: 12.5,
            color: Derived.textMuted,
            lineHeight: lineHeight(12.5),
          }}
        >
          Choose a starting point, then make it yours.
        </div>
        <div style={{ height: 12 }} />
        {STARTER_PROMPTS.map(([label, prompt, icon]) => (
          <button
            key={label}
            type="button"
            className="bare-button"
            onClick={() => onTap(prompt)}
            style={{
              width: '100%',
              minHeight: 48,
              marginBottom: 8,
              padding: '14px 16px',
              borderRadius: AppRadius.sm,
              background: Derived.glassSoft,
              color: Derived.textMedium,
              fontFamily: Fonts.reading,
              fontSize: 14,
              fontWeight: 400,
              letterSpacing: 0.25,
              lineHeight: lineHeight(14),
              display: 'flex',
              alignItems: 'center',
              gap: 14,
            }}
          >
            <Icon name={icon} size={18} color={Derived.textMuted} />
            <span style={{ flex: 1, textAlign: 'left' }}>{label}</span>
            <Icon name="arrow_outward" size={15} color={Derived.textMedium} />
          </button>
        ))}
      </div>
    </div>
  );
}

const TOOL_NAMES: Record<string, string> = {
  request_tools: 'Getting ready…',
  propose_choices: 'Picking choices…',
  add_to_watchlist: 'Adding to watchlist…',
  save_to_starlight_jar: 'Saving to Starlight Jar…',
  read_starlight_jar: 'Reading the Starlight Jar…',
  set_mood: 'Logging mood…',
  search_movies: 'Searching movies…',
  get_watchlist: 'Reading the watchlist…',
  get_weather: 'Checking the weather…',
  create_reminder: 'Writing a sticky note…',
  log_activity: 'Logging activity…',
  search_books: 'Browsing book shelves…',
  add_book_to_our_books: 'Adding to Our Books…',
  get_date_ideas: 'Dreaming up date ideas…',
  read_chat_messages: 'Reading chat messages…',
  send_sanctuary_message: 'Sending to Sanctuary…',
  get_xp_stats: 'Checking XP stats…',
  search_anime: 'Searching anime…',
  remember_fact: 'Tucking into memory…',
  read_memories: 'Flipping through memories…',
  pin_memory: 'Pinning memory…',
  delete_memory: 'Forgetting that…',
  edit_memory: 'Updating memory…',
  mark_watchlist_item_watched: 'Marking as watched…',
  update_book_progress: 'Updating book progress…',
  add_xp: 'Awarding XP…',
  send_note_to_partner: 'Sending a love note…',
  get_relationship_insights: 'Finding love patterns…',
  get_memory_trivia: 'Making memory trivia…',
  get_today_recap: 'Compiling today…',
  get_gallery: 'Browsing our photos…',
  get_garden: 'Visiting the garden…',
  get_canvas: 'Looking at drawings…',
  search_spotify: 'Tuning into Spotify…',
  remove_from_watchlist: 'Removing from watchlist…',
  search_everglow: 'Searching Everglow…',
  plan_date_night: 'Planning date night…',
  add_calendar_event: 'Marking the calendar…',
  create_journal_entry: 'Writing in diary…',
  add_bucket_item: 'Adding to bucket list…',
  add_trip: 'Planning our getaway…',
  add_trip_pin: 'Pinning trip spot…',
  log_habit: 'Tracking habit…',
  complete_habit: 'Completing habit…',
  get_calendar_events: 'Checking the calendar…',
  get_bucket_list: 'Reading bucket list…',
  get_journal_entries: 'Reading our diary…',
  search_journal_entries: 'Searching journal…',
  read_journal_entry: 'Reading journal entry…',
  get_trips: 'Reading our trips…',
  web_search: 'Searching the web…',
  read_web_page: 'Reading webpage…',
  browse_web: 'Browsing the web…',
  list_reminders: 'Checking sticky notes…',
  cancel_reminder: 'Dropping reminder…',
  edit_journal_entry: 'Editing journal…',
  delete_journal_entry: 'Deleting journal entry…',
  update_calendar_event: 'Updating calendar…',
  delete_calendar_event: 'Removing calendar event…',
  complete_bucket_item: 'Checking off bucket item…',
  delete_bucket_item: 'Removing bucket item…',
};

function formatToolStatus(status: string): string {
  if (status === 'generating' || status === 'thinking' || status.startsWith('round_')) return 'Motchi is thinking…';
  if (status === 'executing') return 'Motchi is working on it…';
  if (status === 'done') return 'Motchi is done';
  if (status === 'request_tools') return 'Motchi is getting ready…';
  return TOOL_NAMES[status] ?? status.replaceAll('_', ' ');
}

function toolAccent(status: string): string {
  switch (status) {
    case 'add_to_watchlist':
    case 'search_movies':
    case 'get_watchlist':
    case 'search_anime':
    case 'search_spotify':
    case 'search_everglow':
    case 'add_bucket_item':
      return AppColors.blushGold;
    case 'save_to_starlight_jar':
    case 'read_starlight_jar':
    case 'get_gallery':
    case 'get_canvas':
    case 'create_journal_entry':
    case 'send_note_to_partner':
    case 'send_sanctuary_message':
    case 'get_relationship_insights':
      return AppColors.auroraLilac;
    case 'set_mood':
    case 'get_weather':
    case 'get_garden':
    case 'add_calendar_event':
    case 'add_trip':
    case 'add_trip_pin':
    case 'web_search':
    case 'read_web_page':
    case 'browse_web':
    case 'mark_watchlist_item_watched':
    case 'update_book_progress':
    case 'add_xp':
    case 'remove_from_watchlist':
      return AppColors.auroraTeal;
    case 'get_date_ideas':
    case 'remember_fact':
    case 'read_memories':
    case 'pin_memory':
    case 'delete_memory':
    case 'edit_memory':
    case 'get_memory_trivia':
    case 'get_today_recap':
    case 'plan_date_night':
    case 'log_habit':
    case 'complete_habit':
      return AppColors.roseQuartz;
    case 'get_calendar_events':
    case 'get_bucket_list':
    case 'get_journal_entries':
    case 'search_journal_entries':
    case 'read_journal_entry':
    case 'get_trips':
    case 'list_reminders':
    case 'cancel_reminder':
      return Derived.textMuted;
    case 'edit_journal_entry':
    case 'delete_journal_entry':
    case 'update_calendar_event':
    case 'delete_calendar_event':
    case 'complete_bucket_item':
    case 'delete_bucket_item':
      return AppColors.auroraRose;
    default:
      return AppColors.blushGold;
  }
}

export function LiveToolStrip({ tools }: { tools: string[] }) {
  if (tools.length === 0) return null;
  return (
    <div style={{ paddingTop: 8, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
      {tools.map((tool) => {
        const accent = toolAccent(tool);
        return (
          <div
            key={tool}
            role="status"
            aria-live="polite"
            style={{
              padding: '10px 12px',
              background: Derived.glassSoft,
              borderRadius: AppRadius.md,
              border: `1px solid ${Derived.border}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <span
              style={{
                width: 6,
                height: 6,
                borderRadius: '50%',
                background: accent,
                flexShrink: 0,
              }}
            />
            <Icon name="auto_fix_high" size={16} color={accent} />
            <span style={{ ...AppTypography.bodySmall, fontSize: 13, color: Derived.textHigh, lineHeight: 1.3 }}>
              {formatToolStatus(tool)}
            </span>
          </div>
        );
      })}
    </div>
  );
}

export function WebSourcesCard({ sources }: { sources: Record<string, string>[] }) {
  if (sources.length === 0) return null;
  return (
    <div
      style={{
        background: Derived.glassSoft,
        borderRadius: AppRadius.md,
        border: `1px solid ${Derived.border}`,
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ padding: '14px 14px 6px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <Icon name="travel_explore" size={20} color={AppColors.softLavender} />
        <span style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>Sources</span>
        <span style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>{sources.length}</span>
      </div>
      {sources.map((src, i) => {
        const rawUrl = (src.url ?? '').trim();
        let host = '';
        let canOpen = false;
        try {
          const parsed = new URL(rawUrl);
          canOpen = parsed.protocol === 'http:' || parsed.protocol === 'https:';
          host = parsed.host.replace(/^www\./, '');
        } catch {
          canOpen = false;
        }
        const site = (src.site ?? '').trim();
        const subtitle = host || site;
        const title = (src.title ?? '').trim() || subtitle || 'Source';
        return (
          <a
            key={`${rawUrl}_${i}`}
            href={canOpen ? rawUrl : undefined}
            target="_blank"
            rel="noopener noreferrer"
            style={{
              minHeight: 64,
              padding: '10px 14px',
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              textDecoration: 'none',
            }}
          >
            <div style={{ flex: 1, minWidth: 0 }}>
              <div
                className="clamp-2"
                style={{
                  ...AppTypography.bodySmall,
                  fontSize: 13,
                  fontWeight: 600,
                  color: Derived.textHigh,
                  lineHeight: 1.4,
                }}
              >
                {title}
              </div>
              {subtitle && (
                <div
                  className="ellipsis"
                  style={{
                    marginTop: 3,
                    ...AppTypography.bodySmall,
                    color: Derived.textMedium,
                    lineHeight: 1.4,
                  }}
                >
                  {subtitle}
                </div>
              )}
            </div>
            {canOpen && <Icon name="arrow_outward" size={18} color={AppColors.softLavender} />}
          </a>
        );
      })}
      <div style={{ height: 6 }} />
    </div>
  );
}

function StreamingPlaceholder() {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
      <span
        style={{
          fontFamily: Fonts.reading,
          fontWeight: 400,
          fontSize: 14,
          color: Derived.textMuted,
        }}
      >
        Thinking…
      </span>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
        {[0, 1, 2].map((i) => (
          <span
            key={i}
            style={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              background: AppColors.roseQuartz,
              opacity: 0.75,
            }}
          />
        ))}
      </span>
    </div>
  );
}

export function ThinkingIndicator() {
  return (
    <div style={{ padding: '20px 0', display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <MotchiPageAvatar size={20} />
        <span style={{ fontFamily: Fonts.reading, fontSize: 12.5, color: Derived.textMedium }}>Motchi</span>
      </div>
      <div style={{ height: 12 }} />
      <StreamingPlaceholder />
    </div>
  );
}

export function MessageBubble({
  text,
  isUser,
  timestamp,
  isStreaming = false,
  reasoning,
  imageUrls = [],
  onUseAsDraft,
  showArtifacts = true,
  keepFullText = false,
}: {
  text: string;
  isUser: boolean;
  timestamp?: Date;
  isStreaming?: boolean;
  reasoning?: string | null;
  imageUrls?: string[];
  onUseAsDraft?: () => void;
  showArtifacts?: boolean;
  keepFullText?: boolean;
}) {
  const { width } = useViewport();
  const [showReasoning, setShowReasoning] = useState(true);
  const [speaking, setSpeaking] = useState(false);

  useEffect(() => {
    return () => {
      if (speaking) WebTts.stop();
    };
  }, [speaking]);

  const bubbleText = isUser ? text : text.trimStart();
  const cleanText = isUser
    ? bubbleText
    : isStreaming
      ? stripStreamingArtifacts(bubbleText)
      : stripArtifactBlocks(bubbleText, !keepFullText);
  const artifacts = isUser ? null : parseStudyArtifacts(bubbleText);
  const displayText = isUser ? text : stripMarkdown(cleanText);
  const hasReasoning = Boolean(reasoning);

  const now = new Date();
  const isToday =
    timestamp != null &&
    now.getDate() === timestamp.getDate() &&
    now.getMonth() === timestamp.getMonth() &&
    now.getFullYear() === timestamp.getFullYear();
  const timeStr = timestamp ? timestamp.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }) : '';
  const fullDateStr = timestamp ? `${timestamp.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}, ${timeStr}` : '';

  const toggleSpeak = () => {
    if (speaking) {
      WebTts.stop();
      setSpeaking(false);
    } else {
      setSpeaking(true);
      WebTts.speak(displayText, { onComplete: () => setSpeaking(false) });
    }
  };

  return (
    <div style={{ padding: '20px 0', display: 'flex', justifyContent: isUser ? 'flex-end' : 'flex-start' }}>
      <div
        style={{
          maxWidth: width * (isUser ? 0.85 : 1),
          width: isUser ? undefined : '100%',
          padding: isUser ? '12px 16px' : 0,
          background: isUser ? Derived.glassSoft : undefined,
          borderRadius: isUser ? AppRadius.lg : undefined,
          display: 'flex',
          flexDirection: 'column',
          alignItems: isUser ? 'flex-end' : 'flex-start',
        }}
      >
        {!isUser && (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <MotchiPageAvatar size={20} />
              <span style={{ fontFamily: Fonts.reading, fontSize: 12.5, color: Derived.textMedium }}>Motchi</span>
            </div>
            <div style={{ height: 10 }} />
          </>
        )}

        {hasReasoning && (
          <div
            style={{
              width: '100%',
              marginBottom: 12,
              background: Derived.glassSoft,
              borderRadius: AppRadius.md,
              border: `1px solid ${Derived.border}`,
              overflow: 'hidden',
            }}
          >
            <button
              type="button"
              className="bare-button"
              aria-expanded={showReasoning}
              onClick={() => setShowReasoning((v) => !v)}
              style={{
                width: '100%',
                minHeight: 48,
                padding: '0 12px',
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                color: Derived.textHigh,
              }}
            >
              <Icon name="psychology_outlined" size={18} color={AppColors.softLavender} />
              <span style={{ flex: 1, textAlign: 'left', ...AppTypography.bodySmall, fontSize: 13, fontWeight: 600 }}>
                Motchi&apos;s thoughts{isStreaming ? '…' : ''}
              </span>
              <span
                style={{
                  display: 'flex',
                  transform: `rotate(${showReasoning ? 180 : 0}deg)`,
                  transition: `transform ${orZero(160)}ms ease`,
                }}
              >
                <Icon name="expand_more" size={18} color={Derived.textHigh} />
              </span>
            </button>
            {showReasoning && (
              <div
                style={{
                  padding: '0 12px 12px',
                  ...AppTypography.bodySmall,
                  fontSize: 13,
                  color: Derived.textMedium,
                  lineHeight: 1.5,
                  whiteSpace: 'pre-wrap',
                }}
              >
                {reasoning}
              </div>
            )}
          </div>
        )}

        {imageUrls.length > 0 && (
          <div style={{ marginTop: 8, marginBottom: text ? 8 : 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {imageUrls.map((url, idx) => (
              <img
                key={`${idx}_${url.slice(0, 24)}`}
                src={url}
                alt="Attached"
                style={{ width: 180, height: 180, objectFit: 'cover', borderRadius: AppRadius.md, display: 'block' }}
              />
            ))}
          </div>
        )}

        {isUser ? (
          <div
            style={{
              fontFamily: Fonts.reading,
              fontWeight: 400,
              fontSize: 15.5,
              lineHeight: lineHeight(15.5, 1.55),
              color: AppColors.petalWhite,
              whiteSpace: 'pre-wrap',
              overflowWrap: 'anywhere',
              userSelect: 'text',
            }}
          >
            {text}
          </div>
        ) : isStreaming && cleanText === '' ? (
          <StreamingPlaceholder />
        ) : (
          <div style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
            {!isStreaming && showArtifacts && artifacts && !artifactsEmpty(artifacts) && (
              <div style={{ width: '100%' }}>
                <StudyArtifactEntry artifacts={artifacts} />
              </div>
            )}
            <EverglowMarkdown
              text={cleanText}
              plain
              baseStyle={{
                fontFamily: Fonts.reading,
                fontWeight: 400,
                fontSize: 16,
                lineHeight: lineHeight(16, 1.65),
                color: Derived.textHigh,
              }}
            />
            {isStreaming && cleanText !== '' && (
              <div style={{ paddingTop: 8, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 3, height: 14, borderRadius: 1.5, background: AppColors.blushGold }} />
              </div>
            )}
          </div>
        )}

        {!isUser && !isStreaming && (
          <div style={{ width: '100%', paddingTop: 8, display: 'flex', alignItems: 'center' }}>
            {displayText.trim() !== '' && (
              <>
                <MaterialIconButton
                  icon="copy"
                  size={17}
                  tooltip="Copy message"
                  color={Derived.textMuted}
                  onPressed={() => copyText(displayText)}
                />
                {WebTts.isSupported && (
                  <MaterialIconButton
                    icon={speaking ? 'stop_circle_outlined' : 'volume_up_outlined'}
                    size={19}
                    tooltip={speaking ? 'Stop speaking' : 'Listen to Motchi'}
                    color={speaking ? AppColors.roseQuartz : Derived.textMuted}
                    onPressed={toggleSpeak}
                  />
                )}
              </>
            )}
            <div style={{ flex: 1 }} />
            {timestamp && (
              <span style={{ ...AppTypography.bodySmall, fontSize: 12, color: Derived.textDisabled }}>
                {isToday ? timeStr : fullDateStr}
              </span>
            )}
          </div>
        )}

        {isUser && !isStreaming && (
          <div style={{ paddingTop: 6, display: 'flex', alignItems: 'center' }}>
            <MaterialIconButton
              icon="copy"
              size={16}
              tooltip="Copy your message"
              color={Derived.textMuted}
              onPressed={() => copyText(displayText)}
            />
            {onUseAsDraft && (
              <MaterialIconButton
                icon="edit_note"
                size={20}
                tooltip="Use as draft"
                color={Derived.textMuted}
                onPressed={onUseAsDraft}
              />
            )}
            {timestamp && (
              <span
                className="ellipsis"
                style={{ ...AppTypography.bodySmall, fontSize: 12, fontWeight: 400, color: Derived.textMuted }}
              >
                {isToday ? timeStr : fullDateStr}
              </span>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export function ErrorBanner({ lastSentMessage, onRetry }: { lastSentMessage: string | null; onRetry: () => void }) {
  const ai = useAIChat();
  if (!ai.lastError || !lastSentMessage) return null;
  const tooLarge = ai.lastError.includes('too large') || ai.lastError.includes('413');
  return (
    <div
      style={{
        margin: '4px 16px',
        padding: '10px 14px',
        background: withAlpha(AppColors.deepRose, 0.15),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.deepRose, 0.3)}`,
        display: 'flex',
        alignItems: 'center',
        gap: 10,
      }}
    >
      <Icon name="error_outline" size={18} color={AppColors.deepRose} />
      <span style={{ flex: 1, ...AppTypography.bodySmall, color: Derived.textMedium }}>
        {tooLarge ? ai.lastError : 'Motchi got distracted. Try again?'}
      </span>
      <button
        type="button"
        className="bare-button"
        disabled={ai.isLoading}
        onClick={onRetry}
        style={{
          minWidth: 64,
          height: 48,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          ...AppTypography.labelLarge,
          color: AppColors.petalWhite,
        }}
      >
        Retry
      </button>
    </div>
  );
}

const THINK_OPTIONS: Array<[DeepThinkMode, string, string]> = [
  ['auto', 'Auto', 'Let Motchi choose how much to think'],
  ['on', 'Deep', 'Take more time for tricky questions'],
  ['off', 'Fast', 'Keep replies quick and simple'],
];

export function ComposerInput({
  enabled = true,
  text,
  onTextChange,
  inputRef,
  onSend,
  onStop,
  onPickImages,
  attachedImages = [],
  onRemoveImage,
  centered = false,
  deepThinkMode,
  onSelectDeepThink,
  canvasEnabled = false,
  onToggleCanvas,
}: {
  enabled?: boolean;
  text: string;
  onTextChange: (value: string) => void;
  inputRef: React.RefObject<HTMLTextAreaElement | null>;
  onSend: () => void;
  onStop: () => void;
  onPickImages: () => void;
  attachedImages?: string[];
  onRemoveImage: (index: number) => void;
  centered?: boolean;
  deepThinkMode: DeepThinkMode;
  onSelectDeepThink: (mode: DeepThinkMode) => void;
  canvasEnabled?: boolean;
  onToggleCanvas?: () => void;
}) {
  const ai = useAIChat();
  const [focused, setFocused] = useState(false);
  const [addMenuOpen, setAddMenuOpen] = useState(false);
  const [thinkMenuOpen, setThinkMenuOpen] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [voiceLevels, setVoiceLevels] = useState<number[]>(() => Array(25).fill(0));
  const bridgeRef = useRef<MotchiWebBridge | null>(null);
  if (!bridgeRef.current) bridgeRef.current = new MotchiWebBridge();

  useEffect(() => {
    const bridge = bridgeRef.current;
    return () => bridge?.cancelRecognition();
  }, []);

  useEffect(() => {
    const el = inputRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 144)}px`;
  }, [inputRef, text]);

  const startVoice = async () => {
    const bridge = bridgeRef.current!;
    if (isListening) {
      bridge.stopRecognition();
      return;
    }
    if (!bridge.isSpeechSupported) {
      inputRef.current?.focus();
      showSnackBar('Use the microphone on your keyboard to dictate.');
      return;
    }
    const prefix = text;
    const updateDraft = (words: string) => {
      const next = words === '' ? prefix : prefix === '' ? words : `${prefix} ${words}`;
      onTextChange(next);
    };
    inputRef.current?.blur();
    setVoiceLevels(Array(25).fill(0));
    setIsListening(true);
    try {
      const result = await bridge.recognizeOnce({
        onTranscript: updateDraft,
        onAudioLevel: (level) => setVoiceLevels((prev) => [...prev.slice(1), level]),
      });
      if (result && result.trim()) {
        updateDraft(result.trim());
      } else {
        onTextChange(prefix);
        showSnackBar('No speech caught. Try again or use keyboard dictation.');
      }
    } catch (e) {
      Logger.e('Motchi voice input failed', e);
      onTextChange(prefix);
      const msg = e instanceof Error ? e.message : '';
      const denied = msg === 'not-allowed' || msg === 'service-not-allowed';
      showSnackBar(
        denied
          ? 'Allow microphone and speech access, then try again. Keyboard dictation works too.'
          : 'Speech input is unavailable here. Try Safari with Siri enabled, or use keyboard dictation.',
      );
    } finally {
      setIsListening(false);
    }
  };

  const hasText = text.trim().length > 0;
  const canSend = enabled && !isListening && (hasText || attachedImages.length > 0);
  const thinkLabel = deepThinkMode === 'auto' ? 'Auto' : deepThinkMode === 'on' ? 'Deep' : 'Fast';

  return (
    <div style={{ width: '100%', maxWidth: 752, margin: '0 auto', padding: '8px 16px 14px', boxSizing: 'border-box' }}>
      {attachedImages.length > 0 && (
        <div className="no-scrollbar" style={{ height: 76, display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 4 }}>
          {attachedImages.map((src, i) => (
            <div key={i} style={{ position: 'relative', width: 64, height: 64, flexShrink: 0 }}>
              <img
                src={src}
                alt="Attachment"
                style={{ width: 64, height: 64, borderRadius: AppRadius.md, objectFit: 'cover', display: 'block' }}
              />
              <button
                type="button"
                className="bare-button"
                aria-label="Remove image"
                onClick={() => onRemoveImage(i)}
                style={{
                  position: 'absolute',
                  top: 0,
                  right: 0,
                  width: 24,
                  height: 24,
                  borderRadius: '50%',
                  background: AppColors.inkDeep,
                  color: AppColors.petalWhite,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="close" size={16} color={AppColors.petalWhite} />
              </button>
            </div>
          ))}
        </div>
      )}

      <div
        style={{
          background: AppColors.silk,
          borderRadius: AppRadius.lg,
          border: `1px solid ${focused ? withAlpha(AppColors.roseQuartz, 0.45) : withAlpha(AppColors.moonlight, 0.12)}`,
          transition: `border-color ${orZero(160)}ms ease`,
        }}
      >
        <textarea
          ref={inputRef}
          value={text}
          disabled={!enabled}
          readOnly={isListening}
          rows={1}
          placeholder="Message Motchi…"
          className="money-input"
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onChange={(e) => onTextChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing && !ai.isLoading && !isListening && canSend) {
              e.preventDefault();
              onSend();
            }
          }}
          style={{
            width: '100%',
            background: 'transparent',
            border: 'none',
            outline: 'none',
            resize: 'none',
            padding: '16px 16px 4px',
            boxSizing: 'border-box',
            fontFamily: Fonts.reading,
            fontWeight: 400,
            fontSize: 16,
            lineHeight: 1.5,
            letterSpacing: 0.5,
            color: AppColors.petalWhite,
            caretColor: AppColors.roseQuartz,
            ['--hint-color' as string]: Derived.textMuted,
            ['--hint-size' as string]: '16px',
            maxHeight: 144,
          }}
        />
        {isListening && <MotchiVoiceWaveform levels={voiceLevels} />}
        <div style={{ padding: '2px 8px 8px 6px', display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', flexWrap: 'wrap' }}>
            {/* Add menu */}
            <div style={{ position: 'relative' }}>
              <MaterialIconButton
                icon="add"
                size={22}
                tooltip="Add to message"
                color={Derived.textMuted}
                onPressed={enabled ? () => setAddMenuOpen((v) => !v) : undefined}
              />
              {addMenuOpen && (
                <>
                  <div onClick={() => setAddMenuOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 999 }} />
                  <div
                    style={{
                      position: 'absolute',
                      left: 0,
                      bottom: 48,
                      minWidth: 185,
                      padding: 6,
                      borderRadius: AppRadius.lg,
                      background: AppColors.silk,
                      border: `1px solid ${Derived.border}`,
                      boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
                      zIndex: 1000,
                      display: 'flex',
                      flexDirection: 'column',
                    }}
                  >
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => {
                        setAddMenuOpen(false);
                        onPickImages();
                      }}
                      style={{
                        padding: '10px 12px',
                        borderRadius: AppRadius.sm,
                        ...AppTypography.bodyMedium,
                        textAlign: 'left',
                      }}
                    >
                      Attach images
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => {
                        setAddMenuOpen(false);
                        onToggleCanvas?.();
                      }}
                      style={{
                        padding: '10px 12px',
                        borderRadius: AppRadius.sm,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8,
                      }}
                    >
                      <Icon
                        name="dashboard_customize_outlined"
                        size={18}
                        color={canvasEnabled ? AppColors.roseQuartz : Derived.textMuted}
                      />
                      <span style={{ flex: 1, ...AppTypography.bodyMedium, textAlign: 'left' }}>Canvas</span>
                      <span
                        style={{
                          ...AppTypography.labelSmall,
                          color: canvasEnabled ? AppColors.roseQuartz : Derived.textMuted,
                        }}
                      >
                        {canvasEnabled ? 'On' : 'Off'}
                      </span>
                      <Icon
                        name={canvasEnabled ? 'toggle_on' : 'toggle_off'}
                        size={24}
                        color={canvasEnabled ? AppColors.roseQuartz : Derived.textMuted}
                      />
                    </button>
                  </div>
                </>
              )}
            </div>

            {/* DeepThink pill */}
            <div style={{ position: 'relative' }}>
              <Tooltip message={`Reply mode: ${thinkLabel}`}>
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => setThinkMenuOpen((v) => !v)}
                  style={{
                    minWidth: 64,
                    minHeight: 48,
                    padding: '0 10px',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                    fontFamily: Fonts.reading,
                    fontSize: 12.5,
                    fontWeight: 500,
                    color: deepThinkMode === 'on' ? AppColors.roseQuartz : Derived.textMuted,
                  }}
                >
                  <span>{thinkLabel}</span>
                  <Icon name="expand_more" size={16} color={Derived.textMuted} />
                </button>
              </Tooltip>
              {thinkMenuOpen && (
                <>
                  <div onClick={() => setThinkMenuOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 999 }} />
                  <div
                    style={{
                      position: 'absolute',
                      left: 0,
                      bottom: 48,
                      minWidth: 260,
                      padding: 6,
                      borderRadius: AppRadius.lg,
                      background: AppColors.silk,
                      border: `1px solid ${Derived.border}`,
                      boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
                      zIndex: 1000,
                      display: 'flex',
                      flexDirection: 'column',
                    }}
                  >
                    {THINK_OPTIONS.map(([mode, title, desc]) => (
                      <button
                        key={mode}
                        type="button"
                        className="bare-button"
                        onClick={() => {
                          setThinkMenuOpen(false);
                          onSelectDeepThink(mode);
                        }}
                        style={{
                          padding: '10px 12px',
                          borderRadius: AppRadius.sm,
                          display: 'flex',
                          alignItems: 'center',
                          gap: 12,
                          textAlign: 'left',
                        }}
                      >
                        <Icon
                          name={mode === deepThinkMode ? 'check' : 'remove'}
                          size={18}
                          color={mode === deepThinkMode ? AppColors.roseQuartz : Derived.textMuted}
                        />
                        <div style={{ flex: 1 }}>
                          <div style={{ ...AppTypography.bodyMedium }}>{title}</div>
                          <div style={{ ...AppTypography.bodySmall }}>{desc}</div>
                        </div>
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>

            {canvasEnabled && (
              <MaterialIconButton
                icon="dashboard_customize_outlined"
                size={19}
                tooltip="Canvas: on — tap to turn off"
                color={AppColors.roseQuartz}
                onPressed={onToggleCanvas}
              />
            )}
          </div>

          {!ai.isLoading && (
            <MaterialIconButton
              icon={isListening ? 'stop_circle_outlined' : 'mic_none'}
              size={24}
              tooltip={isListening ? 'Stop voice input' : 'Dictate message'}
              color={isListening ? AppColors.roseQuartz : Derived.textMuted}
              onPressed={enabled ? () => void startVoice() : undefined}
            />
          )}

          <Tooltip message={ai.isLoading ? 'Stop generating' : 'Send message'}>
            <div
              style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
            >
              <button
                type="button"
                className="bare-button"
                aria-label={ai.isLoading ? 'Stop generating' : 'Send message'}
                disabled={!ai.isLoading && !canSend}
                onClick={ai.isLoading ? onStop : onSend}
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: AppRadius.md,
                  background: ai.isLoading || canSend ? AppColors.roseQuartz : Derived.glassSoft,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: ai.isLoading || canSend ? 'pointer' : 'default',
                  flexShrink: 0,
                }}
              >
                <Icon
                  name={ai.isLoading ? 'stop' : 'arrow_upward'}
                  size={21}
                  color={ai.isLoading || canSend ? AppColors.inkDeep : Derived.textDisabled}
                />
              </button>
            </div>
          </Tooltip>
        </div>
      </div>

      {centered && (
        <div style={{ paddingTop: 10, textAlign: 'center', ...AppTypography.bodySmall, color: Derived.textDisabled }}>
          Enter to send · Shift + Enter for a new line
        </div>
      )}
    </div>
  );
}
