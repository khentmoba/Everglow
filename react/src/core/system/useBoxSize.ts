// The border-box size of an element, for paints (diagonal gradients) that
// Flutter lays out against the box's real size.
import { useLayoutEffect, useRef, useState } from 'react';

export function useBoxSize<T extends HTMLElement>(): [React.RefObject<T | null>, [number, number] | undefined] {
  const ref = useRef<T | null>(null);
  const [size, setSize] = useState<[number, number]>();
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => {
      const w = el.offsetWidth;
      const h = el.offsetHeight;
      setSize((s) => (s && s[0] === w && s[1] === h ? s : [w, h]));
    };
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, size];
}
