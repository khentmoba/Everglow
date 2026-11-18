// Flutter's AnimatedSwitcher with its default fade and centered stack: the
// old child fades out while the new one fades in. The first child shows at
// once.
import { useEffect, useRef, useState, type ReactNode } from 'react';

type Entry = { id: string; node: ReactNode; visible: boolean };

export function AnimatedSwitcher({
  id,
  duration,
  children,
}: {
  id: string;
  duration: number;
  children: ReactNode;
}) {
  const [entries, setEntries] = useState<Entry[]>([{ id, node: children, visible: true }]);
  const [entered, setEntered] = useState<Set<string>>(() => new Set([id]));
  const timers = useRef<number[]>([]);

  useEffect(() => {
    setEntries((list) => {
      if (list[list.length - 1]?.id === id) {
        return list.map((e) => (e.id === id ? { ...e, node: children } : e));
      }
      return [...list.filter((e) => e.id !== id).map((e) => ({ ...e, visible: false })), { id, node: children, visible: true }];
    });
  }, [id, children]);

  useEffect(() => {
    if (entered.has(id)) return;
    const frame = requestAnimationFrame(() => setEntered((s) => new Set(s).add(id)));
    const timer = window.setTimeout(() => {
      setEntries((list) => list.filter((e) => e.visible));
      setEntered((s) => new Set([...s].filter((k) => k === id)));
    }, duration);
    timers.current.push(timer);
    return () => cancelAnimationFrame(frame);
  }, [id, duration, entered]);

  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  return (
    <div style={{ display: 'grid', placeItems: 'center' }}>
      {entries.map((e) => (
        <div
          key={e.id}
          style={{
            gridArea: '1 / 1',
            opacity: e.visible && entered.has(e.id) ? 1 : 0,
            transition: `opacity ${duration}ms linear`,
          }}
        >
          {e.node}
        </div>
      ))}
    </div>
  );
}
