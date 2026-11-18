// Port of lib/features/trip_kit/presentation/screens/trip_list_screen.dart.
import { useRef, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { authService } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { TripInput, TripProgress } from './TripUi';
import {
  budgetProgress,
  formatMonthDay,
  overBudget,
  packedCount,
  spentTotal,
  tripDateRange,
  tripPeso,
  tripService,
  visitedCount,
  type Trip,
} from './tripService';

type Nav = ReturnType<typeof useNavigate>;

function showCreateSheet(navigate: Nav) {
  void showModalBottomSheet<void>((close) => (
    <TripEditSheet
      createdBy={authService.currentUser ?? 'unknown'}
      close={() => close(null)}
      onCreated={(id) => navigate(`/trips/${id}`)}
    />
  ));
}

export function showTripEditSheet(trip: Trip) {
  void showModalBottomSheet<void>((close) => <TripEditSheet createdBy={trip.createdBy} trip={trip} close={() => close(null)} />);
}

function Constrained({ children }: { children: ReactNode }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div style={{ width: '100%', maxWidth: 720, display: 'flex', flexDirection: 'column' }}>{children}</div>
    </div>
  );
}

export function TripListPage() {
  const navigate = useNavigate();
  const [retry, setRetry] = useState(0);
  return (
    <EverglowScaffold
      backgroundColor={AppColors.inkDeep}
      floatingActionButton={<NewTripFab onTap={() => showCreateSheet(navigate)} />}
    >
      <EverglowFeatureHeader title="Trip Kit" subtitle="every lakad, one page" icon="luggage" hue={AppColors.auroraTeal} />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <EverglowStreamView
          source={() => tripService.watchAll()}
          sourceKey={[retry]}
          label="trip-kit-list"
          errorMessage="Could not load trips"
          onRetry={() => setRetry((r) => r + 1)}
          loadingView={<LoadingTrips />}
          isEmpty={(trips) => trips.length === 0}
          emptyView={
            <EverglowEmptyState
              icon="luggage_outlined"
              title="No trips yet"
              subtitle="Plan your first lakad together"
              ctaLabel="Plan a trip"
              onCta={() => showCreateSheet(navigate)}
            />
          }
          builder={(trips) => (
            <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto', overflowX: 'hidden' }}>
              <Constrained>
                <div style={{ padding: '4px 16px 96px' }}>
                  {trips.map((t) => (
                    <TripCard key={t.id} trip={t} onTap={() => navigate(`/trips/${t.id}`)} />
                  ))}
                </div>
              </Constrained>
            </div>
          )}
        />
      </div>
    </EverglowScaffold>
  );
}

function MiniStat({ icon, text, hue }: { icon: string; text: string; hue: string }) {
  return (
    <div
      style={{
        flex: 1,
        minWidth: 0,
        padding: '7px 8px',
        background: withAlpha(hue, 0.1),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(hue, 0.25)}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={icon} size={13} color={hue} />
      <div style={{ width: 5 }} />
      <span
        style={{
          ...AppTypography.outfitBold,
          fontSize: 10.5,
          color: hue,
          flex: 1,
          minWidth: 0,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {text}
      </span>
    </div>
  );
}

export function TripCard({ trip, onTap }: { trip: Trip; onTap: () => void }) {
  const where = trip.destination === '' ? 'Somewhere' : trip.destination;
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const over = overBudget(trip);
  return (
    <div style={{ paddingBottom: 12 }}>
      <div
        ref={ref}
        role="button"
        tabIndex={0}
        aria-label={`Open trip ${trip.title}`}
        onClick={onTap}
        style={{
          padding: 18,
          background: linear([AppColors.silk, AppColors.velvet], { begin: Align.topLeft, end: Align.bottomRight, size }),
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.22)}`,
          cursor: 'pointer',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div
            style={{
              width: 42,
              height: 42,
              boxSizing: 'border-box',
              borderRadius: '50%',
              background: withAlpha(AppColors.auroraTeal, 0.14),
              border: `1px solid ${withAlpha(AppColors.auroraTeal, 0.4)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <Icon name="luggage" size={20} color={AppColors.auroraTeal} />
          </div>
          <div style={{ width: 12 }} />
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <span
              style={{
                ...AppTypography.cormorantBold,
                fontSize: 21,
                lineHeight: lineHeight(21, 1.1),
                color: AppColors.petalWhite,
              }}
            >
              {trip.title === '' ? 'Untitled trip' : trip.title}
            </span>
            <div style={{ height: 2 }} />
            <span
              style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6) }}
            >{`${where} · ${tripDateRange(trip)}`}</span>
          </div>
          <Icon name="chevron_right" size={24} color={withAlpha(AppColors.petalWhite, 0.35)} />
        </div>
        <div style={{ height: 14 }} />
        <div style={{ display: 'flex' }}>
          <MiniStat icon="backpack" text={`${packedCount(trip)}/${trip.packing.length} packed`} hue={AppColors.warmAmber} />
          <div style={{ width: 8 }} />
          <MiniStat
            icon="wallet"
            text={
              trip.budgetTotal > 0
                ? `${tripPeso(spentTotal(trip))} of ${tripPeso(trip.budgetTotal)}`
                : `${tripPeso(spentTotal(trip))} spent`
            }
            hue={over ? AppColors.error : AppColors.auroraTeal}
          />
          <div style={{ width: 8 }} />
          <MiniStat icon="place" text={`${visitedCount(trip)}/${trip.places.length} places`} hue={AppColors.auroraRose} />
        </div>
        {trip.budgetTotal > 0 && (
          <>
            <div style={{ height: 10 }} />
            <TripProgress value={budgetProgress(trip)} height={6} color={over ? AppColors.error : AppColors.auroraTeal} />
          </>
        )}
      </div>
    </div>
  );
}

const fieldBox = {
  background: withAlpha(AppColors.moonlight, 0.06),
  borderRadius: AppRadius.lg,
  border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
};

const toInputDate = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

function DateChip({ label, value, onPick }: { label: string; value: Date | null; onPick: (d: Date | null) => void }) {
  const input = useRef<HTMLInputElement>(null);
  const open = () => {
    const el = input.current;
    if (!el) return;
    try {
      el.showPicker();
    } catch {
      el.focus();
    }
  };
  return (
    <div style={{ flex: 1, minWidth: 0, position: 'relative' }}>
      <div
        role="button"
        tabIndex={0}
        onClick={open}
        style={{ ...fieldBox, padding: '12px 14px', display: 'flex', alignItems: 'center', cursor: 'pointer' }}
      >
        <Icon name="calendar_today" size={14} color={withAlpha(AppColors.auroraTeal, 0.8)} />
        <div style={{ width: 8 }} />
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 13,
            flex: 1,
            minWidth: 0,
            color: value == null ? withAlpha(AppColors.petalWhite, 0.35) : AppColors.petalWhite,
          }}
        >
          {value == null ? label : formatMonthDay(value)}
        </span>
        {value != null && (
          <span
            role="button"
            aria-label={`Clear ${label}`}
            onClick={(e) => {
              e.stopPropagation();
              onPick(null);
            }}
            style={{ display: 'flex' }}
          >
            <Icon name="close" size={14} color={withAlpha(AppColors.petalWhite, 0.4)} />
          </span>
        )}
      </div>
      <input
        ref={input}
        type="date"
        tabIndex={-1}
        aria-hidden
        min="2020-01-01"
        max="2040-12-31"
        value={toInputDate(value ?? new Date())}
        onChange={(e) => {
          const [y, m, d] = e.target.value.split('-').map(Number);
          if (y && m && d) onPick(new Date(y, m - 1, d));
        }}
        style={{ position: 'absolute', inset: 0, opacity: 0, pointerEvents: 'none' }}
      />
    </div>
  );
}

function SheetField({
  value,
  onChange,
  hint,
  numeric,
  rows,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  numeric?: boolean;
  rows?: number;
}) {
  return (
    <div style={{ ...fieldBox, padding: '4px 14px' }}>
      <TripInput value={value} onChange={onChange} hint={hint} numeric={numeric} rows={rows} />
    </div>
  );
}

function TripEditSheet({
  createdBy,
  trip,
  close,
  onCreated,
}: {
  createdBy: string;
  trip?: Trip;
  close: () => void;
  onCreated?: (id: string) => void;
}) {
  const editing = trip != null;
  const [title, setTitle] = useState(trip?.title ?? '');
  const [destination, setDestination] = useState(trip?.destination ?? '');
  const [notes, setNotes] = useState(trip?.notes ?? '');
  const [budget, setBudget] = useState(
    trip && trip.budgetTotal > 0 ? (trip.budgetTotal % 1 === 0 ? trip.budgetTotal.toFixed(0) : trip.budgetTotal.toFixed(2)) : '',
  );
  const [start, setStart] = useState<Date | null>(trip?.startDate ?? null);
  const [end, setEnd] = useState<Date | null>(trip?.endDate ?? null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const save = async () => {
    const t = title.trim();
    if (t === '' || saving) return;
    setSaving(true);
    setSaveError(null);
    const parsed = Number.parseFloat(budget.trim());
    const b = Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
    try {
      if (!trip) {
        const id = await tripService.create({
          id: '',
          title: t,
          destination: destination.trim(),
          startDate: start,
          endDate: end,
          notes: notes.trim(),
          budgetTotal: b,
          packing: [],
          expenses: [],
          places: [],
          createdBy,
          createdAt: new Date(),
        });
        close();
        onCreated?.(id);
      } else {
        await tripService.updateDetails({
          ...trip,
          title: t,
          destination: destination.trim(),
          notes: notes.trim(),
          budgetTotal: b,
          startDate: start,
          endDate: end,
        });
        close();
      }
    } catch {
      setSaveError('Could not save this trip. Your details are still here — please try again.');
      setSaving(false);
    }
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div
        className="no-scrollbar"
        style={{
          width: '100%',
          maxWidth: 640,
          maxHeight: '92vh',
          overflowY: 'auto',
          padding: '12px 20px calc(24px + env(keyboard-inset-height, 0px))',
          background: AppColors.velvet,
          borderRadius: '24px 24px 0 0',
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
            borderRadius: 999,
            background: withAlpha(AppColors.moonlight, 0.25),
          }}
        />
        <div style={{ height: 14 }} />
        <span style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.petalWhite }}>
          {editing ? 'Edit trip' : 'New trip'}
        </span>
        <div style={{ height: 14 }} />
        <SheetField value={title} onChange={setTitle} hint="Trip name (e.g. Tagaytay weekend)" />
        <div style={{ height: 10 }} />
        <SheetField value={destination} onChange={setDestination} hint="Destination (e.g. Tagaytay)" />
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex' }}>
          <DateChip label="Start" value={start} onPick={setStart} />
          <div style={{ width: 8 }} />
          <DateChip label="End" value={end} onPick={setEnd} />
        </div>
        <div style={{ height: 10 }} />
        <SheetField value={budget} onChange={setBudget} hint="Budget in ₱ (optional)" numeric />
        <div style={{ height: 10 }} />
        <SheetField value={notes} onChange={setNotes} hint="Notes (optional)" rows={2} />
        <div style={{ height: 16 }} />
        {saveError != null && (
          <>
            <span style={{ color: AppColors.error }}>{saveError}</span>
            <div style={{ height: 10 }} />
          </>
        )}
        <button
          type="button"
          className="bare-button"
          onClick={save}
          disabled={saving}
          style={{
            padding: '14px 0',
            background: linear([AppColors.deepRose, AppColors.rosePressed]),
            borderRadius: AppRadius.full,
            display: 'flex',
            justifyContent: 'center',
          }}
        >
          {saving ? (
            <CircularProgress size={18} strokeWidth={2} color={AppColors.petalWhite} />
          ) : (
            <span style={{ ...AppTypography.outfitBold, fontSize: 15, color: AppColors.petalWhite }}>
              {editing ? 'Save changes' : 'Create trip'}
            </span>
          )}
        </button>
      </div>
    </div>
  );
}

function NewTripFab({ onTap }: { onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Plan a new trip"
      onClick={onTap}
      style={{
        padding: '14px 20px',
        background: linear([AppColors.deepRose, AppColors.rosePressed]),
        borderRadius: AppRadius.full,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.35), blur: 20, offset: [0, 8] }]),
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name="add" size={18} color={AppColors.petalWhite} />
      <div style={{ width: 6 }} />
      <span style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14), color: AppColors.petalWhite }}>
        New trip
      </span>
    </button>
  );
}

function LoadingTrips() {
  return (
    <div style={{ padding: '4px 16px 24px', display: 'flex', flexDirection: 'column' }}>
      <EverglowSkeleton height={170} radius={24} />
      <div style={{ height: 12 }} />
      <EverglowSkeleton height={170} radius={24} />
    </div>
  );
}
