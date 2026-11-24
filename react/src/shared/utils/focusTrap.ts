import { useEffect, useRef, type RefObject } from 'react';
import { isDialogOpen } from '../widgets/Dialogs';

const FOCUSABLE = 'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])';

/** Keeps Tab inside an open dialog, closes it on Escape, and restores focus. */
export function useDialogFocus(
  active: boolean,
  panelRef: RefObject<HTMLElement | null>,
  onClose: () => void,
  restoreRef?: RefObject<HTMLElement | null>,
): void {
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  useEffect(() => {
    if (!active) return;
    const panel = panelRef.current;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        // A dialog opened from inside the panel owns Escape first: without this,
        // one press closed the confirm and the whole sheet behind it.
        if (isDialogOpen()) return;
        e.preventDefault();
        closeRef.current();
        return;
      }
      if (e.key !== 'Tab' || !panel) return;
      const nodes = Array.from(panel.querySelectorAll<HTMLElement>(FOCUSABLE)).filter((n) => n.offsetParent !== null);
      if (nodes.length === 0) return;
      const first = nodes[0];
      const last = nodes[nodes.length - 1];
      const active = document.activeElement;
      // Focus starts on the panel itself (tabIndex -1), which is inside no node in
      // the list; without this branch Shift+Tab walks out of an aria-modal dialog.
      const outside = !(active instanceof Node) || !panel.contains(active);
      if (e.shiftKey && (outside || active === first)) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && (outside || active === last)) {
        e.preventDefault();
        first.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    const id = window.requestAnimationFrame(() => panel?.focus());
    return () => {
      window.removeEventListener('keydown', onKey);
      window.cancelAnimationFrame(id);
      restoreRef?.current?.focus();
    };
  }, [active, panelRef, restoreRef]);
}
