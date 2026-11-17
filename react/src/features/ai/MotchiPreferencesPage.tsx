// Port of lib/features/ai/presentation/screens/motchi_preferences_screen.dart.
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { Logger } from '../../core/system/logger';
import { AppColors } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { canPop, DropdownField, MaterialAppBar, SwitchListTile, type DropdownItem } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { companionOperation, type CompanionPreferences } from './aiService';

const hour = (h: number) => `${h % 12 === 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}`;
const HOURS: DropdownItem<number>[] = Array.from({ length: 24 }, (_, h) => ({ value: h, label: hour(h) }));
const NUDGES: DropdownItem<string>[] = [
  { value: 'daily', label: 'At most once a day' },
  { value: 'weekly', label: 'At most once a week' },
  { value: 'off', label: 'Off' },
];

const body = { ...AppTypography.bodyMedium, lineHeight: lineHeight(14) };

export function MotchiPreferencesPage() {
  const navigate = useNavigate();
  const [preferences, setPreferences] = useState<CompanionPreferences | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const result = await companionOperation('load');
      setPreferences({ ...result.preferences });
    } catch (e) {
      Logger.e('Motchi preferences failed to load', e);
      setError('Could not load your preferences. Try again.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    setSaving(true);
    setError(null);
    try {
      await companionOperation('preferences', preferences!);
      showSnackBar('Your Motchi preferences are saved.');
      if (canPop()) navigate(-1);
    } catch (e) {
      Logger.e('Motchi preferences failed to save', e);
      setError('Could not save your preferences. Try again.');
    } finally {
      setSaving(false);
    }
  };

  const set = <K extends keyof CompanionPreferences>(key: K) =>
    saving ? undefined : (value: CompanionPreferences[K]) => setPreferences((p) => p && { ...p, [key]: value });

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep, display: 'flex', flexDirection: 'column' }}>
      <MaterialAppBar title="Motchi preferences" />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: '100%', maxWidth: 600, display: 'flex', flexDirection: 'column' }}>
          {preferences == null ? (
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              {error == null ? (
                <CircularProgress size={36} strokeWidth={4} color={AppColors.deepRose} />
              ) : (
                <>
                  <span style={body}>{error}</span>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => void load()}
                    style={{ ...AppTypography.labelLarge, color: AppColors.deepRose, padding: '10px 12px' }}
                  >
                    Try again
                  </button>
                </>
              )}
            </div>
          ) : (
            <div style={{ flex: 1, overflowY: 'auto', padding: 16 }}>
              <div style={{ ...AppTypography.bodyMedium, fontSize: 22, fontWeight: 600, lineHeight: lineHeight(22) }}>
                A little help, at your pace.
              </div>
              <div style={{ height: 8 }} />
              <div style={body}>These choices are just for you. Reminders you ask for still arrive at their scheduled time.</div>
              <div style={{ height: 20 }} />
              <DropdownField label="Helpful nudges" value={preferences.nudges} items={NUDGES} onChanged={set('nudges')} />
              <div style={{ height: 12 }} />
              <SwitchListTile
                title="Morning and evening recaps"
                subtitle="Includes the weekly recap."
                value={preferences.digests === true}
                onChanged={set('digests')}
              />
              <div style={{ height: 16 }} />
              <div style={body}>Quiet hours · Philippine time</div>
              <div style={{ height: 12 }} />
              <DropdownField
                label="Quiet hours start"
                value={preferences.quietStart}
                items={HOURS}
                onChanged={set('quietStart')}
              />
              <div style={{ height: 12 }} />
              <DropdownField label="Quiet hours end" value={preferences.quietEnd} items={HOURS} onChanged={set('quietEnd')} />
              <div style={{ height: 8 }} />
              <div style={body}>
                Choose the same start and end time to turn quiet hours off. Messages skipped during quiet hours are not queued.
              </div>
              {error != null && <div style={{ ...body, color: AppColors.error, paddingTop: 12 }}>{error}</div>}
              <div style={{ height: 20 }} />
              <EverglowButton
                stretch
                onPressed={saving ? undefined : () => void save()}
                label={saving ? 'Saving…' : 'Save preferences'}
                enabled={!saving}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
