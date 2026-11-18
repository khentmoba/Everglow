// Port of lib/shared/widgets/everglow/everglow_chat_bubble.dart.
import type { CSSProperties, ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, letterSpacing, lineHeight, linear, shadowLayer, type BoxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowMarkdown } from './EverglowMarkdown';
import { Icon } from './Icon';
import { showSnackBar } from './SnackBar';

export function copyText(text: string) {
  void navigator.clipboard?.writeText(text).catch(() => undefined);
  showSnackBar('Copied', { duration: 1000 });
}

/** A see-through box whose Flutter shadows still show underneath it. */
export function GlassBox({
  shadows,
  radius,
  style,
  children,
}: {
  shadows: BoxShadow[];
  radius: string | number;
  style?: CSSProperties;
  children?: ReactNode;
}) {
  return (
    <div style={{ position: 'relative', borderRadius: radius, ...style }}>
      {shadows.map((s, i) => (
        <div key={i} style={{ ...shadowLayer(s, { radius }), zIndex: 0 }} />
      ))}
      {children}
    </div>
  );
}

export function MotchiAvatar({
  size = 36,
  radius = 12,
  glow = AppColors.blushGold,
}: {
  size?: number;
  radius?: number;
  glow?: string;
}) {
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <div style={{ ...shadowLayer({ color: withAlpha(glow, 0.25), blur: 14, spread: 1 }, { radius }) }} />
      <div
        style={{
          position: 'relative',
          width: size,
          height: size,
          borderRadius: radius,
          boxShadow: `inset 0 0 0 1.2px ${withAlpha(glow, 0.45)}`,
          overflow: 'hidden',
        }}
      >
        <img
          src="/images/motchi_avatar.webp"
          alt=""
          width={size}
          height={size}
          style={{ display: 'block', width: size, height: size, objectFit: 'cover', borderRadius: radius - 1 }}
        />
      </div>
    </div>
  );
}

export function EverglowUserBubble({
  text,
  timeLabel,
  maxWidthFactor = 0.78,
}: {
  text: string;
  timeLabel?: string;
  maxWidthFactor?: number;
}) {
  const { width } = useViewport();
  const radius = '20px 20px 6px 20px';
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'flex-end' }}>
      <GlassBox
        radius={radius}
        shadows={[
          { color: 'rgba(0,0,0,0.25)', blur: 14, offset: [0, 4] },
          { color: withAlpha(AppColors.deepRose, 0.32), blur: 20, offset: [0, 6] },
        ]}
        style={{ maxWidth: width * maxWidthFactor, minWidth: 0 }}
      >
        <div
          onContextMenu={undefined}
          style={{
            position: 'relative',
            padding: '13px 16px',
            borderRadius: radius,
            background: linear([AppColors.deepRose, AppColors.roseDepths, AppColors.roseDark], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            border: `1px solid ${withAlpha(AppColors.petalWhite, 0.2)}`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-end',
          }}
        >
          <div
            style={{
              ...AppTypography.bodyMedium,
              color: AppColors.petalWhite,
              fontSize: 14.5,
              fontWeight: 500,
              lineHeight: lineHeight(14.5, 1.55),
              whiteSpace: 'pre-wrap',
              overflowWrap: 'anywhere',
              userSelect: 'text',
              alignSelf: 'stretch',
            }}
          >
            {text}
          </div>
          {timeLabel ? (
            <div style={{ marginTop: 5, display: 'flex', alignItems: 'center', gap: 4 }}>
              <Icon name="favorite" size={9} color={withAlpha(AppColors.petalWhite, 0.65)} />
              <span
                style={{
                  ...AppTypography.bodySmall,
                  fontSize: 11,
                  fontWeight: 500,
                  color: withAlpha(AppColors.petalWhite, 0.78),
                }}
              >
                {timeLabel}
              </span>
            </div>
          ) : null}
        </div>
      </GlassBox>
    </div>
  );
}

export const assistantBubbleRadius = '6px 22px 22px 22px';
export const assistantBubbleShadows: BoxShadow[] = [
  { color: 'rgba(0,0,0,0.35)', blur: 22, offset: [0, 8] },
  { color: withAlpha(AppColors.auroraLilac, 0.09), blur: 24, offset: [0, 2] },
];
export const assistantBubbleFill = linear([withAlpha(AppColors.velvet, 0.68), withAlpha(AppColors.inkDeep, 0.88)], {
  begin: Align.topLeft,
  end: Align.bottomRight,
});

export function EverglowAssistantBubble({
  text,
  title = 'Motchi',
  subtitle,
  timeLabel,
  isStreaming = false,
  streamingFooter,
  leadingReasoning,
  showAvatar = true,
  maxWidth,
}: {
  text: string;
  title?: string;
  subtitle?: string;
  timeLabel?: string;
  isStreaming?: boolean;
  streamingFooter?: ReactNode;
  leadingReasoning?: ReactNode;
  showAvatar?: boolean;
  maxWidth?: number;
}) {
  const { width } = useViewport();
  const bubbleMax = maxWidth ?? width * 0.82;
  const body = text.trimStart();
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start' }}>
      {showAvatar && (
        <>
          <MotchiAvatar />
          <div style={{ width: 10, flexShrink: 0 }} />
        </>
      )}
      <GlassBox
        radius={assistantBubbleRadius}
        shadows={assistantBubbleShadows}
        style={{ flex: '0 1 auto', minWidth: 0, maxWidth: bubbleMax }}
      >
        <div
          style={{
            position: 'relative',
            padding: '14px 17px 13px',
            borderRadius: assistantBubbleRadius,
            background: assistantBubbleFill,
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                padding: '3.5px 8.5px',
                background: withAlpha(AppColors.blushGold, 0.12),
                borderRadius: AppRadius.full,
                boxShadow: `inset 0 0 0 0.8px ${withAlpha(AppColors.blushGold, 0.28)}`,
                display: 'flex',
                alignItems: 'center',
                flexShrink: 0,
              }}
            >
              <span style={{ fontSize: 10, lineHeight: 1.2 }}>🐾</span>
              <span style={{ width: 4.5 }} />
              <span
                style={{
                  ...AppTypography.labelSmall,
                  fontSize: 10.5,
                  fontWeight: 700,
                  color: AppColors.blushGold,
                  ...letterSpacing(0.8),
                }}
              >
                {title.toUpperCase()}
              </span>
            </div>
            {subtitle ? (
              <span
                style={{
                  ...AppTypography.bodySmall,
                  marginLeft: 8,
                  fontSize: 11.5,
                  fontWeight: 500,
                  color: withAlpha(AppColors.roseQuartz, 0.82),
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                  minWidth: 0,
                }}
              >
                · {subtitle}
              </span>
            ) : null}
            <div style={{ flex: 1 }} />
            <EverglowCopyIconButton textToCopy={text} />
          </div>
          <div style={{ height: 9 }} />
          {leadingReasoning != null && (
            <>
              {leadingReasoning}
              <div style={{ height: 8 }} />
            </>
          )}
          {isStreaming && !body ? (
            streamingFooter
          ) : (
            <div style={{ userSelect: 'text' }}>
              <EverglowMarkdown
                text={body}
                baseStyle={{
                  ...AppTypography.bodyMedium,
                  color: Derived.textHigh,
                  lineHeight: 1.65,
                  fontSize: 14.5,
                  fontWeight: 500,
                }}
              />
            </div>
          )}
          {isStreaming && body ? (
            <>
              <div style={{ height: 8 }} />
              {streamingFooter}
            </>
          ) : null}
          {!isStreaming && timeLabel != null ? (
            <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 5 }}>
              <Icon name="auto_awesome" size={11} color={withAlpha(AppColors.blushGold, 0.75)} />
              <span style={{ ...AppTypography.bodySmall, fontSize: 11, fontWeight: 500, color: Derived.textMuted }}>
                {timeLabel}
              </span>
            </div>
          ) : null}
        </div>
      </GlassBox>
    </div>
  );
}

export function EverglowCopyIconButton({ textToCopy }: { textToCopy: string }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Copy"
      onClick={() => copyText(textToCopy)}
      style={{ padding: 5, borderRadius: 8, display: 'flex' }}
    >
      <Icon name="copy" size={14} color={Derived.textMuted} />
    </button>
  );
}
