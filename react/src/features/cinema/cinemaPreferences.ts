// Port of lib/features/cinema/data/services/cinema_preferences.dart: per-user
// "Hide spoilers" / "Autoplay next episode", kept in the same shared_preferences key.
import { Logger } from '../../core/system/logger';
import { Prefs } from '../../core/system/prefs';
import { ValueNotifier } from '../../core/system/store';

export type CinemaPrefs = { hideSpoilers: boolean; autoplayNext: boolean };

const DEFAULTS: CinemaPrefs = { hideSpoilers: true, autoplayNext: false };
const key = (user: string) => `cinema_preferences_v1/${user}`;

class CinemaPreferences extends ValueNotifier<CinemaPrefs> {
  private user = '';

  constructor() {
    super(DEFAULTS);
  }

  setUser(name: string | null | undefined) {
    const user = name ?? '';
    if (user === this.user) return;
    this.user = user;
    let next = DEFAULTS;
    if (user) {
      try {
        const raw = Prefs.getString(key(user));
        const data = raw ? (JSON.parse(raw) as Record<string, unknown>) : null;
        if (data && typeof data === 'object') {
          next = { hideSpoilers: data.hideSpoilers !== false, autoplayNext: data.autoplayNext === true };
        }
      } catch (e) {
        Logger.e('Cinema preferences: load failed', e);
      }
    }
    this.value = next;
  }

  setHideSpoilers(v: boolean) {
    this.save({ ...this.value, hideSpoilers: v });
  }

  setAutoplayNext(v: boolean) {
    this.save({ ...this.value, autoplayNext: v });
  }

  private save(next: CinemaPrefs) {
    if (!this.user) return;
    this.value = next;
    Prefs.set(key(this.user), JSON.stringify(next));
  }
}

export const cinemaPreferences = new CinemaPreferences();
