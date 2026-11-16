// Port of lib/features/guardian/presentation/widgets/thought_bubble.dart.
import { AppColors, withAlpha } from '../../core/theme/colors';
import { boxShadow } from '../../core/theme/paint';

export function ThoughtBubble({ message }: { message: string }) {
  const fill = withAlpha(AppColors.petalWhite, 0.92);
  return (
    <div
      style={{
        pointerEvents: 'none',
        position: 'relative',
        padding: '12px 16px',
        maxWidth: 150,
        background: fill,
        borderRadius: 24,
        border: `1.5px solid ${AppColors.petalWhite}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.12), blur: 15, offset: [0, 6] }]),
      }}
    >
      <div
        style={{
          fontSize: 13,
          color: AppColors.deepRose,
          fontWeight: 600,
          fontStyle: 'italic',
          textAlign: 'center',
        }}
      >
        {message}
      </div>
      <svg
        width={15}
        height={15}
        viewBox="0 0 15 15"
        style={{ position: 'absolute', bottom: -14, right: 20, display: 'block' }}
        aria-hidden
      >
        <polygon points="0,0 15,0 7.5,15" fill={fill} />
      </svg>
    </div>
  );
}
