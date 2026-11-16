// Port of lib/features/calendar/presentation/screens/calendar_screen.dart
// + calendar_grid.dart + day_detail_sheet.dart + polls_tab.dart + add dialogs.
import { useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import {
  CALENDAR_TYPE_INFO,
  calendarEventHue,
  calendarPollService,
  calendarService,
  type CalendarEvent,
  type DatePoll,
} from './calendarService';
import type { CalendarEventType } from '../../core/agent/fixtures';

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const WEEKDAYS = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function dayDiffFromNow(date: Date): number {
  const now = new Date();
  const a = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  const b = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  return Math.round((a - b) / 86_400_000);
}

export function CalendarPage() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? 'khentsgdz';
  const [tab, setTab] = useState<0 | 1>(0);
  const [currentMonth, setCurrentMonth] = useState(() => {
    const n = new Date();
    return new Date(n.getFullYear(), n.getMonth(), 1);
  });
  const [selectedDay, setSelectedDay] = useState<Date>(() => new Date());
  const [refreshTick, setRefreshTick] = useState(0);
  const [daySheetDay, setDaySheetDay] = useState<Date | null>(null);
  const [addEventDay, setAddEventDay] = useState<Date | null>(null);
  const [addPollOpen, setAddPollOpen] = useState(false);

  const monthEvents = useSource<CalendarEvent[]>(
    () => calendarService.getEventsForMonth(currentMonth),
    [currentMonth.getFullYear(), currentMonth.getMonth(), refreshTick],
    [],
  );
  const upcomingEvents = useSource<CalendarEvent[]>(
    () => calendarService.getUpcomingEvents(60),
    [refreshTick],
    [],
  );
  const polls = useSource<DatePoll[]>(() => calendarPollService.watchAll(), [refreshTick], []);

  const refresh = () => setRefreshTick((t) => t + 1);

  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.12 },
          { color: AppColors.softLavender, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
        ]}
      />
      <div
        className="no-scrollbar"
        style={{
          position: 'relative',
          zIndex: 1,
          height: '100%',
          overflowY: 'auto',
          overflowX: 'hidden',
          display: 'flex',
          flexDirection: 'column',
          paddingBottom: 96,
        }}
      >
        <EverglowFeatureHeader
          title="Shared Calendar"
          subtitle="our special dates"
          icon="calendar_month"
          hue={AppColors.warmAmber}
          actions={[
            <Tooltip key="refresh" message="Refresh">
              <button
                type="button"
                className="bare-button"
                aria-label="Refresh"
                onClick={refresh}
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: '50%',
                  background: withAlpha(AppColors.moonlight, 0.08),
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.2)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="refresh" size={18} color={AppColors.blushGold} />
              </button>
            </Tooltip>,
          ]}
        />

        <div style={{ height: 8 }} />
        <div style={{ padding: '0 16px' }}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(2, 1fr)',
              background: withAlpha(AppColors.inkDeep, 0.58),
              borderRadius: 18,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
              padding: 5,
            }}
          >
            {(
              [
                ['Calendar', 'calendar_month'],
                ['Polls', 'how_to_vote'],
              ] as const
            ).map(([label, icon], idx) => {
              const selected = tab === idx;
              return (
                <button
                  key={label}
                  type="button"
                  className="bare-button"
                  onClick={() => setTab(idx as 0 | 1)}
                  style={{
                    minHeight: 44,
                    padding: '13px 0',
                    borderRadius: 14,
                    background: selected ? withAlpha(AppColors.warmAmber, 0.16) : 'transparent',
                    border: `1px solid ${selected ? withAlpha(AppColors.warmAmber, 0.42) : 'transparent'}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: 6,
                    ...AppTypography.outfitBold,
                    fontSize: 11.5,
                    letterSpacing: 0.15,
                    color: selected ? AppColors.warmAmber : withAlpha(AppColors.petalWhite, 0.62),
                  }}
                >
                  <Icon
                    name={icon}
                    size={14}
                    color={selected ? AppColors.warmAmber : withAlpha(AppColors.petalWhite, 0.58)}
                  />
                  <span>{label}</span>
                </button>
              );
            })}
          </div>
        </div>
        <div style={{ height: 12 }} />

        {tab === 0 ? (
          <>
            <CalendarGridCard
              month={currentMonth}
              events={monthEvents}
              selectedDay={selectedDay}
              onPrevMonth={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1))}
              onNextMonth={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1))}
              onToday={() => {
                const n = new Date();
                setCurrentMonth(new Date(n.getFullYear(), n.getMonth(), 1));
              }}
              onSelectDay={(d) => {
                setSelectedDay(d);
                setDaySheetDay(d);
              }}
            />

            <div style={{ height: 14 }} />

            <div style={{ padding: '0 20px', display: 'flex', alignItems: 'center' }}>
              <div
                style={{
                  width: 4,
                  height: 30,
                  borderRadius: AppRadius.full,
                  background: `linear-gradient(180deg, ${AppColors.deepRose}, ${AppColors.blushGold})`,
                  boxShadow: `0 0 10px ${withAlpha(AppColors.deepRose, 0.4)}`,
                }}
              />
              <div style={{ width: 10 }} />
              <div>
                <div style={{ ...AppTypography.cormorantBold, fontSize: 21, lineHeight: 1, letterSpacing: 0.3, color: AppColors.petalWhite }}>
                  Coming up
                </div>
                <div style={{ ...AppTypography.outfitWhite, fontSize: 10.5, letterSpacing: 0.4, color: withAlpha(AppColors.petalWhite, 0.45), marginTop: 2 }}>
                  {upcomingEvents.length === 0 ? 'nothing planned yet' : 'your next dates'}
                </div>
              </div>
              <div style={{ flex: 1 }} />
              {upcomingEvents.length > 0 && (
                <div
                  style={{
                    padding: '5px 11px',
                    borderRadius: AppRadius.full,
                    background: `linear-gradient(90deg, ${AppColors.auroraRose}, ${AppColors.deepRose})`,
                    boxShadow: `0 0 12px ${withAlpha(AppColors.deepRose, 0.4)}`,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 5,
                  }}
                >
                  <Icon name="favorite" size={10} color={AppColors.petalWhite} />
                  <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.petalWhite }}>
                    {upcomingEvents.length}
                  </span>
                </div>
              )}
            </div>

            <div style={{ height: 6 }} />

            {upcomingEvents.length === 0 ? (
              <CalendarEmpty onAdd={() => setAddEventDay(selectedDay)} />
            ) : (
              <div style={{ padding: '2px 16px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
                {upcomingEvents.slice(0, 10).map((ev, idx) =>
                  idx === 0 ? (
                    <NextDateHero key={ev.id} event={ev} onTap={() => setDaySheetDay(ev.date)} />
                  ) : (
                    <UpcomingEventCard key={ev.id} event={ev} onTap={() => setDaySheetDay(ev.date)} />
                  ),
                )}
              </div>
            )}
          </>
        ) : (
          <PollsView
            polls={polls}
            currentUser={currentUser}
            onCreatePoll={() => setAddPollOpen(true)}
          />
        )}
      </div>

      {/* Floating Add Button */}
      <Tooltip message="Add">
        <button
          type="button"
          className="bare-button"
          aria-label="Add"
          onClick={() => (tab === 0 ? setAddEventDay(selectedDay) : setAddPollOpen(true))}
          style={{
            position: 'fixed',
            right: 20,
            bottom: 24,
            width: 58,
            height: 58,
            borderRadius: '50%',
            background: `linear-gradient(135deg, ${AppColors.deepRose}, ${AppColors.blushGold})`,
            border: `1.5px solid ${withAlpha(AppColors.petalWhite, 0.4)}`,
            boxShadow: `0 6px 24px ${withAlpha(AppColors.deepRose, 0.45)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 50,
          }}
        >
          <Icon name="add" size={26} color={AppColors.petalWhite} />
        </button>
      </Tooltip>

      {daySheetDay && (
        <DayDetailModal
          day={daySheetDay}
          events={monthEvents.filter((e) => sameDay(e.date, daySheetDay))}
          onClose={() => setDaySheetDay(null)}
          onAdd={() => {
            const d = daySheetDay;
            setDaySheetDay(null);
            setAddEventDay(d);
          }}
          onDelete={async (id) => {
            await calendarService.deleteEvent(id);
            showSnackBar('Event removed');
          }}
        />
      )}

      {addEventDay && (
        <AddEventModal
          initialDay={addEventDay}
          currentUser={currentUser}
          onClose={() => setAddEventDay(null)}
        />
      )}

      {addPollOpen && (
        <AddPollModal
          currentUser={currentUser}
          onClose={() => setAddPollOpen(false)}
        />
      )}
    </div>
  );
}

function CalendarGridCard({
  month,
  events,
  selectedDay,
  onPrevMonth,
  onNextMonth,
  onToday,
  onSelectDay,
}: {
  month: Date;
  events: CalendarEvent[];
  selectedDay: Date;
  onPrevMonth: () => void;
  onNextMonth: () => void;
  onToday: () => void;
  onSelectDay: (d: Date) => void;
}) {
  const now = new Date();
  const isCurrentMonth = month.getFullYear() === now.getFullYear() && month.getMonth() === now.getMonth();
  const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const firstWeekday = (new Date(month.getFullYear(), month.getMonth(), 1).getDay() + 6) % 7;
  const rows = Math.ceil((firstWeekday + daysInMonth) / 7);

  const monthEventCount = events.filter(
    (e) => e.date.getFullYear() === month.getFullYear() && e.date.getMonth() === month.getMonth(),
  ).length;
  const selectedEvents = events.filter((e) => sameDay(e.date, selectedDay));

  return (
    <div style={{ padding: '0 16px' }}>
      <div
        style={{
          position: 'relative',
          overflow: 'hidden',
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.24)}`,
          background: `linear-gradient(135deg, ${withAlpha(AppColors.plum, 0.72)}, ${withAlpha(AppColors.silk, 0.72)}, ${withAlpha(AppColors.inkDeep, 0.88)})`,
          boxShadow: `0 12px 26px ${withAlpha(AppColors.inkDeep, 0.55)}, 0 -6px 28px ${withAlpha(AppColors.blushGold, 0.07)}`,
          padding: '14px 10px 10px',
        }}
      >
        <div style={{ position: 'absolute', top: -14, right: -10, pointerEvents: 'none' }}>
          <Icon name="favorite" size={118} color={withAlpha(AppColors.auroraRose, 0.07)} />
        </div>
        <div style={{ position: 'absolute', top: 18, left: 14, pointerEvents: 'none' }}>
          <Icon name="auto_awesome" size={22} color={withAlpha(AppColors.blushGold, 0.16)} />
        </div>

        {/* Month header */}
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
          <NavCircleBtn icon="chevron_left" label="Previous month" onClick={onPrevMonth} />
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 24, lineHeight: 1, letterSpacing: 0.4, color: AppColors.petalWhite }}>
              {MONTH_NAMES[month.getMonth()]} {month.getFullYear()}
            </div>
            <div style={{ height: 7 }} />
            <button
              type="button"
              className="bare-button"
              onClick={isCurrentMonth ? undefined : onToday}
              style={{
                margin: '0 auto',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 5,
                padding: '4px 11px',
                borderRadius: AppRadius.full,
                background: `linear-gradient(90deg, ${withAlpha(AppColors.blushGold, 0.2)}, ${withAlpha(AppColors.auroraRose, 0.14)})`,
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.36)}`,
                cursor: isCurrentMonth ? 'default' : 'pointer',
              }}
            >
              <Icon name={isCurrentMonth ? 'favorite' : 'today'} size={10} color={AppColors.blushGold} />
              <span style={{ ...AppTypography.outfitBold, fontSize: 10.5, letterSpacing: 0.5, color: AppColors.blushGold }}>
                {isCurrentMonth ? `${monthEventCount} special ${monthEventCount === 1 ? 'date' : 'dates'}` : 'Back to today'}
              </span>
            </button>
          </div>
          <NavCircleBtn icon="chevron_right" label="Next month" onClick={onNextMonth} />
        </div>

        <div style={{ height: 12 }} />

        {/* Weekday header */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
          {WEEKDAYS.map((w, idx) => (
            <div
              key={w}
              style={{
                textAlign: 'center',
                ...AppTypography.outfitBold,
                fontSize: 10,
                letterSpacing: 1.6,
                color: idx >= 5 ? AppColors.auroraGold : withAlpha(AppColors.petalWhite, 0.62),
              }}
            >
              {w}
            </div>
          ))}
        </div>
        <div style={{ height: 8 }} />
        <div
          style={{
            height: 1,
            margin: '0 6px',
            background: `linear-gradient(90deg, transparent, ${withAlpha(AppColors.blushGold, 0.3)}, transparent)`,
          }}
        />
        <div style={{ height: 8 }} />

        {/* Day grid */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
          {Array.from({ length: rows }).map((_, r) => (
            <div key={r} style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
              {Array.from({ length: 7 }).map((__, c) => {
                const dayNum = r * 7 + c - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return <div key={c} style={{ height: 58 }} />;
                }
                const day = new Date(month.getFullYear(), month.getMonth(), dayNum);
                const dayEvents = events.filter((e) => sameDay(e.date, day));
                const isToday = sameDay(day, now);
                const isSelected = sameDay(day, selectedDay);
                const isWeekend = c >= 5;

                return (
                  <button
                    key={c}
                    type="button"
                    className="bare-button"
                    onClick={() => onSelectDay(day)}
                    style={{
                      margin: 3,
                      height: 52,
                      borderRadius: AppRadius.md,
                      background: isSelected
                        ? `linear-gradient(135deg, ${AppColors.deepRose}, ${AppColors.blushGold})`
                        : isToday
                          ? withAlpha(AppColors.blushGold, 0.14)
                          : dayEvents.length > 0
                            ? withAlpha(AppColors.moonlight, 0.05)
                            : 'transparent',
                      border: isSelected
                        ? `1.2px solid ${withAlpha(AppColors.petalWhite, 0.55)}`
                        : isToday
                          ? `1.4px solid ${withAlpha(AppColors.blushGold, 0.7)}`
                          : undefined,
                      boxShadow: isSelected
                        ? `0 0 18px ${withAlpha(AppColors.deepRose, 0.5)}`
                        : isToday
                          ? `0 0 14px ${withAlpha(AppColors.blushGold, 0.18)}`
                          : undefined,
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <span
                      style={{
                        ...AppTypography.outfitWhite,
                        fontSize: isSelected ? 14.5 : 13.5,
                        fontWeight: isToday || isSelected ? 700 : 500,
                        color: isSelected
                          ? AppColors.petalWhite
                          : isToday
                            ? AppColors.blushGold
                            : withAlpha(AppColors.petalWhite, isWeekend ? 0.92 : 0.74),
                      }}
                    >
                      {dayNum}
                    </span>
                    <div style={{ height: 4 }} />
                    {dayEvents.length > 0 ? (
                      <div style={{ display: 'flex', gap: 4 }}>
                        {dayEvents.slice(0, 3).map((ev) => (
                          <span
                            key={ev.id}
                            style={{
                              width: 6,
                              height: 6,
                              borderRadius: '50%',
                              background: isSelected ? AppColors.petalWhite : calendarEventHue(ev.type),
                              boxShadow: `0 0 6px ${withAlpha(calendarEventHue(ev.type), 0.7)}`,
                            }}
                          />
                        ))}
                      </div>
                    ) : isToday ? (
                      <span
                        style={{
                          width: 4,
                          height: 4,
                          borderRadius: '50%',
                          background: withAlpha(AppColors.blushGold, 0.85),
                        }}
                      />
                    ) : (
                      <div style={{ height: 6 }} />
                    )}
                  </button>
                );
              })}
            </div>
          ))}
        </div>

        <div style={{ height: 10 }} />

        {/* Footer */}
        <button
          type="button"
          className="bare-button"
          onClick={() => onSelectDay(selectedDay)}
          style={{
            width: '100%',
            padding: '8px 10px',
            borderRadius: AppRadius.md,
            background: `linear-gradient(90deg, ${withAlpha(AppColors.blushGold, 0.12)}, ${withAlpha(AppColors.auroraRose, 0.1)})`,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
            display: 'flex',
            alignItems: 'center',
            gap: 9,
          }}
        >
          <div
            style={{
              width: 26,
              height: 26,
              borderRadius: '50%',
              background: withAlpha(AppColors.blushGold, 0.18),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.36)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="favorite" size={13} color={AppColors.blushGold} />
          </div>
          <span style={{ flex: 1, textAlign: 'left', ...AppTypography.outfitBold, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.85) }}>
            {selectedDay.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}
          </span>
          {selectedEvents.length > 0 ? (
            <span
              style={{
                padding: '3px 9px',
                borderRadius: AppRadius.full,
                background: `linear-gradient(90deg, ${AppColors.auroraRose}, ${AppColors.deepRose})`,
                ...AppTypography.outfitBold,
                fontSize: 10,
                color: AppColors.petalWhite,
              }}
            >
              {selectedEvents.length} {selectedEvents.length === 1 ? 'event' : 'events'} ♥
            </span>
          ) : (
            <span style={{ ...AppTypography.outfitWhite, fontSize: 10.5, fontStyle: 'italic', color: withAlpha(AppColors.petalWhite, 0.45) }}>
              no events yet
            </span>
          )}
        </button>
      </div>
    </div>
  );
}

function NavCircleBtn({ icon, label, onClick }: { icon: string; label: string; onClick: () => void }) {
  return (
    <Tooltip message={label}>
      <button
        type="button"
        className="bare-button"
        aria-label={label}
        onClick={onClick}
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          background: withAlpha(AppColors.moonlight, 0.08),
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.22)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={icon} size={22} color={AppColors.blushGold} />
      </button>
    </Tooltip>
  );
}

function NextDateHero({ event, onTap }: { event: CalendarEvent; onTap: () => void }) {
  const info = CALENDAR_TYPE_INFO[event.type];
  const hue = calendarEventHue(event.type);
  const diff = dayDiffFromNow(event.date);
  const countdown = diff <= 0 ? 'Today!' : diff === 1 ? 'Tomorrow!' : String(diff);
  const countdownLabel = diff <= 1 ? 'is the day' : 'days to go';

  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        width: '100%',
        textAlign: 'left',
        position: 'relative',
        overflow: 'hidden',
        padding: 16,
        borderRadius: AppRadius.x2,
        background: `linear-gradient(135deg, ${withAlpha(hue, 0.28)}, ${withAlpha(AppColors.plum, 0.65)}, ${withAlpha(AppColors.inkDeep, 0.75)})`,
        border: `1px solid ${withAlpha(hue, 0.38)}`,
        boxShadow: `0 8px 24px ${withAlpha(hue, 0.16)}`,
      }}
    >
      <div style={{ position: 'absolute', top: -12, right: -8, pointerEvents: 'none' }}>
        <Icon name="favorite" size={92} color={withAlpha(hue, 0.12)} />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span
          style={{
            padding: '4px 9px',
            borderRadius: AppRadius.full,
            background: `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.blushGold})`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 4,
            ...AppTypography.outfitBold,
            fontSize: 9,
            letterSpacing: 1.2,
            color: AppColors.petalWhite,
          }}
        >
          <Icon name="auto_awesome" size={10} color={AppColors.petalWhite} />
          <span>NEXT DATE</span>
        </span>
        <span style={{ ...AppTypography.outfitBold, fontSize: 9.5, letterSpacing: 1, color: withAlpha(hue, 0.9) }}>
          {info.label.toUpperCase()}
        </span>
      </div>
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.cormorantBold, fontSize: 23, lineHeight: 1.1, color: AppColors.petalWhite }}>
            {info.emoji}  {event.title}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
            <Icon name="calendar_today" size={12} color={withAlpha(hue, 0.9)} />
            <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.8) }}>
              {event.date.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}
            </span>
          </div>
          {event.location && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
              <Icon name="place" size={12} color={AppColors.auroraTeal} />
              <span style={{ ...AppTypography.outfitWhite, fontSize: 11.5, color: AppColors.auroraTeal }}>
                {event.location}
              </span>
            </div>
          )}
        </div>
        <div
          style={{
            padding: '10px 14px',
            borderRadius: AppRadius.lg,
            background: withAlpha(AppColors.inkDeep, 0.55),
            border: `1px solid ${withAlpha(hue, 0.4)}`,
            textAlign: 'center',
            flexShrink: 0,
          }}
        >
          <div style={{ ...AppTypography.cormorantBold, fontSize: 30, lineHeight: 1, color: hue }}>{countdown}</div>
          <div style={{ ...AppTypography.outfitBold, fontSize: 9, letterSpacing: 0.6, color: withAlpha(AppColors.petalWhite, 0.6), marginTop: 2 }}>
            {countdownLabel}
          </div>
        </div>
      </div>
    </button>
  );
}

function UpcomingEventCard({ event, onTap }: { event: CalendarEvent; onTap: () => void }) {
  const info = CALENDAR_TYPE_INFO[event.type];
  const hue = calendarEventHue(event.type);
  const diff = dayDiffFromNow(event.date);
  const timeLabel = diff <= 0 ? 'Today' : diff === 1 ? 'Tomorrow' : `In ${diff} days`;

  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        width: '100%',
        textAlign: 'left',
        padding: 13,
        borderRadius: AppRadius.lg,
        background: `linear-gradient(135deg, ${withAlpha(hue, 0.12)}, ${withAlpha(AppColors.silk, 0.55)}, ${withAlpha(AppColors.inkDeep, 0.6)})`,
        border: `1px solid ${withAlpha(hue, 0.28)}`,
        boxShadow: `0 5px 14px ${withAlpha(AppColors.inkDeep, 0.35)}`,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
      }}
    >
      <div
        style={{
          width: 46,
          height: 46,
          borderRadius: AppRadius.md,
          background: `linear-gradient(135deg, ${withAlpha(hue, 0.26)}, ${withAlpha(hue, 0.08)})`,
          border: `1px solid ${withAlpha(hue, 0.42)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 20,
          flexShrink: 0,
        }}
      >
        {info.emoji}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.outfitBold,
            fontSize: 13.5,
            color: AppColors.petalWhite,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {event.title}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
          <Icon name="calendar_today" size={11} color={withAlpha(hue, 0.85)} />
          <span style={{ ...AppTypography.outfitWhite, fontSize: 10.5, color: withAlpha(AppColors.petalWhite, 0.55) }}>
            {event.date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
          </span>
          <span style={{ width: 3, height: 3, borderRadius: '50%', background: withAlpha(hue, 0.7) }} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 10, letterSpacing: 0.3, color: withAlpha(hue, 0.9) }}>
            {info.label}
          </span>
        </div>
      </div>
      <span
        style={{
          padding: '5px 10px',
          borderRadius: AppRadius.full,
          background: timeLabel === 'Today' ? `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.blushGold})` : withAlpha(hue, 0.14),
          border: timeLabel === 'Today' ? undefined : `1px solid ${withAlpha(hue, 0.4)}`,
          ...AppTypography.outfitBold,
          fontSize: 10.5,
          color: timeLabel === 'Today' ? AppColors.petalWhite : hue,
          flexShrink: 0,
        }}
      >
        {timeLabel === 'Today' ? 'Today ♥' : timeLabel}
      </span>
      <div
        style={{
          width: 28,
          height: 28,
          borderRadius: '50%',
          background: withAlpha(hue, 0.1),
          border: `1px solid ${withAlpha(hue, 0.3)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="chevron_right" size={16} color={hue} />
      </div>
    </button>
  );
}

function CalendarEmpty({ onAdd }: { onAdd: () => void }) {
  return (
    <div style={{ padding: '24px 32px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div
        style={{
          width: 84,
          height: 84,
          borderRadius: '50%',
          background: `linear-gradient(135deg, ${withAlpha(AppColors.auroraRose, 0.22)}, ${withAlpha(AppColors.deepRose, 0.1)})`,
          border: `1px solid ${withAlpha(AppColors.auroraRose, 0.4)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="favorite" size={34} color={AppColors.auroraRose} />
      </div>
      <div style={{ height: 12 }} />
      <div style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite }}>Nothing planned yet</div>
      <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.55), marginTop: 4 }}>
        Your next date night is waiting to be dreamed up.
      </div>
      <div style={{ height: 16 }} />
      <EverglowButton label="Plan the next date" icon="add" onPressed={onAdd} />
    </div>
  );
}

function PollsView({
  polls,
  currentUser,
  onCreatePoll,
}: {
  polls: DatePoll[];
  currentUser: string;
  onCreatePoll: () => void;
}) {
  if (polls.length === 0) {
    return (
      <div style={{ padding: 48, textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <Icon name="how_to_vote" size={48} color={withAlpha(AppColors.warmAmber, 0.7)} />
        <div style={{ height: 12 }} />
        <div style={{ ...AppTypography.outfitBold, fontSize: 16 }}>No date polls yet</div>
        <div style={{ ...AppTypography.bodySmall, marginTop: 6, color: Derived.textMedium }}>
          Create a poll to pick the perfect date together
        </div>
        <div style={{ marginTop: 18 }}>
          <EverglowButton label="Create Poll" onPressed={onCreatePoll} />
        </div>
      </div>
    );
  }

  return (
    <div style={{ padding: '8px 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
      {polls.map((poll) => {
        const isClosed = poll.status === 'closed';
        const myVote = poll.votes[currentUser];
        const tally: Record<string, number> = {};
        for (const v of Object.values(poll.votes)) {
          tally[v] = (tally[v] ?? 0) + 1;
        }
        const totalVotes = Object.keys(poll.votes).length;
        let winningId = poll.winningOptionId;
        if (!winningId) {
          let max = 0;
          for (const [k, c] of Object.entries(tally)) {
            if (c > max) {
              max = c;
              winningId = k;
            }
          }
        }

        return (
          <div
            key={poll.id}
            style={{
              padding: 16,
              borderRadius: 16,
              background: withAlpha(AppColors.moonlight, 0.08),
              border: `1px solid ${withAlpha(isClosed ? AppColors.softLavender : AppColors.blushGold, isClosed ? 0.2 : 0.15)}`,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span
                style={{
                  padding: '4px 8px',
                  borderRadius: 20,
                  background: withAlpha(isClosed ? AppColors.softLavender : AppColors.warmAmber, 0.15),
                  ...AppTypography.outfitBold,
                  fontSize: 10,
                  color: isClosed ? AppColors.softLavender : AppColors.warmAmber,
                }}
              >
                {isClosed ? 'Closed' : 'Open'}
              </span>
              <div style={{ flex: 1, ...AppTypography.outfitBold, fontSize: 15, color: AppColors.petalWhite }}>
                {poll.title}
              </div>
              <button
                type="button"
                className="bare-button"
                aria-label="Delete poll"
                onClick={() => void calendarPollService.delete(poll.id)}
              >
                <Icon name="delete_outline" size={18} color={withAlpha(AppColors.petalWhite, 0.45)} />
              </button>
            </div>
            {poll.description && (
              <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium, marginTop: 6 }}>{poll.description}</div>
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 12 }}>
              {poll.options.map((opt) => {
                const count = tally[opt.id] ?? 0;
                const picked = myVote === opt.id;
                const isWinner = isClosed && winningId === opt.id;
                return (
                  <button
                    key={opt.id}
                    type="button"
                    className="bare-button"
                    disabled={isClosed}
                    onClick={() => void calendarPollService.vote(poll.id, currentUser, opt.id)}
                    style={{
                      padding: '10px 12px',
                      borderRadius: 12,
                      background: picked || isWinner ? withAlpha(AppColors.blushGold, 0.14) : withAlpha(AppColors.inkDeep, 0.5),
                      border: `1px solid ${withAlpha(picked || isWinner ? AppColors.blushGold : AppColors.moonlight, picked || isWinner ? 0.5 : 0.1)}`,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      gap: 8,
                    }}
                  >
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ ...AppTypography.outfitBold, fontSize: 13, color: AppColors.petalWhite }}>
                        {opt.label || opt.date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
                      </div>
                      <div style={{ ...AppTypography.bodySmall, fontSize: 11, color: Derived.textMuted }}>
                        {opt.date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                      </div>
                    </div>
                    <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.blushGold }}>
                      {count} {count === 1 ? 'vote' : 'votes'}
                    </span>
                  </button>
                );
              })}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 12 }}>
              <span style={{ ...AppTypography.bodySmall, fontSize: 11, color: Derived.textMuted }}>
                {totalVotes} {totalVotes === 1 ? 'vote' : 'votes'}
              </span>
              {isClosed ? (
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => void calendarPollService.reopen(poll.id)}
                  style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.blushGold }}
                >
                  Reopen
                </button>
              ) : (
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => {
                    if (!winningId) {
                      showSnackBar('No votes yet');
                      return;
                    }
                    const winOpt = poll.options.find((o) => o.id === winningId) ?? poll.options[0];
                    void calendarPollService
                      .finalize(poll.id, winningId, {
                        title: poll.title,
                        description: `Decided via poll: ${poll.title}`,
                        date: winOpt.date,
                        type: 'dateNight',
                        createdBy: poll.createdBy,
                        attendees: Object.keys(poll.votes),
                      })
                      .then(() => showSnackBar('Poll finalized & event created!'));
                  }}
                  style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.blushGold }}
                >
                  Finalize & Schedule
                </button>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function DayDetailModal({
  day,
  events,
  onClose,
  onAdd,
  onDelete,
}: {
  day: Date;
  events: CalendarEvent[];
  onClose: () => void;
  onAdd: () => void;
  onDelete: (id: string) => Promise<void>;
}) {
  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.55)',
        zIndex: 600,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 600,
          maxHeight: '80vh',
          overflowY: 'auto',
          background: `linear-gradient(180deg, ${AppColors.velvet}, ${AppColors.inkDeep})`,
          borderRadius: '24px 24px 0 0',
          border: `1.2px solid ${withAlpha(AppColors.blushGold, 0.28)}`,
          padding: 20,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite }}>
              {day.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
            </div>
            <div style={{ ...AppTypography.bodySmall, color: Derived.textMuted }}>
              {day.toLocaleDateString('en-US', { weekday: 'long' })}
            </div>
          </div>
          <EverglowButton label="Add Event" icon="add" onPressed={onAdd} />
        </div>
        {events.length === 0 ? (
          <div style={{ padding: '24px 0', textAlign: 'center', ...AppTypography.bodySmall, color: Derived.textMedium }}>
            No events planned on this day yet.
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {events.map((ev) => {
              const info = CALENDAR_TYPE_INFO[ev.type];
              const hue = calendarEventHue(ev.type);
              return (
                <div
                  key={ev.id}
                  style={{
                    padding: 14,
                    borderRadius: 16,
                    background: withAlpha(AppColors.moonlight, 0.06),
                    border: `1px solid ${withAlpha(hue, 0.3)}`,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                  }}
                >
                  <span style={{ fontSize: 22 }}>{info.emoji}</span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>{ev.title}</div>
                    {ev.description && (
                      <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium, marginTop: 2 }}>{ev.description}</div>
                    )}
                  </div>
                  <button
                    type="button"
                    className="bare-button"
                    aria-label="Delete event"
                    onClick={() => void onDelete(ev.id)}
                  >
                    <Icon name="delete_outline" size={18} color={withAlpha(AppColors.petalWhite, 0.45)} />
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

function AddEventModal({
  initialDay,
  currentUser,
  onClose,
}: {
  initialDay: Date;
  currentUser: string;
  onClose: () => void;
}) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [type, setType] = useState<CalendarEventType>('dateNight');
  const [dateStr, setDateStr] = useState(() => initialDay.toISOString().slice(0, 10));
  const [location, setLocation] = useState('');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      const [y, m, d] = dateStr.split('-').map(Number);
      await calendarService.addEvent({
        title: title.trim(),
        description: description.trim(),
        date: new Date(y, (m || 1) - 1, d || 1, 19, 0),
        type,
        createdBy: currentUser,
        location: location.trim() || undefined,
      });
      showSnackBar('Event added to Calendar');
      onClose();
    } catch {
      showSnackBar('Could not save event');
      setSaving(false);
    }
  };

  return (
    <div
      onClick={() => !saving && onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.68)',
        zIndex: 650,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 18,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 440,
          background: AppColors.velvet,
          borderRadius: 24,
          border: `1px solid ${Derived.border}`,
          padding: 22,
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{ ...AppTypography.titleLarge, color: AppColors.petalWhite }}>New Special Date</div>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" style={modalFieldStyle} />
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {(Object.keys(CALENDAR_TYPE_INFO) as CalendarEventType[]).map((t) => {
            const info = CALENDAR_TYPE_INFO[t];
            const sel = type === t;
            return (
              <button
                key={t}
                type="button"
                className="bare-button"
                onClick={() => setType(t)}
                style={{
                  padding: '6px 10px',
                  borderRadius: AppRadius.full,
                  background: sel ? withAlpha(calendarEventHue(t), 0.22) : withAlpha(AppColors.inkDeep, 0.5),
                  border: `1px solid ${sel ? calendarEventHue(t) : Derived.border}`,
                  ...AppTypography.outfitBold,
                  fontSize: 11,
                  color: AppColors.petalWhite,
                }}
              >
                {info.emoji} {info.label}
              </button>
            );
          })}
        </div>
        <input type="date" value={dateStr} onChange={(e) => setDateStr(e.target.value)} style={modalFieldStyle} />
        <input value={location} onChange={(e) => setLocation(e.target.value)} placeholder="Place (optional)" style={modalFieldStyle} />
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} placeholder="Notes..." style={modalFieldStyle} />
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <EverglowButton label="Cancel" variant="ghost" onPressed={onClose} enabled={!saving} />
          <EverglowButton label={saving ? 'Saving…' : 'Save'} enabled={Boolean(title.trim()) && !saving} onPressed={() => void submit()} />
        </div>
      </div>
    </div>
  );
}

function AddPollModal({ currentUser, onClose }: { currentUser: string; onClose: () => void }) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [opt1, setOpt1] = useState(() => new Date(Date.now() + 2 * 86_400_000).toISOString().slice(0, 10));
  const [opt2, setOpt2] = useState(() => new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10));
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      const parseDate = (s: string) => {
        const [y, m, d] = s.split('-').map(Number);
        return new Date(y, (m || 1) - 1, d || 1, 19, 0);
      };
      const d1 = parseDate(opt1);
      const d2 = parseDate(opt2);
      await calendarPollService.create({
        title: title.trim(),
        description: description.trim(),
        createdBy: currentUser,
        createdAt: new Date(),
        status: 'open',
        options: [
          { id: 'opt_1', date: d1, label: d1.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) },
          { id: 'opt_2', date: d2, label: d2.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) },
        ],
        votes: {},
      });
      showSnackBar('Poll created');
      onClose();
    } catch {
      showSnackBar('Could not create poll');
      setSaving(false);
    }
  };

  return (
    <div
      onClick={() => !saving && onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.68)',
        zIndex: 650,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 18,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 420,
          background: AppColors.velvet,
          borderRadius: 24,
          border: `1px solid ${Derived.border}`,
          padding: 22,
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{ ...AppTypography.titleLarge, color: AppColors.petalWhite }}>New Date Poll</div>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="What are we planning?" style={modalFieldStyle} />
        <input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Details (optional)" style={modalFieldStyle} />
        <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>Date option 1</div>
        <input type="date" value={opt1} onChange={(e) => setOpt1(e.target.value)} style={modalFieldStyle} />
        <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium }}>Date option 2</div>
        <input type="date" value={opt2} onChange={(e) => setOpt2(e.target.value)} style={modalFieldStyle} />
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <EverglowButton label="Cancel" variant="ghost" onPressed={onClose} enabled={!saving} />
          <EverglowButton label={saving ? 'Creating…' : 'Create Poll'} enabled={Boolean(title.trim()) && !saving} onPressed={() => void submit()} />
        </div>
      </div>
    </div>
  );
}

const modalFieldStyle = {
  width: '100%',
  padding: '11px 14px',
  borderRadius: 12,
  background: withAlpha(AppColors.inkDeep, 0.55),
  border: `1px solid ${Derived.border}`,
  color: AppColors.petalWhite,
  outline: 'none',
  fontSize: 14,
};
