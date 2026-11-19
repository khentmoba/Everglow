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
  set(key: string, value: unknown): void {
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
  /** Stored keys (without the flutter. prefix) that start with `prefix`. */
  keysWithPrefix(prefix: string): string[] {
    const out: string[] = [];
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key?.startsWith(PREFIX + prefix)) out.push(key.slice(PREFIX.length));
      }
    } catch {
      // Storage blocked.
    }
    return out;
  },
};
