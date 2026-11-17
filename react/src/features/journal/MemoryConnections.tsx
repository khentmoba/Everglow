// Port of lib/features/journal/presentation/widgets/memory_connections.dart.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useAuth } from '../../core/services/auth';
import { AppColors, M3Scheme, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import type { Source } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showModalBottomSheet, TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { bucketListService } from '../bucket_list/bucketListService';
import { calendarService } from '../calendar/calendarService';
import { AddPhotoDialog, PhotoViewerScreen } from '../gallery/GalleryPage';
import { galleryService, gridPhotoUrl, type MemoryPhoto } from '../gallery/galleryService';
import { journalService, type JournalEntry } from './journalService';
import { COUPLE_USERS } from './openSharedMemory';

type Snap<T> = { data: T | undefined; error: boolean; active: boolean };

/** StreamBuilder with its error and connection state. */
function useStream<T>(make: () => Source<T> | null, key: unknown[], initial?: T): Snap<T> {
  const [snap, setSnap] = useState<Snap<T>>({ data: initial, error: false, active: false });
  useEffect(() => {
    setSnap({ data: initial, error: false, active: false });
    const source = make();
    if (!source) return;
    return source({
      data: (v) => setSnap({ data: v, error: false, active: true }),
      error: () => setSnap((s) => ({ ...s, error: true, active: true })),
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, key);
  return snap;
}

const body: CSSProperties = { ...AppTypography.bodyMedium, lineHeight: lineHeight(14) };

type LinkButton = (icon: string, text: string, onPressed?: () => void) => ReactNode;

export function MemoryConnections({ entry: initial }: { entry: JournalEntry }) {
  const username = useAuth().currentUser;
  const snap = useStream<JournalEntry | null>(() => journalService.watchEntry(initial), [initial.id], initial);
  const [words, setWords] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const loadedFor = useRef<string | null>(null);
  const lastWords = useRef<string | null>(null);
  const [overlay, setOverlay] = useState<{ kind: 'viewer'; photos: MemoryPhoto[]; index: number } | { kind: 'add' } | null>(null);

  const removed = snap.active && snap.data == null && !snap.error;
  const entry = snap.data ?? initial;
  const incoming = username ? (entry.perspectives[username] ?? '') : '';
  useEffect(() => {
    if (!username) return;
    if (loadedFor.current !== username || (words === (lastWords.current ?? '') && incoming !== lastWords.current)) {
      loadedFor.current = username;
      setWords(incoming);
      lastWords.current = incoming;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [username, incoming]);

  if (username == null || !COUPLE_USERS.has(username)) return null;
  if (removed) return <div style={body}>This memory was removed from Journal.</div>;

  const run = async (action: () => Promise<void>) => {
    if (saving) return;
    setSaving(true);
    setError(null);
    setNotice(null);
    try {
      await action();
      setNotice('Saved to this memory.');
    } catch {
      setError('Could not save this part of your memory. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const choosePhotos = async () => {
    const selected = await showModalBottomSheet<string[]>((close) => (
      <MemoryPhotoPicker selected={entry.photoIds} close={close} />
    ));
    if (selected == null) return;
    await run(() => journalService.setMemoryPhotos(entry.id, selected));
  };

  const linkButton: LinkButton = (icon, text, onPressed) => (
    <TextButton
      color={AppColors.roseQuartz}
      icon={<Icon name={icon} size={18} color={AppColors.roseQuartz} />}
      onPressed={onPressed}
    >
      {text}
    </TextButton>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      <div style={{ height: 24 }} />
      <div style={{ ...AppTypography.titleLarge, lineHeight: lineHeight(22, 28 / 22) }}>Our memory</div>
      {entry.bucketItemId != null && <WishLink id={entry.bucketItemId} button={linkButton} />}
      {entry.calendarEventId != null && <EventLink id={entry.calendarEventId} button={linkButton} />}
      {snap.error && <div style={body}>Could not refresh this memory. Close and reopen to retry.</div>}
      <div style={{ height: 12 }} />
      {entry.photoIds.length > 0 && (
        <PhotoStrip ids={entry.photoIds} onOpen={(photos, index) => setOverlay({ kind: 'viewer', photos, index })} />
      )}
      <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 8 }}>
        {linkButton('photo_library_outlined', 'Choose gallery photos', saving ? undefined : () => void choosePhotos())}
        {linkButton(
          'add_photo_alternate_outlined',
          'Upload a photo',
          saving || entry.photoIds.length >= 20 ? undefined : () => setOverlay({ kind: 'add' }),
        )}
      </div>
      <div style={{ height: 12 }} />
      {(['khentsgdz', 'clairjassen'] as const).map((person) => (
        <div key={person} style={{ alignSelf: 'stretch', display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <div style={{ ...AppTypography.titleSmall, lineHeight: lineHeight(14) }}>
            {person === 'khentsgdz' ? 'Khent’s favorite part' : 'Clair’s favorite part'}
          </div>
          <div style={{ height: 6 }} />
          {person === username ? (
            <>
              <OutlinedArea value={words} onChange={setWords} hint="What do you want to remember?" maxLength={1000} />
              <TextButton
                color={AppColors.roseQuartz}
                onPressed={saving ? undefined : () => void run(() => journalService.savePerspective(entry.id, username, words))}
              >
                {saving ? 'Saving...' : 'Save my words'}
              </TextButton>
            </>
          ) : (
            <div style={{ ...body, whiteSpace: 'pre-wrap' }}>
              {entry.perspectives[person] ? entry.perspectives[person] : 'A little space for their side of the story.'}
            </div>
          )}
          <div style={{ height: 16 }} />
        </div>
      ))}
      {notice != null && <div style={{ ...body, color: AppColors.roseQuartz }}>{notice}</div>}
      {error != null && <div style={{ ...body, color: AppColors.error }}>{error}</div>}
      {overlay?.kind === 'viewer' &&
        createPortal(
          <PhotoViewerScreen
            photos={overlay.photos}
            initialIndex={overlay.index}
            onClose={() => setOverlay(null)}
            onDelete={(p) => galleryService.deletePhoto(p)}
          />,
          document.body,
        )}
      {overlay?.kind === 'add' &&
        createPortal(
          <AddPhotoDialog
            onClose={(photo) => {
              setOverlay(null);
              if (photo) void run(() => journalService.addMemoryPhoto(entry.id, photo.id));
            }}
          />,
          document.body,
        )}
    </div>
  );
}

function WishLink({ id, button }: { id: string; button: LinkButton }) {
  const s = useStream(() => bucketListService.watchItem(id), [id]);
  if (s.error) return <div style={body}>Could not load the original wish.</div>;
  if (s.data == null) return <div style={body}>The original wish is no longer available.</div>;
  return button('auto_awesome_outlined', `Original wish: ${s.data.title}`, () => undefined);
}

function EventLink({ id, button }: { id: string; button: LinkButton }) {
  const s = useStream(() => calendarService.watchEvent(id), [id]);
  if (s.error) return <div style={body}>Could not load the calendar plan.</div>;
  if (s.data == null) return <div style={body}>The calendar plan is no longer available.</div>;
  return button('event_outlined', `Calendar plan: ${s.data.title}`, () => undefined);
}

function PhotoStrip({ ids, onOpen }: { ids: string[]; onOpen: (photos: MemoryPhoto[], index: number) => void }) {
  const s = useStream(() => galleryService.watchPhotosByIds(ids), [ids.join('|')]);
  if (s.error) return <div style={body}>Photos could not load. Close and reopen to retry.</div>;
  const photos = s.data;
  if (photos == null) return <LinearProgress color={AppColors.deepRose} background={withAlpha(AppColors.deepRose, 0.24)} />;
  if (photos.length === 0) return <div style={body}>The linked photos are no longer in the gallery.</div>;
  return (
    <div className="no-scrollbar" style={{ alignSelf: 'stretch', height: 112, display: 'flex', gap: 8, overflowX: 'auto' }}>
      {photos.map((p, i) => (
        <button
          key={p.id}
          type="button"
          className="bare-button"
          aria-label={`Open memory photo ${i + 1}`}
          onClick={() => onOpen(photos, i)}
          style={{ width: 112, height: 112, flexShrink: 0 }}
        >
          <img src={gridPhotoUrl(p)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
        </button>
      ))}
    </div>
  );
}

function OutlinedArea({
  value,
  onChange,
  hint,
  maxLength,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  maxLength: number;
}) {
  const [focused, setFocused] = useState(false);
  const ref = useRef<HTMLTextAreaElement>(null);
  const line = 24;
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = '0px';
    const lines = Math.min(4, Math.max(2, Math.round((el.scrollHeight - 32) / line)));
    el.style.height = `${lines * line + 32}px`;
  }, [value]);
  return (
    <div style={{ alignSelf: 'stretch' }}>
      <textarea
        ref={ref}
        className="money-input no-scrollbar"
        value={value}
        maxLength={maxLength}
        placeholder={hint}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        onChange={(e) => onChange(e.target.value)}
        style={{
          width: '100%',
          boxSizing: 'border-box',
          padding: '16px 12px',
          background: 'transparent',
          borderRadius: 4,
          border: 'none',
          boxShadow: `inset 0 0 0 ${focused ? 2 : 1}px ${focused ? AppColors.deepRose : M3Scheme.outline}`,
          outline: 'none',
          resize: 'none',
          fontFamily: AppTypography.bodyMedium.fontFamily,
          fontSize: 16,
          letterSpacing: 0.5,
          lineHeight: `${line}px`,
          color: AppColors.petalWhite,
          ['--hint-color' as string]: M3Scheme.onSurfaceVariant,
          ['--hint-size' as string]: '16px',
        }}
      />
      <div
        style={{
          padding: '4px 16px 0',
          textAlign: 'right',
          fontSize: 12,
          lineHeight: lineHeight(12, 16 / 12),
          color: M3Scheme.onSurfaceVariant,
        }}
      >
        {value.length}/{maxLength}
      </div>
    </div>
  );
}

function MemoryPhotoPicker({ selected: initial, close }: { selected: string[]; close: (v: string[] | null) => void }) {
  const [selected, setSelected] = useState(() => new Set(initial));
  const s = useStream(() => galleryService.getPhotosStream(100), []);
  const center = (child: ReactNode) => (
    <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{child}</div>
  );
  return (
    <div
      style={{
        width: '100%',
        maxWidth: 640,
        margin: '0 auto',
        height: window.innerHeight * 0.8,
        background: AppColors.velvet,
        borderRadius: '28px 28px 0 0',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ padding: 16, display: 'flex', alignItems: 'center' }}>
        <div style={{ flex: 1, ...body }}>Recent gallery photos · up to 20</div>
        <TextButton color={AppColors.roseQuartz} onPressed={() => close([...selected])}>
          Save photos
        </TextButton>
      </div>
      {s.error ? (
        center(<div style={body}>Could not load photos. Close and try again.</div>)
      ) : s.data == null ? (
        center(<CircularProgress size={36} strokeWidth={4} color={AppColors.deepRose} />)
      ) : s.data.length === 0 ? (
        center(<div style={body}>Upload a photo to Gallery first, or use Upload a photo.</div>)
      ) : (
        <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto' }}>
          {s.data.map((p) => {
            const on = selected.has(p.id);
            const disabled = !on && selected.size >= 20;
            return (
              <label
                key={p.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 16,
                  padding: '8px 24px 8px 16px',
                  opacity: disabled ? 0.38 : 1,
                  cursor: 'pointer',
                }}
              >
                <img src={gridPhotoUrl(p)} alt="" style={{ width: 48, height: 48, objectFit: 'cover' }} />
                <span style={{ flex: 1, ...AppTypography.titleMedium, lineHeight: lineHeight(16, 1.5) }}>
                  {p.caption === '' ? 'A photo together' : p.caption}
                </span>
                <input
                  type="checkbox"
                  checked={on}
                  disabled={disabled}
                  onChange={(e) => {
                    const next = new Set(selected);
                    if (e.target.checked) next.add(p.id);
                    else next.delete(p.id);
                    setSelected(next);
                  }}
                  style={{ width: 18, height: 18, accentColor: AppColors.deepRose }}
                />
              </label>
            );
          })}
        </div>
      )}
    </div>
  );
}
