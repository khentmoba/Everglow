// Port of lib/features/dashboard/presentation/widgets/calendar_preview.dart.
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, letterSpacing, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { calendarService, type CalendarEvent } from '../calendar/calendarService';
import { FeatureSection, SectionChevron } from './FeatureSection';

const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

export function CalendarPreview() {
  const navigate = useNavigate();
  const events = useSource<CalendarEvent[] | null>(() => calendarService.getUpcomingEvents(60), [], calendarService.cachedUpcoming);

  return (
    <div style={{ padding: '6px 16px' }}>
      <FeatureSection
        icon="calendar_month"
        hue={AppColors.warmAmber}
        title="Upcoming Dates"
        subtitle={
          events == null
            ? 'loading dates…'
            : events.length === 0
              ? 'nothing on the calendar'
              : `next ${events.length} ${events.length === 1 ? 'date' : 'dates'}`
        }
        trailing={<SectionChevron hue={AppColors.warmAmber} />}
        onTap={() => navigate('/calendar')}
      >
        {events == null ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <CircularProgress size={16} strokeWidth={2} color={AppColors.warmAmber} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.petalWhite, 0.6) }}>
              Loading upcoming dates…
            </span>
          </div>
        ) : events.length === 0 ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: 12,
                background: linear([withAlpha(AppColors.warmAmber, 0.22), withAlpha(AppColors.auroraRose, 0.12)], {
                  begin: Align.topLeft,
                  end: Align.bottomRight,
                }),
                border: `1px solid ${withAlpha(AppColors.warmAmber, 0.35)}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="favorite" size={18} color={AppColors.warmAmber} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ ...AppTypography.outfitWhite, fontSize: 12.5, fontWeight: 600 }}>No dates yet</div>
              <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.55) }}>
                Tap to plan something special ♥
              </div>
            </div>
            <Icon name="add_circle_outline" size={20} color={AppColors.warmAmber} />
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {events.slice(0, 3).map((ev) => {
              const dayDiff = Math.max(0, Math.floor((ev.date.getTime() - Date.now()) / 86_400_000));
              const timeLabel = dayDiff === 0 ? 'Today' : dayDiff === 1 ? 'Tomorrow' : `In ${dayDiff} days`;
              const isToday = dayDiff === 0;
              return (
                <div key={ev.id + ev.date.toISOString()} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div
                    style={{
                      width: 44,
                      padding: '5px 0',
                      borderRadius: 12,
                      background: linear([withAlpha(AppColors.warmAmber, 0.2), withAlpha(AppColors.auroraRose, 0.1)], {
                        begin: Align.topLeft,
                        end: Align.bottomRight,
                      }),
                      border: `1px solid ${withAlpha(AppColors.warmAmber, 0.38)}`,
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <span style={{ ...AppTypography.outfitBold, fontSize: 8, ...letterSpacing(1), color: AppColors.warmAmber }}>
                      {MONTHS[ev.date.getMonth()]}
                    </span>
                    <span style={{ ...AppTypography.cormorantBold, fontSize: 17, lineHeight: 1.1, color: AppColors.petalWhite }}>
                      {ev.date.getDate()}
                    </span>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      style={{
                        ...AppTypography.outfitBold,
                        fontSize: 13,
                        color: AppColors.petalWhite,
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                    >
                      {ev.title}
                    </div>
                    <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: isToday ? AppColors.auroraRose : withAlpha(AppColors.petalWhite, 0.55) }}>
                      {timeLabel}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </FeatureSection>
    </div>
  );
}
