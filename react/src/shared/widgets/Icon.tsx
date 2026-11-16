// Flutter's `Icon(Icons.x_rounded)` / `Icons.x_outlined`, drawn with the same
// Material Icons font Flutter bundles.
import 'material-icons/iconfont/round.css';
import 'material-icons/iconfont/outlined.css';
import 'material-icons/iconfont/filled.css';

export type IconStyle = 'round' | 'outlined' | 'filled';

export function Icon({
  name,
  size = 24,
  color,
  variant = 'round',
  label,
}: {
  name: string;
  size?: number;
  color?: string;
  variant?: IconStyle;
  label?: string;
}) {
  const cls = variant === 'filled' ? 'material-icons' : `material-icons-${variant}`;
  return (
    <span
      className={cls}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      style={{
        fontSize: size,
        width: size,
        height: size,
        lineHeight: 1,
        letterSpacing: 0,
        color,
        display: 'inline-block',
        overflow: 'hidden',
        userSelect: 'none',
        flexShrink: 0,
      }}
    >
      {name}
    </span>
  );
}
