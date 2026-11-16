// Port of lib/features/dashboard/presentation/widgets/on_this_day_card.dart
// + lib/core/services/on_this_day_service.dart.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures } from '../../core/agent/fixtures';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { FeatureSection, SectionChevron } from './FeatureSection';

type OnThisDaySource = 'gallery' | 'cinema' | 'chat';
type OnThisDayMemory = {
  source: OnThisDaySource;
  date: Date;
  title: string;
  subtitle: string;
  imageUrl?: string;
};

function matchesToday(d: Date, now: Date): boolean {
  return d.getMonth() === now.getMonth() && d.getDate() === now.getDate() && d.getFullYear() < now.getFullYear();
}

export function OnThisDayCard() {
  const navigate = useNavigate();
  const [memories, setMemories] = useState<OnThisDayMemory[]>([]);

  useEffect(() => {
    const now = new Date();
    if (AgentMode.demo) {
      const photos = AgentFixtures.demoPhotos()
        .filter((p) => matchesToday(p.uploadedAt, now))
        .map<OnThisDayMemory>((p) => ({
          source: 'gallery',
          date: p.uploadedAt,
          title: p.caption || 'A photo memory',
          subtitle: 'Gallery photo',
          imageUrl: p.imageUrl,
        }));
      setMemories(photos);
    }
  }, []);

  if (memories.length === 0) return null;

  return (
    <div style={{ padding: '6px 16px' }}>
      <FeatureSection
        icon="history"
        hue={AppColors.blushGold}
        title="On This Day"
        subtitle={`${memories.length} ${memories.length === 1 ? 'memory' : 'memories'} from the past`}
        trailing={<SectionChevron />}
      >
        <div className="no-scrollbar" style={{ overflowX: 'auto', height: 168 }}>
          <div style={{ display: 'flex', gap: 12, height: '100%', width: 'max-content' }}>
            {memories.map((m, i) => {
              const yearsAgo = new Date().getFullYear() - m.date.getFullYear();
              const route = m.source === 'gallery' ? '/gallery' : m.source === 'cinema' ? '/cinema' : '/sanctuary';
              const hue = m.source === 'gallery' ? AppColors.roseQuartz : m.source === 'cinema' ? AppColors.deepRose : AppColors.softLavender;
              return (
                <button
                  key={i}
                  type="button"
                  className="bare-button"
                  onClick={() => navigate(route)}
                  style={{
                    position: 'relative',
                    width: 140,
                    height: 168,
                    borderRadius: AppRadius.lg,
                    overflow: 'hidden',
                    background: linear([withAlpha(hue, 0.2), AppColors.velvet], { begin: Align.topLeft, end: Align.bottomRight }),
                    border: `1px solid ${withAlpha(hue, 0.35)}`,
                    padding: 12,
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'flex-end',
                  }}
                >
                  {m.imageUrl && (
                    <img
                      src={m.imageUrl}
                      alt={m.title}
                      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.45 }}
                    />
                  )}
                  <div style={{ position: 'relative' }}>
                    <div style={{ ...AppTypography.outfitBold, fontSize: 10, color: AppColors.blushGold }}>
                      {yearsAgo > 0 ? `${yearsAgo}y ago` : 'Today'}
                    </div>
                    <div className="clamp-2" style={{ ...AppTypography.outfitHeading, fontSize: 12, marginTop: 2 }}>
                      {m.title}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      </FeatureSection>
    </div>
  );
}
