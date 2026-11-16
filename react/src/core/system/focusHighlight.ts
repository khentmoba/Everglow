// Flutter's FocusManager.highlightMode: focus rings show after mouse or
// keyboard use, and hide after touch. Phones and tablets start in touch mode.
import { ValueNotifier } from './store';

const startsTouch = /android|iphone|ipad|ipod/i.test(navigator.userAgent) ||
  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

export const focusHighlightTraditional = new ValueNotifier<boolean>(!startsTouch);

window.addEventListener(
  'pointerdown',
  (e) => {
    focusHighlightTraditional.value = e.pointerType !== 'touch';
  },
  true,
);
window.addEventListener(
  'keydown',
  () => {
    focusHighlightTraditional.value = true;
  },
  true,
);

/** Flutter web's HapticFeedback durations. */
export const Haptics = {
  vibrate: () => navigator.vibrate?.(50),
  selectionClick: () => navigator.vibrate?.(10),
};
