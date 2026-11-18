// Port of lib/features/trip_kit/presentation/screens/trip_detail_screen.dart.
import { useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { authService } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, linear, lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { showTripEditSheet } from './TripListPage';
import { TripAddRow, TripCheckRow, TripProgress, TripSectionTitle } from './TripUi';
import {
  budgetProgress,
  newTripItemId,
  overBudget,
  packedCount,
  remaining,
  spentTotal,
  tripDateRange,
  tripPeso,
  tripService,
  visitedCount,
  type Trip,
  type TripExpense,
  type TripPackItem,
  type TripPlace,
} from './tripService';

async function runTripAction(message: string, action: () => Promise<void>, onRetry?: () => void): Promise<void> {
  try {
    await action();
  } catch {
    showSnackBar(message, { action: { label: 'Retry', onPressed: onRetry ?? (() => void runTripAction(message, action)) } });
  }
}

function HeaderIcon({ icon, label, onTap }: { icon: string; label: string; onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={onTap}
      style={{
        width: 38,
        height: 38,
        boxSizing: 'border-box',
        borderRadius: '50%',
        background: withAlpha(AppColors.moonlight, 0.08),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={17} color={withAlpha(AppColors.petalWhite, 0.8)} />
    </button>
  );
}

export function TripDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const [retry, setRetry] = useState(0);
  return (
    <EverglowScaffold backgroundColor={AppColors.inkDeep}>
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <EverglowStreamView
          source={() => tripService.watchOne(id)}
          sourceKey={[id, retry]}
          label="trip-kit-detail"
          errorMessage="Could not load trip"
          onRetry={() => setRetry((r) => r + 1)}
          loadingView={<LoadingTrip />}
          isEmpty={(trip) => trip == null}
          emptyView={
            <EverglowEmptyState
              icon="luggage_outlined"
              title="Trip not found"
              subtitle="It may have been deleted"
              ctaLabel="Back to trips"
              onCta={() => navigate('/trips', { replace: true })}
            />
          }
          builder={(trip) => <TripDetailBody trip={trip!} />}
        />
      </div>
    </EverglowScaffold>
  );
}

function TripDetailBody({ trip }: { trip: Trip }) {
  const navigate = useNavigate();
  const [pack, setPack] = useState('');
  const [placeName, setPlaceName] = useState('');
  const [placeNote, setPlaceNote] = useState('');
  const addingPack = useRef(false);
  const addingPlace = useRef(false);
  const packText = useRef('');
  const placeText = useRef({ name: '', note: '' });
  packText.current = pack;
  placeText.current = { name: placeName, note: placeNote };

  const savePackItem = async (item: TripPackItem, label: string): Promise<void> => {
    if (addingPack.current) return;
    addingPack.current = true;
    try {
      await runTripAction(
        'Could not add this item. Your text is still here.',
        async () => {
          await tripService.addPackingItem(trip.id, item);
          if (packText.current.trim() === label) setPack('');
        },
        () => void savePackItem(item, label),
      );
    } finally {
      addingPack.current = false;
    }
  };

  const addPackItem = () => {
    const label = pack.trim();
    if (addingPack.current || label === '') return;
    void savePackItem({ id: newTripItemId(), label, packed: false, packedBy: null }, label);
  };

  const savePlace = async (place: TripPlace, name: string, note: string): Promise<void> => {
    if (addingPlace.current) return;
    addingPlace.current = true;
    try {
      await runTripAction(
        'Could not add this place. Your text is still here.',
        async () => {
          await tripService.addPlace(trip.id, place);
          if (placeText.current.name.trim() === name && placeText.current.note.trim() === note) {
            setPlaceName('');
            setPlaceNote('');
          }
        },
        () => void savePlace(place, name, note),
      );
    } finally {
      addingPlace.current = false;
    }
  };

  const addPlace = () => {
    const name = placeName.trim();
    if (addingPlace.current || name === '') return;
    const note = placeNote.trim();
    void savePlace({ id: newTripItemId(), name, note, done: false, lat: null, lng: null, category: null }, name, note);
  };

  const deleteTrip = async (): Promise<void> => {
    try {
      await tripService.delete(trip.id);
      navigate('/trips', { replace: true });
    } catch {
      showSnackBar('Could not delete this trip. Please try again.', {
        action: { label: 'Retry', onPressed: () => void deleteTrip() },
      });
    }
  };

  const confirmDelete = async () => {
    const ok = await showDialog<boolean>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={AppRadius.x2}
        title={
          <span style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite }}>Delete this trip?</span>
        }
        content={
          <span style={{ ...AppTypography.outfitWhite, fontSize: 13, color: withAlpha(AppColors.petalWhite, 0.7) }}>
            Packing, budget, and places go with it. This cannot be undone.
          </span>
        }
        actions={[
          <TextButton key="keep" onPressed={() => close(false)}>
            <span style={{ ...AppTypography.outfitBold, color: withAlpha(AppColors.petalWhite, 0.7) }}>Keep it</span>
          </TextButton>,
          <TextButton key="delete" onPressed={() => close(true)}>
            <span style={{ ...AppTypography.outfitBold, color: AppColors.error }}>Delete</span>
          </TextButton>,
        ]}
      />
    ));
    if (ok === true) await deleteTrip();
  };

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <EverglowFeatureHeader
        title={trip.title === '' ? 'Untitled trip' : trip.title}
        subtitle={trip.destination === '' ? tripDateRange(trip) : `${trip.destination} · ${tripDateRange(trip)}`}
        icon="luggage"
        hue={AppColors.auroraTeal}
        actions={[
          <HeaderIcon
            key="motchi"
            icon="auto_awesome"
            label="Ask Motchi about this trip"
            onTap={() =>
              navigate('/motchi', {
                state: `Help me with our trip "${trip.title}" to ${trip.destination}. The trip id is ${trip.id}. What should we plan next?`,
              })
            }
          />,
          <HeaderIcon key="edit" icon="edit" label="Edit trip details" onTap={() => showTripEditSheet(trip)} />,
          <div key="gap" style={{ width: 8 }} />,
          <HeaderIcon key="delete" icon="delete_outline" label="Delete trip" onTap={() => void confirmDelete()} />,
        ]}
      />
      <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto', overflowX: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: '100%', maxWidth: 720, padding: '0 16px 48px', boxSizing: 'border-box' }}>
            {trip.notes !== '' && <NotesCard notes={trip.notes} />}
            <TripBudgetCard trip={trip} />
            <TripSectionTitle
              icon="backpack"
              title="PACKING"
              hue={AppColors.warmAmber}
              trailing={trip.packing.length === 0 ? null : `${packedCount(trip)}/${trip.packing.length}`}
            />
            <TripAddRow
              value={pack}
              onChange={setPack}
              hint="Add to pack (e.g. Sunscreen)"
              hue={AppColors.warmAmber}
              onAdd={addPackItem}
            />
            <div style={{ height: 10 }} />
            {trip.packing.map((item) => (
              <TripCheckRow
                key={`pack-${item.id}`}
                label={item.label}
                subtitle={item.packedBy}
                checked={item.packed}
                hue={AppColors.warmAmber}
                toggleLabel={`Pack ${item.label}`}
                onToggle={() =>
                  void runTripAction('Could not update this packing item. Please try again.', () =>
                    tripService.setPackingItemPacked(trip.id, item.id, !item.packed, authService.currentUser),
                  )
                }
                onDelete={() =>
                  void runTripAction('Could not remove this packing item. Please try again.', () =>
                    tripService.removePackingItem(trip.id, item.id),
                  )
                }
              />
            ))}
            <TripSectionTitle
              icon="place"
              title="PLACES"
              hue={AppColors.auroraRose}
              trailing={trip.places.length === 0 ? null : `${visitedCount(trip)}/${trip.places.length}`}
            />
            <TripAddRow
              value={placeName}
              onChange={setPlaceName}
              hint="Place"
              hue={AppColors.auroraRose}
              second={{ value: placeNote, onChange: setPlaceNote, hint: 'Note (optional)' }}
              onAdd={addPlace}
            />
            <div style={{ height: 10 }} />
            {trip.places.map((place) => (
              <TripCheckRow
                key={`place-${place.id}`}
                label={place.name}
                subtitle={place.note}
                checked={place.done}
                hue={AppColors.auroraRose}
                toggleLabel={`Visit ${place.name}`}
                onToggle={() =>
                  void runTripAction('Could not update this place. Please try again.', () =>
                    tripService.setPlaceDone(trip.id, place.id, !place.done),
                  )
                }
                onDelete={() =>
                  void runTripAction('Could not remove this place. Please try again.', () =>
                    tripService.removePlace(trip.id, place.id),
                  )
                }
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function NotesCard({ notes }: { notes: string }) {
  return (
    <div
      style={{
        marginBottom: 4,
        padding: 14,
        background: withAlpha(AppColors.moonlight, 0.05),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
        display: 'flex',
        alignItems: 'flex-start',
      }}
    >
      <Icon name="sticky_note_2_outlined" size={15} color={withAlpha(AppColors.blushGold, 0.8)} />
      <div style={{ width: 10 }} />
      <span
        style={{
          ...AppTypography.outfitWhite,
          flex: 1,
          fontSize: 13,
          lineHeight: lineHeight(13, 1.45),
          color: withAlpha(AppColors.petalWhite, 0.75),
        }}
      >
        {notes}
      </span>
    </div>
  );
}

function BudgetNumber({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <span
        style={{ ...AppTypography.outfitBold, fontSize: 10, letterSpacing: 1.4, color: withAlpha(AppColors.petalWhite, 0.5) }}
      >
        {label.toUpperCase()}
      </span>
      <div style={{ height: 4 }} />
      <span style={{ ...AppTypography.outfitBold, fontSize: 20, lineHeight: mixedLineHeight(20), color }}>{value}</span>
    </div>
  );
}

function TripBudgetCard({ trip }: { trip: Trip }) {
  const [expanded, setExpanded] = useState(true);
  const [ref, size] = useBoxSize<HTMLDivElement>();
  const over = overBudget(trip);
  const spent = spentTotal(trip);
  const left = remaining(trip);
  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      <TripSectionTitle
        icon="wallet"
        title="BUDGET"
        hue={AppColors.auroraTeal}
        trailing={trip.budgetTotal > 0 ? `${tripPeso(spent)} / ${tripPeso(trip.budgetTotal)}` : `${tripPeso(spent)} spent`}
      />
      <div
        ref={ref}
        style={{
          padding: 16,
          background: linear([AppColors.silk, AppColors.velvet], { begin: Align.topLeft, end: Align.bottomRight, size }),
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(over ? AppColors.error : AppColors.auroraTeal, 0.25)}`,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <BudgetNumber label="Spent" value={tripPeso(spent)} color={over ? AppColors.error : AppColors.petalWhite} />
          <div style={{ width: 1, height: 36, background: withAlpha(AppColors.moonlight, 0.12) }} />
          <BudgetNumber
            label={trip.budgetTotal > 0 ? 'Left' : 'Budget'}
            value={trip.budgetTotal > 0 ? tripPeso(left) : 'Not set'}
            color={trip.budgetTotal > 0 && left < 0 ? AppColors.error : AppColors.auroraTeal}
          />
        </div>
        {trip.budgetTotal > 0 && (
          <>
            <div style={{ height: 12 }} />
            <TripProgress value={budgetProgress(trip)} height={8} color={over ? AppColors.error : AppColors.auroraTeal} />
            {over && (
              <span
                style={{
                  ...AppTypography.outfitBold,
                  paddingTop: 8,
                  fontSize: 12,
                  lineHeight: mixedLineHeight(12),
                  color: AppColors.error,
                }}
              >
                {`Over budget by ${tripPeso(-left)} — worth it? 💸`}
              </span>
            )}
          </>
        )}
        <div style={{ height: 12 }} />
        <TripExpenseAdder trip={trip} />
        {trip.expenses.length > 0 && (
          <>
            <div style={{ height: 8 }} />
            <div
              role="button"
              tabIndex={0}
              onClick={() => setExpanded((e) => !e)}
              style={{ padding: '6px 0', display: 'flex', alignItems: 'center', cursor: 'pointer' }}
            >
              <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6) }}>
                {`${trip.expenses.length} expense${trip.expenses.length === 1 ? '' : 's'}`}
              </span>
              <div style={{ width: 4 }} />
              <Icon name={expanded ? 'expand_less' : 'expand_more'} size={16} color={withAlpha(AppColors.petalWhite, 0.5)} />
            </div>
            {expanded && trip.expenses.map((e) => <TripExpenseRow key={e.id} trip={trip} expense={e} />)}
          </>
        )}
      </div>
    </div>
  );
}

function TripExpenseAdder({ trip }: { trip: Trip }) {
  const [label, setLabel] = useState('');
  const [amount, setAmount] = useState('');
  const saving = useRef(false);
  const latest = useRef({ label: '', amount: '' });
  latest.current = { label, amount };

  const saveExpense = async (expense: TripExpense, l: string, a: string): Promise<void> => {
    if (saving.current) return;
    saving.current = true;
    try {
      await tripService.addExpense(trip.id, expense);
      if (latest.current.label.trim() === l && latest.current.amount.trim() === a) {
        setLabel('');
        setAmount('');
      }
    } catch {
      showSnackBar('Could not add this expense. Your text is still here.', {
        action: { label: 'Retry', onPressed: () => void saveExpense(expense, l, a) },
      });
    } finally {
      saving.current = false;
    }
  };

  const add = () => {
    if (saving.current) return;
    const l = label.trim();
    const a = amount.trim();
    const n = Number.parseFloat(a);
    const value = Number.isFinite(n) ? n : 0;
    if (l === '' || value <= 0) return;
    void saveExpense({ id: newTripItemId(), label: l, amount: value, paidBy: null }, l, a);
  };

  return (
    <TripAddRow
      value={label}
      onChange={setLabel}
      hint="What (e.g. Gas)"
      hue={AppColors.auroraTeal}
      second={{ value: amount, onChange: setAmount, hint: '₱', numeric: true }}
      onAdd={add}
    />
  );
}

function TripExpenseRow({ trip, expense }: { trip: Trip; expense: TripExpense }) {
  const remove = async (): Promise<void> => {
    try {
      await tripService.removeExpense(trip.id, expense.id);
    } catch {
      showSnackBar('Could not remove this expense. Please try again.', {
        action: { label: 'Retry', onPressed: () => void remove() },
      });
    }
  };
  return (
    <div style={{ paddingBottom: 6 }}>
      <div
        style={{
          padding: '10px 12px',
          background: withAlpha(AppColors.moonlight, 0.05),
          borderRadius: AppRadius.lg,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <span style={{ ...AppTypography.outfitWhite, flex: 1, minWidth: 0, fontSize: 13 }}>{expense.label}</span>
        <span style={{ ...AppTypography.outfitBold, fontSize: 13, lineHeight: mixedLineHeight(13), color: AppColors.auroraTeal }}>
          {tripPeso(expense.amount)}
        </span>
        <div style={{ width: 4 }} />
        <span
          role="button"
          aria-label="Remove expense"
          onClick={() => void remove()}
          style={{ padding: 4, display: 'flex', cursor: 'pointer' }}
        >
          <Icon name="close" size={14} color={withAlpha(AppColors.petalWhite, 0.35)} />
        </span>
      </div>
    </div>
  );
}

function LoadingTrip() {
  return (
    <div style={{ padding: '90px 16px 24px', display: 'flex', flexDirection: 'column' }}>
      <EverglowSkeleton height={190} radius={24} />
      <div style={{ height: 12 }} />
      <EverglowSkeleton height={60} radius={16} />
      <div style={{ height: 10 }} />
      <EverglowSkeleton height={60} radius={16} />
    </div>
  );
}
