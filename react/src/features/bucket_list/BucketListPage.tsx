// Port of lib/features/bucket_list/presentation/screens/bucket_list_screen.dart.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { authService, useAuth } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { boxShadow, letterSpacing, lineHeight, mixedLineHeight, radial, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { showAddBucketItemSheet } from './AddBucketItemSheet';
import { BucketItemCard } from './BucketItemCard';
import { BucketKanbanBoard } from './BucketKanbanBoard';
import { bucketListService, isBucketOverdue, type BucketItem, type BucketPriority, type BucketStatus } from './bucketListService';
import {
  BUCKET_CLAIR,
  BUCKET_KHENT,
  BUCKET_PRIORITIES,
  paintBucketStars,
  priorityHue,
  priorityShort,
  sortDreams,
  STATUS_EMOJI,
  statusHue,
} from './bucketUi';

type ViewMode = 'list' | 'board';
type Filters = { status: BucketStatus | null; assignee: string | null; priority: BucketPriority | null; overdueOnly: boolean };

const NO_FILTERS: Filters = { status: null, assignee: null, priority: null, overdueOnly: false };

const bold = (size: number, color: string, height?: string): CSSProperties => ({
  ...AppTypography.outfitBold,
  fontSize: size,
  lineHeight: height ?? lineHeight(size),
  color,
});

function filtered(all: BucketItem[], f: Filters): BucketItem[] {
  return all
    .filter(
      (i) =>
        (f.status == null || i.status === f.status) &&
        (f.assignee == null || (f.assignee === 'unassigned' ? i.assignedTo == null : i.assignedTo === f.assignee)) &&
        (f.priority == null || i.priority === f.priority) &&
        (!f.overdueOnly || isBucketOverdue(i)),
    )
    .sort(sortDreams);
}

const addDream = () => showAddBucketItemSheet(authService.currentUser ?? 'unknown');

/** _Constrained: centred, at most 720 wide. */
function Constrained({ children, fill = false }: { children: ReactNode; fill?: boolean }) {
  return (
    <div
      style={{
        width: '100%',
        maxWidth: 720,
        alignSelf: 'center',
        flexShrink: 0,
        ...(fill ? { flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' } : {}),
      }}
    >
      {children}
    </div>
  );
}

export function BucketListPage() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? '';
  const [view, setView] = useState<ViewMode>('list');
  const [f, setF] = useState<Filters>(NO_FILTERS);
  const [retry, setRetry] = useState(0);
  const hasAnyFilter = f.status != null || f.assignee != null || f.priority != null || f.overdueOnly;

  const content = (all: BucketItem[], items: BucketItem[]) => {
    if (all.length === 0) {
      return (
        <EverglowEmptyState
          icon="auto_awesome_outlined"
          title="No dreams yet"
          subtitle="Plant your first star together"
          ctaLabel="Plant a dream"
          onCta={addDream}
        />
      );
    }
    if (items.length === 0) {
      return (
        <EverglowEmptyState
          icon="search_off"
          title="No matching dreams"
          subtitle="Try a different filter"
          ctaLabel={hasAnyFilter ? 'Clear filters' : undefined}
          onCta={hasAnyFilter ? () => setF(NO_FILTERS) : undefined}
        />
      );
    }
    if (view === 'board') return <BucketKanbanBoard items={items} currentUsername={currentUser} onAdd={addDream} />;
    return (
      <Constrained fill>
        <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '4px 16px 96px' }}>
          {items.map((it, i) => (
            <BucketItemCard key={it.id} item={it} currentUsername={currentUser} entranceDelay={Math.min(i, 8) * 45} />
          ))}
        </div>
      </Constrained>
    );
  };

  return (
    <EverglowScaffold backgroundColor={AppColors.inkDeep} floatingActionButton={<NewDreamFab onTap={addDream} />}>
      <EverglowFeatureHeader
        title="Our Bucket List"
        subtitle="dreams we chase together"
        icon="auto_awesome"
        hue={AppColors.blushGold}
        actions={[<ViewToggle key="view" view={view} onTap={() => setView(view === 'list' ? 'board' : 'list')} />]}
      />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <EverglowStreamView<BucketItem[]>
          source={() => bucketListService.watchAll()}
          sourceKey={[retry]}
          label="bucket-list"
          errorMessage="Could not load bucket list"
          onRetry={() => setRetry((r) => r + 1)}
          isEmpty={() => false}
          loadingView={<LoadingDreams />}
          builder={(all) => (
            <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column' }}>
              <Constrained>
                <JourneyHero
                  all={all}
                  selected={f.status}
                  overdueOnly={f.overdueOnly}
                  onSelect={(s) => setF({ ...f, status: f.status === s ? null : s })}
                  onOverdueTap={() => setF({ ...f, overdueOnly: !f.overdueOnly })}
                />
              </Constrained>
              <Constrained>
                <FilterRow f={f} setF={setF} />
              </Constrained>
              <div style={{ height: 4, flexShrink: 0 }} />
              <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
                {content(all, filtered(all, f))}
              </div>
            </div>
          )}
        />
      </div>
    </EverglowScaffold>
  );
}

function ViewToggle({ view, onTap }: { view: ViewMode; onTap: () => void }) {
  const isList = view === 'list';
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={isList ? 'Show board view' : 'Show list view'}
      onClick={onTap}
      style={{
        padding: '8px 12px',
        borderRadius: AppRadius.full,
        background: withAlpha(AppColors.moonlight, 0.08),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name={isList ? 'view_kanban' : 'view_list'} size={14} color={AppColors.blushGold} />
      <div style={{ width: 6 }} />
      <span style={bold(11, AppColors.blushGold)}>{isList ? 'Board' : 'List'}</span>
    </button>
  );
}

function headline(total: number, done: number, progress: number) {
  if (total === 0) return 'Every love story needs a first dream';
  if (progress >= 1) return 'Every dream came true — dream more!';
  if (progress >= 0.66) return 'Look how far we’ve wandered';
  if (progress >= 0.33) return 'Our story is unfolding';
  if (done > 0) return 'Dreams are coming true';
  return 'So many stars left to chase';
}

function StarsCanvas() {
  const ref = useRef<HTMLCanvasElement>(null);
  const [boxRef, size] = useBoxSize<HTMLDivElement>();
  useEffect(() => {
    const c = ref.current;
    if (!c || !size) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    c.width = Math.round(size[0] * dpr);
    c.height = Math.round(size[1] * dpr);
    const ctx = c.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, size[0], size[1]);
    paintBucketStars(ctx, size[0], size[1]);
  }, [size]);
  return (
    <div ref={boxRef} aria-hidden style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
      <canvas ref={ref} style={{ width: '100%', height: '100%', display: 'block' }} />
    </div>
  );
}

function JourneyHero({
  all,
  selected,
  overdueOnly,
  onSelect,
  onOverdueTap,
}: {
  all: BucketItem[];
  selected: BucketStatus | null;
  overdueOnly: boolean;
  onSelect: (s: BucketStatus | null) => void;
  onOverdueTap: () => void;
}) {
  const total = all.length;
  const completed = all.filter((i) => i.status === 'completed').length;
  const wishes = all.filter((i) => i.status === 'wish').length;
  const planned = all.filter((i) => i.status === 'planned').length;
  const overdue = all.filter(isBucketOverdue).length;
  const progress = total > 0 ? completed / total : 0;
  const [ref, size] = useBoxSize<HTMLDivElement>();

  return (
    <div style={{ padding: '4px 16px 10px' }}>
      <div style={{ position: 'relative' }}>
        <div
          aria-hidden
          style={shadowLayer({ color: withAlpha('#000000', 0.45), blur: 24, offset: [0, 10] }, { radius: AppRadius.x2 })}
        />
        <div
          aria-hidden
          style={shadowLayer({ color: withAlpha(AppColors.blushGold, 0.07), blur: 28, spread: -6 }, { radius: AppRadius.x2 })}
        />
        <div
          ref={ref}
          style={{
            position: 'relative',
            borderRadius: AppRadius.x2,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
            overflow: 'hidden',
          }}
        >
          {/* The silk gradient Container has no child, so Flutter lays it out 0px tall: only the glow and stars paint. */}
          <div
            aria-hidden
            style={{
              position: 'absolute',
              inset: 0,
              background: size
                ? radial([withAlpha(AppColors.auroraGold, 0.16), withAlpha(AppColors.auroraGold, 0)], {
                    center: [0.85, -0.7],
                    radius: 1.1,
                    size: [size[0] - 2, size[1] - 2],
                  })
                : undefined,
            }}
          />
          <StarsCanvas />
          <div
            aria-hidden
            style={{
              position: 'absolute',
              top: 0,
              left: 24,
              right: 24,
              height: 1.4,
              background: `linear-gradient(90deg, rgba(0,0,0,0), ${withAlpha(AppColors.blushGold, 0.5)}, rgba(0,0,0,0))`,
            }}
          />
          <div style={{ position: 'relative', padding: '18px 20px 16px', display: 'flex', flexDirection: 'column' }}>
            <div style={{ ...AppTypography.handwrittenBody, fontSize: 19, lineHeight: 1.1, color: withAlpha(AppColors.blushGold, 0.9) }}>our journey so far</div>
            <div style={{ height: 4 }} />
            <div
              style={{
                ...AppTypography.cormorantBold,
                fontSize: 24,
                lineHeight: lineHeight(24, 1.05),
                color: AppColors.petalWhite,
              }}
            >
              {headline(total, completed, progress)}
            </div>
            <div style={{ height: 4 }} />
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <div
                style={{
                  flex: 1,
                  minWidth: 0,
                  ...AppTypography.outfitWhite,
                  fontSize: 12,
                  lineHeight: lineHeight(12),
                  color: withAlpha(AppColors.petalWhite, 0.62),
                }}
              >
                {total === 0
                  ? 'Your story is waiting for its first dream'
                  : `${completed} of ${total} dreams fulfilled · ${Math.round(progress * 100)}%`}
              </div>
              {overdue > 0 && <OverdueNudge count={overdue} active={overdueOnly} onTap={onOverdueTap} />}
            </div>
            <div style={{ height: 12 }} />
            <TrailBar progress={progress} />
            <div style={{ height: 14 }} />
            <div
              style={{
                padding: 4,
                background: withAlpha(AppColors.inkDeep, 0.45),
                borderRadius: AppRadius.xl,
                border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
                display: 'flex',
              }}
            >
              <Segment
                emoji="✨"
                label="All"
                count={total}
                hue={AppColors.roseQuartz}
                status={null}
                selected={selected}
                onSelect={onSelect}
              />
              <Segment
                emoji={STATUS_EMOJI.wish}
                label="Wishes"
                count={wishes}
                hue={statusHue('wish')}
                status="wish"
                selected={selected}
                onSelect={onSelect}
              />
              <Segment
                emoji={STATUS_EMOJI.planned}
                label="Planned"
                count={planned}
                hue={statusHue('planned')}
                status="planned"
                selected={selected}
                onSelect={onSelect}
              />
              <Segment
                emoji={STATUS_EMOJI.completed}
                label="Done"
                count={completed}
                hue={statusHue('completed')}
                status="completed"
                selected={selected}
                onSelect={onSelect}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function TrailBar({ progress }: { progress: number }) {
  const p = Math.min(1, Math.max(0, progress));
  const ms = orZero(AppMotion.medium);
  return (
    <div style={{ position: 'relative', height: 22 }}>
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 7,
          height: 8,
          borderRadius: AppRadius.full,
          background: withAlpha(AppColors.moonlight, 0.1),
        }}
      />
      {p > 0 && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: 7,
            height: 8,
            width: `${p * 100}%`,
            borderRadius: AppRadius.full,
            background: `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.auroraGold})`,
            boxShadow: boxShadow([{ color: withAlpha(AppColors.auroraGold, 0.35), blur: 10 }]),
            transition: `width ${ms}ms ${CssCurves.easeOutStrong}`,
          }}
        />
      )}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: `clamp(0px, calc(${p * 100}% - 11px), calc(100% - 22px))`,
          width: 22,
          height: 22,
          borderRadius: '50%',
          background: AppColors.inkDeep,
          boxShadow: `inset 0 0 0 1.4px ${withAlpha(AppColors.blushGold, 0.7)}, ${boxShadow([
            { color: withAlpha(AppColors.blushGold, 0.45), blur: 8 },
          ])}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="star" size={13} color={AppColors.blushGold} />
      </div>
    </div>
  );
}

function OverdueNudge({ count, active, onTap }: { count: number; active: boolean; onTap: () => void }) {
  const ms = orZero(AppMotion.fast);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Show overdue dreams"
      aria-pressed={active}
      onClick={onTap}
      style={{
        padding: '5px 9px',
        borderRadius: AppRadius.full,
        background: withAlpha(AppColors.error, active ? 0.22 : 0.1),
        border: `1px solid ${withAlpha(AppColors.error, active ? 0.8 : 0.35)}`,
        display: 'flex',
        alignItems: 'center',
        transition: `background ${ms}ms, border-color ${ms}ms`,
        cursor: 'pointer',
      }}
    >
      <Icon name="warning" size={11} color={AppColors.error} />
      <div style={{ width: 4 }} />
      <span style={bold(10, AppColors.error)}>
        {count} need{count === 1 ? 's' : ''} love
      </span>
    </button>
  );
}

function Segment({
  emoji,
  label,
  count,
  hue,
  status,
  selected,
  onSelect,
}: {
  emoji: string;
  label: string;
  count: number;
  hue: string;
  status: BucketStatus | null;
  selected: BucketStatus | null;
  onSelect: (s: BucketStatus | null) => void;
}) {
  const isSelected = selected === status;
  const ms = orZero(AppMotion.fast);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={`Filter by ${label}`}
      aria-pressed={isSelected}
      onClick={() => onSelect(isSelected ? null : status)}
      style={{
        flex: 1,
        minWidth: 0,
        padding: '8px 0',
        borderRadius: AppRadius.lg,
        background: isSelected ? withAlpha(hue, 0.16) : 'rgba(0,0,0,0)',
        border: `1px solid ${isSelected ? withAlpha(hue, 0.55) : 'rgba(0,0,0,0)'}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        transition: `background ${ms}ms ${CssCurves.easeOutStrong}, border-color ${ms}ms ${CssCurves.easeOutStrong}`,
        cursor: 'pointer',
      }}
    >
      <span style={{ fontSize: 14, lineHeight: mixedLineHeight(14) }}>{emoji}</span>
      <div style={{ height: 3 }} />
      <span style={{ ...bold(9.5, isSelected ? hue : withAlpha(AppColors.petalWhite, 0.55)), ...letterSpacing(0.4) }}>
        {label}
      </span>
      <span style={bold(13, isSelected ? hue : withAlpha(AppColors.petalWhite, 0.85))}>{count}</span>
    </button>
  );
}

function FilterRow({ f, setF }: { f: Filters; setF: (f: Filters) => void }) {
  const hasSecondary = f.assignee != null || f.priority != null || f.overdueOnly;
  const gap = <div style={{ width: 8, flexShrink: 0 }} />;
  const divider = (
    <div style={{ padding: '0 12px', flexShrink: 0 }}>
      <div style={{ width: 4, height: 4, borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.3) }} />
    </div>
  );
  return (
    <div style={{ paddingBottom: 10 }}>
      <div className="no-scrollbar" style={{ overflowX: 'auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '0 16px', width: 'max-content' }}>
          {hasSecondary && (
            <>
              <ClearPill onTap={() => setF({ ...f, assignee: null, priority: null, overdueOnly: false })} />
              {gap}
            </>
          )}
          <FilterPill
            label="Everyone"
            icon="groups"
            hue={AppColors.roseQuartz}
            selected={f.assignee == null}
            onTap={() => setF({ ...f, assignee: null })}
          />
          {gap}
          <FilterPill
            label="Khent"
            icon="person"
            hue={AppColors.auroraTeal}
            selected={f.assignee === BUCKET_KHENT}
            onTap={() => setF({ ...f, assignee: BUCKET_KHENT })}
          />
          {gap}
          <FilterPill
            label="Clair"
            icon="favorite"
            hue={AppColors.auroraRose}
            selected={f.assignee === BUCKET_CLAIR}
            onTap={() => setF({ ...f, assignee: BUCKET_CLAIR })}
          />
          {gap}
          <FilterPill
            label="Unassigned"
            icon="person_outline"
            hue={AppColors.mutedPurple}
            selected={f.assignee === 'unassigned'}
            onTap={() => setF({ ...f, assignee: 'unassigned' })}
          />
          {divider}
          <FilterPill
            label="Any pace"
            icon="speed"
            hue={AppColors.roseQuartz}
            selected={f.priority == null}
            onTap={() => setF({ ...f, priority: null })}
          />
          {gap}
          {BUCKET_PRIORITIES.map((p) => (
            <div key={p} style={{ paddingRight: 8, flexShrink: 0 }}>
              <FilterPill
                label={priorityShort(p)}
                dot={priorityHue(p)}
                hue={priorityHue(p)}
                selected={f.priority === p}
                onTap={() => setF({ ...f, priority: p })}
              />
            </div>
          ))}
          {divider}
          <FilterPill
            label="Overdue"
            icon="warning"
            hue={AppColors.error}
            selected={f.overdueOnly}
            onTap={() => setF({ ...f, overdueOnly: !f.overdueOnly })}
          />
        </div>
      </div>
    </div>
  );
}

function FilterPill({
  label,
  icon,
  dot,
  hue,
  selected,
  onTap,
}: {
  label: string;
  icon?: string;
  dot?: string;
  hue: string;
  selected: boolean;
  onTap: () => void;
}) {
  const ms = orZero(AppMotion.fast);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      aria-pressed={selected}
      onClick={onTap}
      style={{
        padding: '7px 11px',
        flexShrink: 0,
        borderRadius: AppRadius.full,
        background: selected ? withAlpha(hue, 0.16) : withAlpha(AppColors.moonlight, 0.05),
        border: `1px solid ${selected ? withAlpha(hue, 0.6) : withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
        transition: `background ${ms}ms, border-color ${ms}ms`,
        cursor: 'pointer',
      }}
    >
      {dot && (
        <>
          <div style={{ width: 7, height: 7, borderRadius: '50%', background: dot }} />
          <div style={{ width: 6 }} />
        </>
      )}
      {icon && (
        <>
          <Icon name={icon} size={12} color={selected ? hue : withAlpha(AppColors.petalWhite, 0.55)} />
          <div style={{ width: 5 }} />
        </>
      )}
      <span style={{ ...bold(11, selected ? hue : withAlpha(AppColors.petalWhite, 0.6)), whiteSpace: 'nowrap' }}>{label}</span>
    </button>
  );
}

function ClearPill({ onTap }: { onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Clear filters"
      onClick={onTap}
      style={{
        padding: '7px 10px',
        flexShrink: 0,
        borderRadius: AppRadius.full,
        background: withAlpha(AppColors.blushGold, 0.12),
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name="close" size={12} color={AppColors.blushGold} />
      <div style={{ width: 4 }} />
      <span style={bold(11, AppColors.blushGold)}>Clear</span>
    </button>
  );
}

function NewDreamFab({ onTap }: { onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Plant a new dream"
      onClick={onTap}
      style={{
        padding: '14px 20px',
        borderRadius: AppRadius.full,
        background: `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.rosePressed})`,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.35), blur: 20, offset: [0, 8] }]),
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name="add" size={18} color={AppColors.petalWhite} />
      <div style={{ width: 6 }} />
      <span style={bold(14, AppColors.petalWhite)}>New dream</span>
    </button>
  );
}

function LoadingDreams() {
  return (
    <div style={{ padding: '4px 16px 24px', display: 'flex', flexDirection: 'column' }}>
      <EverglowSkeleton height={250} radius={24} />
      <div style={{ height: 12 }} />
      <EverglowSkeleton height={92} radius={20} />
      <div style={{ height: 10 }} />
      <EverglowSkeleton height={92} radius={20} />
      <div style={{ height: 10 }} />
      <EverglowSkeleton height={92} radius={20} />
    </div>
  );
}
