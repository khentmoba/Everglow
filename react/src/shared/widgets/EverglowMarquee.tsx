// Port of lib/shared/widgets/everglow/everglow_marquee.dart.
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { motionReduced } from '../../core/theme/motion';

export function EverglowMarquee({
  children,
  height,
  pixelsPerSecond = 34,
  itemSpacing = 12,
  edgeFade = true,
}: {
  children: ReactNode[];
  height: number;
  pixelsPerSecond?: number;
  itemSpacing?: number;
  edgeFade?: boolean;
}) {
  const reduceAmbient = motionReduced();
  const outerRef = useRef<HTMLDivElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const firstSetRef = useRef<HTMLDivElement>(null);
  const [hovered, setHovered] = useState(false);
  const [touchPaused, setTouchPaused] = useState(false);
  const [visible, setVisible] = useState(() => typeof IntersectionObserver === 'undefined');
  const [repeatCount, setRepeatCount] = useState(2);
  const [interSetGap, setInterSetGap] = useState(itemSpacing);
  const offsetRef = useRef(0);
  const loopWidthRef = useRef(0);

  useEffect(() => {
    const outer = outerRef.current;
    if (!outer || typeof IntersectionObserver === 'undefined') return;
    const io = new IntersectionObserver(
      (entries) => {
        setVisible(entries.some((e) => e.isIntersecting));
      },
      { rootMargin: '150px 0px' },
    );
    io.observe(outer);
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    if (reduceAmbient || children.length === 0) return;
    const measure = () => {
      const outer = outerRef.current;
      const setEl = firstSetRef.current;
      if (!outer || !setEl) return;
      const vw = outer.clientWidth;
      const setWidth = setEl.scrollWidth;
      if (vw <= 0 || setWidth <= 0) return;
      const isShort = setWidth < vw;
      const gap = isShort ? vw - setWidth + itemSpacing : itemSpacing;
      const loopW = Math.max(1, setWidth + gap);
      loopWidthRef.current = loopW;
      setInterSetGap(gap);
      setRepeatCount(isShort ? 2 : Math.min(12, Math.max(2, 1 + Math.ceil(vw / loopW))));
    };
    measure();
    const ro = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(measure) : null;
    if (ro && outerRef.current) ro.observe(outerRef.current);
    if (ro && firstSetRef.current) ro.observe(firstSetRef.current);
    return () => ro?.disconnect();
  }, [reduceAmbient, children.length, itemSpacing]);

  useEffect(() => {
    if (reduceAmbient || children.length === 0 || hovered || touchPaused || !visible) return;
    let rafId = 0;
    let lastTs = performance.now();
    const tick = (now: number) => {
      rafId = 0;
      if (document.hidden) return;
      const dt = Math.min(0.1, Math.max(0, (now - lastTs) / 1000));
      lastTs = now;
      const loopW = loopWidthRef.current;
      if (loopW > 1 && trackRef.current) {
        offsetRef.current = (offsetRef.current + pixelsPerSecond * dt) % loopW;
        trackRef.current.style.transform = `translate3d(${-offsetRef.current.toFixed(2)}px, 0, 0)`;
      }
      rafId = window.requestAnimationFrame(tick);
    };
    const onVisibility = () => {
      if (document.hidden) {
        if (rafId) {
          window.cancelAnimationFrame(rafId);
          rafId = 0;
        }
      } else if (!rafId) {
        lastTs = performance.now();
        rafId = window.requestAnimationFrame(tick);
      }
    };
    document.addEventListener('visibilitychange', onVisibility);
    if (!document.hidden) rafId = window.requestAnimationFrame(tick);
    return () => {
      document.removeEventListener('visibilitychange', onVisibility);
      if (rafId) window.cancelAnimationFrame(rafId);
    };
  }, [reduceAmbient, children.length, hovered, touchPaused, visible, pixelsPerSecond]);

  if (children.length === 0) return null;

  if (reduceAmbient) {
    return (
      <div className="no-scrollbar" style={{ overflowX: 'auto', height }}>
        <div style={{ display: 'flex', gap: itemSpacing, width: 'max-content', height: '100%', alignItems: 'center' }}>
          {children}
        </div>
      </div>
    );
  }

  const maskStyle = edgeFade
    ? {
        maskImage: 'linear-gradient(to right, transparent 0%, black 3.5%, black 96.5%, transparent 100%)',
        WebkitMaskImage: 'linear-gradient(to right, transparent 0%, black 3.5%, black 96.5%, transparent 100%)',
      }
    : undefined;

  return (
    <div
      ref={outerRef}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onTouchStart={() => setTouchPaused(true)}
      onTouchEnd={() => setTouchPaused(false)}
      onTouchCancel={() => setTouchPaused(false)}
      style={{
        position: 'relative',
        height,
        overflow: 'hidden',
        ...maskStyle,
      }}
    >
      <div
        ref={trackRef}
        style={{
          display: 'flex',
          alignItems: 'center',
          height: '100%',
          width: 'max-content',
          willChange: 'transform',
        }}
      >
        {Array.from({ length: repeatCount }).map((_, setIdx) => (
          <div
            key={setIdx}
            ref={setIdx === 0 ? firstSetRef : undefined}
            aria-hidden={setIdx > 0 || undefined}
            inert={setIdx > 0 || undefined}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: itemSpacing,
              marginRight: interSetGap,
              flexShrink: 0,
            }}
          >
            {children}
          </div>
        ))}
      </div>
    </div>
  );
}
