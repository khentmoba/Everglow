// Same storage the Flutter app uses (shared_preferences on web keeps
// JSON-encoded values in localStorage under "flutter."), so Clair stays
// signed in when she moves from the Flutter app to this one.
const PREFIX = 'flutter.';

export const Prefs = {
  getString(key: string): string | null {
    const value = Prefs.get(key);
    return typeof value === 'string' ? value : null;
  },
  getBool(key: string): boolean | null {
    const value = Prefs.get(key);
    return typeof value === 'boolean' ? value : null;
  },
  get(key: string): unknown {
    try {
      const raw = localStorage.getItem(PREFIX + key);
      return raw == null ? null : JSON.parse(raw);
    } catch {
      return null;
    }
  },
  set(key: string, value: string | boolean | number): void {
    try {
      localStorage.setItem(PREFIX + key, JSON.stringify(value));
    } catch {
      // Storage blocked (private mode); nothing to keep.
    }
  },
  remove(key: string): void {
    try {
      localStorage.removeItem(PREFIX + key);
    } catch {
      // Storage blocked.
    }
  },
};
