// Port of lib/features/calendar/presentation/widgets/polls_tab.dart and add_poll_dialog.dart.
import { useRef, useState, type CSSProperties } from 'react';
import { useAuth } from '../../core/services/auth';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { AlertDialog, showDialog, showModalBottomSheet, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowIconButton } from '../../shared/widgets/EverglowScaffold';
import { EverglowEmptyState, EverglowSkeleton, EverglowStreamView } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { FilledField } from '../../shared/widgets/FilledField';
import { calendarPollService, pollTally, pollWinningOptionId, type DatePoll } from './calendarService';
import { jm, monthDay } from './calendarUi';

export function openAddPollDialog(): Promise<boolean | null> {
  return showDialog<boolean>((pop) => <AddPollDialog close={pop} />, { insetPadding: '16px' });
}

export function PollsTab() {
  const auth = useAuth();
  const currentUser = auth.currentUser ?? '';
  return (
    <EverglowStreamView<DatePoll[]>
      source={() => calendarPollService.watchAll()}
      sourceKey={[]}
      label="calendar-polls"
      errorMessage="Could not load polls"
      errorIcon="poll_outlined"
      onRetry={() => undefined}
      loadingView={
        <div style={{ padding: 20 }}>
          <EverglowSkeleton height={100} radius={16} />
        </div>
      }
      isEmpty={(p) => p.length === 0}
      emptyView={
        <EverglowEmptyState
          icon="how_to_vote"
          title="No date polls yet"
          subtitle="Create a Rallly-style poll to pick the perfect date together"
          ctaLabel="Create Poll"
          onCta={() => void openAddPollDialog()}
        />
      }
      builder={(polls) => (
        <div
          className="no-scrollbar"
          style={{ height: '100%', overflowY: 'auto', padding: '8px 16px 96px', boxSizing: 'border-box' }}
        >
          {polls.map((p) => (
            <PollCard key={p.id} poll={p} currentUser={currentUser} />
          ))}
        </div>
      )}
    />
  );
}

const text = (size: number, color: string, extra: CSSProperties = {}): CSSProperties => ({
  ...AppTypography.outfitWhite,
  fontSize: size,
  lineHeight: lineHeight(size),
  color,
  ...extra,
});

function PollCard({ poll, currentUser }: { poll: DatePoll; currentUser: string }) {
  const isClosed = poll.status === 'closed';
  const myVote = poll.votes[currentUser];
  const tally = pollTally(poll);
  const winningId = pollWinningOptionId(poll);
  const totalVotes = Object.keys(poll.votes).length;

  const vote = (optionId: string) => {
    if (currentUser === '') return;
    void calendarPollService.vote(poll.id, currentUser, optionId);
  };

  const finalize = async () => {
    const winning = pollWinningOptionId(poll);
    if (winning == null) {
      showSnackBar('No votes yet', { background: AppColors.deepRose });
      return;
    }
    const confirm = await showDialog<boolean>((pop) => (
      <AlertDialog
        background={AppColors.velvet}
        title={<span style={{ ...AppTypography.outfitBold, color: AppColors.petalWhite }}>Finalize poll?</span>}
        content={
          <span style={text(14, withAlpha(AppColors.petalWhite, 0.7))}>
            This will close the poll and create a calendar event for the winning date.
          </span>
        }
        actions={[
          <TextButton key="c" onPressed={() => pop(false)}>
            Cancel
          </TextButton>,
          <TextButton key="f" color={AppColors.blushGold} onPressed={() => pop(true)}>
            Finalize
          </TextButton>,
        ]}
      />
    ));
    if (confirm !== true || poll.options.length === 0) return;
    const opt = poll.options.find((o) => o.id === winning) ?? poll.options[0];
    try {
      await calendarPollService.finalize(poll.id, winning, {
        title: poll.title,
        description: `Decided via poll: ${poll.title}`,
        date: opt.date,
        type: 'dateNight',
        createdBy: poll.createdBy,
        recurring: 'none',
        attendees: Object.keys(poll.votes),
        isAllDay: false,
      });
    } catch {
      showSnackBar('Could not save the event. Your poll is still open — please try again.');
      return;
    }
    showSnackBar('Poll finalized & event created!', { background: AppColors.deepRose });
  };

  const menu = () =>
    showModalBottomSheet<void>((close) => (
      <div
        style={{
          padding: 20,
          background: AppColors.velvet,
          borderRadius: '24px 24px 0 0',
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
        }}
      >
        <button
          type="button"
          className="bare-button"
          onClick={() => {
            close(null);
            void calendarPollService.delete(poll.id);
          }}
          style={{ width: '100%', height: 56, padding: '0 16px', display: 'flex', alignItems: 'center', gap: 16 }}
        >
          <Icon name="delete_outline" size={24} color={AppColors.error} />
          <span style={text(16, AppColors.error, { lineHeight: lineHeight(16, 1.5) })}>Delete poll</span>
        </button>
      </div>
    ));

  const decided =
    poll.options.length === 0 ? '—' : (poll.options.find((o) => o.id === poll.decidedOptionId) ?? poll.options[0]).label;

  return (
    <div
      style={{
        marginBottom: 12,
        padding: 16,
        background: withAlpha(AppColors.moonlight, 0.08),
        borderRadius: 16,
        border: `1px solid ${isClosed ? withAlpha(AppColors.softLavender, 0.2) : withAlpha(AppColors.blushGold, 0.15)}`,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            padding: '4px 8px',
            borderRadius: 20,
            background: isClosed ? withAlpha(AppColors.softLavender, 0.15) : withAlpha(AppColors.warmAmber, 0.15),
            ...text(10, isClosed ? AppColors.softLavender : AppColors.warmAmber, { fontWeight: 700 }),
          }}
        >
          {isClosed ? 'Closed' : 'Open'}
        </span>
        <div style={{ width: 8 }} />
        <span style={{ flex: 1, minWidth: 0, ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14) }}>
          {poll.title}
        </span>
        <button
          type="button"
          className="bare-button"
          aria-label="Poll menu"
          onClick={() => void menu()}
          style={{ display: 'flex' }}
        >
          <Icon name="more_horiz" size={18} color={withAlpha(AppColors.petalWhite, 0.5)} />
        </button>
      </div>
      {poll.description !== '' && (
        <>
          <div style={{ height: 4 }} />
          <div style={text(12, withAlpha(AppColors.petalWhite, 0.65))}>{poll.description}</div>
        </>
      )}
      <div style={{ height: 6 }} />
      <div style={text(10, withAlpha(AppColors.petalWhite, 0.5))}>
        by {poll.createdBy} • {monthDay(poll.createdAt)} • {totalVotes} vote{totalVotes === 1 ? '' : 's'}
      </div>
      <div style={{ height: 12 }} />
      {poll.options.map((opt) => {
        const count = tally[opt.id] ?? 0;
        const isWinning = opt.id === winningId && totalVotes > 0;
        const isMine = myVote === opt.id;
        const voters = Object.entries(poll.votes).filter(([, v]) => v === opt.id);
        return (
          <div
            key={opt.id}
            onClick={isClosed ? undefined : () => vote(opt.id)}
            style={{
              marginBottom: 8,
              padding: 12,
              borderRadius: 12,
              background: isMine ? withAlpha(AppColors.deepRose, 0.18) : AppColors.twilight,
              border: `1px solid ${isMine ? AppColors.blushGold : isWinning ? withAlpha(AppColors.warmAmber, 0.5) : Derived.border}`,
              cursor: isClosed ? undefined : 'pointer',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <Icon
                name={isMine ? 'check_circle' : 'radio_button_unchecked'}
                size={16}
                color={isMine ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.4)}
              />
              <div style={{ width: 8 }} />
              <span style={{ flex: 1, minWidth: 0, ...text(13, AppColors.petalWhite, { fontWeight: isMine ? 700 : 500 }) }}>
                {opt.label}
              </span>
              {isWinning && (
                <span
                  style={{
                    padding: '2px 6px',
                    borderRadius: 6,
                    background: withAlpha(AppColors.warmAmber, 0.15),
                    ...text(9, AppColors.warmAmber, { fontWeight: 700 }),
                  }}
                >
                  Leading
                </span>
              )}
              <div style={{ width: 8 }} />
              <span
                style={{
                  ...AppTypography.outfitBold,
                  fontSize: 13,
                  lineHeight: lineHeight(13),
                  color: isMine ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.8),
                }}
              >
                {count}
              </span>
            </div>
            <div style={{ height: 8 }} />
            <LinearProgress
              value={totalVotes === 0 ? 0 : count / totalVotes}
              height={4}
              radius={4}
              color={isMine ? AppColors.blushGold : AppColors.auroraTeal}
              background={withAlpha(AppColors.moonlight, 0.12)}
            />
            {voters.length > 0 && (
              <>
                <div style={{ height: 6 }} />
                <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 4 }}>
                  {voters.map(([name]) => (
                    <span
                      key={name}
                      style={{
                        padding: '2px 6px',
                        borderRadius: 20,
                        background: withAlpha(AppColors.moonlight, 0.08),
                        ...text(10, withAlpha(AppColors.petalWhite, 0.7)),
                      }}
                    >
                      {name}
                    </span>
                  ))}
                </div>
              </>
            )}
          </div>
        );
      })}
      <div style={{ height: 8 }} />
      {!isClosed ? (
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            type="button"
            className="bare-button"
            disabled={poll.options.length === 0}
            onClick={() => vote(poll.options[0].id)}
            style={{
              flex: 1,
              minHeight: 40,
              padding: '10px 0',
              borderRadius: 20,
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
            }}
          >
            <Icon name="how_to_vote" size={14} color={AppColors.blushGold} />
            <span style={text(11, AppColors.blushGold, { letterSpacing: 0 })}>Vote</span>
          </button>
          <button
            type="button"
            className="bare-button"
            onClick={() => void finalize()}
            style={{
              flex: 1,
              minHeight: 40,
              padding: '10px 0',
              borderRadius: 12,
              background: AppColors.deepRose,
              ...AppTypography.outfitBold,
              fontSize: 11,
              color: AppColors.petalWhite,
            }}
          >
            Finalize
          </button>
        </div>
      ) : poll.decidedOptionId != null ? (
        <div
          style={{
            padding: '10px 12px',
            borderRadius: 12,
            background: withAlpha(AppColors.warmAmber, 0.12),
            border: `1px solid ${withAlpha(AppColors.warmAmber, 0.25)}`,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <Icon name="celebration" size={16} color={AppColors.warmAmber} />
          <div style={{ width: 8 }} />
          <span style={{ flex: 1, minWidth: 0, ...AppTypography.outfitBold, fontSize: 12, color: AppColors.warmAmber }}>
            Decided: {decided}
          </span>
          <TextButton
            onPressed={() => void calendarPollService.reopen(poll.id)}
            style={{ ...AppTypography.outfitWhite, fontSize: 11, color: AppColors.blushGold }}
          >
            Reopen
          </TextButton>
        </div>
      ) : null}
    </div>
  );
}

function AddPollDialog({ close }: { close: (saved: boolean | null) => void }) {
  const auth = useAuth();
  const [title, setTitle] = useState('');
  const [desc, setDesc] = useState('');
  const [dates, setDates] = useState<Date[]>([]);
  const [saving, setSaving] = useState(false);
  const picker = useRef<HTMLInputElement>(null);

  const now = new Date();
  const iso = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

  // showDatePicker then showTimePicker; the browser's date-and-time picker asks both at once (7 PM by default).
  const addDate = (value: string) => {
    if (value === '') return;
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime())) return;
    if (dates.some((d) => d.getTime() === dt.getTime())) return;
    setDates((ds) => [...ds, dt].sort((a, b) => a.getTime() - b.getTime()));
  };

  const canSave = !saving && title.trim() !== '' && dates.length >= 2;
  const save = async () => {
    if (!canSave) return;
    setSaving(true);
    try {
      await calendarPollService.create({
        title: title.trim(),
        description: desc.trim(),
        createdBy: auth.currentUser ?? 'unknown',
        createdAt: new Date(),
        status: 'open',
        votes: {},
        options: dates.map((d) => ({ id: String(d.getTime()), date: d, label: `${d.getMonth() + 1}/${d.getDate()} ${jm(d)}` })),
      });
    } catch {
      setSaving(false);
      showSnackBar('Could not create the poll — please try again.');
      return;
    }
    close(true);
  };

  return (
    <div
      className="no-scrollbar"
      style={{
        width: '100%',
        maxWidth: 520,
        maxHeight: 700,
        overflowY: 'auto',
        padding: 21,
        background: AppColors.velvet,
        borderRadius: 20,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
        boxSizing: 'border-box',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <span style={{ ...AppTypography.cormorantBold, fontSize: 22, lineHeight: mixedLineHeight(22) }}>New Date Poll 📊</span>
        <div style={{ flex: 1 }} />
        <EverglowIconButton icon="close" semanticLabel="Close" tooltip="Close" onPressed={() => close(null)} />
      </div>
      <div style={{ height: 4 }} />
      <div style={text(11, withAlpha(AppColors.petalWhite, 0.6))}>Rallly-style: propose dates, vote together</div>
      <div style={{ height: 16 }} />
      <FilledField
        value={title}
        onChange={setTitle}
        hint="What are we scheduling? e.g., Anniversary dinner"
        hintAlpha={0.4}
        radius={12}
        padding={[14, 12]}
      />
      <div style={{ height: 12 }} />
      <FilledField
        value={desc}
        onChange={setDesc}
        hint="Details (optional)"
        hintAlpha={0.4}
        radius={12}
        padding={[14, 14]}
        fontSize={13}
        lines={2}
      />
      <div style={{ height: 16 }} />
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 12,
            lineHeight: lineHeight(12),
            color: withAlpha(AppColors.petalWhite, 0.7),
          }}
        >
          Proposed dates
        </span>
        <div style={{ flex: 1 }} />
        <div style={{ position: 'relative' }}>
          <TextButton
            color={AppColors.blushGold}
            icon={<Icon name="add" size={16} color={AppColors.blushGold} />}
            onPressed={() => picker.current?.showPicker?.()}
            style={{ ...AppTypography.outfitBold, fontSize: 12 }}
          >
            Add date
          </TextButton>
          <input
            ref={picker}
            type="datetime-local"
            tabIndex={-1}
            aria-hidden
            min={`${iso(now)}T00:00`}
            max={`${iso(new Date(now.getTime() + 180 * 86_400_000))}T23:59`}
            defaultValue={`${iso(new Date(now.getTime() + 86_400_000))}T19:00`}
            onChange={(e) => addDate(e.target.value)}
            style={{ position: 'absolute', inset: 0, opacity: 0, pointerEvents: 'none' }}
          />
        </div>
      </div>
      <div style={{ height: 8 }} />
      {dates.length === 0 ? (
        <div
          style={{
            padding: 16,
            borderRadius: 12,
            background: AppColors.twilight,
            border: `1px solid ${Derived.border}`,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          <Icon name="event" size={18} color={withAlpha(AppColors.petalWhite, 0.5)} />
          <span style={text(12, withAlpha(AppColors.petalWhite, 0.6))}>Add at least 2 dates to vote</span>
        </div>
      ) : (
        dates.map((d) => (
          <div
            key={d.getTime()}
            style={{
              marginBottom: 8,
              padding: '10px 12px',
              borderRadius: 12,
              background: withAlpha(AppColors.moonlight, 0.08),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Icon name="calendar_today" size={14} color={AppColors.blushGold} />
            <div style={{ width: 8 }} />
            <span style={text(13, AppColors.petalWhite)}>
              {d.getMonth() + 1}/{d.getDate()}/{d.getFullYear()} {' '}
              {jm(d)}
            </span>
            <div style={{ flex: 1 }} />
            <button
              type="button"
              className="bare-button"
              aria-label="Remove date"
              onClick={() => setDates((ds) => ds.filter((x) => x !== d))}
              style={{ display: 'flex' }}
            >
              <Icon name="close" size={16} color={withAlpha(AppColors.petalWhite, 0.5)} />
            </button>
          </div>
        ))
      )}
      <div style={{ height: 20 }} />
      <button
        type="button"
        className="bare-button"
        onClick={() => void save()}
        style={{
          width: '100%',
          padding: '14px 0',
          borderRadius: 14,
          background: saving ? AppColors.moonlight : `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.rosePressed})`,
          display: 'flex',
          justifyContent: 'center',
          cursor: canSave ? 'pointer' : 'default',
        }}
      >
        {saving ? (
          <CircularProgress size={18} strokeWidth={2} color={AppColors.petalWhite} />
        ) : (
          <span
            style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: mixedLineHeight(14), color: AppColors.petalWhite }}
          >
            Create Poll ✨
          </span>
        )}
      </button>
    </div>
  );
}
