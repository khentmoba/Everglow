// Port of lib/features/money/presentation/screens/money_screen.dart.
import { useMemo, useRef, useState, type CSSProperties } from 'react';
import { authService } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, SimpleDialog, SimpleDialogOption, TextButton, dialogTitleStyle, showDialog } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowIconButton, EverglowScaffold, ExtendedFab } from '../../shared/widgets/EverglowScaffold';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { EverglowEmptyState, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { showAddMoneyDialog, showSetBudgetDialog } from './MoneyDialogs';
import {
  MoneyCategories,
  formatPeso,
  moneyService,
  spentByCategory,
  summarizeMonth,
  type BudgetLimit,
  type MoneyEntry,
  type MonthlyTotal,
} from './moneyService';

const bodySmall: CSSProperties = { ...AppTypography.bodySmall, lineHeight: lineHeight(12.5) };
const bodyMedium: CSSProperties = { ...AppTypography.bodyMedium, lineHeight: lineHeight(14) };

function quickAdd() {
  const author = authService.currentUser ?? '';
  return showAddMoneyDialog((d) => moneyService.add({ ...d, author }));
}

function editBudget(category: string, current = 0) {
  return showSetBudgetDialog(category, {
    current,
    onSave: (amount) => (amount <= 0 ? moneyService.removeLimit(category) : moneyService.setLimit(category, amount)),
  });
}

function pickCategory(options: string[]) {
  return showDialog<string>((close) => (
    <SimpleDialog background={AppColors.velvet} title="Budget for…">
      {options.map((c) => (
        <SimpleDialogOption key={c} onPressed={() => close(c)}>
          <span style={{ ...bodyMedium, color: AppColors.petalWhite }}>{`${MoneyCategories.iconFor(c)} ${c}`}</span>
        </SimpleDialogOption>
      ))}
    </SimpleDialog>
  ));
}

export function MoneyPage() {
  const month = useMemo(() => new Date(), []);
  return (
    <EverglowScaffold
      backgroundColor={AppColors.inkDeep}
      glows={[
        { color: AppColors.deepRose, alignment: [-0.8, -0.9], size: 0.7, opacity: 0.14 },
        { color: AppColors.auroraGold, alignment: [0.9, 0.9], size: 0.65, opacity: 0.07 },
      ]}
      floatingActionButton={<ExtendedFab icon="add" label="Add" onPressed={quickAdd} />}
    >
      <EverglowFeatureHeader
        title="Our Money"
        subtitle="one shared wallet"
        icon="savings"
        hue={AppColors.auroraGold}
        actions={[
          <EverglowIconButton
            key="add"
            icon="add"
            onPressed={quickAdd}
            semanticLabel="Add money entry"
            tooltip="Add"
            iconColor={AppColors.blushGold}
          />,
        ]}
      />
      <div style={{ flex: 1, minHeight: 0 }}>
        <EverglowStreamView
          source={() => moneyService.watchMonth(month)}
          sourceKey={[month]}
          label="money-recent"
          errorMessage="Could not load our money"
          builder={(entries) => <MoneyBody entries={entries} month={month} />}
        />
      </div>
    </EverglowScaffold>
  );
}

function MoneyBody({ entries, month }: { entries: MoneyEntry[]; month: Date }) {
  const [visible, setVisible] = useState(50);
  const total = summarizeMonth(entries, month);
  const spent = spentByCategory(entries, month);
  const monthEntries = entries.filter(
    (e) => e.createdAt.getFullYear() === month.getFullYear() && e.createdAt.getMonth() === month.getMonth(),
  );
  return (
    <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto', overflowX: 'hidden' }}>
      <div style={{ padding: '4px 16px 96px', display: 'flex', flexDirection: 'column' }}>
        <SummaryCard total={total} />
        <div style={{ height: 18 }} />
        <EverglowSectionHeader label="Budgets" icon="pie_chart_outline" hue={AppColors.auroraTeal} />
        <div style={{ height: 10 }} />
        <EverglowStreamView
          source={() => moneyService.watchLimits()}
          sourceKey={[]}
          label="money-limits"
          errorMessage="Could not load budgets"
          isEmpty={(limits) => limits.length === 0}
          emptyView={<SetBudgetHint />}
          builder={(limits) => (
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              {limits.map((l) => (
                <BudgetBar key={l.category} limit={l} spent={spent[l.category] ?? 0} onEdit={() => editBudget(l.category, l.amount)} />
              ))}
              <AddBudgetTile existing={new Set(limits.map((l) => l.category))} />
            </div>
          )}
        />
        <div style={{ height: 18 }} />
        <EverglowSectionHeader label="This month" icon="receipt_long" hue={AppColors.blushGold} />
        <div style={{ height: 10 }} />
        {monthEntries.length === 0 ? (
          <EverglowEmptyState
            icon="savings_outlined"
            title="Nothing yet this month"
            subtitle="Tap + to log your first peso together."
            ctaLabel="Add money"
            onCta={quickAdd}
          />
        ) : (
          monthEntries.slice(0, visible).map((e) => <MoneyRow key={e.id} entry={e} />)
        )}
        {monthEntries.length > visible && (
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <TextButton onPressed={() => setVisible((v) => v + 50)}>Load older entries</TextButton>
          </div>
        )}
      </div>
    </div>
  );
}

function SummaryCard({ total }: { total: MonthlyTotal }) {
  return (
    <div
      style={{
        padding: 18,
        background: Derived.panelGlass,
        borderRadius: AppRadius.xl,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.11)}`,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ ...bodySmall, color: Derived.textMuted, letterSpacing: 0.4 }}>Left this month</div>
      <div style={{ height: 4 }} />
      <div
        style={{
          ...AppTypography.cormorantBlack,
          fontSize: 40,
          lineHeight: '40px',
          color: total.balance < 0 ? AppColors.error : AppColors.blushGold,
        }}
      >
        {formatPeso(total.balance)}
      </div>
      {total.income > 0 && <SpentBar income={total.income} expense={total.expense} />}
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <MiniStat label="Got" value={formatPeso(total.income)} color={AppColors.success} icon="arrow_downward" />
        <div style={{ width: 1, height: 36, background: Derived.divider }} />
        <MiniStat label="Spent" value={formatPeso(total.expense)} color={AppColors.auroraRose} icon="arrow_upward" />
      </div>
    </div>
  );
}

function SpentBar({ income, expense }: { income: number; expense: number }) {
  const ratio = Math.max(0, expense / income);
  const over = ratio > 1;
  const pct = Math.round(ratio * 100);
  return (
    <div style={{ marginTop: 12 }}>
      <div
        role="progressbar"
        aria-label="Share of this month's money spent"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.min(100, pct)}
        style={{ height: 8, borderRadius: 999, background: withAlpha(AppColors.moonlight, 0.1), overflow: 'hidden' }}
      >
        <div
          style={{
            width: `${Math.min(100, Math.max(ratio > 0 ? 3 : 0, pct))}%`,
            height: '100%',
            borderRadius: 999,
            background: over ? AppColors.error : `linear-gradient(90deg, ${AppColors.blushGold}, ${AppColors.auroraRose})`,
          }}
        />
      </div>
      <div style={{ ...AppTypography.handwrittenBody, fontSize: 17, lineHeight: 1.2, marginTop: 6, color: over ? AppColors.error : withAlpha(AppColors.petalWhite, 0.62) }}>
        {over ? `${Math.max(1, pct - 100)}% more than came in` : `${Math.min(99, pct)}% of this month's money spent`}
      </div>
    </div>
  );
}

function MiniStat({ label, value, color, icon }: { label: string; value: string; color: string; icon: string }) {
  return (
    <div style={{ flex: 1, minWidth: 0, padding: '0 12px', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <Icon name={icon} size={13} color={color} />
        <div style={{ width: 4 }} />
        <span style={{ ...bodySmall, color: Derived.textMuted }}>{label}</span>
      </div>
      <div style={{ height: 2 }} />
      <div style={{ ...AppTypography.outfitBold, fontSize: 17, lineHeight: mixedLineHeight(17), color: AppColors.petalWhite }}>{value}</div>
    </div>
  );
}

const tile: CSSProperties = {
  marginBottom: 8,
  background: withAlpha(AppColors.moonlight, 0.05),
  borderRadius: AppRadius.lg,
  border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
};

function BudgetBar({ limit, spent, onEdit }: { limit: BudgetLimit; spent: number; onEdit: () => void }) {
  const pct = limit.amount <= 0 ? 0 : Math.min(1, Math.max(0, spent / limit.amount));
  const over = limit.amount > 0 && spent > limit.amount;
  const color = over ? AppColors.error : AppColors.auroraTeal;
  return (
    <div role="button" tabIndex={0} onClick={onEdit} style={{ ...tile, padding: 12, cursor: 'pointer', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <span style={{ fontSize: 16, lineHeight: lineHeight(16) }}>{MoneyCategories.iconFor(limit.category)}</span>
        <div style={{ width: 8 }} />
        <span style={{ ...bodyMedium, flex: 1, color: AppColors.petalWhite, fontWeight: 600 }}>{limit.category}</span>
        <span style={{ ...bodySmall, color: over ? AppColors.error : Derived.textMuted, fontWeight: over ? 700 : 400 }}>
          {`${formatPeso(spent)} / ${formatPeso(limit.amount)}`}
        </span>
      </div>
      <div style={{ height: 8 }} />
      <div style={{ height: 6, borderRadius: 999, overflow: 'hidden', background: withAlpha(AppColors.moonlight, 0.1) }}>
        <div style={{ width: `${pct * 100}%`, height: '100%', background: color }} />
      </div>
    </div>
  );
}

function SetBudgetHint() {
  const pick = async () => {
    const picked = await pickCategory(MoneyCategories.expense);
    if (picked != null) await editBudget(picked);
  };
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={pick}
      style={{
        padding: 14,
        background: withAlpha(AppColors.auroraTeal, 0.07),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.25)}`,
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      <Icon name="pie_chart_outline" size={20} color={AppColors.auroraTeal} />
      <div style={{ width: 10 }} />
      <span style={{ ...bodySmall, flex: 1, color: Derived.textMedium }}>Set a monthly cap — e.g. Food ₱8,000</span>
      <Icon name="add" size={18} color={AppColors.auroraTeal} />
    </div>
  );
}

function AddBudgetTile({ existing }: { existing: Set<string> }) {
  const remaining = MoneyCategories.expense.filter((c) => !existing.has(c));
  if (remaining.length === 0) return null;
  return (
    <div style={{ display: 'flex' }}>
      <TextButton
        color={AppColors.auroraTeal}
        icon={<Icon name="add" size={16} color={AppColors.auroraTeal} />}
        style={{ ...bodySmall, color: AppColors.auroraTeal }}
        onPressed={async () => {
          const picked = await pickCategory(remaining);
          if (picked != null) await editBudget(picked);
        }}
      >
        Add budget
      </TextButton>
    </div>
  );
}

function authorLabel(author: string) {
  const a = author.toLowerCase();
  if (a === 'clairjassen' || a === 'clair') return 'Clair';
  if (a === 'khentsgdz' || a === 'khent') return 'Khent';
  if (a === '') return 'us';
  return a;
}

async function confirmRemove(entry: MoneyEntry) {
  const yes = await showDialog<boolean>((close) => (
    <AlertDialog
      background={AppColors.velvet}
      title={<span style={dialogTitleStyle}>Remove this?</span>}
      actions={[
        <TextButton key="keep" onPressed={() => close(false)}>
          Keep
        </TextButton>,
        <TextButton key="remove" color={AppColors.error} onPressed={() => close(true)}>
          Remove
        </TextButton>,
      ]}
    />
  ));
  if (yes !== true) return;
  try {
    await moneyService.delete(entry.id);
  } catch {
    showSnackBar('Could not remove this entry. Try again.');
  }
}

/** A row you can swipe left to remove (Dismissible endToStart, always snaps back). */
function MoneyRow({ entry }: { entry: MoneyEntry }) {
  const isIncome = entry.type === 'income';
  const [dx, setDx] = useState(0);
  const start = useRef<{ x: number; y: number; id: number; dragging: boolean } | null>(null);
  const width = useRef(1);
  const end = () => {
    const s = start.current;
    start.current = null;
    if (s?.dragging && -dx / width.current >= 0.4) void confirmRemove(entry);
    setDx(0);
  };
  return (
    <div style={{ position: 'relative', marginBottom: 8 }}>
      {dx < 0 && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: AppRadius.lg,
            background: withAlpha(AppColors.error, 0.15),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            paddingRight: 20,
          }}
        >
          <Icon name="delete_outline" size={24} color={AppColors.error} />
        </div>
      )}
      <div
        onPointerDown={(e) => {
          width.current = e.currentTarget.offsetWidth || 1;
          start.current = { x: e.clientX, y: e.clientY, id: e.pointerId, dragging: false };
        }}
        onPointerMove={(e) => {
          const s = start.current;
          if (!s) return;
          const mx = e.clientX - s.x;
          if (!s.dragging) {
            if (Math.abs(mx) < 8 || Math.abs(mx) < Math.abs(e.clientY - s.y)) return;
            s.dragging = true;
            e.currentTarget.setPointerCapture(s.id);
          }
          setDx(Math.min(0, mx));
        }}
        onPointerUp={end}
        onPointerCancel={end}
        style={{
          ...tile,
          marginBottom: 0,
          padding: '10px 12px',
          display: 'flex',
          alignItems: 'center',
          position: 'relative',
          transform: `translateX(${dx}px)`,
          transition: start.current?.dragging ? undefined : 'transform 200ms ease-out',
          touchAction: 'pan-y',
        }}
      >
        <div
          style={{
            width: 38,
            height: 38,
            borderRadius: '50%',
            background: withAlpha(isIncome ? AppColors.success : AppColors.auroraRose, 0.12),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            fontSize: 17,
            lineHeight: lineHeight(17),
          }}
        >
          {MoneyCategories.iconFor(entry.category)}
        </div>
        <div style={{ width: 10 }} />
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
          <span className="ellipsis" style={{ ...bodyMedium, color: AppColors.petalWhite, fontWeight: 600 }}>
            {entry.note === '' ? entry.category : entry.note}
          </span>
          <div style={{ height: 1 }} />
          <span style={{ ...AppTypography.bodySmall, fontSize: 11, lineHeight: lineHeight(11), color: Derived.textMuted }}>
            {`${entry.category} · ${authorLabel(entry.author)}`}
          </span>
        </div>
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 15,
            lineHeight: lineHeight(15),
            color: isIncome ? AppColors.success : AppColors.petalWhite,
          }}
        >
          {`${isIncome ? '+' : '−'}${formatPeso(entry.amount)}`}
        </span>
      </div>
    </div>
  );
}
