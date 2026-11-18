// Port of lib/features/calendar/presentation/screens/calendar_screen.dart.
import { useState } from 'react';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { boxShadow, insetBorder, letterSpacing, lineHeight, linear, mixedLineHeight, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { showDialog } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowSegmentedControl } from '../../shared/widgets/EverglowSegmentedControl';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { AddEventDialog } from './AddEventDialog';
import { CalendarGrid } from './CalendarGrid';
import { CALENDAR_TYPE_INFO, calendarEventHue, calendarService, type CalendarEvent } from './calendarService';
import { dayMonth, inDays, roseGold, shortDayMonth } from './calendarUi';
import { showDayDetailSheet } from './DayDetailSheet';
import { openAddPollDialog, PollsTab } from './PollsTab';

const fast = `${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}`;

export function CalendarPage() {
  const [selectedDay, setSelectedDay] = useState(() => new Date());
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [tab, setTab] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const monthEvents = useSource(
    () => calendarService.getEventsForMonth(month),
    [month.getTime(), refresh],
    [] as CalendarEvent[],
  );
  const upcoming = useSource(() => calendarService.getUpcomingEvents(60), [refresh], [] as CalendarEvent[]);

  const reload = () => setRefresh((r) => r + 1);
  const openDaySheet = (day: Date) => void showDayDetailSheet(day, { onEventAdded: reload });
  const onDaySelected = (day: Date) => {
    setSelectedDay(day);
    openDaySheet(day);
  };
  const openAddEvent = async () => {
    const saved = await showDialog<boolean>((pop) => <AddEventDialog selectedDay={selectedDay} close={pop} />, {
      barrierColor: 'rgba(0,0,0,0.54)',
    });
    if (saved === true) reload();
  };
  const openAddPoll = async () => {
    if ((await openAddPollDialog()) === true) reload();
  };

  return (
    <EverglowScaffold
      backgroundColor={AppColors.inkDeep}
      glows={[
        { color: AppColors.warmAmber, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.12 },
        { color: AppColors.softLavender, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
      ]}
      floatingActionButton={<CalendarFab onPressed={() => void (tab === 0 ? openAddEvent() : openAddPoll())} />}
    >
      <EverglowFeatureHeader
        title="Shared Calendar"
        subtitle="our special dates"
        icon="calendar_month"
        hue={AppColors.warmAmber}
        actions={[<RefreshButton key="r" onPressed={reload} />]}
      />
      <div style={{ height: 8, flexShrink: 0 }} />
      <div style={{ padding: '0 16px', flexShrink: 0 }}>
        <EverglowSegmentedControl
          selectedIndex={tab}
          onChanged={setTab}
          activeColor={AppColors.warmAmber}
          items={[
            { label: 'Calendar', icon: 'calendar_month' },
            { label: 'Polls', icon: 'how_to_vote' },
          ]}
        />
      </div>
      <div style={{ height: 12, flexShrink: 0 }} />
      {tab === 0 ? (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          <CalendarGrid
            month={month}
            events={monthEvents}
            selectedDay={selectedDay}
            onDaySelected={onDaySelected}
            onMonthChanged={setMonth}
          />
          <div style={{ height: 14, flexShrink: 0 }} />
          <UpcomingHeader count={upcoming.length} />
          <div style={{ height: 6, flexShrink: 0 }} />
          <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
            {upcoming.length === 0 ? (
              <EmptyState onAdd={() => void openAddEvent()} />
            ) : (
              <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '2px 16px 96px' }}>
                {upcoming
                  .slice(0, 10)
                  .map((ev, i) =>
                    i === 0 ? (
                      <NextDateHero key={`${ev.id}-${i}`} event={ev} onTap={() => openDaySheet(ev.date)} />
                    ) : (
                      <UpcomingEventCard key={`${ev.id}-${i}`} event={ev} onTap={() => openDaySheet(ev.date)} />
                    ),
                  )}
              </div>
            )}
          </div>
        </div>
      ) : (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          <PollsTab />
        </div>
      )}
    </EverglowScaffold>
  );
}

function UpcomingHeader({ count }: { count: number }) {
  return (
    <div style={{ padding: '0 20px', display: 'flex', alignItems: 'center', flexShrink: 0 }}>
      <div
        style={{
          width: 4,
          height: 30,
          borderRadius: 999,
          background: roseGold(4, 30),
          boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.4), blur: 10 }]),
        }}
      />
      <div style={{ width: 10 }} />
      <div>
        <div
          style={{
            ...AppTypography.cormorantBold,
            fontSize: 21,
            lineHeight: '21px',
            letterSpacing: 0.3,
            color: AppColors.petalWhite,
          }}
        >
          Coming up
        </div>
        <div style={{ height: 2 }} />
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 10.5,
            lineHeight: lineHeight(10.5),
            letterSpacing: 0.4,
            color: withAlpha(AppColors.petalWhite, 0.45),
          }}
        >
          {count === 0 ? 'nothing planned yet' : 'your next dates'}
        </div>
      </div>
      <div style={{ flex: 1 }} />
      {count > 0 && (
        <div
          style={{
            padding: '5px 11px',
            borderRadius: 999,
            background: linear([AppColors.auroraRose, AppColors.deepRose]),
            boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.4), blur: 12 }]),
            display: 'flex',
            alignItems: 'center',
            gap: 5,
          }}
        >
          <Icon name="favorite" size={10} color={AppColors.petalWhite} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 12, lineHeight: lineHeight(12), color: AppColors.petalWhite }}>
            {count}
          </span>
        </div>
      )}
    </div>
  );
}

function EmptyState({ onAdd }: { onAdd: () => void }) {
  const ring = (color: string, icon: string, pos: React.CSSProperties) => (
    <div
      style={{
        position: 'absolute',
        ...pos,
        width: 30,
        height: 30,
        borderRadius: '50%',
        background: withAlpha(AppColors.inkDeep, 0.85),
        border: `1px solid ${withAlpha(color, 0.5)}`,
        boxSizing: 'border-box',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={14} color={color} />
    </div>
  );
  return (
    <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', display: 'flex' }} className="no-scrollbar">
      <div style={{ margin: 'auto', padding: '12px 32px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div
          style={{
            position: 'relative',
            width: 120,
            height: 100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div
            style={{
              width: 84,
              height: 84,
              borderRadius: '50%',
              background: linear([withAlpha(AppColors.auroraRose, 0.22), withAlpha(AppColors.deepRose, 0.1)], {
                begin: [-1, -1],
                end: [1, 1],
              }),
              border: `1px solid ${withAlpha(AppColors.auroraRose, 0.4)}`,
              boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.25), blur: 24 }]),
              boxSizing: 'border-box',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="favorite" size={34} color={AppColors.auroraRose} />
          </div>
          {ring(AppColors.blushGold, 'auto_awesome', { top: 2, right: 8 })}
          {ring(AppColors.auroraLilac, 'calendar_month', { bottom: 2, left: 6 })}
        </div>
        <div style={{ height: 10 }} />
        <div style={{ ...AppTypography.cormorantBold, fontSize: 22, lineHeight: lineHeight(22), color: AppColors.petalWhite }}>
          Nothing planned yet
        </div>
        <div style={{ height: 4 }} />
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 12,
            lineHeight: lineHeight(12, 1.5),
            color: withAlpha(AppColors.petalWhite, 0.55),
            textAlign: 'center',
            whiteSpace: 'pre-line',
          }}
        >
          {'Your next date night is waiting\nto be dreamed up.'}
        </div>
        <div style={{ height: 16 }} />
        <button
          type="button"
          className="bare-button"
          onClick={onAdd}
          style={{
            padding: '13.2px 23.2px',
            borderRadius: 999,
            background: roseGold(1, 1),
            boxShadow: [
              insetBorder(withAlpha(AppColors.petalWhite, 0.35), 1.2).boxShadow,
              boxShadow([{ color: withAlpha(AppColors.deepRose, 0.45), blur: 20, spread: -2 }]),
            ].join(', '),
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name="add" size={17} color={AppColors.petalWhite} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 13, lineHeight: lineHeight(13), color: AppColors.petalWhite }}>
            Plan the next date
          </span>
        </button>
      </div>
    </div>
  );
}

function NextDateHero({ event, onTap }: { event: CalendarEvent; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const [pillRef, pillSize] = useBoxSize<HTMLDivElement>();
  const info = CALENDAR_TYPE_INFO[event.type];
  const hue = calendarEventHue(event.type);
  const dayDiff = inDays(new Date(), event.date);
  const countdown = dayDiff <= 0 ? 'Today!' : dayDiff === 1 ? 'Tomorrow!' : `${dayDiff}`;
  const countdownLabel = dayDiff <= 1 ? 'is the day' : 'days to go';
  return (
    <div style={{ padding: '4px 0 12px' }}>
      <div
        ref={ref}
        role="button"
        tabIndex={0}
        onClick={onTap}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          transform: `translateY(${hovered ? -2 : 0}px)`,
          transition: `transform ${fast}`,
          cursor: 'pointer',
        }}
      >
        <div style={shadowLayer({ color: withAlpha(hue, hovered ? 0.25 : 0.16), blur: 24, offset: [0, 8] }, { radius: 24 })} />
        <div
          style={{
            position: 'relative',
            padding: 16,
            borderRadius: 24,
            background: linear([withAlpha(hue, 0.28), withAlpha(AppColors.plum, 0.65), withAlpha(AppColors.inkDeep, 0.75)], {
              begin: [-1, -1],
              end: [1, 1],
              size,
            }),
            border: `1px solid ${withAlpha(hue, hovered ? 0.65 : 0.38)}`,
            transition: `border-color ${fast}`,
          }}
        >
          <div style={{ position: 'relative' }}>
            <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
              <div style={{ position: 'absolute', top: -12, right: -8 }}>
                <Icon name="favorite" size={92} color={withAlpha(hue, 0.12)} />
              </div>
            </div>
            <div style={{ position: 'relative' }}>
              <div style={{ display: 'flex', alignItems: 'center' }}>
                <div
                  ref={pillRef}
                  style={{
                    padding: '4px 9px',
                    borderRadius: 999,
                    background: roseGold(pillSize?.[0] ?? 1, pillSize?.[1] ?? 1),
                    display: 'flex',
                    alignItems: 'center',
                    gap: 4,
                  }}
                >
                  <Icon name="auto_awesome" size={10} color={AppColors.petalWhite} />
                  <span
                    style={{
                      ...AppTypography.outfitBold,
                      fontSize: 9,
                      lineHeight: lineHeight(9),
                      ...letterSpacing(1.2),
                      color: AppColors.petalWhite,
                    }}
                  >
                    NEXT DATE
                  </span>
                </div>
                <div style={{ width: 8 }} />
                <span
                  style={{
                    ...AppTypography.outfitBold,
                    fontSize: 9.5,
                    lineHeight: lineHeight(9.5),
                    ...letterSpacing(1),
                    color: withAlpha(hue, 0.9),
                  }}
                >
                  {info.label.toUpperCase()}
                </span>
              </div>
              <div style={{ height: 12 }} />
              <div style={{ display: 'flex', alignItems: 'center' }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      ...AppTypography.cormorantBold,
                      fontSize: 23,
                      lineHeight: mixedLineHeight(23, 1.1),
                      color: AppColors.petalWhite,
                      display: '-webkit-box',
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden',
                    }}
                  >
                    {/* Flutter's two spaces after the emoji measure about a space and a half here. */}
                    {info.emoji} <span style={{ marginLeft: 5.5 }} />
                    {event.title}
                  </div>
                  <div style={{ height: 6 }} />
                  <div style={{ display: 'flex', alignItems: 'center' }}>
                    <Icon name="calendar_today" size={12} color={withAlpha(hue, 0.9)} />
                    <div style={{ width: 6 }} />
                    <span
                      style={{
                        ...AppTypography.outfitBold,
                        fontSize: 12,
                        lineHeight: lineHeight(12),
                        color: withAlpha(AppColors.petalWhite, 0.8),
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {dayMonth(event.date)}
                    </span>
                  </div>
                  {event.location != null && (
                    <>
                      <div style={{ height: 4 }} />
                      <div style={{ display: 'flex', alignItems: 'center' }}>
                        <Icon name="place" size={12} color={AppColors.auroraTeal} />
                        <div style={{ width: 6 }} />
                        <span
                          style={{
                            ...AppTypography.outfitWhite,
                            fontSize: 11.5,
                            lineHeight: lineHeight(11.5),
                            color: AppColors.auroraTeal,
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                          }}
                        >
                          {event.location}
                        </span>
                      </div>
                    </>
                  )}
                </div>
                <div style={{ width: 12 }} />
                <div
                  style={{
                    padding: '10px 14px',
                    borderRadius: 16,
                    background: withAlpha(AppColors.inkDeep, 0.55),
                    border: `1px solid ${withAlpha(hue, 0.4)}`,
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                  }}
                >
                  <span style={{ ...AppTypography.cormorantBold, fontSize: 30, lineHeight: '30px', color: hue }}>
                    {countdown}
                  </span>
                  <div style={{ height: 2 }} />
                  <span
                    style={{
                      ...AppTypography.outfitBold,
                      fontSize: 9,
                      lineHeight: lineHeight(9),
                      letterSpacing: 0.6,
                      color: withAlpha(AppColors.petalWhite, 0.6),
                    }}
                  >
                    {countdownLabel}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function UpcomingEventCard({ event, onTap }: { event: CalendarEvent; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const info = CALENDAR_TYPE_INFO[event.type];
  const hue = calendarEventHue(event.type);
  const dayDiff = inDays(new Date(), event.date);
  const timeLabel = dayDiff === 0 ? 'Today' : dayDiff === 1 ? 'Tomorrow' : `In ${dayDiff} days`;
  return (
    <div style={{ paddingBottom: 10 }}>
      <div
        ref={ref}
        role="button"
        tabIndex={0}
        onClick={onTap}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          transform: `translateY(${hovered ? -2 : 0}px)`,
          transition: `transform ${fast}`,
          cursor: 'pointer',
        }}
      >
        <div style={shadowLayer({ color: withAlpha(AppColors.inkDeep, 0.35), blur: 14, offset: [0, 5] }, { radius: 16 })} />
        {hovered && <div style={shadowLayer({ color: withAlpha(hue, 0.16), blur: 20, offset: [0, 6] }, { radius: 16 })} />}
        <div
          style={{
            position: 'relative',
            padding: 13,
            borderRadius: 16,
            background: linear([withAlpha(hue, 0.12), withAlpha(AppColors.silk, 0.55), withAlpha(AppColors.inkDeep, 0.6)], {
              begin: [-1, -1],
              end: [1, 1],
              size,
            }),
            border: `1px solid ${withAlpha(hue, hovered ? 0.55 : 0.28)}`,
            transition: `border-color ${fast}`,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <div
            style={{
              width: 46,
              height: 46,
              flexShrink: 0,
              borderRadius: 14,
              background: linear([withAlpha(hue, 0.26), withAlpha(hue, 0.08)], { begin: [-1, -1], end: [1, 1] }),
              border: `1px solid ${withAlpha(hue, 0.42)}`,
              boxShadow: boxShadow([{ color: withAlpha(hue, 0.18), blur: 12, offset: [0, 4] }]),
              boxSizing: 'border-box',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <span style={{ fontSize: 20, lineHeight: mixedLineHeight(20) }}>{info.emoji}</span>
          </div>
          <div style={{ width: 12 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 13.5,
                lineHeight: mixedLineHeight(13.5),
                fontWeight: 700,
                color: AppColors.petalWhite,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {event.title}
            </div>
            <div style={{ height: 3 }} />
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <Icon name="calendar_today" size={11} color={withAlpha(hue, 0.85)} />
              <div style={{ width: 5 }} />
              <span
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 10.5,
                  lineHeight: lineHeight(10.5),
                  color: withAlpha(AppColors.petalWhite, 0.55),
                  whiteSpace: 'nowrap',
                }}
              >
                {shortDayMonth(event.date)}
              </span>
              <div style={{ width: 8 }} />
              <div style={{ width: 3, height: 3, borderRadius: '50%', background: withAlpha(hue, 0.7), flexShrink: 0 }} />
              <div style={{ width: 8 }} />
              <span
                style={{
                  ...AppTypography.outfitBold,
                  fontSize: 10,
                  lineHeight: lineHeight(10),
                  letterSpacing: 0.3,
                  color: withAlpha(hue, 0.9),
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  minWidth: 0,
                }}
              >
                {info.label}
              </span>
            </div>
            {event.location != null && (
              <>
                <div style={{ height: 3 }} />
                <div style={{ display: 'flex', alignItems: 'center' }}>
                  <Icon name="place" size={10} color={AppColors.auroraTeal} />
                  <div style={{ width: 4 }} />
                  <span
                    style={{
                      ...AppTypography.outfitWhite,
                      fontSize: 10,
                      lineHeight: lineHeight(10),
                      color: AppColors.auroraTeal,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {event.location}
                  </span>
                </div>
              </>
            )}
          </div>
          <div style={{ width: 10 }} />
          <TimePill label={timeLabel} hue={hue} />
          <div style={{ width: 6 }} />
          <div
            style={{
              width: 28,
              height: 28,
              flexShrink: 0,
              borderRadius: '50%',
              background: withAlpha(hue, 0.1),
              border: `1px solid ${withAlpha(hue, 0.3)}`,
              boxSizing: 'border-box',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="chevron_right" size={16} color={hue} />
          </div>
        </div>
      </div>
    </div>
  );
}

function TimePill({ label, hue }: { label: string; hue: string }) {
  const style = {
    ...AppTypography.outfitBold,
    fontSize: 10.5,
    lineHeight: lineHeight(10.5),
    letterSpacing: 0.2,
    whiteSpace: 'nowrap' as const,
  };
  if (label === 'Today') {
    return (
      <span
        style={{
          padding: '5px 11px',
          borderRadius: 999,
          background: linear([AppColors.auroraRose, AppColors.deepRose]),
          boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.45), blur: 12 }]),
          ...style,
          color: AppColors.petalWhite,
          flexShrink: 0,
        }}
      >
        Today ♥
      </span>
    );
  }
  return (
    <span
      style={{
        padding: '5px 10px',
        borderRadius: 999,
        background: withAlpha(hue, 0.14),
        border: `1px solid ${withAlpha(hue, 0.4)}`,
        ...style,
        color: hue,
        flexShrink: 0,
      }}
    >
      {label}
    </span>
  );
}

function RefreshButton({ onPressed }: { onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <Tooltip message="Refresh">
      <button
        type="button"
        className="bare-button"
        aria-label="Refresh"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: 36,
          height: 36,
          borderRadius: '50%',
          background: withAlpha(AppColors.moonlight, hovered ? 0.16 : 0.08),
          border: `1px solid ${hovered ? withAlpha(AppColors.blushGold, 0.5) : withAlpha(AppColors.moonlight, 0.2)}`,
          boxSizing: 'border-box',
          transition: `background-color ${fast}, border-color ${fast}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="refresh" size={18} color={AppColors.blushGold} />
      </button>
    </Tooltip>
  );
}

function CalendarFab({ onPressed }: { onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <Tooltip message="Add">
      <button
        type="button"
        className="bare-button"
        aria-label="Add"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: 58,
          height: 58,
          borderRadius: '50%',
          background: roseGold(1, 1),
          boxShadow: [
            insetBorder(withAlpha(AppColors.petalWhite, 0.4), 1.5).boxShadow,
            boxShadow([{ color: withAlpha(AppColors.deepRose, 0.45), blur: 24, spread: -2 }]),
          ].join(', '),
          // Matrix scale with no alignment: grows from the top-left corner.
          transform: `scale(${hovered ? 1.08 : 1})`,
          transformOrigin: '0 0',
          transition: `transform ${fast}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="add" size={26} color={AppColors.petalWhite} />
      </button>
    </Tooltip>
  );
}
