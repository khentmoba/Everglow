// Port of lib/features/calendar/presentation/widgets/add_event_dialog.dart.
import { useRef, useState, type CSSProperties } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { boxShadow, insetBorder, lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { TextButton } from '../../shared/widgets/Dialogs';
import { FilledField } from '../../shared/widgets/FilledField';
import { Icon } from '../../shared/widgets/Icon';
import { CALENDAR_EVENT_TYPES, CALENDAR_TYPE_INFO, calendarService, type CalendarEventType } from './calendarService';
import { jm } from './calendarUi';

export type WishSeed = { id: string; title: string; description: string; notes: string };

const label12: CSSProperties = {
  ...AppTypography.outfitWhite,
  fontSize: 12,
  lineHeight: lineHeight(12),
  color: withAlpha(AppColors.petalWhite, 0.75),
};

export function AddEventDialog({
  selectedDay,
  initialType = 'custom',
  wish,
  close,
}: {
  selectedDay: Date;
  initialType?: CalendarEventType;
  wish?: WishSeed;
  close: (saved: boolean | null) => void;
}) {
  const auth = useAuth();
  const { height } = useViewport();
  const [title, setTitle] = useState(wish?.title ?? '');
  const [desc, setDesc] = useState(wish ? [wish.description, wish.notes].filter((s) => s !== '').join('\n\n') : '');
  const [location, setLocation] = useState('');
  const [type, setType] = useState<CalendarEventType>(initialType);
  const [recurring, setRecurring] = useState('none');
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [time, setTime] = useState({ h: 19, m: 0 });
  const [allDay, setAllDay] = useState(false);
  const [attendees, setAttendees] = useState<string[]>(wish ? ['khentsgdz', 'clairjassen'] : []);
  const timeInput = useRef<HTMLInputElement>(null);
  const errorRef = useRef<HTMLDivElement>(null);

  const d = selectedDay;
  const date = allDay
    ? new Date(d.getFullYear(), d.getMonth(), d.getDate())
    : new Date(d.getFullYear(), d.getMonth(), d.getDate(), time.h, time.m);
  const canSave = title.trim() !== '' && !saving;

  const save = async () => {
    if (!canSave) return;
    setSaving(true);
    setSaveError(null);
    try {
      await calendarService.addEvent({
        bucketItemId: wish?.id,
        title: title.trim(),
        description: desc.trim(),
        date,
        type,
        createdBy: auth.currentUser ?? 'unknown',
        recurring,
        location: location.trim() === '' ? undefined : location.trim(),
        attendees,
        isAllDay: allDay,
      });
      close(true);
    } catch {
      setSaveError('Could not save this event. Your details are still here — please try again.');
      requestAnimationFrame(() => errorRef.current?.scrollIntoView({ block: 'center' }));
    } finally {
      setSaving(false);
    }
  };

  const attendee = (username: string, label: string) => {
    const sel = attendees.includes(username);
    return (
      <button
        type="button"
        className="bare-button"
        onClick={() => setAttendees((a) => (sel ? a.filter((x) => x !== username) : [...a, username]))}
        style={{
          padding: '6px 12px',
          borderRadius: 20,
          background: sel ? withAlpha(AppColors.deepRose, 0.25) : AppColors.twilight,
          border: `1px solid ${sel ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15)}`,
          ...AppTypography.outfitWhite,
          fontSize: 12,
          lineHeight: lineHeight(12),
          fontWeight: sel ? 700 : 500,
          color: sel ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.7),
        }}
      >
        {label}
      </button>
    );
  };

  return (
    <div
      style={{
        margin: '0 32px',
        width: '100%',
        maxHeight: height * 0.85,
        padding: 25.5,
        background: AppColors.velvet,
        borderRadius: 24,
        boxShadow: [
          insetBorder(withAlpha(AppColors.blushGold, 0.25), 1.5).boxShadow,
          boxShadow([{ color: withAlpha(AppColors.deepRose, 0.3), blur: 20, spread: 5 }]),
        ].join(', '),
        boxSizing: 'border-box',
        overflowY: 'auto',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
      className="no-scrollbar"
    >
      <div style={{ ...AppTypography.cormorantBold, fontSize: 26, lineHeight: mixedLineHeight(26) }}>Add Event 📅</div>
      <div style={{ height: 4 }} />
      <div style={{ ...AppTypography.outfitWhite, fontSize: 13, lineHeight: lineHeight(13), color: AppColors.blushGold }}>
        {d.getMonth() + 1}/{d.getDate()}/{d.getFullYear()}
      </div>
      <div style={{ height: 20 }} />
      <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 8, rowGap: 6, justifyContent: 'center' }}>
        {CALENDAR_EVENT_TYPES.map((t) => {
          const info = CALENDAR_TYPE_INFO[t];
          const sel = type === t;
          return (
            <button
              key={t}
              type="button"
              className="bare-button"
              onClick={() => setType(t)}
              style={{
                padding: '6px 12px',
                borderRadius: 16,
                background: sel ? withAlpha(AppColors.deepRose, 0.7) : AppColors.twilight,
                border: `1px solid ${sel ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15)}`,
                transition: 'background-color 200ms, border-color 200ms',
                ...AppTypography.outfitWhite,
                fontSize: 12,
                lineHeight: mixedLineHeight(12),
                fontWeight: sel ? 700 : 500,
                color: sel ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.7),
              }}
            >
              {info.emoji} {info.label}
            </button>
          );
        })}
      </div>
      <div style={{ height: 16 }} />
      <FilledField
        value={title}
        onChange={setTitle}
        hint="Event title"
        hintAlpha={0.65}
        radius={16}
        padding={[16, 16]}
        borderColor={withAlpha(AppColors.blushGold, 0.2)}
        focusColor={AppColors.blushGold}
      />
      <div style={{ height: 12 }} />
      <FilledField
        value={desc}
        onChange={setDesc}
        hint="Description (optional)"
        hintAlpha={0.65}
        radius={16}
        padding={[16, 16]}
        lines={2}
        borderColor={withAlpha(AppColors.blushGold, 0.2)}
        focusColor={AppColors.blushGold}
      />
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', width: '100%', alignItems: 'center' }}>
        <div
          onClick={allDay ? undefined : () => timeInput.current?.showPicker?.()}
          style={{
            flex: 1,
            position: 'relative',
            padding: '12px 14px',
            borderRadius: 12,
            background: allDay ? withAlpha(AppColors.twilight, 0.5) : AppColors.twilight,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            cursor: allDay ? undefined : 'pointer',
          }}
        >
          <Icon name="access_time" size={16} color={allDay ? withAlpha(AppColors.petalWhite, 0.3) : AppColors.blushGold} />
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 13,
              lineHeight: lineHeight(13),
              color: allDay ? withAlpha(AppColors.petalWhite, 0.4) : AppColors.petalWhite,
            }}
          >
            {allDay ? 'All day' : jm(new Date(2000, 0, 1, time.h, time.m))}
          </span>
          <input
            ref={timeInput}
            type="time"
            tabIndex={-1}
            aria-hidden
            value={`${String(time.h).padStart(2, '0')}:${String(time.m).padStart(2, '0')}`}
            onChange={(e) => {
              const [h, m] = e.target.value.split(':').map(Number);
              if (!Number.isNaN(h) && !Number.isNaN(m)) setTime({ h, m });
            }}
            style={{ position: 'absolute', inset: 0, opacity: 0, pointerEvents: 'none' }}
          />
        </div>
        <div style={{ width: 10 }} />
        <button
          type="button"
          className="bare-button"
          onClick={() => setAllDay((v) => !v)}
          style={{
            padding: '10px 12px',
            borderRadius: 12,
            background: allDay ? withAlpha(AppColors.deepRose, 0.2) : AppColors.twilight,
            border: `1px solid ${allDay ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15)}`,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon
            name={allDay ? 'check_box' : 'check_box_outline_blank'}
            size={16}
            color={allDay ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.6)}
          />
          <span style={{ ...label12, color: allDay ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.7) }}>All-day</span>
        </button>
      </div>
      <div style={{ height: 12 }} />
      <FilledField
        value={location}
        onChange={setLocation}
        hint="Location (optional)"
        hintAlpha={0.65}
        radius={16}
        padding={[16, 16]}
        borderColor={withAlpha(AppColors.blushGold, 0.2)}
        focusColor={AppColors.blushGold}
        prefixIcon={<Icon name="place_outlined" size={18} color={withAlpha(AppColors.petalWhite, 0.6)} />}
      />
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', width: '100%', alignItems: 'center' }}>
        <span style={label12}>With</span>
        <div style={{ width: 10 }} />
        {attendee('khentsgdz', 'Khent')}
        <div style={{ width: 8 }} />
        {attendee('clairjassen', 'Clair')}
      </div>
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', width: '100%', alignItems: 'center' }}>
        <span style={label12}>Repeat</span>
        <div style={{ width: 12 }} />
        <div
          style={{
            flex: 1,
            padding: '0 12px',
            borderRadius: 12,
            background: AppColors.twilight,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
          }}
        >
          <select
            value={recurring}
            onChange={(e) => setRecurring(e.target.value)}
            style={{
              width: '100%',
              height: 48,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              ...AppTypography.outfitWhite,
              fontSize: 13,
              color: AppColors.petalWhite,
              colorScheme: 'dark',
            }}
          >
            <option value="none">None</option>
            <option value="monthly">Monthly</option>
            <option value="yearly">Yearly</option>
          </select>
        </div>
      </div>
      <div style={{ height: 24 }} />
      {saveError && (
        <>
          <div ref={errorRef} style={{ ...AppTypography.outfitWhite, fontSize: 14, color: AppColors.error, width: '100%' }}>
            {saveError}
          </div>
          <div style={{ height: 12 }} />
        </>
      )}
      <div style={{ display: 'flex', width: '100%', justifyContent: 'flex-end', alignItems: 'center', gap: 12 }}>
        <TextButton
          onPressed={() => close(null)}
          style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.6) }}
        >
          Cancel
        </TextButton>
        {/* Flutter only re-reads the title on the next rebuild; here Save enables as you type. */}
        <button
          type="button"
          className="bare-button"
          disabled={!canSave}
          onClick={() => void save()}
          style={{
            minHeight: 40,
            padding: '12px 24px',
            borderRadius: 24,
            background: canSave || saving ? AppColors.deepRose : withAlpha(AppColors.deepRose, 0.3),
            color: canSave ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.38),
            ...AppTypography.outfitWhite,
            fontWeight: 700,
            fontSize: 14,
            lineHeight: lineHeight(14),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {saving ? <CircularProgress size={16} strokeWidth={2} color={AppColors.petalWhite} /> : 'Save'}
        </button>
      </div>
    </div>
  );
}
