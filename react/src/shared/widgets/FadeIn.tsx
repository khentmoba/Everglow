// animate_do's FadeInDown / FadeInUp (package animate_do 3.3.9), as Flutter
// uses them: slides `from` px over `duration` with Curves.easeOut while the
// opacity runs linearly over the first 65%. Moves the picture only, never the
// layout (Flutter's Transform.translate).
import { useEffect, type CSSProperties, type ReactNode } from 'react';
import { useController } from '../../core/anim/controller';
import { Curves } from '../../core/theme/motion';

export function FadeIn({
  direction,
  children,
  duration = 800,
  delay = 0,
  from = 100,
  style,
}: {
  direction: 'down' | 'up';
  children: ReactNode;
  duration?: number;
  delay?: number;
  from?: number;
  style?: CSSProperties;
}) {
  const controller = useController(duration);
  useEffect(() => {
    const timer = window.setTimeout(() => void controller.forward(), delay);
    return () => window.clearTimeout(timer);
  }, [controller, delay]);
  const t = controller.value;
  const start = direction === 'down' ? -from : from;
  const dy = start * (1 - Curves.easeOut(t));
  const opacity = Math.min(1, t / 0.65);
  return <div style={{ ...style, transform: dy ? `translateY(${dy}px)` : undefined, opacity }}>{children}</div>;
}
