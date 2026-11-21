import { useEffect, useState, type CSSProperties } from 'react';
import { ConnectivityService } from '../../core/network/connectivity';
import { NetworkQualityService } from '../../core/network/networkQuality';
import { useAuth } from '../../core/services/auth';
import type { SystemStatus } from '../../core/system/healthService';
import { useValue } from '../../core/system/store';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import type { MilestoneCategory } from '../../core/agent/fixtures';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { creatorService, type MemberAccount } from './creatorService';
import { MILESTONE_META } from './milestoneService';

type CreatorTab = 'letters' | 'memories' | 'surprises' | 'accounts' | 'system';

const LETTER_TEMPLATES = [
  { name: 'Love Letter', title: 'To My Love', body: 'Just a quiet reminder that you are my favorite part of every single day.' },
  { name: 'Midnight Note', title: 'For Late Nights', body: 'If you are awake reading this, take a deep breath — I am right here with you.' },
  { name: 'Countdown', title: 'Almost Time', body: 'Counting down the hours until I get to see your smile again.' },
];

const WHISPER_IDEAS = [
  'You are doing amazing today, my love',
  'Khent left your favorite snack ready for movie night',
  'Take a deep breath — I am so proud of you',
  'Check the Letterbox… something secret is waiting',
];

const inputStyle: CSSProperties = {
  width: '100%',
  padding: '10px 12px',
  borderRadius: AppRadius.sm,
  background: withAlpha(AppColors.shimmerBase, 0.9),
  border: `1px solid ${Derived.border}`,
  color: AppColors.petalWhite,
  outline: 'none',
  fontSize: 13.5,
  fontFamily: 'inherit',
  boxSizing: 'border-box',
};

const cardStyle: CSSProperties = {
  padding: 14,
  borderRadius: AppRadius.md,
  background: Derived.surfaceGlass,
  border: `1px solid ${Derived.border}`,
  display: 'flex',
  flexDirection: 'column',
  gap: 10,
};

function toDateInputValue(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function CreatorModal({ onClose }: { onClose: () => void }) {
  const [tab, setTab] = useState<CreatorTab>('letters');

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const tabs: Array<{ id: CreatorTab; label: string; icon: string }> = [
    { id: 'letters', label: 'Letters', icon: 'mail_outline' },
    { id: 'memories', label: 'Memories', icon: 'photo_library' },
    { id: 'surprises', label: 'Surprises', icon: 'auto_awesome' },
    { id: 'accounts', label: 'Accounts', icon: 'manage_accounts' },
    { id: 'system', label: 'System', icon: 'tune' },
  ];

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Creator Studio"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 1200,
        background: withAlpha(AppColors.inkDeep, 0.72),
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 680,
          height: '86%',
          maxHeight: 760,
          background: AppColors.inkDeep,
          borderTopLeftRadius: 28,
          borderTopRightRadius: 28,
          border: `1px solid ${Derived.border}`,
          borderBottom: 'none',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          boxShadow: '0 -12px 40px rgba(0,0,0,0.55)',
        }}
      >
        <div style={{ padding: '12px 18px 0', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: withAlpha(AppColors.moonlight, 0.24) }} />
          <div style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 10 }}>
            <div>
              <div style={{ ...AppTypography.outfitHeading, fontSize: 17, color: AppColors.petalWhite }}>
                Creator Studio
              </div>
              <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: Derived.textMuted }}>
                Khent&apos;s private workshop for Clair
              </div>
            </div>
            <button
              type="button"
              className="bare-button"
              aria-label="Close Creator Studio"
              onClick={onClose}
              style={{
                width: 34,
                height: 34,
                borderRadius: '50%',
                background: withAlpha(AppColors.petalWhite, 0.08),
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="close" size={18} color={AppColors.petalWhite} />
            </button>
          </div>

          <div
            role="tablist"
            style={{
              width: '100%',
              display: 'grid',
              gridTemplateColumns: 'repeat(5, 1fr)',
              gap: 6,
              marginTop: 12,
              paddingBottom: 10,
              borderBottom: `1px solid ${Derived.border}`,
            }}
          >
            {tabs.map((t) => {
              const active = tab === t.id;
              return (
                <button
                  key={t.id}
                  role="tab"
                  aria-selected={active}
                  type="button"
                  className="bare-button"
                  onClick={() => setTab(t.id)}
                  style={{
                    padding: '8px 6px',
                    borderRadius: AppRadius.sm,
                    background: active ? withAlpha(AppColors.deepRose, 0.24) : 'transparent',
                    border: `1px solid ${active ? withAlpha(AppColors.blushGold, 0.45) : 'transparent'}`,
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: 4,
                    color: active ? AppColors.petalWhite : Derived.textMuted,
                    ...AppTypography.outfitBold,
                    fontSize: 11.5,
                  }}
                >
                  <Icon name={t.icon} size={18} color={active ? AppColors.blushGold : Derived.textMuted} />
                  <span>{t.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        <div
          className="no-scrollbar"
          style={{ flex: 1, overflowY: 'auto', padding: `${AppSpacing.md}px 18px 28px`, display: 'flex', flexDirection: 'column', gap: 14 }}
        >
          {tab === 'letters' && <CreatorLettersTab />}
          {tab === 'memories' && <CreatorMemoriesTab />}
          {tab === 'surprises' && <CreatorSurprisesTab />}
          {tab === 'accounts' && <CreatorAccountsTab />}
          {tab === 'system' && <CreatorSystemTab />}
        </div>
      </div>
    </div>
  );
}

function CreatorLettersTab() {
  const notes = useSource(() => creatorService.watchHiddenNotes(50), [], []);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [unlockDate, setUnlockDate] = useState(() => {
    const tomorrow = new Date(Date.now() + 86400000);
    return toDateInputValue(tomorrow);
  });
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!title.trim() || !content.trim()) {
      showSnackBar('Add a title and message first.');
      return;
    }
    setSaving(true);
    try {
      await creatorService.saveHiddenNote({
        title,
        content,
        unlockDate: new Date(`${unlockDate}T09:00:00`),
      });
      setTitle('');
      setContent('');
      showSnackBar('Letter sealed in the Letterbox');
    } catch {
      showSnackBar('Could not save letter.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
          Seal a New Letter
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {LETTER_TEMPLATES.map((tpl) => (
            <button
              key={tpl.name}
              type="button"
              className="bare-button"
              onClick={() => {
                setTitle(tpl.title);
                setContent(tpl.body);
              }}
              style={{
                padding: '5px 10px',
                borderRadius: 999,
                background: withAlpha(AppColors.roseQuartz, 0.14),
                border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.3)}`,
                color: AppColors.petalWhite,
                fontSize: 11.5,
              }}
            >
              {tpl.name}
            </button>
          ))}
        </div>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Letter title" style={inputStyle} />
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Write something warm for Clair…"
          rows={4}
          style={{ ...inputStyle, resize: 'vertical' }}
        />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <label style={{ fontSize: 12, color: Derived.textMedium, flexShrink: 0 }}>Unlock date</label>
          <input type="date" value={unlockDate} onChange={(e) => setUnlockDate(e.target.value)} style={{ ...inputStyle, flex: 1 }} />
        </div>
        <button
          type="button"
          className="bare-button"
          disabled={saving}
          onClick={() => void handleSave()}
          style={{
            padding: '10px 16px',
            borderRadius: AppRadius.sm,
            background: AppColors.deepRose,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 13,
          }}
        >
          {saving ? 'Sealing…' : 'Schedule Letter'}
        </button>
      </div>

      <div style={{ ...AppTypography.outfitBold, fontSize: 12.5, color: Derived.textMedium }}>
        Scheduled &amp; Past Letters ({notes.length})
      </div>
      {notes.map((n) => (
        <div key={n.id} style={{ ...cardStyle, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ minWidth: 0, flex: 1 }}>
            <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.petalWhite }}>{n.title}</div>
            <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
              Unlocks {n.unlockDate.toLocaleDateString()} · {n.isRead ? 'Read' : 'Unread'}
            </div>
          </div>
          <button
            type="button"
            className="bare-button"
            aria-label={`Delete ${n.title}`}
            onClick={() => void creatorService.deleteHiddenNote(n.id).then(() => showSnackBar('Letter deleted'))}
            style={{ padding: 6 }}
          >
            <Icon name="delete_outline" size={18} color={AppColors.roseQuartz} />
          </button>
        </div>
      ))}
    </>
  );
}

function CreatorMemoriesTab() {
  const auth = useAuth();
  const milestones = useSource(() => creatorService.watchMilestones(40), [], []);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [dateStr, setDateStr] = useState(() => toDateInputValue(new Date()));
  const [category, setCategory] = useState<MilestoneCategory>('memory');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [existingUrls, setExistingUrls] = useState<string[]>([]);
  const [files, setFiles] = useState<File[]>([]);
  const [saving, setSaving] = useState(false);

  const reset = () => {
    setTitle('');
    setDescription('');
    setDateStr(toDateInputValue(new Date()));
    setCategory('memory');
    setEditingId(null);
    setExistingUrls([]);
    setFiles([]);
  };

  const handleSave = async () => {
    if (!title.trim()) {
      showSnackBar('Give this milestone a title.');
      return;
    }
    setSaving(true);
    try {
      const uploaded: string[] = [];
      for (const f of files) {
        const url = await creatorService.uploadMilestoneImage(f, auth.uid ?? 'khent');
        if (url) uploaded.push(url);
      }
      const imageUrls = [...existingUrls, ...uploaded];
      const payload = {
        title,
        description,
        date: new Date(`${dateStr}T12:00:00`),
        category,
        imageUrls,
        author: auth.currentUser ?? 'khentsgdz',
      };
      if (editingId) {
        await creatorService.updateMilestone({ id: editingId, ...payload });
        showSnackBar('Milestone updated');
      } else {
        await creatorService.saveMilestone(payload);
        showSnackBar('Milestone added to timeline');
      }
      reset();
    } catch {
      showSnackBar('Could not save milestone.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <div style={cardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
            {editingId ? 'Edit Milestone' : 'Add Timeline Milestone'}
          </span>
          {editingId && (
            <button type="button" className="bare-button" onClick={reset} style={{ fontSize: 12, color: Derived.textMuted }}>
              Cancel edit
            </button>
          )}
        </div>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Milestone title" style={inputStyle} />
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="What happened on this day?"
          rows={3}
          style={{ ...inputStyle, resize: 'vertical' }}
        />
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {(Object.keys(MILESTONE_META) as MilestoneCategory[]).map((cat) => (
            <button
              key={cat}
              type="button"
              className="bare-button"
              onClick={() => setCategory(cat)}
              style={{
                padding: '5px 10px',
                borderRadius: 999,
                background: category === cat ? withAlpha(AppColors.deepRose, 0.35) : withAlpha(AppColors.petalWhite, 0.06),
                border: `1px solid ${category === cat ? AppColors.roseQuartz : Derived.border}`,
                color: AppColors.petalWhite,
                fontSize: 11.5,
              }}
            >
              {MILESTONE_META[cat].emoji} {MILESTONE_META[cat].label}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <input type="date" value={dateStr} onChange={(e) => setDateStr(e.target.value)} style={{ ...inputStyle, flex: 1 }} />
          <label
            style={{
              padding: '9px 12px',
              borderRadius: AppRadius.sm,
              background: withAlpha(AppColors.petalWhite, 0.08),
              border: `1px solid ${Derived.border}`,
              fontSize: 12,
              cursor: 'pointer',
            }}
          >
            {files.length ? `${files.length} photo(s) ready` : 'Add photos'}
            <input
              type="file"
              accept="image/*"
              multiple
              style={{ display: 'none' }}
              onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
            />
          </label>
        </div>
        <button
          type="button"
          className="bare-button"
          disabled={saving}
          onClick={() => void handleSave()}
          style={{
            padding: '10px 16px',
            borderRadius: AppRadius.sm,
            background: AppColors.deepRose,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 13,
          }}
        >
          {saving ? 'Saving…' : editingId ? 'Update Milestone' : 'Save Milestone'}
        </button>
      </div>

      <div style={{ ...AppTypography.outfitBold, fontSize: 12.5, color: Derived.textMedium }}>
        Timeline Milestones ({milestones.length})
      </div>
      {milestones.map((m) => (
        <div key={m.id} style={{ ...cardStyle, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ minWidth: 0, flex: 1 }}>
            <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.petalWhite }}>{m.title}</div>
            <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
              {m.date.toLocaleDateString()} · {m.imageUrls.length} photo(s)
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button
              type="button"
              className="bare-button"
              aria-label={`Edit ${m.title}`}
              onClick={() => {
                setEditingId(m.id);
                setTitle(m.title);
                setDescription(m.description);
                setDateStr(toDateInputValue(m.date));
                setCategory(m.category);
                setExistingUrls(m.imageUrls);
                setFiles([]);
              }}
              style={{ padding: 6 }}
            >
              <Icon name="edit" size={17} color={AppColors.blushGold} />
            </button>
            <button
              type="button"
              className="bare-button"
              aria-label={`Delete ${m.title}`}
              onClick={() => void creatorService.deleteMilestone(m.id).then(() => showSnackBar('Milestone deleted'))}
              style={{ padding: 6 }}
            >
              <Icon name="delete_outline" size={18} color={AppColors.roseQuartz} />
            </button>
          </div>
        </div>
      ))}
    </>
  );
}

function CreatorSurprisesTab() {
  const auth = useAuth();
  const whispers = useSource(() => creatorService.watchGuardianWhispers(12), [], []);
  const tonight = useSource(() => creatorService.watchTonightFeature(), [], null);
  const [whisper, setWhisper] = useState('');
  const [burst, setBurst] = useState('');
  const [teaserTitle, setTeaserTitle] = useState('');
  const [teaserDate, setTeaserDate] = useState(() => toDateInputValue(new Date(Date.now() + 7 * 86400000)));
  const [spotTitle, setSpotTitle] = useState('');
  const [spotNote, setSpotNote] = useState('');
  const [spotType, setSpotType] = useState<'movie' | 'tv'>('movie');

  return (
    <>
      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
          Guardian Cat Whisper
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {WHISPER_IDEAS.map((idea) => (
            <button
              key={idea}
              type="button"
              className="bare-button"
              onClick={() => setWhisper(idea)}
              style={{
                padding: '4px 9px',
                borderRadius: 999,
                background: withAlpha(AppColors.petalWhite, 0.07),
                border: `1px solid ${Derived.border}`,
                color: Derived.textMedium,
                fontSize: 11,
                textAlign: 'left',
              }}
            >
              {idea}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <input value={whisper} onChange={(e) => setWhisper(e.target.value)} placeholder="Whisper from the Guardian cat…" style={{ ...inputStyle, flex: 1 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              if (!whisper.trim()) return;
              void creatorService.sendGuardianWhisper(whisper).then(() => {
                setWhisper('');
                showSnackBar('Whisper sent to Guardian');
              });
            }}
            style={{ padding: '0 14px', borderRadius: AppRadius.sm, background: AppColors.deepRose, color: AppColors.petalWhite, fontWeight: 700, fontSize: 12.5 }}
          >
            Send
          </button>
        </div>
        {whispers.map((w) => (
          <div key={w.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 12, color: Derived.textMedium }}>
            <span style={{ flex: 1 }}>{w.content}</span>
            <button type="button" className="bare-button" onClick={() => void creatorService.deleteGuardianWhisper(w.id)} style={{ padding: 4 }}>
              <Icon name="close" size={14} color={Derived.textMuted} />
            </button>
          </div>
        ))}
      </div>

      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
          Drop a Love Burst (Starlight Jar)
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <input value={burst} onChange={(e) => setBurst(e.target.value)} placeholder="Drop a surprise star note…" style={{ ...inputStyle, flex: 1 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              if (!burst.trim()) return;
              void creatorService.sendLoveBurst(burst, auth.currentUser ?? 'khentsgdz').then(() => {
                setBurst('');
                showSnackBar('Surprise star dropped in the jar');
              });
            }}
            style={{ padding: '0 14px', borderRadius: AppRadius.sm, background: AppColors.deepRose, color: AppColors.petalWhite, fontWeight: 700, fontSize: 12.5 }}
          >
            Drop
          </button>
        </div>
      </div>

      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
          Teaser Countdown
        </div>
        <input value={teaserTitle} onChange={(e) => setTeaserTitle(e.target.value)} placeholder="e.g. Surprise Dinner Date" style={inputStyle} />
        <div style={{ display: 'flex', gap: 8 }}>
          <input type="date" value={teaserDate} onChange={(e) => setTeaserDate(e.target.value)} style={{ ...inputStyle, flex: 1 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              if (!teaserTitle.trim()) return;
              void creatorService
                .createTeaserCountdown({
                  title: teaserTitle,
                  date: new Date(`${teaserDate}T18:00:00`),
                  createdBy: auth.currentUser ?? 'khentsgdz',
                })
                .then(() => {
                  setTeaserTitle('');
                  showSnackBar('Countdown added to Calendar');
                });
            }}
            style={{ padding: '0 14px', borderRadius: AppRadius.sm, background: AppColors.deepRose, color: AppColors.petalWhite, fontWeight: 700, fontSize: 12.5 }}
          >
            Add
          </button>
        </div>
      </div>

      <div style={cardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
            Tonight&apos;s Cinema Spotlight
          </span>
          {tonight?.active && (
            <button
              type="button"
              className="bare-button"
              onClick={() => void creatorService.clearTonightFeature().then(() => showSnackBar('Spotlight cleared'))}
              style={{ fontSize: 11.5, color: AppColors.roseQuartz }}
            >
              Clear
            </button>
          )}
        </div>
        {tonight?.active && (
          <div style={{ fontSize: 12, color: Derived.textMedium }}>
            Active: <strong>{tonight.title}</strong> {tonight.note ? `— ${tonight.note}` : ''}
          </div>
        )}
        <div style={{ display: 'flex', gap: 8 }}>
          <input value={spotTitle} onChange={(e) => setSpotTitle(e.target.value)} placeholder="Movie or series title" style={{ ...inputStyle, flex: 1 }} />
          <select
            value={spotType}
            onChange={(e) => setSpotType(e.target.value === 'tv' ? 'tv' : 'movie')}
            style={{ ...inputStyle, width: 92 }}
          >
            <option value="movie">Movie</option>
            <option value="tv">Series</option>
          </select>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <input value={spotNote} onChange={(e) => setSpotNote(e.target.value)} placeholder="Optional note for Clair" style={{ ...inputStyle, flex: 1 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              if (!spotTitle.trim()) return;
              void creatorService
                .setTonightFeature({
                  title: spotTitle,
                  mediaType: spotType,
                  note: spotNote,
                  setBy: auth.currentUser ?? 'khentsgdz',
                })
                .then(() => {
                  setSpotTitle('');
                  setSpotNote('');
                  showSnackBar('Tonight spotlight updated');
                });
            }}
            style={{ padding: '0 14px', borderRadius: AppRadius.sm, background: AppColors.deepRose, color: AppColors.petalWhite, fontWeight: 700, fontSize: 12.5 }}
          >
            Set
          </button>
        </div>
      </div>
    </>
  );
}

function CreatorSystemTab() {
  const isOnline = useValue(ConnectivityService.isOnlineNotifier);
  const netQuality = useValue(NetworkQualityService.qualityNotifier);
  const [health, setHealth] = useState<SystemStatus | null>(null);
  const [checkingHealth, setCheckingHealth] = useState(false);
  const [usage, setUsage] = useState<Record<string, unknown> | null>(null);

  const runHealth = async () => {
    setCheckingHealth(true);
    const res = await creatorService.fetchHealthStatus();
    setHealth(res);
    setCheckingHealth(false);
  };

  useEffect(() => {
    void runHealth();
    void creatorService.fetchMotchiStats().then(setUsage);
  }, []);

  const statusColor =
    health?.status === 'ok'
      ? AppColors.success
      : health?.status === 'degraded'
        ? AppColors.warmAmber
        : AppColors.roseQuartz;

  return (
    <>
      <div style={cardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
            Backend Health
          </span>
          <button
            type="button"
            className="bare-button"
            disabled={checkingHealth}
            onClick={() => void runHealth()}
            style={{ fontSize: 12, color: AppColors.roseQuartz }}
          >
            {checkingHealth ? 'Checking…' : 'Refresh'}
          </button>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 9, height: 9, borderRadius: '50%', background: statusColor }} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 13, color: AppColors.petalWhite }}>
            {health ? health.status.toUpperCase() : 'Checking…'}
          </span>
          {health?.version && <span style={{ fontSize: 11.5, color: Derived.textMuted }}>v{health.version}</span>}
        </div>
        {health?.error && <div style={{ fontSize: 12, color: AppColors.roseQuartz }}>{health.error}</div>}
      </div>

      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
          Connection &amp; Data Saver
        </div>
        <div style={{ fontSize: 12.5, color: Derived.textMedium }}>
          Status: <strong>{isOnline ? 'Online' : 'Offline'}</strong> · Quality: <strong>{netQuality}</strong>
        </div>
        <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
          TMDB poster tier: {NetworkQualityService.preferredTmdbPosterSize()} · Prefetching:{' '}
          {NetworkQualityService.shouldSkipPrefetch() ? 'Paused (saving data)' : 'Active'}
        </div>
      </div>

      {usage && (
        <div style={cardStyle}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
            Motchi Usage
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, fontSize: 12, color: Derived.textMedium }}>
            {Object.entries(usage)
              .slice(0, 6)
              .map(([k, v]) => (
                <div key={k}>
                  <span style={{ color: Derived.textMuted }}>{k}: </span>
                  <strong>{typeof v === 'object' ? JSON.stringify(v) : String(v)}</strong>
                </div>
              ))}
          </div>
        </div>
      )}

      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
          Local Maintenance
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => {
            creatorService.clearLocalCaches();
            showSnackBar('Local Letterbox & Cinema caches cleared');
          }}
          style={{
            padding: '10px 14px',
            borderRadius: AppRadius.sm,
            background: withAlpha(AppColors.petalWhite, 0.08),
            border: `1px solid ${Derived.border}`,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 12.5,
            textAlign: 'left',
          }}
        >
          Clear local Letterbox &amp; Cinema caches
        </button>
      </div>
    </>
  );
}

function formatShortDate(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function CreatorAccountsTab() {
  const [accounts, setAccounts] = useState<MemberAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyUser, setBusyUser] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await creatorService.listMemberAccounts();
      setAccounts(list);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load accounts');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const act = async (username: string, action: 'approve' | 'reject' | 'revoke' | 'delete') => {
    setBusyUser(username);
    try {
      await creatorService.updateMemberAccount(username, action);
      const labels: Record<typeof action, string> = {
        approve: `Approved @${username}`,
        reject: `Rejected @${username}`,
        revoke: `Moved @${username} back to pending`,
        delete: `Deleted @${username}`,
      };
      showSnackBar(labels[action]);
      await load();
    } catch (e) {
      showSnackBar(e instanceof Error ? e.message : 'Action failed');
    } finally {
      setBusyUser(null);
    }
  };

  const pending = accounts.filter((a) => a.status === 'pending');
  const approved = accounts.filter((a) => a.status === 'approved');
  const rejected = accounts.filter((a) => a.status === 'rejected');

  return (
    <>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
        <div>
          <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
            Member Account Approvals
          </div>
          <div style={{ fontSize: 12, color: Derived.textMuted }}>
            {pending.length} pending · {approved.length} approved
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => void load()}
          disabled={loading}
          style={{
            padding: '7px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.petalWhite, 0.08),
            border: `1px solid ${Derived.border}`,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 12,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
          }}
        >
          <Icon name="refresh" size={15} color={AppColors.blushGold} />
          <span>{loading ? 'Loading…' : 'Refresh'}</span>
        </button>
      </div>

      {error && (
        <div
          role="alert"
          style={{
            ...cardStyle,
            borderColor: withAlpha(AppColors.error, 0.5),
            background: withAlpha(AppColors.error, 0.12),
            color: AppColors.petalWhite,
            fontSize: 12.5,
          }}
        >
          {error}
        </div>
      )}

      <div style={cardStyle}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.blushGold }}>
            Pending Approval ({pending.length})
          </div>
        </div>
        {loading && accounts.length === 0 ? (
          <div style={{ fontSize: 12.5, color: Derived.textMuted }}>Checking pending requests…</div>
        ) : pending.length === 0 ? (
          <div style={{ fontSize: 12.5, color: Derived.textMuted }}>No pending account requests right now.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {pending.map((acc) => {
              const isBusy = busyUser === acc.username;
              return (
                <div
                  key={acc.id}
                  style={{
                    padding: '10px 12px',
                    borderRadius: AppRadius.sm,
                    background: withAlpha(AppColors.shimmerBase, 0.72),
                    border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 10,
                    flexWrap: 'wrap',
                  }}
                >
                  <div style={{ minWidth: 0 }}>
                    <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
                      @{acc.username}
                    </div>
                    {acc.createdAt && (
                      <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
                        Requested {formatShortDate(acc.createdAt)}
                      </div>
                    )}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={isBusy}
                      onClick={() => void act(acc.username, 'approve')}
                      style={{
                        padding: '7px 12px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.success, 0.22),
                        border: `1px solid ${withAlpha(AppColors.success, 0.6)}`,
                        color: AppColors.petalWhite,
                        ...AppTypography.outfitBold,
                        fontSize: 12,
                        opacity: isBusy ? 0.5 : 1,
                      }}
                    >
                      Approve
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={isBusy}
                      onClick={() => void act(acc.username, 'reject')}
                      style={{
                        padding: '7px 12px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.error, 0.16),
                        border: `1px solid ${withAlpha(AppColors.error, 0.45)}`,
                        color: AppColors.petalWhite,
                        ...AppTypography.outfitBold,
                        fontSize: 12,
                        opacity: isBusy ? 0.5 : 1,
                      }}
                    >
                      Reject
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: AppColors.success }}>
          Approved Accounts ({approved.length})
        </div>
        {approved.length === 0 ? (
          <div style={{ fontSize: 12.5, color: Derived.textMuted }}>No custom accounts approved yet.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {approved.map((acc) => {
              const isBusy = busyUser === acc.username;
              return (
                <div
                  key={acc.id}
                  style={{
                    padding: '10px 12px',
                    borderRadius: AppRadius.sm,
                    background: withAlpha(AppColors.shimmerBase, 0.65),
                    border: `1px solid ${Derived.border}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 10,
                    flexWrap: 'wrap',
                  }}
                >
                  <div style={{ minWidth: 0 }}>
                    <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
                      @{acc.username}
                    </div>
                    {acc.approvedAt && (
                      <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
                        Approved {formatShortDate(acc.approvedAt)}
                      </div>
                    )}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={isBusy}
                      onClick={() => void act(acc.username, 'revoke')}
                      style={{
                        padding: '6px 10px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.petalWhite, 0.08),
                        border: `1px solid ${Derived.border}`,
                        color: Derived.textMedium,
                        ...AppTypography.outfitBold,
                        fontSize: 11.5,
                        opacity: isBusy ? 0.5 : 1,
                      }}
                    >
                      Revoke
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={isBusy}
                      onClick={() => void act(acc.username, 'delete')}
                      style={{
                        padding: '6px 10px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.error, 0.14),
                        border: `1px solid ${withAlpha(AppColors.error, 0.4)}`,
                        color: AppColors.petalWhite,
                        ...AppTypography.outfitBold,
                        fontSize: 11.5,
                        opacity: isBusy ? 0.5 : 1,
                      }}
                    >
                      Remove
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div style={cardStyle}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: Derived.textMedium }}>
          Legacy Door-Key Accounts
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {['breyan', 'octagram'].map((legacy) => (
            <span
              key={legacy}
              style={{
                padding: '6px 12px',
                borderRadius: 999,
                background: withAlpha(AppColors.petalWhite, 0.06),
                border: `1px solid ${Derived.border}`,
                ...AppTypography.outfitBold,
                fontSize: 12.5,
                color: AppColors.petalWhite,
              }}
            >
              @{legacy}
            </span>
          ))}
        </div>
        <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
          Always active via their legacy 4-digit door key.
        </div>
      </div>

      {rejected.length > 0 && (
        <div style={cardStyle}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: Derived.textMuted }}>
            Rejected ({rejected.length})
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {rejected.map((acc) => {
              const isBusy = busyUser === acc.username;
              return (
                <div
                  key={acc.id}
                  style={{
                    padding: '8px 12px',
                    borderRadius: AppRadius.sm,
                    background: withAlpha(AppColors.shimmerBase, 0.5),
                    border: `1px solid ${Derived.border}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 10,
                  }}
                >
                  <span style={{ ...AppTypography.outfitBold, fontSize: 13, color: Derived.textMuted }}>
                    @{acc.username}
                  </span>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={isBusy}
                      onClick={() => void act(acc.username, 'approve')}
                      style={{
                        padding: '5px 10px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.success, 0.18),
                        border: `1px solid ${withAlpha(AppColors.success, 0.45)}`,
                        color: AppColors.petalWhite,
                        ...AppTypography.outfitBold,
                        fontSize: 11.5,
                      }}
                    >
                      Approve
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      disabled={isBusy}
                      onClick={() => void act(acc.username, 'delete')}
                      style={{
                        padding: '5px 10px',
                        borderRadius: 999,
                        background: withAlpha(AppColors.error, 0.14),
                        border: `1px solid ${withAlpha(AppColors.error, 0.38)}`,
                        color: AppColors.petalWhite,
                        ...AppTypography.outfitBold,
                        fontSize: 11.5,
                      }}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </>
  );
}
