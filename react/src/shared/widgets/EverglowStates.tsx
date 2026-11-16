// Ports of everglow_empty_state.dart, everglow_error_state.dart,
// EverglowLoadingState (everglow_skeleton.dart) and everglow_stream_view.dart.
import { useEffect, useState, type ReactNode } from 'react';
import { Logger } from '../../core/system/logger';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { TimeoutError, type Source } from '../../core/utils/liveSource';
import { CircularProgress } from './CircularProgress';
import { EverglowButton } from './EverglowButton';
import { Icon } from './Icon';

const headlineSmall = { ...AppTypography.cormorantHeading, fontSize: 24, lineHeight: lineHeight(24) };
const bodyMedium = { ...AppTypography.bodyMedium, lineHeight: lineHeight(14) };

export function EverglowEmptyState({
  icon,
  title,
  subtitle,
  ctaLabel,
  onCta,
  compact = false,
}: {
  icon: string;
  title: string;
  subtitle?: string;
  ctaLabel?: string;
  onCta?: () => void;
  compact?: boolean;
}) {
  const size = compact ? 64 : 84;
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div
        style={{
          padding: compact ? AppSpacing.x2 : AppSpacing.x4,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: size,
            height: size,
            borderRadius: '50%',
            background: linear([withAlpha(AppColors.velvet, 0.9), AppColors.inkDeep], {
              begin: Align.topLeft,
              end: Align.bottomRight,
              size: [size, size],
            }),
            border: `1px solid ${Derived.border}`,
            boxShadow: compact ? undefined : boxShadow([{ color: withAlpha(AppColors.deepRose, 0.12), blur: 12 }]),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxSizing: 'border-box',
          }}
        >
          <Icon name={icon} size={compact ? 28 : 34} color={AppColors.roseQuartz} />
        </div>
        <div style={{ height: AppSpacing.xl }} />
        <div style={{ ...headlineSmall, textAlign: 'center' }}>{title}</div>
        {subtitle != null && (
          <>
            <div style={{ height: AppSpacing.md }} />
            <div style={{ ...bodyMedium, textAlign: 'center' }}>{subtitle}</div>
          </>
        )}
        {ctaLabel != null && onCta && (
          <>
            <div style={{ height: AppSpacing.xl }} />
            <CtaButton label={ctaLabel} onPressed={onCta} />
          </>
        )}
      </div>
    </div>
  );
}

function CtaButton({ label, onPressed }: { label: string; onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={onPressed}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        padding: `${AppSpacing.md}px ${AppSpacing.x2}px`,
        background: linear([AppColors.deepRose, AppColors.velvet]),
        borderRadius: AppRadius.xl,
        boxShadow: hovered
          ? boxShadow([{ color: withAlpha(AppColors.deepRose, 0.18), blur: 14 }])
          : boxShadow([{ color: 'rgba(0,0,0,0.2)', blur: 8, offset: [0, 2] }]),
        transform: `translateY(${hovered ? -2 : 0}px)`,
        transition: `transform ${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}, box-shadow ${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}`,
        ...AppTypography.labelLarge,
        lineHeight: lineHeight(14),
      }}
    >
      {label}
    </button>
  );
}

export function EverglowErrorState({ message, onRetry, retryLabel, icon = 'cloud_off' }: {
  message: string;
  onRetry?: () => void;
  retryLabel?: string;
  icon?: string;
}) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div style={{ padding: AppSpacing.x3, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div
          style={{
            width: 80,
            height: 80,
            borderRadius: '50%',
            background: withAlpha(AppColors.velvet, 0.5),
            border: `1px solid ${withAlpha(AppColors.error, 0.3)}`,
            boxShadow: boxShadow([{ color: withAlpha(AppColors.error, 0.15), blur: 24 }]),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxSizing: 'border-box',
          }}
        >
          <Icon name={icon} size={36} color={AppColors.error} />
        </div>
        <div style={{ height: AppSpacing.x2 }} />
        <div style={{ ...headlineSmall, textAlign: 'center' }}>Something went wrong</div>
        <div style={{ height: AppSpacing.sm }} />
        <div className="clamp-3" style={{ ...bodyMedium, textAlign: 'center' }}>
          {message}
        </div>
        {onRetry && (
          <>
            <div style={{ height: AppSpacing.x2 }} />
            <EverglowButton label={retryLabel ?? 'Retry'} icon="refresh" onPressed={onRetry} />
          </>
        )}
      </div>
    </div>
  );
}

export function EverglowLoadingState({ message }: { message?: string }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
      <CircularProgress size={24} strokeWidth={2} color={AppColors.deepRose} />
      {message != null && (
        <>
          <div style={{ height: 16 }} />
          <div style={{ ...AppTypography.outfitWhite, fontSize: 13, lineHeight: lineHeight(13), color: withAlpha(AppColors.roseQuartz, 0.7) }}>
            {message}
          </div>
        </>
      )}
    </div>
  );
}

type StreamState<T> = { data: T | null; error: unknown };

function isTransient(e: unknown): boolean {
  if (e instanceof TimeoutError) return true;
  const code = (e as { code?: string } | null)?.code ?? '';
  return ['unavailable', 'deadline-exceeded', 'aborted', 'cancelled', 'resource-exhausted'].some(
    (c) => code === c || code.endsWith(`/${c}`),
  );
}

/** `EverglowStreamView`: loading spinner, error state, empty view, or the builder. */
export function EverglowStreamView<T>({
  source,
  sourceKey,
  label,
  builder,
  isEmpty,
  emptyView,
  loadingView,
  loadingMessage,
  errorMessage = 'Could not load',
  errorIcon = 'cloud_off',
  onRetry,
}: {
  source: () => Source<T>;
  sourceKey: unknown[];
  label?: string;
  builder: (data: T) => ReactNode;
  isEmpty?: (data: T) => boolean;
  emptyView?: ReactNode;
  loadingView?: ReactNode;
  loadingMessage?: string;
  errorMessage?: string;
  errorIcon?: string;
  onRetry?: () => void;
}) {
  const [state, setState] = useState<StreamState<T>>({ data: null, error: null });
  useEffect(() => {
    setState({ data: null, error: null });
    return source()({
      data: (data) => setState({ data, error: null }),
      error: (error) => {
        Logger.e(label ?? 'stream', error);
        setState((s) => ({ data: isTransient(error) ? s.data : null, error }));
      },
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, sourceKey);

  if (state.error != null && state.data == null) {
    return <EverglowErrorState message={errorMessage} onRetry={onRetry} icon={errorIcon} />;
  }
  if (state.data == null) return <>{loadingView ?? <EverglowLoadingState message={loadingMessage} />}</>;
  const content = isEmpty?.(state.data) ? (emptyView ?? null) : builder(state.data);
  return (
    <div style={{ position: 'relative' }}>
      {content}
      {state.error != null && (
        <button
          type="button"
          className="bare-button"
          onClick={onRetry}
          style={{
            position: 'absolute',
            top: 8,
            right: 8,
            height: 40,
            padding: '0 16px 0 12px',
            borderRadius: 12,
            background: AppColors.twilight,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            ...AppTypography.labelLarge,
          }}
        >
          <Icon name="cloud_off" size={16} color={AppColors.petalWhite} />
          {onRetry ? 'Could not refresh · Retry' : 'Could not refresh'}
        </button>
      )}
    </div>
  );
}
