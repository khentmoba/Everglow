// Flutter's LinearProgressIndicator: determinate when `value` is given,
// otherwise the indeterminate two-line sweep with Flutter's curves.
import { useEffect, useRef } from 'react';
import { cubic } from '../../core/theme/motion';

const PERIOD = 1800;
const seg = (start: number, length: number, curve: (t: number) => number) => (ms: number) =>
  curve(Math.min(1, Math.max(0, (ms - start) / length)));
const line1Head = seg(0, 750, cubic(0.2, 0, 0.8, 1));
const line1Tail = seg(333, 750, cubic(0.4, 0, 1, 1));
const line2Head = seg(1000, 567, cubic(0, 0, 0.65, 1));
const line2Tail = seg(1267, 533, cubic(0.1, 0, 0.45, 1));

export function LinearProgress({
  value,
  height = 4,
  color,
  background = 'transparent',
  radius = 0,
}: {
  value?: number;
  height?: number;
  color: string;
  background?: string;
  radius?: number;
}) {
  const bar1 = useRef<HTMLDivElement>(null);
  const bar2 = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (value != null) return;
    let frame = 0;
    const start = performance.now();
    const draw = (now: number) => {
      const ms = (now - start) % PERIOD;
      const place = (el: HTMLDivElement | null, head: number, tail: number) => {
        if (!el) return;
        el.style.left = `${tail * 100}%`;
        el.style.width = `${Math.max(0, head - tail) * 100}%`;
      };
      place(bar1.current, line1Head(ms), line1Tail(ms));
      place(bar2.current, line2Head(ms), line2Tail(ms));
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [value]);
  const bar = { position: 'absolute' as const, top: 0, bottom: 0, background: color };
  return (
    <div
      role="progressbar"
      style={{ position: 'relative', height, width: '100%', overflow: 'hidden', background, borderRadius: radius }}
    >
      {value != null ? (
        <div style={{ ...bar, left: 0, width: `${Math.min(1, Math.max(0, value)) * 100}%` }} />
      ) : (
        <>
          <div ref={bar1} style={bar} />
          <div ref={bar2} style={bar} />
        </>
      )}
    </div>
  );
}
