// Port of lib/features/bucket_list/presentation/widgets/bucket_item_card.dart:
// the dream card (swipe to fulfil or let go), and the dream detail sheet.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useBoxSize } from '../../core/system/useBoxSize';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, CssCurves, motionReduced, orZero } from '../../core/theme/motion';
import { Align, boxShadow, letterSpacing, linear, lineHeight, mixedLineHeight, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { pickDate } from '../../shared/utils/pickDate';
import { AlertDialog, CenteredSheetArea, showDialog, showModalBottomSheet, TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { AddEventDialog } from '../calendar/AddEventDialog';
import { showDayDetailSheet } from '../calendar/DayDetailSheet';
import { openSharedMemory } from '../journal/openSharedMemory';
import { bucketListService, isBucketDueSoon, isBucketOverdue, type BucketItem, type BucketStatus } from './bucketListService';
import {
  assigneeHue,
  assigneeIcon,
  assigneeLabel,
  BUCKET_PRIORITIES,
  BUCKET_STATUSES,
  categoryInfo,
  MMMd,
  nextAssignee,
  priorityHue,
  priorityShort,
  statusHue,
  statusIcon,
  statusLabel,
  yMMMd,
} from './bucketUi';

const cssEaseOutExpo = 'cubic-bezier(0.16, 1, 0.3, 1)';

const text = (size: number, color: string, bold = true, height?: string): CSSProperties => ({
  ...(bold ? AppTypography.outfitBold : AppTypography.outfitWhite),
  fontSize: size,
  lineHeight: height ?? lineHeight(size),
  color,
});

/** `showBucketItemDetail`: the sheet on a velvet bottom-sheet surface (used from Journal links). */
export function showBucketItemDetail(item: BucketItem, username: string): Promise<void> {
  return showModalBottomSheet<void>((close) => (
    <CenteredSheetArea close={() => close(null)} background={AppColors.velvet}>
      <DreamDetailSheet item={item} currentUsername={username} close={() => close(null)} />
    </CenteredSheetArea>
  )).then(() => undefined);
}

function showDreamSheet(item: BucketItem, username: string) {
  void showModalBottomSheet<void>((close) => (
    <CenteredSheetArea close={() => close(null)}>
      <DreamDetailSheet item={item} currentUsername={username} close={() => close(null)} />
    </CenteredSheetArea>
  ));
}

function confirmLetGo(title: string): Promise<boolean> {
  return showDialog<boolean>((close) => (
    <AlertDialog
      background={AppColors.velvet}
      radius={AppRadius.x2}
      title={<span style={{ ...AppTypography.outfitBold, fontSize: 16, color: AppColors.roseQuartz }}>Let go of "{title}"?</span>}
      content={
        <div style={text(13, withAlpha(AppColors.petalWhite, 0.7), false)}>
          This dream will drift away. This cannot be undone.
        </div>
      }
      actions={[
        <TextButton key="keep" onPressed={() => close(false)}>
          <span style={text(13, withAlpha(AppColors.petalWhite, 0.7))}>Keep it</span>
        </TextButton>,
        <TextButton key="go" onPressed={() => close(true)}>
          <span style={text(13, AppColors.error)}>Let go</span>
        </TextButton>,
      ]}
    />
  )).then((v) => v === true);
}

const shown = new Set<string>();

/** _DreamEntrance: rises 12% of its height and fades in, once per dream. */
function DreamEntrance({ id, delay, children }: { id: string; delay: number; children: ReactNode }) {
  const [visible, setVisible] = useState(() => shown.has(id) || motionReduced());
  useEffect(() => {
    if (visible) return;
    const t = window.setTimeout(() => {
      shown.add(id);
      if (shown.size > 300) shown.clear();
      setVisible(true);
    }, delay);
    return () => window.clearTimeout(t);
  }, [id, delay, visible]);
  const ms = orZero(AppMotion.medium);
  return (
    <div
      style={{
        transform: visible ? 'none' : 'translateY(12%)',
        opacity: visible ? 1 : 0,
        transition: `transform ${ms}ms ${cssEaseOutExpo}, opacity ${ms}ms linear`,
      }}
    >
      {children}
    </div>
  );
}

export function BucketItemCard({
  item,
  currentUsername,
  enableSwipe = true,
  entranceDelay = 0,
}: {
  item: BucketItem;
  currentUsername: string;
  enableSwipe?: boolean;
  entranceDelay?: number;
}) {
  const [optimistic, setOptimistic] = useState<boolean | null>(null);
  const toggling = useRef(false);
  const [boxRef, size] = useBoxSize<HTMLDivElement>();
  useEffect(() => setOptimistic(null), [item.status]);

  const isCompleted = optimistic ?? item.status === 'completed';
  const effective: BucketStatus = isCompleted ? 'completed' : item.status === 'completed' ? 'wish' : item.status;
  const cat = categoryInfo(item.category);

  const toggleComplete = async () => {
    if (toggling.current) return;
    toggling.current = true;
    const next = !isCompleted;
    setOptimistic(next);
    try {
      if (next) await bucketListService.markComplete(item.id, currentUsername);
      else await bucketListService.markUncomplete(item.id);
      if (next) {
        showSnackBar('A wish came true.', {
          action: {
            label: 'Keep memory',
            onPressed: () => void openSharedMemory({ title: item.title, date: new Date(), bucketItemId: item.id }),
          },
        });
      }
    } catch {
      setOptimistic(null);
      showSnackBar('Something went wrong. Please try again.');
    } finally {
      toggling.current = false;
    }
  };

  const edgeHue = isCompleted
    ? withAlpha(AppColors.blushGold, 0.8)
    : item.priority === 'urgent'
      ? withAlpha(AppColors.error, 0.85)
      : item.priority === 'high'
        ? withAlpha(AppColors.warmAmber, 0.8)
        : withAlpha(AppColors.moonlight, 0.1);

  const card = (
    <DreamEntrance id={item.id} delay={entranceDelay}>
      <div style={{ position: 'relative' }}>
        {isCompleted && (
          <div
            aria-hidden
            style={shadowLayer({ color: withAlpha(AppColors.blushGold, 0.1), blur: 18, spread: -4 }, { radius: AppRadius.x2 })}
          />
        )}
        <div
          aria-hidden
          style={shadowLayer({ color: withAlpha('#000000', 0.3), blur: 14, offset: [0, 6] }, { radius: AppRadius.x2 })}
        />
        <div
          ref={boxRef}
          role="button"
          tabIndex={0}
          aria-label={`${item.title}, ${cat.name}, ${statusLabel(effective)}`}
          onClick={() => showDreamSheet(item, currentUsername)}
          onKeyDown={(e) => e.key === 'Enter' && showDreamSheet(item, currentUsername)}
          style={{
            position: 'relative',
            padding: 12,
            background: linear([withAlpha(AppColors.petalWhite, isCompleted ? 0.06 : 0.045), withAlpha(AppColors.velvet, 0.55)], {
              begin: Align.topLeft,
              end: Align.bottomRight,
              size: size ?? [1, 1],
            }),
            borderRadius: AppRadius.x2,
            border: `1px solid ${isCompleted ? withAlpha(AppColors.blushGold, 0.45) : withAlpha(AppColors.moonlight, 0.1)}`,
            display: 'flex',
            alignItems: 'flex-start',
            cursor: 'pointer',
            outline: 'none',
          }}
        >
          <div style={{ width: 4, height: 58, borderRadius: AppRadius.full, background: edgeHue, flexShrink: 0 }} />
          <div style={{ width: 10, flexShrink: 0 }} />
          <FulfillRing completed={isCompleted} title={item.title} onTap={() => void toggleComplete()} />
          <div style={{ width: 12, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start' }}>
              <div
                style={{
                  flex: 1,
                  minWidth: 0,
                  ...AppTypography.outfitBold,
                  fontSize: 15,
                  lineHeight: lineHeight(15, 1.15),
                  color: isCompleted ? withAlpha(AppColors.petalWhite, 0.5) : AppColors.petalWhite,
                  overflowWrap: 'break-word',
                  // A wrapped line holding an emoji measures about 1px taller in Flutter (fallback font metrics).
                  paddingBottom: /\p{Extended_Pictographic}/u.test(item.title) ? 1 : 0,
                }}
              >
                {isCompleted ? (
                  // Flutter's line-through sits lower and thinner than Chrome's; painted per line to match.
                  <span
                    style={{
                      backgroundImage: `linear-gradient(${withAlpha(AppColors.blushGold, 0.7)}, ${withAlpha(AppColors.blushGold, 0.7)})`,
                      lineHeight: 'inherit',
                      backgroundRepeat: 'no-repeat',
                      backgroundSize: '100% 1.15px',
                      backgroundPosition: '0 calc(50% + 1.07px)',
                    }}
                  >
                    {item.title}
                  </span>
                ) : (
                  item.title
                )}
              </div>
              <div style={{ width: 8, flexShrink: 0 }} />
              {item.priority === 'urgent' && !isCompleted && (
                <div style={{ padding: '1px 6px 0 0', display: 'flex' }}>
                  <Icon name="local_fire_department" size={15} color={AppColors.error} />
                </div>
              )}
              <StatusPill status={effective} />
            </div>
            {item.description !== '' && (
              <>
                <div style={{ height: 3 }} />
                <div
                  style={{
                    ...text(12, withAlpha(AppColors.petalWhite, 0.5), false),
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {item.description}
                </div>
              </>
            )}
            <div style={{ height: 8 }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              <div style={{ padding: '4px 8px', borderRadius: AppRadius.sm, background: withAlpha(cat.hue, 0.12) }}>
                <div style={{ ...text(10, withAlpha(AppColors.petalWhite, 0.75), false, mixedLineHeight(10)), fontWeight: 600 }}>
                  {cat.emoji} {cat.name}
                </div>
              </div>
              {item.assignedTo != null && <AssigneePill username={item.assignedTo} />}
              {item.dueDate != null && <DuePill item={item} />}
            </div>
          </div>
        </div>
      </div>
    </DreamEntrance>
  );

  return (
    <div style={{ paddingBottom: 10 }}>
      {enableSwipe ? (
        <Swipeable
          allowRight={!isCompleted}
          onRight={() => void toggleComplete()}
          onLeft={() => confirmLetGo(item.title).then((yes) => (yes ? bucketListService.delete(item.id) : undefined))}
        >
          {card}
        </Swipeable>
      ) : (
        card
      )}
    </div>
  );
}

/** Dismissible that never dismisses itself: right fulfils, left asks to let go (40% threshold). */
function Swipeable({
  allowRight,
  onRight,
  onLeft,
  children,
}: {
  allowRight: boolean;
  onRight: () => void;
  onLeft: () => Promise<unknown>;
  children: ReactNode;
}) {
  const [dx, setDx] = useState(0);
  const [dragging, setDragging] = useState(false);
  const start = useRef<{ x: number; y: number; w: number; horizontal: boolean | null } | null>(null);
  const moved = useRef(false);
  const end = () => {
    const s = start.current;
    start.current = null;
    setDragging(false);
    if (!s?.horizontal) return;
    const fraction = Math.abs(dx) / s.w;
    setDx(0);
    if (fraction < 0.4) return;
    if (dx > 0) onRight();
    else void onLeft();
  };
  const bg = (right: boolean): CSSProperties => ({
    position: 'absolute',
    inset: 0,
    borderRadius: AppRadius.x2,
    display: 'flex',
    alignItems: 'center',
    justifyContent: right ? 'flex-start' : 'flex-end',
    padding: right ? '0 0 0 24px' : '0 24px 0 0',
    background: withAlpha(right ? AppColors.success : AppColors.error, right ? 0.16 : 0.12),
    border: `1px solid ${withAlpha(right ? AppColors.success : AppColors.error, right ? 0.35 : 0.3)}`,
  });
  return (
    <div
      style={{ position: 'relative', touchAction: 'pan-y' }}
      onPointerDown={(e) => {
        moved.current = false;
        start.current = { x: e.clientX, y: e.clientY, w: e.currentTarget.offsetWidth || 1, horizontal: null };
      }}
      onPointerMove={(e) => {
        const s = start.current;
        if (!s) return;
        const mx = e.clientX - s.x;
        const my = e.clientY - s.y;
        if (s.horizontal == null && Math.hypot(mx, my) > 8) {
          s.horizontal = Math.abs(mx) > Math.abs(my);
          if (s.horizontal) {
            e.currentTarget.setPointerCapture(e.pointerId);
            setDragging(true);
          }
        }
        if (s.horizontal) {
          moved.current = true;
          setDx(allowRight ? mx : Math.min(0, mx));
        }
      }}
      onPointerUp={end}
      onPointerCancel={end}
      onClickCapture={(e) => {
        if (moved.current) {
          e.stopPropagation();
          moved.current = false;
        }
      }}
    >
      {dx > 0 && (
        <div style={bg(true)}>
          <Icon name="check_circle" size={28} color={AppColors.success} />
        </div>
      )}
      {dx < 0 && (
        <div style={bg(false)}>
          <Icon name="delete" size={28} color={AppColors.error} />
        </div>
      )}
      <div
        style={{
          transform: dx ? `translateX(${dx}px)` : undefined,
          transition: dragging ? undefined : `transform ${orZero(200)}ms ease-out`,
        }}
      >
        {children}
      </div>
    </div>
  );
}

function FulfillRing({ completed, title, onTap }: { completed: boolean; title: string; onTap: () => void }) {
  const ms = orZero(AppMotion.medium);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={completed ? `Reopen ${title}` : `Mark ${title} fulfilled`}
      aria-pressed={completed}
      onClick={(e) => {
        e.stopPropagation();
        onTap();
      }}
      style={{
        width: 46,
        height: 46,
        flexShrink: 0,
        borderRadius: '50%',
        boxSizing: 'border-box',
        background: completed
          ? `linear-gradient(135deg, ${AppColors.blushGold}, ${AppColors.warmAmber})`
          : withAlpha(AppColors.moonlight, 0.05),
        border: `2px solid ${completed ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.45)}`,
        boxShadow: completed ? boxShadow([{ color: withAlpha(AppColors.blushGold, 0.4), blur: 12 }]) : 'none',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        transition: `background ${ms}ms ${CssCurves.easeOutStrong}, border-color ${ms}ms ${CssCurves.easeOutStrong}, box-shadow ${ms}ms ${CssCurves.easeOutStrong}`,
        cursor: 'pointer',
      }}
    >
      <Icon
        name={completed ? 'check' : 'auto_awesome'}
        size={completed ? 24 : 18}
        color={completed ? AppColors.inkDeep : withAlpha(AppColors.blushGold, 0.7)}
      />
    </button>
  );
}

function StatusPill({ status }: { status: BucketStatus }) {
  const hue = statusHue(status);
  return (
    <div
      style={{
        padding: '4px 8px',
        borderRadius: AppRadius.full,
        background: withAlpha(hue, 0.14),
        border: `1px solid ${withAlpha(hue, 0.35)}`,
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
      }}
    >
      <Icon name={statusIcon(status)} size={10} color={hue} />
      <div style={{ width: 4 }} />
      <span style={{ ...text(9, hue), ...letterSpacing(0.7), whiteSpace: 'nowrap' }}>{statusLabel(status).toUpperCase()}</span>
    </div>
  );
}

function AssigneePill({ username }: { username: string }) {
  const hue = assigneeHue(username);
  return (
    <div
      style={{
        padding: '4px 8px',
        borderRadius: AppRadius.sm,
        background: withAlpha(hue, 0.12),
        border: `1px solid ${withAlpha(hue, 0.25)}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={assigneeIcon(username)} size={10} color={hue} />
      <div style={{ width: 4 }} />
      <span style={text(10, hue)}>{assigneeLabel(username)}</span>
    </div>
  );
}

function DuePill({ item }: { item: BucketItem }) {
  const overdue = isBucketOverdue(item);
  const soon = isBucketDueSoon(item);
  const due = item.dueDate!;
  const hue = overdue ? AppColors.error : soon ? AppColors.warmAmber : withAlpha(AppColors.petalWhite, 0.6);
  return (
    <div
      style={{
        padding: '4px 8px',
        borderRadius: AppRadius.sm,
        background: overdue
          ? withAlpha(AppColors.error, 0.14)
          : soon
            ? withAlpha(AppColors.warmAmber, 0.12)
            : withAlpha(AppColors.moonlight, 0.07),
        border: overdue ? `1px solid ${withAlpha(AppColors.error, 0.4)}` : undefined,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={overdue ? 'warning' : 'calendar_today'} size={10} color={hue} />
      <div style={{ width: 4 }} />
      <span style={text(10, hue)}>{overdue ? `Overdue · ${MMMd(due)}` : MMMd(due)}</span>
    </div>
  );
}

function SectionLabel({ label }: { label: string }) {
  return <div style={{ ...text(10, withAlpha(AppColors.petalWhite, 0.5)), ...letterSpacing(1.4) }}>{label.toUpperCase()}</div>;
}

function DreamDetailSheet({ item, currentUsername, close }: { item: BucketItem; currentUsername: string; close: () => void }) {
  const { height } = useViewport();
  const hue = statusHue(item.status);
  const cat = categoryInfo(item.category);
  const isCompleted = item.status === 'completed';
  const overdue = isBucketOverdue(item);
  const after = (p: Promise<unknown>) => p.then(close);

  const planThis = async () => {
    if (item.calendarEventId != null) {
      void showDayDetailSheet(item.dueDate ?? new Date(), { background: AppColors.velvet });
      return;
    }
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const date = await pickDate({
      initial: item.dueDate && item.dueDate > now ? item.dueDate : now,
      first: today,
      last: new Date(now.getFullYear() + 10, 0, 1),
    });
    if (date == null) return;
    const saved = await showDialog<boolean>(
      (pop) => (
        <AddEventDialog
          selectedDay={date}
          initialType="dateNight"
          wish={{ id: item.id, title: item.title, description: item.description, notes: item.notes ?? '' }}
          close={pop}
        />
      ),
      { barrierColor: 'rgba(0,0,0,0.54)' },
    );
    if (saved === true) close();
  };

  const pickDueDate = async () => {
    const now = new Date();
    const picked = await pickDate({
      initial: item.dueDate ?? now,
      first: new Date(now.getTime() - 86_400_000),
      last: new Date(now.getTime() + 730 * 86_400_000),
    });
    if (picked) await after(bucketListService.setDueDate(item.id, picked));
  };

  return (
    <div style={{ width: '100%', minHeight: 0, display: 'flex', justifyContent: 'center' }}>
      <div
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: height - 48,
          overflowY: 'auto',
          padding: '12px 24px 32px',
          background: AppColors.velvet,
          borderRadius: `${AppRadius.x3}px ${AppRadius.x3}px 0 0`,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
          boxSizing: 'border-box',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div
          style={{
            alignSelf: 'center',
            width: 40,
            height: 4,
            marginBottom: 16,
            flexShrink: 0,
            borderRadius: AppRadius.full,
            background: withAlpha(AppColors.petalWhite, 0.3),
          }}
        />
        <div style={{ display: 'flex', alignItems: 'flex-start' }}>
          <div
            style={{
              width: 60,
              height: 60,
              flexShrink: 0,
              boxSizing: 'border-box',
              borderRadius: AppRadius.lg,
              background: `linear-gradient(135deg, ${withAlpha(cat.hue, 0.3)}, ${withAlpha(cat.hue, 0.08)})`,
              border: `1px solid ${withAlpha(cat.hue, 0.4)}`,
              boxShadow: boxShadow([{ color: withAlpha(cat.hue, 0.2), blur: 14, offset: [0, 4] }]),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 30,
              lineHeight: mixedLineHeight(30),
            }}
          >
            {cat.emoji}
          </div>
          <div style={{ width: 14, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 24, lineHeight: lineHeight(24, 1.05) }}>{item.title}</div>
            <div style={{ height: 4 }} />
            <div style={text(11, withAlpha(AppColors.petalWhite, 0.5), false)}>
              Dreamed up by {item.createdBy} · {yMMMd(item.createdAt)}
            </div>
            {item.completedAt != null && (
              <>
                <div style={{ height: 2 }} />
                <div style={text(11, withAlpha(AppColors.success, 0.9), true, mixedLineHeight(11))}>
                  💛 Fulfilled by {item.completedBy ?? 'us'} · {yMMMd(item.completedAt)}
                </div>
              </>
            )}
          </div>
          <SheetIconButton icon="close" label="Close" onTap={close} />
        </div>
        {item.description !== '' && (
          <>
            <div style={{ height: 12 }} />
            <div style={text(14, withAlpha(AppColors.petalWhite, 0.8), false, lineHeight(14, 1.4))}>{item.description}</div>
          </>
        )}
        <div style={{ height: 18 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {!isCompleted ? (
            <TextButton
              color={AppColors.roseQuartz}
              icon={<Icon name="event_available_outlined" size={18} color={AppColors.roseQuartz} />}
              onPressed={() => void planThis()}
            >
              {item.calendarEventId != null ? 'View calendar plan' : 'Plan this'}
            </TextButton>
          ) : (
            <TextButton
              color={AppColors.roseQuartz}
              icon={<Icon name="auto_stories_outlined" size={18} color={AppColors.roseQuartz} />}
              onPressed={() =>
                void openSharedMemory({
                  title: item.title,
                  date: item.completedAt ?? new Date(),
                  bucketItemId: item.id,
                  calendarEventId: item.calendarEventId,
                })
              }
            >
              Keep this memory
            </TextButton>
          )}
        </div>
        <div style={{ height: 12 }} />
        <SectionLabel label="Dream journey" />
        <div style={{ height: 10 }} />
        <JourneyStepper
          status={item.status}
          onMove={(s) => {
            if (s === item.status) return;
            void after(bucketListService.moveStatus(item.id, s, currentUsername === '' ? undefined : currentUsername));
          }}
        />
        <div style={{ height: 18 }} />
        <SectionLabel label="Details — tap to change" />
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', gap: 8 }}>
          <MetaTile
            label="Dreamer"
            value={assigneeLabel(item.assignedTo)}
            icon={assigneeIcon(item.assignedTo)}
            hue={assigneeHue(item.assignedTo)}
            onTap={() => void after(bucketListService.assign(item.id, nextAssignee(item.assignedTo)))}
          />
          <MetaTile
            label="Dream date"
            value={item.dueDate == null ? 'Someday' : MMMd(item.dueDate)}
            icon={overdue ? 'warning' : 'calendar_today'}
            hue={overdue ? AppColors.error : AppColors.blushGold}
            onTap={() => void pickDueDate()}
            onClear={item.dueDate == null ? undefined : () => void after(bucketListService.setDueDate(item.id, undefined))}
          />
          <MetaTile
            label="Pace"
            value={priorityShort(item.priority)}
            icon="speed"
            hue={priorityHue(item.priority)}
            onTap={() => {
              const next = BUCKET_PRIORITIES[(BUCKET_PRIORITIES.indexOf(item.priority) + 1) % BUCKET_PRIORITIES.length];
              void after(bucketListService.setPriority(item.id, next));
            }}
          />
        </div>
        <div style={{ height: 20 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <PrimaryAction
            label={isCompleted ? 'Reopen dream' : 'Mark fulfilled 💛'}
            icon={isCompleted ? 'refresh' : 'check'}
            filled={!isCompleted}
            onTap={() =>
              void after(
                isCompleted
                  ? bucketListService.markUncomplete(item.id)
                  : bucketListService.markComplete(item.id, currentUsername),
              )
            }
          />
          <div style={{ width: 10, flexShrink: 0 }} />
          <SheetIconButton
            icon="delete_outline"
            label="Delete dream"
            danger
            onTap={async () => {
              if (!(await confirmLetGo(item.title))) return;
              await after(bucketListService.delete(item.id));
            }}
          />
        </div>
        <div style={{ height: 4 }} />
        <div style={{ alignSelf: 'center', ...text(10, withAlpha(hue, 0.7), false) }}>
          {cat.name} · {statusLabel(item.status)}
        </div>
      </div>
    </div>
  );
}

function JourneyStepper({ status, onMove }: { status: BucketStatus; onMove: (s: BucketStatus) => void }) {
  const current = BUCKET_STATUSES.indexOf(status);
  const ms = orZero(AppMotion.fast);
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      {BUCKET_STATUSES.map((stage, i) => {
        const hue = statusHue(stage);
        const reached = i <= current;
        const isCurrent = i === current;
        const bw = isCurrent ? 1.6 : 1;
        return [
          i > 0 && (
            <div
              key={`l${i}`}
              style={{
                flex: 1,
                height: 2,
                margin: '0 4px',
                borderRadius: AppRadius.full,
                background: i <= current ? withAlpha(AppColors.blushGold, 0.6) : withAlpha(AppColors.moonlight, 0.12),
              }}
            />
          ),
          <button
            key={stage}
            type="button"
            className="bare-button"
            aria-label={`Move to ${statusLabel(stage)}`}
            aria-pressed={isCurrent}
            onClick={isCurrent ? undefined : () => onMove(stage)}
            style={{
              padding: `${9 + bw}px ${12 + bw}px`,
              borderRadius: AppRadius.lg,
              background: isCurrent ? withAlpha(hue, 0.18) : reached ? withAlpha(hue, 0.08) : AppColors.twilight,
              boxShadow: `inset 0 0 0 ${bw}px ${isCurrent ? hue : withAlpha(hue, reached ? 0.4 : 0.15)}`,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              flexShrink: 0,
              transition: `background ${ms}ms, box-shadow ${ms}ms, padding ${ms}ms`,
              cursor: isCurrent ? 'default' : 'pointer',
            }}
          >
            <Icon
              name={reached ? statusIcon(stage) : 'circle_outlined'}
              size={18}
              color={reached ? hue : withAlpha(AppColors.petalWhite, 0.35)}
            />
            <div style={{ height: 4 }} />
            <span style={text(10, reached ? hue : withAlpha(AppColors.petalWhite, 0.4))}>{statusLabel(stage)}</span>
          </button>,
        ];
      })}
    </div>
  );
}

function MetaTile({
  label,
  value,
  icon,
  hue,
  onTap,
  onClear,
}: {
  label: string;
  value: string;
  icon: string;
  hue: string;
  onTap: () => void;
  onClear?: () => void;
}) {
  return (
    <div
      role="button"
      tabIndex={0}
      aria-label={`${label}: ${value}`}
      onClick={onTap}
      onKeyDown={(e) => e.key === 'Enter' && onTap()}
      style={{
        flex: 1,
        minWidth: 0,
        padding: '12px 10px',
        borderRadius: AppRadius.lg,
        background: withAlpha(AppColors.moonlight, 0.06),
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.12)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <Icon name={icon} size={15} color={hue} />
        {onClear && (
          <>
            <div style={{ width: 4 }} />
            <button
              type="button"
              className="bare-button"
              aria-label={`Clear ${label}`}
              onClick={(e) => {
                e.stopPropagation();
                onClear();
              }}
              style={{ display: 'flex', cursor: 'pointer' }}
            >
              <Icon name="cancel" size={13} color={withAlpha(AppColors.petalWhite, 0.4)} />
            </button>
          </>
        )}
      </div>
      <div style={{ height: 6 }} />
      <div style={{ ...text(12, hue), maxWidth: '100%', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
        {value}
      </div>
      <div style={{ height: 2 }} />
      <div style={text(10, withAlpha(AppColors.petalWhite, 0.45), false)}>{label}</div>
    </div>
  );
}

function PrimaryAction({ label, icon, filled, onTap }: { label: string; icon: string; filled: boolean; onTap: () => void }) {
  const fg = filled ? AppColors.petalWhite : AppColors.blushGold;
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={onTap}
      style={{
        flex: 1,
        minWidth: 0,
        padding: '14px 0',
        borderRadius: AppRadius.lg,
        background: filled
          ? `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.rosePressed})`
          : withAlpha(AppColors.moonlight, 0.07),
        border: `1px solid ${withAlpha(AppColors.blushGold, filled ? 0.3 : 0.2)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name={icon} size={16} color={fg} />
      <div style={{ width: 8 }} />
      <span style={text(14, fg, true, filled ? mixedLineHeight(14) : undefined)}>{label}</span>
    </button>
  );
}

function SheetIconButton({
  icon,
  label,
  danger = false,
  onTap,
}: {
  icon: string;
  label: string;
  danger?: boolean;
  onTap: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={onTap}
      style={{
        width: 48,
        height: 48,
        flexShrink: 0,
        boxSizing: 'border-box',
        borderRadius: AppRadius.lg,
        background: danger ? withAlpha(AppColors.error, 0.1) : withAlpha(AppColors.moonlight, 0.07),
        border: `1px solid ${danger ? withAlpha(AppColors.error, 0.3) : withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name={icon} size={20} color={danger ? AppColors.error : AppColors.petalWhite} />
    </button>
  );
}
