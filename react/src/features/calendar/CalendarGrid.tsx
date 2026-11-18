// Port of lib/features/calendar/presentation/widgets/calendar_grid.dart.
import { useState } from 'react';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { boxShadow, insetBorder, letterSpacing, lineHeight, linear, shadowLayer, sigma } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { calendarEventHue, type CalendarEvent } from './calendarService';
import { dayMonth, longDate, monthYear, roseGold, sameDay } from './calendarUi';

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const fast = `${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}`;

export function CalendarGrid({
  month,
  events,
  selectedDay,
  onDaySelected,
  onMonthChanged,
}: {
  month: Date;
  events: CalendarEvent[];
  selectedDay: Date | null;
  onDaySelected: (d: Date) => void;
  onMonthChanged: (m: Date) => void;
}) {
  const [hoveredDay, setHoveredDay] = useState<number | null>(null);
  const [cardRef, cardSize] = useBoxSize<HTMLDivElement>();
  const year = month.getFullYear();
  const m = month.getMonth();
  const daysInMonth = new Date(year, m + 1, 0).getDate();
  const leading = (new Date(year, m, 1).getDay() + 6) % 7;
  const rows = Math.ceil((leading + daysInMonth) / 7);
  const now = new Date();
  const isCurrentMonth = year === now.getFullYear() && m === now.getMonth();
  const eventsFor = (d: Date) => events.filter((e) => sameDay(e.date, d));
  const go = (next: Date) => {
    setHoveredDay(null);
    onMonthChanged(next);
  };
  const count = events.length;

  const sel = selectedDay;
  const selEvents = sel ? eventsFor(sel) : [];

  return (
    <div style={{ padding: '0 16px', flexShrink: 0 }}>
      <div ref={cardRef} style={{ position: 'relative', borderRadius: 24 }}>
        <div style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.55), blur: 26, offset: [0, 12] }, { radius: 24 })} />
        <div style={shadowLayer({ color: withAlpha(AppColors.blushGold, 0.07), blur: 28, offset: [0, -6] }, { radius: 24 })} />
        <div
          style={{
            position: 'relative',
            borderRadius: 24,
            background: linear(
              [withAlpha(AppColors.plum, 0.72), withAlpha(AppColors.silk, 0.72), withAlpha(AppColors.inkDeep, 0.88)],
              { begin: [-1, -1], end: [1, 1], size: cardSize },
            ),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.24)}`,
          }}
        >
          {/* Stack clips its positioned children to the box inside the border. */}
          <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
            <div style={{ position: 'absolute', top: -14, right: -10 }}>
              <Icon name="favorite" size={118} color={withAlpha(AppColors.auroraRose, 0.07)} />
            </div>
            <div style={{ position: 'absolute', top: 18, left: 14 }}>
              <Icon name="auto_awesome" size={22} color={withAlpha(AppColors.blushGold, 0.16)} />
            </div>
          </div>
          <div style={{ position: 'relative', padding: '14px 10px 10px' }}>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <NavButton icon="chevron_left" tooltip="Previous month" onTap={() => go(new Date(year, m - 1, 1))} />
              <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div
                  style={{
                    ...AppTypography.cormorantBold,
                    fontSize: 24,
                    lineHeight: '24px',
                    letterSpacing: 0.4,
                    color: AppColors.petalWhite,
                    textShadow: `0 0 ${(2 * sigma(14)).toFixed(2)}px ${withAlpha(AppColors.blushGold, 0.28)}`,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    maxWidth: '100%',
                  }}
                >
                  {monthYear(month)}
                </div>
                <div style={{ height: 7 }} />
                <div
                  onClick={isCurrentMonth ? undefined : () => go(new Date(now.getFullYear(), now.getMonth(), 1))}
                  style={{
                    padding: '4px 11px',
                    borderRadius: 999,
                    background: linear([withAlpha(AppColors.blushGold, 0.2), withAlpha(AppColors.auroraRose, 0.14)]),
                    border: `1px solid ${withAlpha(AppColors.blushGold, 0.36)}`,
                    boxShadow: boxShadow([{ color: withAlpha(AppColors.blushGold, 0.1), blur: 12 }]),
                    display: 'flex',
                    alignItems: 'center',
                    gap: 5,
                    cursor: isCurrentMonth ? undefined : 'pointer',
                  }}
                >
                  <Icon name={isCurrentMonth ? 'favorite' : 'today'} size={10} color={AppColors.blushGold} />
                  <span
                    style={{
                      ...AppTypography.outfitBold,
                      fontSize: 10.5,
                      lineHeight: lineHeight(10.5),
                      letterSpacing: 0.5,
                      color: AppColors.blushGold,
                    }}
                  >
                    {isCurrentMonth ? `${count} special ${count === 1 ? 'date' : 'dates'}` : 'Back to today'}
                  </span>
                </div>
              </div>
              <NavButton icon="chevron_right" tooltip="Next month" onTap={() => go(new Date(year, m + 1, 1))} />
            </div>
            <div style={{ height: 12 }} />
            <div style={{ display: 'flex' }}>
              {WEEKDAYS.map((w, i) => (
                <div key={w} style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
                  <span
                    style={{
                      ...AppTypography.outfitBold,
                      fontSize: 10,
                      lineHeight: lineHeight(10),
                      ...letterSpacing(1.6),
                      color: i >= 5 ? AppColors.auroraGold : withAlpha(AppColors.petalWhite, 0.62),
                    }}
                  >
                    {w.toUpperCase()}
                  </span>
                </div>
              ))}
            </div>
            <div style={{ height: 8 }} />
            <div
              style={{
                height: 1,
                margin: '0 6px',
                background: linear(['rgba(0,0,0,0)', withAlpha(AppColors.blushGold, 0.3), 'rgba(0,0,0,0)']),
              }}
            />
            <div style={{ height: 8 }} />
            {Array.from({ length: rows }, (_, r) => (
              <div key={r} style={{ display: 'flex' }}>
                {Array.from({ length: 7 }, (_, c) => {
                  const dayNumber = r * 7 + c - leading + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) return <div key={c} style={{ flex: 1, height: 52 }} />;
                  const day = new Date(year, m, dayNumber);
                  return (
                    <DayCell
                      key={c}
                      day={day}
                      events={eventsFor(day)}
                      isToday={sameDay(day, now)}
                      isSelected={sel != null && sameDay(day, sel)}
                      isHovered={hoveredDay === dayNumber}
                      isWeekend={c >= 5}
                      onHover={(h) => setHoveredDay(h ? dayNumber : null)}
                      onTap={() => onDaySelected(day)}
                    />
                  );
                })}
              </div>
            ))}
            <div style={{ height: 10 }} />
            <div
              onClick={sel ? () => onDaySelected(sel) : undefined}
              style={{
                padding: '8px 10px',
                borderRadius: 14,
                background: linear([withAlpha(AppColors.blushGold, 0.12), withAlpha(AppColors.auroraRose, 0.1)]),
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
                display: 'flex',
                alignItems: 'center',
                cursor: sel ? 'pointer' : undefined,
              }}
            >
              <div
                style={{
                  width: 26,
                  height: 26,
                  borderRadius: '50%',
                  background: withAlpha(AppColors.blushGold, 0.14),
                  border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
                  boxSizing: 'border-box',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                <Icon name={sel ? 'favorite' : 'touch_app'} size={13} color={AppColors.blushGold} />
              </div>
              <div style={{ width: 9 }} />
              <span
                style={{
                  flex: 1,
                  minWidth: 0,
                  ...AppTypography.outfitBold,
                  fontSize: 12,
                  lineHeight: lineHeight(12),
                  letterSpacing: 0.2,
                  color: withAlpha(AppColors.petalWhite, 0.85),
                }}
              >
                {sel ? dayMonth(sel) : 'Tap a day to see its details'}
              </span>
              {selEvents.length > 0 ? (
                <span
                  style={{
                    padding: '3px 9px',
                    borderRadius: 999,
                    background: linear([AppColors.auroraRose, AppColors.deepRose]),
                    boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.35), blur: 10 }]),
                    ...AppTypography.outfitBold,
                    fontSize: 10,
                    lineHeight: lineHeight(10),
                    color: AppColors.petalWhite,
                  }}
                >
                  {selEvents.length} event{selEvents.length === 1 ? '' : 's'} ♥
                </span>
              ) : (
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    fontSize: 10.5,
                    lineHeight: lineHeight(10.5),
                    fontStyle: 'italic',
                    color: withAlpha(AppColors.petalWhite, 0.45),
                  }}
                >
                  {sel ? 'no events yet' : ''}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function DayCell({
  day,
  events,
  isToday,
  isSelected,
  isHovered,
  isWeekend,
  onHover,
  onTap,
}: {
  day: Date;
  events: CalendarEvent[];
  isToday: boolean;
  isSelected: boolean;
  isHovered: boolean;
  isWeekend: boolean;
  onHover: (h: boolean) => void;
  onTap: () => void;
}) {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const label =
    events.length === 0 ? longDate(day) : `${longDate(day)}, ${events.length} ${events.length === 1 ? 'event' : 'events'}`;
  const fill = isSelected
    ? roseGold(size?.[0] ?? 1, size?.[1] ?? 1)
    : isToday
      ? withAlpha(AppColors.blushGold, 0.14)
      : isHovered
        ? withAlpha(AppColors.moonlight, 0.1)
        : events.length > 0
          ? withAlpha(AppColors.moonlight, 0.05)
          : 'transparent';
  const border = isSelected
    ? insetBorder(withAlpha(AppColors.petalWhite, 0.55), 1.2).boxShadow
    : isToday
      ? insetBorder(withAlpha(AppColors.blushGold, 0.7), 1.4).boxShadow
      : isHovered
        ? insetBorder(withAlpha(AppColors.moonlight, 0.24), 1).boxShadow
        : undefined;
  const glow = isSelected
    ? boxShadow([{ color: withAlpha(AppColors.deepRose, 0.5), blur: 18, spread: -2 }])
    : isToday
      ? boxShadow([{ color: withAlpha(AppColors.blushGold, 0.18), blur: 14 }])
      : undefined;
  return (
    <div style={{ flex: 1, minWidth: 0, padding: 3 }}>
      <div
        ref={ref}
        role="button"
        tabIndex={0}
        aria-label={label}
        aria-pressed={isSelected}
        onMouseEnter={() => onHover(true)}
        onMouseLeave={() => onHover(false)}
        onFocus={() => onHover(true)}
        onBlur={() => onHover(false)}
        onClick={onTap}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            onTap();
          }
        }}
        style={{
          height: 52,
          borderRadius: 14,
          background: fill,
          boxShadow: [border, glow].filter(Boolean).join(', ') || undefined,
          // AnimatedContainer's transform has no alignment: it scales from the top-left corner.
          transform: `scale(${isSelected ? 1.05 : 1})`,
          transformOrigin: '0 0',
          transition: `transform ${fast}, background-color ${fast}`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
          outline: 'none',
        }}
      >
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: isSelected ? 14.5 : 13.5,
            lineHeight: lineHeight(isSelected ? 14.5 : 13.5),
            fontWeight: isToday || isSelected ? 700 : 500,
            color: isSelected
              ? AppColors.petalWhite
              : isToday
                ? AppColors.blushGold
                : withAlpha(AppColors.petalWhite, isWeekend ? 0.92 : 0.74),
          }}
        >
          {day.getDate()}
        </span>
        <div style={{ height: 4 }} />
        {events.length > 0 ? (
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            {events.slice(0, 3).map((e, i) => (
              <div
                key={i}
                style={{
                  width: 6,
                  height: 6,
                  margin: '0 2px',
                  borderRadius: '50%',
                  background: isSelected ? AppColors.petalWhite : calendarEventHue(e.type),
                  boxShadow: boxShadow([{ color: withAlpha(calendarEventHue(e.type), 0.7), blur: 6 }]),
                }}
              />
            ))}
          </div>
        ) : isToday ? (
          <div style={{ width: 4, height: 4, borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.85) }} />
        ) : (
          <div style={{ height: 6 }} />
        )}
      </div>
    </div>
  );
}

function NavButton({ icon, tooltip, onTap }: { icon: string; tooltip: string; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <Tooltip message={tooltip}>
      <button
        type="button"
        className="bare-button"
        aria-label={tooltip}
        onClick={onTap}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          background: hovered
            ? linear([withAlpha(AppColors.blushGold, 0.28), withAlpha(AppColors.auroraRose, 0.2)])
            : withAlpha(AppColors.moonlight, 0.08),
          border: `1px solid ${hovered ? withAlpha(AppColors.blushGold, 0.6) : withAlpha(AppColors.moonlight, 0.22)}`,
          boxShadow: hovered ? boxShadow([{ color: withAlpha(AppColors.blushGold, 0.22), blur: 16, spread: -2 }]) : undefined,
          boxSizing: 'border-box',
          transition: `border-color ${fast}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name={icon} size={22} color={AppColors.blushGold} />
      </button>
    </Tooltip>
  );
}
