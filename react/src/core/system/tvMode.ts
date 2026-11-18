// Port of lib/core/system/tv_mode.dart (toggle + key helpers).
import { Prefs } from './prefs';
import { ValueNotifier } from './store';

const PREF_KEY = 'tv_mode_enabled';

const TV_KEYWORDS = [
  'tv', 'smarttv', 'googletv', 'android tv', 'leanback', 'shield', 'mibox', 'mi box',
  'chromecast', 'nexus player', 'adt-', 'tvbro', 'tv bro', 'odin', 'jiopages', 'tizen',
  'webos', 'web0s', 'viera', 'bravia', 'hbbtv', 'netcast', 'apple tv', 'appletv', 'roku',
  'crkey', 'aft', 'pov_tv',
];

function urlOverride(): boolean | null {
  const href = window.location.href.toLowerCase();
  if (href.includes('tv=1') || href.includes('tv=true') || href.includes('mode=tv')) return true;
  if (href.includes('tv=0') || href.includes('tv=false')) return false;
  return null;
}

function detectTvBrowser(): boolean {
  const ua = navigator.userAgent.toLowerCase();
  if (TV_KEYWORDS.some((kw) => ua.includes(kw))) return true;
  const isLandscape = window.innerWidth >= window.innerHeight;
  return ua.includes('android') && !ua.includes('mobile') && navigator.maxTouchPoints === 0 && isLandscape;
}

function initial(): boolean {
  const override = urlOverride();
  if (override != null) return override;
  return Prefs.getBool(PREF_KEY) ?? detectTvBrowser();
}

export const TvMode = {
  isTvMode: new ValueNotifier<boolean>(initial()),
  toggle() {
    const next = !TvMode.isTvMode.value;
    TvMode.isTvMode.value = next;
    Prefs.set(PREF_KEY, next);
  },
  isSelectKey: (key: string) => key === 'Enter' || key === ' ' || key === 'Select',
  isBackKey: (key: string) =>
    key === 'Escape' || key === 'Backspace' || key === 'Delete' || key === 'GoBack' || key === 'BrowserBack',
  digitFromKey: (key: string) => (/^[0-9]$/.test(key) ? key : null),
};
