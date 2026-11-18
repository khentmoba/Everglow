// Port of lib/features/ai/presentation/screens/motchi_today_screen.dart.
import { useEffect, useState, type ReactNode } from 'react';
import { WebTts } from '../../core/system/webTts';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { letterSpacing, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { composeTodayRecap, relationshipInsights } from './memory';
import { fetchToday, isoDay, type TodaySnapshot } from './motchiTodayService';

const medium = { ...AppTypography.outfitMedium, fontSize: 14, lineHeight: lineHeight(14) };

export function MotchiTodayPage() {
  const [snapshot, setSnapshot] = useState<TodaySnapshot | null>(null);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    const s = await fetchToday();
    setSnapshot(s);
    setLoading(false);
  };
  useEffect(() => {
    void load();
  }, []);

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.twilight }}>
      <EverglowBackground
        glows={[
          { color: AppColors.auroraGold, alignment: [-0.75, -0.85], size: 0.7, opacity: 0.13 },
          { color: AppColors.softLavender, alignment: [0.85, 0.9], size: 0.65, opacity: 0.1 },
        ]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          paddingTop: 'env(safe-area-inset-top)',
          paddingBottom: 'env(safe-area-inset-bottom)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <EverglowFeatureHeader
          title="Motchi Today"
          subtitle="today in Everglow, in one breath"
          icon="wb_twilight"
          hue={AppColors.auroraGold}
          actions={[
            <MaterialIconButton
              key="refresh"
              icon="refresh"
              tooltip="Refresh"
              color={AppColors.auroraGold}
              onPressed={
                loading
                  ? undefined
                  : () => {
                      setLoading(true);
                      void load();
                    }
              }
            />,
          ]}
        />
        <div style={{ flex: 1, minHeight: 0 }}>
          {loading || snapshot == null ? (
            <div style={{ padding: 16 }}>
              <EverglowSkeleton height={120} radius={16} />
            </div>
          ) : (
            <TodayBody snapshot={snapshot} />
          )}
        </div>
      </div>
    </div>
  );
}

function TodayBody({ snapshot }: { snapshot: TodaySnapshot }) {
  const recap = composeTodayRecap({
    dateLabel: isoDay(snapshot.date),
    moods: snapshot.moods,
    activities: snapshot.activities,
    watchlist: snapshot.watchlist,
    starlight: snapshot.starlight,
    memories: snapshot.memories,
    now: snapshot.date,
  });
  const insights = relationshipInsights(
    snapshot.moods.map((m) => m.mood),
    snapshot.activities,
  );
  return (
    <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto' }}>
      <div style={{ padding: '8px 16px 24px' }}>
        <div
          style={{
            padding: 17,
            borderRadius: AppRadius.lg,
            background: linear([withAlpha(AppColors.auroraGold, 0.16), withAlpha(AppColors.deepRose, 0.1)]),
            boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.auroraGold, 0.4)}`,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              <Icon name="wb_twilight" size={15} color={AppColors.auroraGold} />
              <div style={{ width: 6 }} />
              <span
                style={{
                  ...AppTypography.labelSmall,
                  fontSize: 10.5,
                  lineHeight: lineHeight(10.5),
                  ...letterSpacing(0.8),
                  color: AppColors.auroraGold,
                }}
              >
                TODAY IN EVERGLOW
              </span>
            </div>
            <ListenButton text={recap} />
          </div>
          <div style={{ height: 10 }} />
          <div style={{ ...AppTypography.outfitWhite, fontSize: 15, lineHeight: '22px', paddingTop: 2, marginBottom: -1 }}>
            {recap}
          </div>
        </div>
        <div style={{ height: 16 }} />
        <Section title="Moods" icon="favorite" color={AppColors.auroraRose}>
          {snapshot.moods.length === 0 ? (
            <EmptyLine text="No mood logged yet today." />
          ) : (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {snapshot.moods.map((m, i) => (
                <span
                  key={i}
                  style={{
                    height: 32,
                    boxSizing: 'border-box',
                    padding: '0 16px',
                    display: 'inline-flex',
                    alignItems: 'center',
                    borderRadius: AppRadius.full,
                    background: withAlpha(AppColors.auroraRose, 0.12),
                    border: `1px solid ${withAlpha(AppColors.auroraRose, 0.4)}`,
                    ...AppTypography.outfitMedium,
                    fontSize: 12,
                  }}
                >
                  {`${m.uid}: ${m.mood}`}
                </span>
              ))}
            </div>
          )}
        </Section>
        <Section title="Recent activity" icon="bolt" color={AppColors.auroraTeal}>
          {snapshot.activities.length === 0 ? (
            <EmptyLine text="Nothing logged yet." />
          ) : (
            snapshot.activities.map((a, i) => (
              <div key={i} style={{ paddingBottom: 8, display: 'flex', alignItems: 'center' }}>
                <Icon name="circle" variant="filled" size={7} color={AppColors.auroraTeal} />
                <div style={{ width: 8 }} />
                <div style={{ ...medium, flex: 1 }}>{a}</div>
              </div>
            ))
          )}
        </Section>
        <Section title="Watchlist & Starlight" icon="auto_stories" color={AppColors.softLavender}>
          {snapshot.watchlist.length > 0 ? (
            snapshot.watchlist.map((w, i) => (
              <div key={i} style={{ ...medium, paddingBottom: 8 }}>
                🎬 {w}
              </div>
            ))
          ) : (
            <EmptyLine text="Watchlist is quiet right now." />
          )}
          {snapshot.starlight.length > 0 && (
            <>
              <div style={{ height: 8 }} />
              {snapshot.starlight.map((s, i) => (
                <div key={i} style={{ ...medium, paddingBottom: 8 }}>
                  ✨ "{s}"
                </div>
              ))}
            </>
          )}
        </Section>
        {insights.length > 0 && (
          <>
            <div style={{ height: 16 }} />
            <Section title="What Motchi notices" icon="psychology" color={AppColors.auroraGold}>
              {insights.map((i) => (
                <div key={i.title} style={{ paddingBottom: 8, display: 'flex', alignItems: 'flex-start' }}>
                  <span style={{ fontSize: 14, lineHeight: lineHeight(14) }}>🐱 </span>
                  <div style={{ ...medium, flex: 1 }}>{`${i.title}: ${i.detail}`}</div>
                </div>
              ))}
            </Section>
          </>
        )}
      </div>
    </div>
  );
}

function Section({ title, icon, color, children }: { title: string; icon: string; color: string; children: ReactNode }) {
  return (
    <div style={{ paddingBottom: 12 }}>
      <div
        style={{
          padding: 17,
          borderRadius: AppRadius.lg,
          background: Derived.surfaceGlass,
          boxShadow: `inset 0 0 0 1px ${Derived.border}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <Icon name={icon} size={16} color={color} />
          <div style={{ width: 8 }} />
          <span style={{ ...AppTypography.outfitHeading, fontSize: 13, lineHeight: lineHeight(13), color }}>{title}</span>
        </div>
        <div style={{ height: 12 }} />
        {children}
      </div>
    </div>
  );
}

function EmptyLine({ text }: { text: string }) {
  return <div style={{ ...AppTypography.outfitMuted, fontSize: 14, lineHeight: lineHeight(14) }}>{text}</div>;
}

function ListenButton({ text }: { text: string }) {
  const [speaking, setSpeaking] = useState(false);
  useEffect(() => () => WebTts.stop(), []);
  if (!WebTts.isSupported) return null;
  const toggle = () => {
    if (speaking) {
      WebTts.stop();
      setSpeaking(false);
    } else {
      setSpeaking(true);
      WebTts.speak(text, { onComplete: () => setSpeaking(false) });
    }
  };
  const color = speaking ? AppColors.auroraRose : AppColors.auroraGold;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={toggle}
      style={{
        padding: '5.3px 10.8px',
        borderRadius: 12,
        background: speaking ? withAlpha(AppColors.auroraRose, 0.2) : withAlpha(AppColors.auroraGold, 0.16),
        boxShadow: `inset 0 0 0 0.8px ${speaking ? withAlpha(AppColors.auroraRose, 0.4) : withAlpha(AppColors.auroraGold, 0.35)}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={speaking ? 'stop_circle' : 'volume_up'} size={14} color={color} />
      <div style={{ width: 5 }} />
      <span style={{ ...AppTypography.labelSmall, fontSize: 11, lineHeight: '15.5px', position: 'relative', top: 1, color }}>
        {speaking ? 'Stop' : 'Listen'}
      </span>
    </button>
  );
}
