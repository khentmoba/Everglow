// Port of lib/shared/utils/draft_text_controller.dart: unsent words are kept
// under the same shared_preferences key ("draft:<key>"), saved 500ms after the
// last keystroke and flushed when the field goes away.
import { useCallback, useEffect, useRef, useState } from 'react';
import { Prefs } from '../../core/system/prefs';

const maxDraftChars = 20000;

function persist(storageKey: string, text: string) {
  const words = text.length > maxDraftChars ? text.slice(0, maxDraftChars) : text;
  if (words === '') Prefs.remove(storageKey);
  else Prefs.set(storageKey, words);
}

export function forgetDraft(draftKey: string, onlyIf?: string) {
  const key = `draft:${draftKey}`;
  if (onlyIf != null && (Prefs.getString(key) ?? '') !== onlyIf) return;
  Prefs.remove(key);
}

/**
 * `[text, setText, clearDraft]` for a field whose words survive a reload.
 * With `enabled` false it is a plain field (Dart never calls `loadDraft`).
 */
export function useDraft(draftKey: string, initial = '', enabled = true): [string, (text: string) => void, () => void] {
  const storageKey = `draft:${draftKey}`;
  const [text, setTextState] = useState(() => (enabled && initial === '' ? (Prefs.getString(storageKey) ?? '') : initial));
  const timer = useRef(0);
  const pending = useRef<string | null>(null);

  const setText = useCallback(
    (next: string) => {
      setTextState(next);
      if (!enabled) return;
      pending.current = next;
      clearTimeout(timer.current);
      timer.current = window.setTimeout(() => {
        pending.current = null;
        persist(storageKey, next);
      }, 500);
    },
    [storageKey, enabled],
  );

  const clearDraft = useCallback(() => {
    clearTimeout(timer.current);
    pending.current = null;
    setTextState('');
    forgetDraft(draftKey);
  }, [draftKey]);

  useEffect(
    () => () => {
      clearTimeout(timer.current);
      if (pending.current != null) persist(storageKey, pending.current);
    },
    [storageKey],
  );

  return [text, setText, clearDraft];
}
