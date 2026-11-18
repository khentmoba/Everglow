// Media/playback keyboard keys forwarded from host pages into the embedded
// Everglow player shell or handled by the offline video HUD.
export const EVERGLOW_FORWARDED_PLAYER_KEYS = new Set([
  ' ',
  'k',
  'K',
  'j',
  'J',
  'l',
  'L',
  'ArrowLeft',
  'ArrowRight',
  'ArrowUp',
  'ArrowDown',
  'm',
  'M',
  'f',
  'F',
  'c',
  'C',
  'n',
  'N',
  's',
  'S',
  'g',
  'G',
  'h',
  'H',
  'i',
  'I',
  'z',
  'Z',
  '[',
  ']',
  '<',
  '>',
  ',',
  '.',
  '?',
  'Escape',
  'Home',
  'End',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
]);

const MEDIA_KEY_ALIASES: Record<string, string> = {
  MediaPlayPause: ' ',
  MediaFastForward: 'l',
  MediaRewind: 'j',
  MediaTrackNext: 'n',
};

/**
 * Maps hardware media keys to canonical player shortcuts and returns `null`
 * when `rawKey` should not be forwarded or intercepted.
 */
export function resolveEverglowPlayerKey(rawKey: string): string | null {
  const key = MEDIA_KEY_ALIASES[rawKey] ?? rawKey;
  if (!key || !EVERGLOW_FORWARDED_PLAYER_KEYS.has(key)) return null;
  return key;
}

export function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof Element)) return false;
  const tag = target.tagName;
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (target instanceof HTMLElement && target.isContentEditable);
}
