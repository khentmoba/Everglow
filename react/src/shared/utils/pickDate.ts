// Flutter's `showDatePicker`, using the browser's own date picker.
// Resolves with the picked day (local midnight), or null when cancelled.
const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

let open: HTMLInputElement | null = null;

export function pickDate({ initial, first, last }: { initial: Date; first: Date; last: Date }): Promise<Date | null> {
  open?.remove();
  return new Promise((resolve) => {
    const input = document.createElement('input');
    open = input;
    input.type = 'date';
    input.min = iso(first);
    input.max = iso(last);
    input.value = iso(initial);
    Object.assign(input.style, { position: 'fixed', left: '50%', bottom: '0', opacity: '0', pointerEvents: 'none' });
    let done = false;
    const finish = (v: Date | null) => {
      if (done) return;
      done = true;
      input.remove();
      if (open === input) open = null;
      resolve(v);
    };
    input.addEventListener('change', () => {
      const [y, m, d] = input.value.split('-').map(Number);
      finish(input.value ? new Date(y, m - 1, d) : null);
    });
    input.addEventListener('cancel', () => finish(null));
    document.body.appendChild(input);
    try {
      input.showPicker();
    } catch {
      finish(null);
    }
  });
}
