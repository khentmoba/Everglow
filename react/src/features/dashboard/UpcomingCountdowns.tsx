// Port of lib/features/dashboard/presentation/widgets/upcoming_countdowns.dart
// + upcoming_countdowns_cards.dart + upcoming_countdowns_footer.dart.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, letterSpacing, linear, radial, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import {
  CALENDAR_TYPE_EMOJI,
  calendarEventHue,
  calendarService,
  type CalendarEvent,
} from '../calendar/calendarService';
import { FeatureSection, SectionChevron, SectionPillLink } from './FeatureSection';

const DAYS_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const formatEventDate = (d: Date) => `${DAYS_SHORT[d.getDay()]}, ${MONTHS_SHORT[d.getMonth()]} ${d.getDate()}`;

export function UpcomingCountdowns() {
  const navigate = useNavigate();
  const [events, setEvents] = useState<CalendarEvent[] | null>(() => calendarService.cachedUpcoming);
  const [loading, setLoading] = useState(() => calendarService.cachedUpcoming == null);
  const [hasError, setHasError] = useState(false);
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    let retries = 0;
    let timer = 0;
    let unsub: (() => void) | null = null;
    const subscribe = () => {
      unsub?.();
      unsub = calendarService.getUpcomingEvents(60)({
        data: (list) => {
          if (cancelled) return;
          retries = 0;
          setEvents(list);
          setLoading(false);
          setHasError(false);
        },
        error: () => {
          if (cancelled) return;
          if (retries < 3) {
            retries++;
            timer = window.setTimeout(subscribe, (1 + retries) * 1000);
          } else {
            setLoading(false);
            setHasError(true);
          }
        },
      });
    };
    subscribe();
    return () => {
      cancelled = true;
      clearTimeout(timer);
      unsub?.();
    };
  }, [retryKey]);

  const link = <SectionPillLink label="Calendar" hue={AppColors.warmAmber} onTap={() => navigate('/calendar')} />;

  if (!loading && (hasError || events == null)) {
    return (
      <div style={{ padding: '6px 0' }}>
        <FeatureSection
          icon="event"
          hue={AppColors.warmAmber}
          title="Coming Up"
          subtitle="could not load dates"
          trailing={link}
          onTap={() => navigate('/calendar')}
        >
          <button
            type="button"
            className="bare-button"
            onClick={(e) => {
              e.stopPropagation();
              setLoading(true);
              setHasError(false);
              setRetryKey((k) => k + 1);
            }}
            style={{ width: '100%', display: 'flex', alignItems: 'center' }}
          >
            <Icon name="refresh" size={18} color={AppColors.warmAmber} />
            <div style={{ width: 10 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6), flex: 1 }}>
              Could not load upcoming dates — tap here to retry.
            </span>
            <SectionChevron hue={AppColors.warmAmber} />
          </button>
        </FeatureSection>
      </div>
    );
  }

  if (events == null) {
    return (
      <div style={{ padding: '6px 0' }}>
        <FeatureSection
          icon="event"
          hue={AppColors.warmAmber}
          title="Coming Up"
          subtitle="loading dates…"
          trailing={link}
          onTap={() => navigate('/calendar')}
        >
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <CircularProgress size={16} strokeWidth={2} color={AppColors.warmAmber} />
            <div style={{ width: 10 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6) }}>
              Loading upcoming dates…
            </span>
          </div>
        </FeatureSection>
      </div>
    );
  }

  const upcoming = events.slice(0, 6);
  return (
    <div style={{ padding: '6px 0' }}>
      <FeatureSection
        icon="event"
        hue={AppColors.warmAmber}
        title="Coming Up"
        subtitle={
          upcoming.length === 0
            ? 'no plans in the next 60 days'
            : `${upcoming.length} ${upcoming.length === 1 ? 'date' : 'dates'} on the horizon`
        }
        trailing={link}
        onTap={() => navigate('/calendar')}
      >
        {upcoming.length === 0 ? (
          <EmptyDatesCta />
        ) : (
          <div className="no-scrollbar" style={{ overflowX: 'auto', height: 210 }}>
            <div style={{ display: 'flex', height: '100%', gap: 12, width: 'max-content' }}>
              {upcoming.map((ev) => (
                <CountdownEventCard key={ev.id + ev.date.toISOString()} event={ev} />
              ))}
            </div>
          </div>
        )}
      </FeatureSection>
    </div>
  );
}

function EmptyDatesCta() {
  return (
    <div
      style={{
        padding: 14,
        borderRadius: 18,
        border: `1px solid ${withAlpha(AppColors.warmAmber, 0.25)}`,
        background: linear([withAlpha(AppColors.warmAmber, 0.14), withAlpha(AppColors.warmAmber, 0.04), AppColors.transparent], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          width: 54,
          height: 54,
          borderRadius: 16,
          background: linear([AppColors.auroraGold, AppColors.warmAmber], { begin: Align.topLeft, end: Align.bottomRight, size: [54, 54] }),
          boxShadow: `0 4px 10px ${withAlpha(AppColors.warmAmber, 0.35)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="calendar_month" size={26} color={AppColors.inkDeep} />
      </div>
      <div style={{ width: 14 }} />
      <div style={{ flex: 1 }}>
        <div style={{ ...AppTypography.cormorantBold, fontSize: 17 }}>Nothing on the horizon</div>
        <div style={{ height: 2 }} />
        <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6) }}>
          Plan the next date together ♥
        </div>
      </div>
      <SectionChevron hue={AppColors.warmAmber} />
    </div>
  );
}

function CountdownEventCard({ event }: { event: CalendarEvent }) {
  const [hovered, setHovered] = useState(false);
  const [now, setNow] = useState(() => new Date());
  const hue = calendarEventHue(event.type);
  const emoji = CALENDAR_TYPE_EMOJI[event.type] ?? '📌';

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 60_000);
    return () => clearInterval(id);
  }, []);

  const diffMs = Math.max(0, event.date.getTime() - now.getTime());
  const days = Math.floor(diffMs / 86_400_000);
  const hours = Math.floor(diffMs / 3_600_000) % 24;
  const minutes = Math.floor(diffMs / 60_000) % 60;
  const totalHours = Math.floor(diffMs / 3_600_000);
  const isImminent = totalHours >= 0 && totalHours < 48;
  const urgencyLabel = totalHours < 24 ? (totalHours < 1 ? 'NOW' : 'TODAY') : days === 1 ? 'TOMORROW' : null;
  const fraction = Math.max(0, Math.min(1, 1 - diffMs / (60 * 86_400_000)));
  const isSoon = days <= 1;
  const footerLabel =
    days === 0
      ? totalHours === 0
        ? `${Math.floor(diffMs / 60_000)}m to go`
        : `${totalHours}h to go`
      : `${days} ${days === 1 ? 'day' : 'days'} to go`;

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        position: 'relative',
        width: 268,
        height: '100%',
        transform: hovered ? 'translateY(-4px)' : undefined,
        transition: 'transform 160ms cubic-bezier(0.23, 1, 0.32, 1)',
      }}
    >
      <div style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.5), blur: 20, offset: [0, 10] }, { radius: AppRadius.xl })} aria-hidden />
      <div
        style={shadowLayer({ color: withAlpha(hue, hovered ? 0.22 : 0.14), blur: 24, offset: [0, 6] }, { radius: AppRadius.xl })}
        aria-hidden
      />
      <div
        style={{
          position: 'relative',
          width: 268,
          height: '100%',
          overflow: 'hidden',
          borderRadius: AppRadius.xl,
          border: `1px solid ${withAlpha(hue, hovered ? 0.55 : 0.28)}`,
          background: linear(
            [withAlpha(hue, 0.24), withAlpha(AppColors.velvet, 0.92), withAlpha(AppColors.inkDeep, 0.96)],
            { begin: Align.topLeft, end: Align.bottomRight, stops: [0, 0.52, 1], size: [268, 210] },
          ),
        }}
      >
        <div
          style={{
            position: 'absolute',
            right: -18,
            top: -18,
            width: 110,
            height: 110,
            borderRadius: '50%',
            background: radial([withAlpha(hue, 0.22), AppColors.transparent], { size: [110, 110] }),
            pointerEvents: 'none',
          }}
        />
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 0,
            height: 1.2,
            background: linear([AppColors.transparent, withAlpha(hue, 0.65), AppColors.transparent]),
          }}
        />
        <div
          style={{
            position: 'absolute',
            right: 8,
            bottom: 28,
            ...AppTypography.cormorantBlackWhite,
            fontSize: 78,
            lineHeight: 1,
            letterSpacing: -4,
            color: withAlpha(AppColors.petalWhite, 0.045),
            pointerEvents: 'none',
          }}
        >
          {days}
        </div>
        {isImminent && urgencyLabel && (
          <div
            style={{
              position: 'absolute',
              top: 12,
              right: 12,
              padding: '3px 7px',
              borderRadius: 999,
              background: linear([hue, AppColors.blushGold]),
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
            }}
          >
            <div style={{ width: 5, height: 5, borderRadius: '50%', background: AppColors.petalWhite }} />
            <span style={{ ...AppTypography.outfitHeading, fontSize: 8, ...letterSpacing(1), color: AppColors.inkDeep }}>
              {urgencyLabel}
            </span>
          </div>
        )}

        <div style={{ position: 'relative', height: '100%', padding: '14px 14px 12px', display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', alignItems: 'flex-start' }}>
            <div
              style={{
                width: 44,
                height: 44,
                borderRadius: AppRadius.md,
                background: linear([withAlpha(hue, 0.32), withAlpha(hue, 0.08)], { begin: Align.topLeft, end: Align.bottomRight, size: [44, 44] }),
                border: `1px solid ${withAlpha(hue, 0.42)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 19,
                flexShrink: 0,
              }}
            >
              {emoji}
            </div>
            <div style={{ width: 11 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div
                style={{
                  ...AppTypography.outfitHeading,
                  fontSize: 13,
                  ...letterSpacing(0.7),
                  lineHeight: 1.1,
                  color: AppColors.petalWhite,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {event.title.toUpperCase()}
              </div>
              <div style={{ height: 5 }} />
              <div
                style={{
                  padding: '3px 7px',
                  background: withAlpha(AppColors.petalWhite, 0.08),
                  borderRadius: 999,
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
                  display: 'inline-flex',
                  alignItems: 'center',
                  maxWidth: '100%',
                }}
              >
                <Icon name="calendar_today" size={10} color={withAlpha(hue, 0.9)} />
                <div style={{ width: 5 }} />
                <span style={{ ...AppTypography.outfitBold, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.78), whiteSpace: 'nowrap' }}>
                  {formatEventDate(event.date)}
                </span>
                {event.type === 'anniversary' && (
                  <>
                    <div style={{ width: 5 }} />
                    <div style={{ width: 3, height: 3, borderRadius: '50%', background: hue }} />
                    <div style={{ width: 5 }} />
                    <span style={{ ...AppTypography.outfitBold, fontSize: 7.5, ...letterSpacing(0.8), color: withAlpha(hue, 0.85) }}>
                      ANNIVERSARY
                    </span>
                  </>
                )}
              </div>
            </div>
          </div>

          <div style={{ height: 14 }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <TimeCapsule value={days} label="days" hue={hue} emphasized />
            <TimeCapsule value={hours} label="hrs" hue={hue} />
            <TimeCapsule value={minutes} label="min" hue={hue} />
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ height: 1, borderTop: `1px dashed ${withAlpha(AppColors.moonlight, 0.14)}` }} />
          <div style={{ height: 10 }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ flex: 1, position: 'relative', height: 5, borderRadius: 999, background: withAlpha(AppColors.moonlight, 0.1) }}>
              <div
                style={{
                  width: `${(fraction * 100).toFixed(1)}%`,
                  height: 5,
                  borderRadius: 999,
                  background: linear(isSoon ? [hue, AppColors.auroraRose] : [hue, AppColors.blushGold]),
                }}
              />
            </div>
            <div
              style={{
                padding: '3.5px 8px',
                borderRadius: 999,
                background: withAlpha(hue, isSoon ? 0.16 : 0.1),
                border: `1px solid ${withAlpha(hue, 0.22)}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 4,
              }}
            >
              <Icon name={isSoon ? 'bolt' : 'hourglass_bottom'} size={11} color={isSoon ? hue : withAlpha(hue, 0.9)} />
              <span style={{ ...AppTypography.outfitBold, fontSize: 10, color: isSoon ? hue : withAlpha(hue, 0.95) }}>
                {footerLabel}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function TimeCapsule({
  value,
  label,
  hue,
  emphasized = false,
}: {
  value: number;
  label: string;
  hue: string;
  emphasized?: boolean;
}) {
  return (
    <div
      style={{
        flex: 1,
        padding: '8px 0',
        borderRadius: 12,
        background: emphasized ? withAlpha(AppColors.petalWhite, 0.08) : withAlpha(hue, 0.1),
        border: `1px solid ${emphasized ? withAlpha(AppColors.petalWhite, 0.14) : withAlpha(hue, 0.22)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <span
        style={{
          ...AppTypography.outfitHeading,
          fontSize: emphasized ? 17 : 15.5,
          lineHeight: 1,
          letterSpacing: -0.5,
          color: emphasized ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.92),
        }}
      >
        {String(value).padStart(2, '0')}
      </span>
      <div style={{ height: 2 }} />
      <span
        style={{
          ...AppTypography.outfitBold,
          fontSize: 7.5,
          ...letterSpacing(1.3),
          color: emphasized ? AppColors.blushGold : withAlpha(hue, 0.85),
        }}
      >
        {label.toUpperCase()}
      </span>
    </div>
  );
}
