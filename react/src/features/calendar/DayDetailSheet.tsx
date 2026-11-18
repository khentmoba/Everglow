// Port of lib/features/calendar/presentation/widgets/day_detail_sheet.dart.
import { useRef, useState, type ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { boxShadow, insetBorder, letterSpacing, lineHeight, linear, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { AlertDialog, showDialog, showModalBottomSheet, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowIconButton } from '../../shared/widgets/EverglowScaffold';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { openSharedMemory } from '../journal/openSharedMemory';
import { AddEventDialog } from './AddEventDialog';
import {
  CALENDAR_TYPE_INFO,
  calendarEventHue,
  calendarService,
  type CalendarEvent,
  type CalendarEventType,
} from './calendarService';
import { jm, longDate, sameDay, weekday } from './calendarUi';

/** The calendar opens it on a see-through sheet over a black 20% barrier; the Journal opens it on velvet. */
export function showDayDetailSheet(day: Date, opts: { onEventAdded?: () => void; background?: string } = {}): Promise<void> {
  return showModalBottomSheet<void>(
    (close) => (
      <DayDetailSheet
        day={day}
        background={opts.background}
        close={() => close(null)}
        onEventAdded={opts.onEventAdded ?? (() => undefined)}
      />
    ),
    { barrierColor: opts.background ? undefined : 'rgba(0,0,0,0.2)' },
  ).then(() => undefined);
}

function DayDetailSheet({
  day,
  close,
  onEventAdded,
  background,
}: {
  day: Date;
  close: () => void;
  onEventAdded: () => void;
  background?: string;
}) {
  const { height } = useViewport();
  const [extent, setExtent] = useState(0.6);
  const [dragging, setDragging] = useState(false);
  const drag = useRef<{ y: number; extent: number } | null>(null);
  const all = useSource(() => calendarService.getEventsForMonth(day), [day.getFullYear(), day.getMonth()], null);
  const dayEvents = (all ?? []).filter((e) => sameDay(e.date, day));

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const target = new Date(day.getFullYear(), day.getMonth(), day.getDate());
  const diff = Math.round((target.getTime() - today.getTime()) / 86_400_000);
  const isToday = diff === 0;
  const relativeTag =
    diff === 0
      ? 'Today'
      : diff === 1
        ? 'Tomorrow'
        : diff === -1
          ? 'Yesterday'
          : diff > 1
            ? `In ${diff} days`
            : `${-diff} days ago`;

  const openAddEvent = async (type: CalendarEventType = 'custom') => {
    close();
    const saved = await showDialog<boolean>((pop) => <AddEventDialog selectedDay={day} initialType={type} close={pop} />, {
      barrierColor: 'transparent',
    });
    if (saved === true) onEventAdded();
  };

  const remove = async (ev: CalendarEvent) => {
    try {
      await calendarService.deleteEvent(ev.id);
      onEventAdded();
    } catch {
      showSnackBar('Could not delete this event. Please try again.');
    }
  };

  // DraggableScrollableSheet(0.60, min 0.38, max 0.88) under the theme's 48px drag-handle row.
  const avail = height - 48;
  const onPointerDown = (e: React.PointerEvent) => {
    drag.current = { y: e.clientY, extent };
    setDragging(true);
    (e.target as Element).setPointerCapture?.(e.pointerId);
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    setExtent(Math.min(0.88, Math.max(0.2, drag.current.extent - (e.clientY - drag.current.y) / avail)));
  };
  const onPointerUp = () => {
    drag.current = null;
    setDragging(false);
    if (extent < 0.38) close();
  };

  return (
    <div style={{ background }}>
      <div style={{ height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: 32, height: 4, borderRadius: 2, background: withAlpha(M3Scheme.onSurfaceVariant, 0.4) }} />
      </div>
      <div
        style={{
          height: extent * avail,
          transition: dragging ? undefined : `height ${orZero(200)}ms ${CssCurves.easeOutStrong}`,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'flex-end',
        }}
      >
        <div
          style={{
            width: '100%',
            maxWidth: 600,
            height: '100%',
            background: `linear-gradient(${AppColors.velvet}, ${AppColors.inkDeep})`,
            borderRadius: '28px 28px 0 0',
            boxShadow: [
              insetBorder(withAlpha(AppColors.blushGold, 0.28), 1.2).boxShadow,
              boxShadow([
                { color: withAlpha(AppColors.inkDeep, 0.85), blur: 32, offset: [0, -6] },
                { color: withAlpha(AppColors.deepRose, 0.15), blur: 24, offset: [0, -2] },
              ]),
            ].join(', '),
            padding: '1.2px 1.2px calc(1.2px + env(safe-area-inset-bottom))',
            boxSizing: 'border-box',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <div
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
            style={{ touchAction: 'none', cursor: 'grab', flexShrink: 0 }}
          >
            <div
              style={{
                margin: '12px auto 6px',
                width: 44,
                height: 4.5,
                borderRadius: 999,
                background: withAlpha(AppColors.petalWhite, 0.28),
              }}
            />
            <div style={{ padding: '8px 16px 12px 20px', display: 'flex', alignItems: 'center' }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center' }}>
                  <div
                    style={{
                      padding: '3px 9px',
                      borderRadius: 999,
                      background: isToday ? withAlpha(AppColors.deepRose, 0.22) : withAlpha(AppColors.moonlight, 0.08),
                      border: `1px solid ${isToday ? withAlpha(AppColors.deepRose, 0.5) : withAlpha(AppColors.blushGold, 0.22)}`,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 4,
                    }}
                  >
                    {isToday && <Icon name="auto_awesome" size={11} color={AppColors.auroraRose} />}
                    <span
                      style={{
                        ...AppTypography.outfitWhite,
                        fontSize: 10.5,
                        lineHeight: lineHeight(10.5),
                        fontWeight: 600,
                        letterSpacing: 0.6,
                        color: isToday ? AppColors.roseQuartz : AppColors.blushGold,
                      }}
                    >
                      {relativeTag}
                    </span>
                  </div>
                  <div style={{ width: 8 }} />
                  <span
                    style={{
                      ...AppTypography.outfitWhite,
                      fontSize: 12,
                      lineHeight: lineHeight(12),
                      color: withAlpha(AppColors.petalWhite, 0.6),
                    }}
                  >
                    {weekday(day)}
                  </span>
                </div>
                <div style={{ height: 4 }} />
                <div
                  style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22, lineHeight: lineHeight(22), letterSpacing: 0.3 }}
                >
                  {longDate(day)}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }} onPointerDown={(e) => e.stopPropagation()}>
                <EverglowIconButton
                  icon="add"
                  size={40}
                  semanticLabel="Add event to this day"
                  tooltip="Add event"
                  backgroundColor={withAlpha(AppColors.deepRose, 0.75)}
                  borderColor={withAlpha(AppColors.roseQuartz, 0.35)}
                  iconColor={AppColors.petalWhite}
                  onPressed={() => void openAddEvent()}
                />
                <EverglowIconButton
                  icon="close"
                  size={36}
                  semanticLabel="Close"
                  tooltip="Close"
                  backgroundColor={Derived.surfaceGlass}
                  onPressed={close}
                />
              </div>
            </div>
          </div>
          <div style={{ height: 1, background: 'rgba(255, 245, 245, 0.102)', flexShrink: 0 }} />
          <div
            className="no-scrollbar"
            onScroll={(e) => e.currentTarget.scrollTop > 0 && extent < 0.88 && !dragging && setExtent(0.88)}
            style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}
          >
            {dayEvents.length === 0 ? (
              <EmptyDayView isToday={isToday} onAdd={() => void openAddEvent()} onAddType={(t) => void openAddEvent(t)} />
            ) : (
              <div style={{ padding: '12px 16px 24px' }}>
                {dayEvents.map((ev) => (
                  <EventTile key={ev.id} event={ev} onDelete={() => void remove(ev)} />
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function EmptyDayView({
  isToday,
  onAdd,
  onAddType,
}: {
  isToday: boolean;
  onAdd: () => void;
  onAddType: (t: CalendarEventType) => void;
}) {
  return (
    <div style={{ padding: '16px 20px 24px', display: 'flex', justifyContent: 'center' }}>
      <div style={{ width: '100%', maxWidth: 380, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ height: 8 }} />
        <div
          style={{
            width: 76,
            height: 76,
            borderRadius: '50%',
            background: linear([withAlpha(AppColors.plum, 0.7), AppColors.velvet], { begin: [-1, -1], end: [1, 1] }),
            boxShadow: [
              insetBorder(withAlpha(AppColors.blushGold, 0.35), 1.5).boxShadow,
              boxShadow([{ color: withAlpha(AppColors.deepRose, 0.22), blur: 22, spread: 2 }]),
            ].join(', '),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="calendar_today" size={32} color={AppColors.blushGold} />
        </div>
        <div style={{ height: 16 }} />
        <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22, lineHeight: lineHeight(22), textAlign: 'center' }}>
          {isToday ? 'A quiet day together' : 'No plans set for this day'}
        </div>
        <div style={{ height: 8 }} />
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13, 1.45),
            color: withAlpha(AppColors.petalWhite, 0.65),
            textAlign: 'center',
          }}
        >
          Make it special with a romantic date, a sweet reminder, or an adventure to look forward to.
        </div>
        <div style={{ height: 20 }} />
        <EverglowButton label="Plan Something Special" icon="add" onPressed={onAdd} />
        <div style={{ height: 20 }} />
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 10.5,
            lineHeight: lineHeight(10.5),
            ...letterSpacing(1.1),
            fontWeight: 600,
            color: withAlpha(AppColors.petalWhite, 0.45),
          }}
        >
          QUICK ADD
        </span>
        <div style={{ height: 8 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
          <QuickTypeChip emoji="🌹" label="Date Night" hue={AppColors.auroraRose} onTap={() => onAddType('dateNight')} />
          <QuickTypeChip emoji="🥂" label="Anniversary" hue={AppColors.blushGold} onTap={() => onAddType('anniversary')} />
          <QuickTypeChip emoji="⏰" label="Reminder" hue={AppColors.auroraLilac} onTap={() => onAddType('reminder')} />
          <QuickTypeChip emoji="✨" label="Custom" hue={AppColors.softLavender} onTap={() => onAddType('custom')} />
        </div>
      </div>
    </div>
  );
}

function QuickTypeChip({ emoji, label, hue, onTap }: { emoji: string; label: string; hue: string; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        padding: '7px 12px',
        borderRadius: 999,
        background: hovered ? withAlpha(hue, 0.22) : withAlpha(AppColors.twilight, 0.8),
        border: `1px solid ${withAlpha(hue, hovered ? 0.6 : 0.3)}`,
        transition: `background-color ${orZero(AppMotion.fast)}ms, border-color ${orZero(AppMotion.fast)}ms`,
        display: 'flex',
        alignItems: 'center',
        gap: 6,
      }}
    >
      <span style={{ fontSize: 14, lineHeight: mixedLineHeight(14) }}>{emoji}</span>
      <span style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), fontWeight: 600, color: hue }}>
        {label}
      </span>
    </button>
  );
}

function confirmDelete(text: string): Promise<boolean | null> {
  return showDialog<boolean>((pop) => (
    <AlertDialog
      background={AppColors.velvet}
      radius={24}
      borderColor={withAlpha(AppColors.blushGold, 0.25)}
      title={<span style={{ ...AppTypography.cormorantBoldWhite, fontSize: 20 }}>Delete Event</span>}
      content={
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13),
            color: withAlpha(AppColors.petalWhite, 0.8),
          }}
        >
          {text}
        </span>
      }
      actions={[
        <TextButton
          key="c"
          onPressed={() => pop(false)}
          style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.7) }}
        >
          Cancel
        </TextButton>,
        <TextButton key="d" onPressed={() => pop(true)} style={{ ...AppTypography.outfitBold, color: AppColors.error }}>
          Delete
        </TextButton>,
      ]}
    />
  ));
}

function Tag({ icon, text, color, background }: { icon: string; text: string; color: string; background: string }) {
  return (
    <div style={{ padding: '3px 7px', borderRadius: 8, background, display: 'flex', alignItems: 'center', gap: 4 }}>
      <Icon name={icon} size={11} color={color} />
      <span style={{ ...AppTypography.outfitWhite, fontSize: 10.5, lineHeight: lineHeight(10.5), color }}>{text}</span>
    </div>
  );
}

/** _EventTile: swipe left (Dismissible endToStart) or tap the bin, both ask first. */
function EventTile({ event, onDelete }: { event: CalendarEvent; onDelete: () => void }) {
  const info = CALENDAR_TYPE_INFO[event.type] ?? { emoji: '✨', label: event.type };
  const hue = calendarEventHue(event.type);
  const [dx, setDx] = useState(0);
  const [dragging, setDragging] = useState(false);
  const start = useRef<{ x: number; w: number } | null>(null);

  const askDelete = async (text: string) => (await confirmDelete(text)) === true;

  const endSwipe = async () => {
    const s = start.current;
    start.current = null;
    setDragging(false);
    if (s && -dx > s.w * 0.4) {
      if (await askDelete(`Are you sure you want to remove "${event.title}"?`)) {
        onDelete();
        return;
      }
    }
    setDx(0);
  };

  const tags: ReactNode[] = [
    <Tag
      key="t"
      icon="schedule"
      text={event.isAllDay ? 'All day' : jm(event.date)}
      color={withAlpha(AppColors.petalWhite, 0.75)}
      background={withAlpha(AppColors.moonlight, 0.08)}
    />,
  ];
  if (event.location) {
    tags.push(
      <Tag
        key="l"
        icon="place"
        text={event.location}
        color={AppColors.auroraTeal}
        background={withAlpha(AppColors.auroraTeal, 0.12)}
      />,
    );
  }
  if (event.attendees && event.attendees.length > 0) {
    tags.push(
      <Tag
        key="a"
        icon="people_alt"
        text={event.attendees.join(', ')}
        color={AppColors.blushGold}
        background={withAlpha(AppColors.blushGold, 0.12)}
      />,
    );
  }
  if (event.recurring && event.recurring !== 'none') {
    tags.push(
      <Tag
        key="r"
        icon="repeat"
        text={event.recurring === 'yearly' ? 'Yearly' : 'Monthly'}
        color={AppColors.softLavender}
        background={withAlpha(AppColors.softLavender, 0.15)}
      />,
    );
  }

  return (
    <div style={{ position: 'relative', marginBottom: 10 }}>
      {dx < 0 && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: 16,
            background: withAlpha(AppColors.deepRose, 0.65),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            paddingRight: 20,
          }}
        >
          <Icon name="delete_outline" size={24} color={AppColors.petalWhite} />
        </div>
      )}
      <div
        onPointerDown={(e) => {
          if (e.pointerType === 'mouse') return;
          start.current = { x: e.clientX, w: e.currentTarget.offsetWidth };
          setDragging(true);
        }}
        onPointerMove={(e) => start.current && setDx(Math.min(0, e.clientX - start.current.x))}
        onPointerUp={() => void endSwipe()}
        onPointerCancel={() => void endSwipe()}
        style={{
          position: 'relative',
          transform: `translateX(${dx}px)`,
          transition: dragging ? undefined : `transform ${orZero(200)}ms ${CssCurves.easeOutStrong}`,
          touchAction: 'pan-y',
          padding: 15.2,
          borderRadius: 16,
          background: withAlpha(AppColors.twilight, 0.85),
          boxShadow: [
            insetBorder(withAlpha(hue, 0.35), 1.2).boxShadow,
            boxShadow([{ color: withAlpha(hue, 0.08), blur: 10, offset: [0, 3] }]),
          ].join(', '),
          display: 'flex',
          alignItems: 'flex-start',
        }}
      >
        <div
          style={{
            width: 42,
            height: 42,
            flexShrink: 0,
            borderRadius: 14,
            background: linear([withAlpha(hue, 0.25), withAlpha(hue, 0.1)], { begin: [-1, -1], end: [1, 1] }),
            border: `1px solid ${withAlpha(hue, 0.35)}`,
            boxSizing: 'border-box',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <span style={{ fontSize: 20, lineHeight: mixedLineHeight(20) }}>{info.emoji}</span>
        </div>
        <div style={{ width: 14 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 15, lineHeight: lineHeight(15), color: AppColors.petalWhite }}>
            {event.title}
          </div>
          {event.date <= new Date() && (
            <div style={{ marginLeft: -12 }}>
              <TextButton
                color={AppColors.roseQuartz}
                icon={<Icon name="auto_stories_outlined" size={18} color={AppColors.roseQuartz} />}
                onPressed={() =>
                  void openSharedMemory({
                    title: event.title,
                    date: event.date,
                    calendarEventId: event.id,
                    bucketItemId: event.bucketItemId,
                  })
                }
              >
                Keep this memory
              </TextButton>
            </div>
          )}
          {event.description !== '' && (
            <>
              <div style={{ height: 3 }} />
              <div
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 12,
                  lineHeight: lineHeight(12, 1.35),
                  color: withAlpha(AppColors.petalWhite, 0.72),
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                }}
              >
                {event.description}
              </div>
            </>
          )}
          <div style={{ height: 8 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 6, rowGap: 5 }}>{tags}</div>
        </div>
        <div style={{ width: 8 }} />
        <EverglowIconButton
          icon="delete_outline"
          size={34}
          semanticLabel="Delete event"
          tooltip="Delete"
          backgroundColor="transparent"
          borderColor="transparent"
          iconColor={withAlpha(AppColors.petalWhite, 0.45)}
          onPressed={() =>
            void askDelete(`Are you sure you want to remove "${event.title}" from your calendar?`).then((ok) => ok && onDelete())
          }
        />
      </div>
    </div>
  );
}
