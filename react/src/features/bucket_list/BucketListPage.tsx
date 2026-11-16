// Port of lib/features/bucket_list/presentation/screens/bucket_list_screen.dart
// + bucket_item_card.dart + bucket_kanban_board.dart + add_bucket_item_sheet.dart.
import { useMemo, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
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
  BUCKET_CATEGORIES,
  BUCKET_PRIORITY_META,
  BUCKET_STATUS_META,
  bucketAssigneeHue,
  bucketAssigneeLabel,
  bucketCategoryMeta,
  bucketListService,
  isBucketDueSoon,
  isBucketOverdue,
  type BucketCategory,
  type BucketItem,
  type BucketPriority,
  type BucketStatus,
} from './bucketListService';

type ViewMode = 'list' | 'board';

export function BucketListPage() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? 'khentsgdz';
  const { width } = useViewport();

  const allItems = useSource<BucketItem[]>(() => bucketListService.watchAll(), [], []);
  const [statusFilter, setStatusFilter] = useState<BucketStatus | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>('list');
  const [assigneeFilter, setAssigneeFilter] = useState<string | null>(null);
  const [priorityFilter, setPriorityFilter] = useState<BucketPriority | null>(null);
  const [overdueOnly, setOverdueOnly] = useState(false);

  const [detailItem, setDetailItem] = useState<BucketItem | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  const filteredItems = useMemo(() => {
    return allItems
      .filter((i) => {
        if (statusFilter && i.status !== statusFilter) return false;
        if (assigneeFilter) {
          if (assigneeFilter === 'unassigned') {
            if (i.assignedTo) return false;
          } else if (i.assignedTo !== assigneeFilter) {
            return false;
          }
        }
        if (priorityFilter && i.priority !== priorityFilter) return false;
        if (overdueOnly && !isBucketOverdue(i)) return false;
        return true;
      })
      .sort((a, b) => {
        const pr = BUCKET_PRIORITY_META[b.priority].rank - BUCKET_PRIORITY_META[a.priority].rank;
        if (pr !== 0) return pr;
        if (a.dueDate && b.dueDate) return a.dueDate.getTime() - b.dueDate.getTime();
        if (a.dueDate) return -1;
        if (b.dueDate) return 1;
        return b.createdAt.getTime() - a.createdAt.getTime();
      });
  }, [allItems, statusFilter, assigneeFilter, priorityFilter, overdueOnly]);

  const hasSecondary = assigneeFilter != null || priorityFilter != null || overdueOnly;
  const hasAnyFilter = statusFilter != null || hasSecondary;

  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden' }}>
      <EverglowBackground baseColor={AppColors.inkDeep} />
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
        <div style={{ maxWidth: 720, width: '100%', margin: '0 auto' }}>
          <EverglowFeatureHeader
            title="Our Bucket List"
            subtitle="dreams we chase together"
            icon="auto_awesome"
            hue={AppColors.blushGold}
            actions={[
              <Tooltip key="view" message={viewMode === 'list' ? 'Board view' : 'List view'}>
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Toggle board view"
                  onClick={() => setViewMode((m) => (m === 'list' ? 'board' : 'list'))}
                  style={{
                    width: 40,
                    height: 40,
                    borderRadius: '50%',
                    background: withAlpha(AppColors.moonlight, 0.08),
                    border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Icon
                    name={viewMode === 'list' ? 'view_kanban' : 'view_agenda'}
                    size={18}
                    color={AppColors.blushGold}
                  />
                </button>
              </Tooltip>,
            ]}
          />

          <JourneyHero
            all={allItems}
            selected={statusFilter}
            overdueOnly={overdueOnly}
            onSelect={(s) => setStatusFilter((cur) => (cur === s ? null : s))}
            onOverdueTap={() => setOverdueOnly((o) => !o)}
          />

          {/* Secondary Filter Row */}
          <div
            className="no-scrollbar"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              overflowX: 'auto',
              padding: '0 16px 10px',
            }}
          >
            {hasSecondary && (
              <FilterPill
                label="Clear"
                icon="close"
                hue={AppColors.blushGold}
                selected
                onClick={() => {
                  setAssigneeFilter(null);
                  setPriorityFilter(null);
                  setOverdueOnly(false);
                }}
              />
            )}
            <FilterPill
              label="Everyone"
              icon="groups"
              hue={AppColors.roseQuartz}
              selected={assigneeFilter == null}
              onClick={() => setAssigneeFilter(null)}
            />
            <FilterPill
              label="Khent"
              icon="person"
              hue={AppColors.auroraTeal}
              selected={assigneeFilter === 'khentsgdz'}
              onClick={() => setAssigneeFilter(assigneeFilter === 'khentsgdz' ? null : 'khentsgdz')}
            />
            <FilterPill
              label="Clair"
              icon="favorite"
              hue={AppColors.auroraRose}
              selected={assigneeFilter === 'clairjassen'}
              onClick={() => setAssigneeFilter(assigneeFilter === 'clairjassen' ? null : 'clairjassen')}
            />
            <FilterPill
              label="Urgent"
              icon="local_fire_department"
              hue={AppColors.error}
              selected={priorityFilter === 'urgent'}
              onClick={() => setPriorityFilter(priorityFilter === 'urgent' ? null : 'urgent')}
            />
            <FilterPill
              label="High"
              icon="arrow_upward"
              hue={AppColors.warmAmber}
              selected={priorityFilter === 'high'}
              onClick={() => setPriorityFilter(priorityFilter === 'high' ? null : 'high')}
            />
          </div>
        </div>

        {/* Content */}
        {allItems.length === 0 ? (
          <div style={{ padding: 48, textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <Icon name="auto_awesome" variant="outlined" size={48} color={withAlpha(AppColors.blushGold, 0.7)} />
            <div style={{ height: 12 }} />
            <div style={{ ...AppTypography.outfitBold, fontSize: 16 }}>No dreams yet</div>
            <div style={{ ...AppTypography.bodySmall, marginTop: 6, color: Derived.textMedium }}>
              Plant your first star together
            </div>
            <div style={{ marginTop: 18 }}>
              <EverglowButton label="Plant a dream" onPressed={() => setAddOpen(true)} />
            </div>
          </div>
        ) : filteredItems.length === 0 ? (
          <div style={{ padding: 48, textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <Icon name="search_off" size={44} color={Derived.textMuted} />
            <div style={{ height: 10 }} />
            <div style={{ ...AppTypography.outfitBold, fontSize: 15 }}>No matching dreams</div>
            <div style={{ ...AppTypography.bodySmall, marginTop: 4, color: Derived.textMedium }}>
              Try a different filter
            </div>
            {hasAnyFilter && (
              <div style={{ marginTop: 14 }}>
                <EverglowButton
                  label="Clear filters"
                  variant="glass"
                  onPressed={() => {
                    setStatusFilter(null);
                    setAssigneeFilter(null);
                    setPriorityFilter(null);
                    setOverdueOnly(false);
                  }}
                />
              </div>
            )}
          </div>
        ) : viewMode === 'board' ? (
          <div
            className="no-scrollbar"
            style={{
              display: 'flex',
              gap: 12,
              overflowX: 'auto',
              padding: '4px 16px 24px',
              alignItems: 'flex-start',
            }}
          >
            {(['wish', 'planned', 'completed'] as BucketStatus[]).map((st) => {
              const meta = BUCKET_STATUS_META[st];
              const colItems = filteredItems.filter((i) => i.status === st);
              const colWidth = width < 560 ? Math.round(width * 0.78) : 300;
              return (
                <div
                  key={st}
                  style={{
                    width: colWidth,
                    flexShrink: 0,
                    background: Derived.panelGlass,
                    borderRadius: AppRadius.x2,
                    border: `1px solid ${withAlpha(meta.hue, 0.16)}`,
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      padding: '12px 14px',
                      background: `linear-gradient(135deg, ${withAlpha(meta.hue, 0.16)}, ${withAlpha(meta.hue, 0.04)})`,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                    }}
                  >
                    <div
                      style={{
                        width: 30,
                        height: 30,
                        borderRadius: '50%',
                        background: withAlpha(meta.hue, 0.14),
                        border: `1px solid ${withAlpha(meta.hue, 0.4)}`,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Icon name={meta.icon} size={15} color={meta.hue} />
                    </div>
                    <div style={{ flex: 1, ...AppTypography.outfitBold, fontSize: 13, color: meta.hue }}>{meta.label}</div>
                    <span
                      style={{
                        padding: '4px 9px',
                        borderRadius: AppRadius.full,
                        background: withAlpha(meta.hue, 0.14),
                        ...AppTypography.outfitBold,
                        fontSize: 11,
                        color: meta.hue,
                      }}
                    >
                      {colItems.length}
                    </span>
                  </div>
                  <div style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 10 }}>
                    {colItems.length === 0 ? (
                      <div style={{ padding: '24px 12px', textAlign: 'center', ...AppTypography.bodySmall, color: Derived.textMuted }}>
                        {st === 'completed' ? 'None fulfilled yet' : `No ${meta.label.toLowerCase()} dreams`}
                      </div>
                    ) : (
                      colItems.map((it) => (
                        <BucketItemCard
                          key={it.id}
                          item={it}
                          currentUser={currentUser}
                          onOpen={() => setDetailItem(it)}
                        />
                      ))
                    )}
                    {st === 'wish' && (
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => setAddOpen(true)}
                        style={{
                          padding: '11px 0',
                          borderRadius: AppRadius.lg,
                          background: withAlpha(AppColors.moonlight, 0.05),
                          border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: 6,
                          ...AppTypography.outfitBold,
                          fontSize: 12,
                          color: withAlpha(AppColors.blushGold, 0.8),
                        }}
                      >
                        <Icon name="add" size={15} color={withAlpha(AppColors.blushGold, 0.8)} />
                        <span>Plant a dream</span>
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div style={{ maxWidth: 720, width: '100%', margin: '0 auto', padding: '4px 16px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
            {filteredItems.map((it) => (
              <BucketItemCard
                key={it.id}
                item={it}
                currentUser={currentUser}
                onOpen={() => setDetailItem(it)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Floating New Dream FAB */}
      <button
        type="button"
        className="bare-button"
        aria-label="Plant a new dream"
        onClick={() => setAddOpen(true)}
        style={{
          position: 'fixed',
          right: 20,
          bottom: 24,
          padding: '14px 20px',
          borderRadius: AppRadius.full,
          background: `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.rosePressed})`,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
          boxShadow: `0 8px 20px ${withAlpha(AppColors.deepRose, 0.45)}`,
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          zIndex: 50,
        }}
      >
        <Icon name="add" size={18} color={AppColors.petalWhite} />
        <span style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>New dream</span>
      </button>

      {detailItem && (
        <BucketDetailModal
          item={allItems.find((i) => i.id === detailItem.id) ?? detailItem}
          currentUser={currentUser}
          onClose={() => setDetailItem(null)}
        />
      )}

      {addOpen && <AddDreamModal currentUser={currentUser} onClose={() => setAddOpen(false)} />}
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
  const wishes = all.filter((i) => i.status === 'wish').length;
  const planned = all.filter((i) => i.status === 'planned').length;
  const completed = all.filter((i) => i.status === 'completed').length;
  const overdue = all.filter((i) => isBucketOverdue(i)).length;
  const progress = total === 0 ? 0 : completed / total;

  const headline =
    total === 0
      ? 'Every love story needs a first dream'
      : progress >= 1
        ? 'Every dream came true — dream more!'
        : progress >= 0.66
          ? 'Look how far we’ve wandered'
          : progress >= 0.33
            ? 'Our story is unfolding'
            : completed > 0
              ? 'Dreams are coming true'
              : 'So many stars left to chase';

  return (
    <div style={{ padding: '4px 16px 12px' }}>
      <div
        style={{
          position: 'relative',
          overflow: 'hidden',
          borderRadius: 24,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.25)}`,
          background: `linear-gradient(135deg, ${withAlpha(AppColors.plum, 0.9)}, ${withAlpha(AppColors.inkDeep, 0.96)})`,
          boxShadow: `0 12px 28px ${withAlpha(AppColors.inkDeep, 0.6)}`,
          padding: '18px 20px 16px',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 24,
            right: 24,
            height: 1.4,
            background: `linear-gradient(90deg, transparent, ${withAlpha(AppColors.blushGold, 0.5)}, transparent)`,
          }}
        />
        <div style={{ ...AppTypography.outfitBold, fontSize: 10, letterSpacing: 1.6, color: withAlpha(AppColors.blushGold, 0.9) }}>
          ✨  OUR JOURNEY SO FAR
        </div>
        <div style={{ ...AppTypography.cormorantBold, fontSize: 24, lineHeight: 1.05, color: AppColors.petalWhite, marginTop: 6 }}>
          {headline}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
          <span style={{ flex: 1, ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.62) }}>
            {total === 0
              ? 'Your story is waiting for its first dream'
              : `${completed} of ${total} dreams fulfilled · ${Math.round(progress * 100)}%`}
          </span>
          {overdue > 0 && (
            <button
              type="button"
              className="bare-button"
              onClick={onOverdueTap}
              style={{
                padding: '5px 9px',
                borderRadius: AppRadius.full,
                background: withAlpha(AppColors.error, overdueOnly ? 0.22 : 0.1),
                border: `1px solid ${withAlpha(AppColors.error, overdueOnly ? 0.8 : 0.35)}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 4,
                ...AppTypography.outfitBold,
                fontSize: 10,
                color: AppColors.error,
              }}
            >
              <Icon name="warning" size={11} color={AppColors.error} />
              <span>{overdue} {overdue === 1 ? 'needs' : 'need'} love</span>
            </button>
          )}
        </div>

        {/* Trail Progress Bar */}
        <div style={{ position: 'relative', height: 22, display: 'flex', alignItems: 'center', marginTop: 12 }}>
          <div style={{ width: '100%', height: 8, borderRadius: AppRadius.full, background: withAlpha(AppColors.moonlight, 0.1) }} />
          {progress > 0 && (
            <div
              style={{
                position: 'absolute',
                left: 0,
                height: 8,
                width: `${Math.min(100, progress * 100)}%`,
                borderRadius: AppRadius.full,
                background: `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.auroraGold})`,
                boxShadow: `0 0 10px ${withAlpha(AppColors.auroraGold, 0.35)}`,
              }}
            />
          )}
          <div
            style={{
              position: 'absolute',
              left: `calc(${Math.min(100, progress * 100)}% - 11px)`,
              width: 22,
              height: 22,
              borderRadius: '50%',
              background: AppColors.inkDeep,
              border: `1.4px solid ${withAlpha(AppColors.blushGold, 0.7)}`,
              boxShadow: `0 0 8px ${withAlpha(AppColors.blushGold, 0.45)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="star" size={13} color={AppColors.blushGold} />
          </div>
        </div>

        {/* Status segments */}
        <div
          style={{
            marginTop: 14,
            display: 'grid',
            gridTemplateColumns: 'repeat(4, 1fr)',
            gap: 4,
            padding: 4,
            borderRadius: AppRadius.xl,
            background: withAlpha(AppColors.inkDeep, 0.45),
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
          }}
        >
          {[
            { emoji: '✨', label: 'All', count: total, hue: AppColors.petalWhite, status: null },
            { emoji: '🌟', label: 'Wished', count: wishes, hue: BUCKET_STATUS_META.wish.hue, status: 'wish' as BucketStatus },
            { emoji: '📋', label: 'Planned', count: planned, hue: BUCKET_STATUS_META.planned.hue, status: 'planned' as BucketStatus },
            { emoji: '✅', label: 'Done', count: completed, hue: BUCKET_STATUS_META.completed.hue, status: 'completed' as BucketStatus },
          ].map((seg) => {
            const isSel = selected === seg.status;
            return (
              <button
                key={seg.label}
                type="button"
                className="bare-button"
                onClick={() => onSelect(seg.status)}
                style={{
                  padding: '8px 0',
                  borderRadius: AppRadius.lg,
                  background: isSel ? withAlpha(seg.hue, 0.16) : 'transparent',
                  border: `1px solid ${isSel ? withAlpha(seg.hue, 0.55) : 'transparent'}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                }}
              >
                <span style={{ fontSize: 14 }}>{seg.emoji}</span>
                <span
                  style={{
                    ...AppTypography.outfitBold,
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                    color: isSel ? seg.hue : withAlpha(AppColors.petalWhite, 0.55),
                    marginTop: 3,
                  }}
                >
                  {seg.label}
                </span>
                <span
                  style={{
                    ...AppTypography.outfitBold,
                    fontSize: 13,
                    color: isSel ? seg.hue : withAlpha(AppColors.petalWhite, 0.85),
                  }}
                >
                  {seg.count}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function FilterPill({
  label,
  icon,
  hue,
  selected,
  onClick,
}: {
  label: string;
  icon: string;
  hue: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        flexShrink: 0,
        padding: '7px 11px',
        borderRadius: AppRadius.full,
        background: selected ? withAlpha(hue, 0.18) : Derived.panelGlass,
        border: `1px solid ${selected ? withAlpha(hue, 0.65) : withAlpha(AppColors.moonlight, 0.1)}`,
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
        ...AppTypography.outfitBold,
        fontSize: 11,
        color: selected ? hue : withAlpha(AppColors.petalWhite, 0.65),
      }}
    >
      <Icon name={icon} size={12} color={selected ? hue : withAlpha(AppColors.petalWhite, 0.55)} />
      <span>{label}</span>
    </button>
  );
}

function BucketItemCard({
  item,
  currentUser,
  onOpen,
}: {
  item: BucketItem;
  currentUser: string;
  onOpen: () => void;
}) {
  const isCompleted = item.status === 'completed';
  const cat = bucketCategoryMeta(item.category);
  const st = BUCKET_STATUS_META[item.status];
  const edgeHue = isCompleted
    ? withAlpha(AppColors.blushGold, 0.8)
    : item.priority === 'urgent'
      ? withAlpha(AppColors.error, 0.85)
      : item.priority === 'high'
        ? withAlpha(AppColors.warmAmber, 0.8)
        : withAlpha(AppColors.moonlight, 0.1);
  const overdue = isBucketOverdue(item);
  const dueSoon = isBucketDueSoon(item);

  return (
    <div
      onClick={onOpen}
      style={{
        cursor: 'pointer',
        padding: '12px 12px',
        borderRadius: AppRadius.x2,
        background: `linear-gradient(135deg, ${withAlpha(AppColors.petalWhite, isCompleted ? 0.06 : 0.045)}, ${withAlpha(AppColors.velvet, 0.55)})`,
        border: `1px solid ${isCompleted ? withAlpha(AppColors.blushGold, 0.45) : withAlpha(AppColors.moonlight, 0.1)}`,
        boxShadow: isCompleted
          ? `0 0 18px ${withAlpha(AppColors.blushGold, 0.1)}, 0 6px 14px rgba(0,0,0,0.3)`
          : '0 6px 14px rgba(0,0,0,0.3)',
        display: 'flex',
        alignItems: 'flex-start',
        gap: 10,
      }}
    >
      <div style={{ width: 4, height: 58, borderRadius: AppRadius.full, background: edgeHue, flexShrink: 0 }} />
      <button
        type="button"
        className="bare-button"
        aria-label={isCompleted ? `Reopen ${item.title}` : `Mark ${item.title} fulfilled`}
        onClick={(e) => {
          e.stopPropagation();
          if (isCompleted) {
            void bucketListService.markUncomplete(item.id);
          } else {
            void bucketListService.markComplete(item.id, currentUser).then(() => showSnackBar('A wish came true.'));
          }
        }}
        style={{
          width: 26,
          height: 26,
          borderRadius: '50%',
          marginTop: 2,
          border: `1.5px solid ${isCompleted ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.35)}`,
          background: isCompleted ? `linear-gradient(135deg, ${AppColors.deepRose}, ${AppColors.blushGold})` : 'transparent',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        {isCompleted && <Icon name="check" size={14} color={AppColors.petalWhite} />}
      </button>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
          <div
            style={{
              flex: 1,
              ...AppTypography.outfitBold,
              fontSize: 15,
              lineHeight: 1.15,
              color: isCompleted ? withAlpha(AppColors.petalWhite, 0.5) : AppColors.petalWhite,
              textDecoration: isCompleted ? 'line-through' : 'none',
            }}
          >
            {item.title}
          </div>
          {item.priority === 'urgent' && !isCompleted && (
            <Icon name="local_fire_department" size={15} color={AppColors.error} />
          )}
          <span
            style={{
              padding: '3px 8px',
              borderRadius: AppRadius.full,
              background: withAlpha(st.hue, 0.14),
              border: `1px solid ${withAlpha(st.hue, 0.35)}`,
              ...AppTypography.outfitBold,
              fontSize: 10,
              color: st.hue,
              flexShrink: 0,
            }}
          >
            {st.label}
          </span>
        </div>

        {item.description && (
          <div
            style={{
              marginTop: 3,
              ...AppTypography.outfitWhite,
              fontSize: 12,
              color: withAlpha(AppColors.petalWhite, 0.5),
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {item.description}
          </div>
        )}

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
          <span
            style={{
              padding: '3px 8px',
              borderRadius: AppRadius.full,
              background: withAlpha(cat.hue, 0.12),
              border: `1px solid ${withAlpha(cat.hue, 0.28)}`,
              ...AppTypography.outfitBold,
              fontSize: 10,
              color: cat.hue,
            }}
          >
            {cat.emoji} {cat.label}
          </span>
          {item.assignedTo && (
            <span
              style={{
                padding: '3px 8px',
                borderRadius: AppRadius.full,
                background: withAlpha(bucketAssigneeHue(item.assignedTo), 0.12),
                border: `1px solid ${withAlpha(bucketAssigneeHue(item.assignedTo), 0.3)}`,
                ...AppTypography.outfitBold,
                fontSize: 10,
                color: bucketAssigneeHue(item.assignedTo),
              }}
            >
              {bucketAssigneeLabel(item.assignedTo)}
            </span>
          )}
          {item.dueDate && (
            <span
              style={{
                padding: '3px 8px',
                borderRadius: AppRadius.full,
                background: withAlpha(overdue ? AppColors.error : dueSoon ? AppColors.warmAmber : AppColors.moonlight, 0.12),
                ...AppTypography.outfitBold,
                fontSize: 10,
                color: overdue ? AppColors.error : dueSoon ? AppColors.warmAmber : Derived.textMedium,
              }}
            >
              {item.dueDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

function BucketDetailModal({
  item,
  currentUser,
  onClose,
}: {
  item: BucketItem;
  currentUser: string;
  onClose: () => void;
}) {
  const isCompleted = item.status === 'completed';
  const cat = bucketCategoryMeta(item.category);
  const pr = BUCKET_PRIORITY_META[item.priority];

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.68)',
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
          maxWidth: 560,
          background: AppColors.velvet,
          borderRadius: '24px 24px 0 0',
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.25)}`,
          padding: 22,
          display: 'flex',
          flexDirection: 'column',
          gap: 14,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
          <span style={{ ...AppTypography.labelSmall, color: cat.hue }}>
            {cat.emoji} {cat.label}
          </span>
          <button
            type="button"
            className="bare-button"
            aria-label="Delete dream"
            onClick={() => {
              void bucketListService.delete(item.id);
              showSnackBar('Dream removed');
              onClose();
            }}
          >
            <Icon name="delete_outline" size={20} color={AppColors.error} />
          </button>
        </div>
        <div style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.petalWhite }}>{item.title}</div>
        {item.description && <div style={{ ...AppTypography.bodyMedium, color: Derived.textMedium }}>{item.description}</div>}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
          <MetaBox
            label="Priority"
            value={`${pr.emoji} ${pr.label}`}
            hue={pr.hue}
            onClick={() => {
              const order: BucketPriority[] = ['low', 'medium', 'high', 'urgent'];
              const next = order[(order.indexOf(item.priority) + 1) % order.length];
              void bucketListService.setPriority(item.id, next);
            }}
          />
          <MetaBox
            label="Status"
            value={BUCKET_STATUS_META[item.status].label}
            hue={BUCKET_STATUS_META[item.status].hue}
            onClick={() => {
              const order: BucketStatus[] = ['wish', 'planned', 'completed'];
              const next = order[(order.indexOf(item.status) + 1) % order.length];
              void bucketListService.moveStatus(item.id, next, currentUser);
            }}
          />
          <MetaBox
            label="Owner"
            value={bucketAssigneeLabel(item.assignedTo)}
            hue={bucketAssigneeHue(item.assignedTo)}
            onClick={() => {
              const next =
                item.assignedTo == null
                  ? 'khentsgdz'
                  : item.assignedTo === 'khentsgdz'
                    ? 'clairjassen'
                    : undefined;
              void bucketListService.assign(item.id, next);
            }}
          />
        </div>

        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1 }}>
            <EverglowButton
              fullWidth
              label={isCompleted ? 'Reopen Dream' : 'Mark Fulfilled'}
              icon={isCompleted ? 'refresh' : 'check'}
              onPressed={() => {
                if (isCompleted) void bucketListService.markUncomplete(item.id);
                else void bucketListService.markComplete(item.id, currentUser);
              }}
            />
          </div>
          <EverglowButton label="Close" variant="ghost" onPressed={onClose} />
        </div>
      </div>
    </div>
  );
}

function MetaBox({ label, value, hue, onClick }: { label: string; value: string; hue: string; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        padding: 10,
        borderRadius: 12,
        background: withAlpha(AppColors.inkDeep, 0.5),
        border: `1px solid ${withAlpha(hue, 0.3)}`,
        textAlign: 'left',
      }}
    >
      <div style={{ ...AppTypography.outfitBold, fontSize: 12, color: hue }}>{value}</div>
      <div style={{ ...AppTypography.outfitWhite, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.45), marginTop: 2 }}>
        {label} (tap)
      </div>
    </button>
  );
}

function AddDreamModal({ currentUser, onClose }: { currentUser: string; onClose: () => void }) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState<BucketCategory>('travel');
  const [priority, setPriority] = useState<BucketPriority>('medium');
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    if (!title.trim() || saving) return;
    setSaving(true);
    try {
      await bucketListService.add({
        title: title.trim(),
        description: description.trim(),
        category,
        status: 'wish',
        createdBy: currentUser,
        createdAt: new Date(),
        priority,
      });
      showSnackBar('Dream planted!');
      onClose();
    } catch {
      showSnackBar('Could not save dream');
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
        <div style={{ ...AppTypography.titleLarge, color: AppColors.petalWhite }}>Plant a New Dream</div>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="What do you dream of?" style={bucketFieldStyle} />
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} placeholder="Little details..." style={bucketFieldStyle} />
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {BUCKET_CATEGORIES.map((c) => (
            <button
              key={c.id}
              type="button"
              className="bare-button"
              onClick={() => setCategory(c.id)}
              style={{
                padding: '5px 10px',
                borderRadius: AppRadius.full,
                background: category === c.id ? withAlpha(c.hue, 0.22) : withAlpha(AppColors.inkDeep, 0.5),
                border: `1px solid ${category === c.id ? c.hue : Derived.border}`,
                ...AppTypography.outfitBold,
                fontSize: 11,
                color: AppColors.petalWhite,
              }}
            >
              {c.emoji} {c.label}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {(['low', 'medium', 'high', 'urgent'] as BucketPriority[]).map((p) => {
            const meta = BUCKET_PRIORITY_META[p];
            return (
              <button
                key={p}
                type="button"
                className="bare-button"
                onClick={() => setPriority(p)}
                style={{
                  padding: '5px 10px',
                  borderRadius: AppRadius.full,
                  background: priority === p ? withAlpha(meta.hue, 0.22) : withAlpha(AppColors.inkDeep, 0.5),
                  border: `1px solid ${priority === p ? meta.hue : Derived.border}`,
                  ...AppTypography.outfitBold,
                  fontSize: 11,
                  color: AppColors.petalWhite,
                }}
              >
                {meta.emoji} {meta.label}
              </button>
            );
          })}
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <EverglowButton label="Cancel" variant="ghost" onPressed={onClose} enabled={!saving} />
          <EverglowButton label={saving ? 'Saving…' : 'Plant Dream'} enabled={Boolean(title.trim()) && !saving} onPressed={() => void submit()} />
        </div>
      </div>
    </div>
  );
}

const bucketFieldStyle = {
  width: '100%',
  padding: '11px 14px',
  borderRadius: 12,
  background: withAlpha(AppColors.inkDeep, 0.55),
  border: `1px solid ${Derived.border}`,
  color: AppColors.petalWhite,
  outline: 'none',
  fontSize: 14,
};
