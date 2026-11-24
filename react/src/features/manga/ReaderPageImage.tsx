import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { Icon } from '../../shared/widgets/Icon';
import { katanaCdnFallback, proxyKatanaImageUrl, resolveCorsProxyImageUrl } from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';
import type { FitMode } from './readerSettings';
import { WIDE_ASPECT_THRESHOLD, type GuidedPanelRect } from './readerSpread';

export function normalizeAssetUrl(src: string): string {
  if (src.startsWith('assets/')) return `/${src.slice('assets/'.length)}`;
  return src;
}

export function resolveReaderImageUrl(src: string, step = 0): string {
  if (!src) return '';
  if (src.startsWith('blob:') || src.startsWith('data:') || src.startsWith('/')) {
    return normalizeAssetUrl(src);
  }
  return proxyKatanaImageUrl(katanaCdnFallback(src, step));
}

interface CropInsets {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

interface SampleAnalysis {
  insets: CropInsets | null;
  edgeColor: string | null;
  panels: GuidedPanelRect[];
}

/**
 * Samples a small offscreen canvas to detect uniform white/black scan margins (max 14%/side),
 * the dominant edge color for adaptive "Smart Background" matching (Komikku/TachiyomiSY style),
 * AND horizontal/vertical panel gutter lines for Guided Panel Zoom.
 */
function analyzePageCanvas(img: HTMLImageElement): SampleAnalysis {
  try {
    const sampleW = 96;
    const sampleH = Math.max(48, Math.min(180, Math.round((img.naturalHeight / Math.max(1, img.naturalWidth)) * sampleW)));
    const canvas = document.createElement('canvas');
    canvas.width = sampleW;
    canvas.height = sampleH;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) return { insets: null, edgeColor: null, panels: [] };
    ctx.drawImage(img, 0, 0, sampleW, sampleH);
    const data = ctx.getImageData(0, 0, sampleW, sampleH).data;

    // Sample perimeter pixels for adaptive background tint
    let rSum = 0;
    let gSum = 0;
    let bSum = 0;
    let count = 0;
    const addPx = (x: number, y: number) => {
      const i = (y * sampleW + x) * 4;
      rSum += data[i];
      gSum += data[i + 1];
      bSum += data[i + 2];
      count++;
    };
    for (let x = 0; x < sampleW; x += 4) {
      addPx(x, 0);
      addPx(x, sampleH - 1);
    }
    for (let y = 0; y < sampleH; y += 4) {
      addPx(0, y);
      addPx(sampleW - 1, y);
    }
    const edgeColor =
      count > 0
        ? `rgb(${Math.round(rSum / count)}, ${Math.round(gSum / count)}, ${Math.round(bSum / count)})`
        : null;

    const isBorderPixel = (x: number, y: number): boolean => {
      const i = (y * sampleW + x) * 4;
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const maxDiff = Math.max(Math.abs(r - g), Math.abs(g - b), Math.abs(r - b));
      if (maxDiff > 22) return false;
      const lum = (r + g + b) / 3;
      return lum >= 232 || lum <= 22;
    };

    let minX = sampleW;
    let maxX = -1;
    let minY = sampleH;
    let maxY = -1;
    for (let y = 0; y < sampleH; y += 2) {
      for (let x = 0; x < sampleW; x += 2) {
        if (!isBorderPixel(x, y)) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX <= minX || maxY <= minY) return { insets: null, edgeColor, panels: [] };

    const maxPct = 14;
    const insets: CropInsets = {
      top: Number(Math.min(maxPct, (minY / sampleH) * 100).toFixed(2)),
      bottom: Number(Math.min(maxPct, ((sampleH - 1 - maxY) / sampleH) * 100).toFixed(2)),
      left: Number(Math.min(maxPct, (minX / sampleW) * 100).toFixed(2)),
      right: Number(Math.min(maxPct, ((sampleW - 1 - maxX) / sampleW) * 100).toFixed(2)),
    };

    // Detect horizontal & vertical gutter lines inside [minX..maxX, minY..maxY] for Guided Panel Zoom
    const panels: GuidedPanelRect[] = [];
    const contentW = Math.max(1, maxX - minX + 1);
    const contentH = Math.max(1, maxY - minY + 1);
    const minRowH = Math.max(8, Math.round(contentH * 0.16));
    const minColW = Math.max(10, Math.round(contentW * 0.22));
    const yCuts: number[] = [minY];
    let yGutterStart = -1;
    for (let y = minY + minRowH; y <= maxY - minRowH; y++) {
      let gutterPx = 0;
      let totalPx = 0;
      for (let x = minX; x <= maxX; x += 2) {
        totalPx++;
        if (isBorderPixel(x, y)) gutterPx++;
      }
      const isGutterRow = totalPx > 0 && gutterPx / totalPx >= 0.86;
      if (isGutterRow) {
        if (yGutterStart < 0) yGutterStart = y;
      } else if (yGutterStart >= 0) {
        const midY = Math.round((yGutterStart + y - 1) / 2);
        if (midY - yCuts[yCuts.length - 1] >= minRowH && yCuts.length < 4) {
          yCuts.push(midY);
        }
        yGutterStart = -1;
      }
    }
    yCuts.push(maxY);

    for (let r = 0; r < yCuts.length - 1; r++) {
      const ry0 = yCuts[r];
      const ry1 = yCuts[r + 1];
      if (ry1 - ry0 < minRowH) continue;
      const xCuts: number[] = [minX];
      let xGutterStart = -1;
      for (let x = minX + minColW; x <= maxX - minColW; x++) {
        let gutterPx = 0;
        let totalPx = 0;
        for (let y = ry0; y <= ry1; y += 2) {
          totalPx++;
          if (isBorderPixel(x, y)) gutterPx++;
        }
        const isGutterCol = totalPx > 0 && gutterPx / totalPx >= 0.85;
        if (isGutterCol) {
          if (xGutterStart < 0) xGutterStart = x;
        } else if (xGutterStart >= 0) {
          const midX = Math.round((xGutterStart + x - 1) / 2);
          if (midX - xCuts[xCuts.length - 1] >= minColW && xCuts.length < 3) {
            xCuts.push(midX);
          }
          xGutterStart = -1;
        }
      }
      xCuts.push(maxX);

      for (let c = 0; c < xCuts.length - 1; c++) {
        const cx0 = xCuts[c];
        const cx1 = xCuts[c + 1];
        const nx0 = Math.max(0, cx0 / sampleW - 0.025);
        const ny0 = Math.max(0, ry0 / sampleH - 0.02);
        const nx1 = Math.min(1, cx1 / sampleW + 0.025);
        const ny1 = Math.min(1, ry1 / sampleH + 0.02);
        panels.push({
          x: Number(nx0.toFixed(3)),
          y: Number(ny0.toFixed(3)),
          w: Number(Math.max(0.18, nx1 - nx0).toFixed(3)),
          h: Number(Math.max(0.14, ny1 - ny0).toFixed(3)),
        });
      }
    }

    return {
      insets: insets.top + insets.bottom + insets.left + insets.right < 1 ? null : insets,
      edgeColor,
      panels,
    };
  } catch {
    return { insets: null, edgeColor: null, panels: [] };
  }
}

export interface ReaderPageImageProps {
  src: string;
  pageNumber: number;
  fitMode: FitMode;
  isWebtoon: boolean;
  isDoubleSpread?: boolean;
  cropHalf?: 'left' | 'right';
  rotateWide?: boolean;
  eager?: boolean;
  lowPriority?: boolean;
  cropBorders?: boolean;
  knownAspect?: number;
  defaultAspect?: number;
  containerWidth?: number;
  reloadToken?: number;
  sampleEdgeColor?: boolean;
  detectPanels?: boolean;
  onDimensions?: (naturalWidth: number, naturalHeight: number) => void;
  onEdgeColor?: (cssColor: string) => void;
  onPanelsDetected?: (panels: GuidedPanelRect[]) => void;
  onCdnStepResolved?: (step: number) => void;
  onErrorChange?: (errored: boolean) => void;
  onLongPress?: (resolvedUrl: string, pageNumber: number) => void;
}

export function ReaderPageImage({
  src,
  pageNumber,
  fitMode,
  isWebtoon,
  isDoubleSpread = false,
  cropHalf,
  rotateWide = false,
  eager = false,
  lowPriority = false,
  cropBorders = false,
  knownAspect,
  defaultAspect = 0.68,
  containerWidth = 430,
  reloadToken = 0,
  sampleEdgeColor = false,
  detectPanels = false,
  onDimensions,
  onEdgeColor,
  onPanelsDetected,
  onCdnStepResolved,
  onErrorChange,
  onLongPress,
}: ReaderPageImageProps) {
  const [step, setStep] = useState(0);
  const [retryCount, setRetryCount] = useState(0);
  const [status, setStatus] = useState<'loading' | 'loaded' | 'error'>('loading');
  const [aspect, setAspect] = useState<number | undefined>(knownAspect);
  const [cropInsets, setCropInsets] = useState<CropInsets | null>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const longPressTimer = useRef<number | null>(null);
  const touchMoved = useRef(false);

  useEffect(() => {
    setStep(0);
    setCropInsets(null);
    const img = imgRef.current;
    if (img && img.complete && img.naturalWidth > 0) {
      setStatus('loaded');
      onErrorChange?.(false);
      onCdnStepResolved?.(0);
      const ratio = img.naturalWidth / img.naturalHeight;
      setAspect(ratio);
      onDimensions?.(img.naturalWidth, img.naturalHeight);
    } else {
      setStatus('loading');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- callbacks arrive as inline arrows from the reader; listing them re-runs this on every render
  }, [src, reloadToken]);

  useEffect(() => {
    if (knownAspect && !aspect) setAspect(knownAspect);
  }, [knownAspect, aspect]);

  const baseResolved = resolveReaderImageUrl(src, step);
  const resolved =
    retryCount > 0 && baseResolved && !baseResolved.startsWith('blob:') && !baseResolved.startsWith('data:')
      ? `${baseResolved}${baseResolved.includes('?') ? '&' : '?'}_r=${retryCount}`
      : baseResolved;

  // Catch cached/data-URL images that finish decoding before React attaches or flushes the reset effect.
  useEffect(() => {
    const img = imgRef.current;
    if (status === 'loading' && img && img.complete && img.naturalWidth > 0) {
      setStatus('loaded');
      onErrorChange?.(false);
      onCdnStepResolved?.(step);
      const ratio = img.naturalWidth / img.naturalHeight;
      setAspect(ratio);
      onDimensions?.(img.naturalWidth, img.naturalHeight);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- same inline callbacks as above
  }, [resolved, reloadToken, status, step]);

  const shouldCrop = cropBorders;
  const needsCanvasSample = shouldCrop || sampleEdgeColor || detectPanels;

  useEffect(() => {
    if (!needsCanvasSample || status !== 'loaded') {
      if (!shouldCrop) setCropInsets(null);
      return;
    }
    const img = imgRef.current;
    if (!img) return;
    const applyAnalysis = (res: SampleAnalysis) => {
      if (shouldCrop) setCropInsets(res.insets);
      if (sampleEdgeColor && res.edgeColor) onEdgeColor?.(res.edgeColor);
      if (detectPanels && res.panels.length >= 2) onPanelsDetected?.(res.panels);
    };
    const isLocalUrl = resolved.startsWith('data:') || resolved.startsWith('blob:') || resolved.startsWith('/');
    if (isLocalUrl) {
      applyAnalysis(analyzePageCanvas(img));
      return;
    }
    // Probe via detached CORS image routed through Everglow's CORS-enabled image proxy
    // so gutter detection, border cropping, and edge-color sampling are always deterministic.
    let alive = true;
    const probe = new Image();
    probe.crossOrigin = 'anonymous';
    probe.onload = () => {
      if (alive) applyAnalysis(analyzePageCanvas(probe));
    };
    probe.onerror = () => {
      if (alive && shouldCrop) setCropInsets(null);
    };
    probe.src = resolveCorsProxyImageUrl(resolved);
    return () => {
      alive = false;
    };
  }, [needsCanvasSample, shouldCrop, sampleEdgeColor, detectPanels, status, resolved, onEdgeColor, onPanelsDetected]);

  useEffect(() => () => {
    if (longPressTimer.current != null) window.clearTimeout(longPressTimer.current);
  }, []);

  const handleRetry = (e: React.MouseEvent) => {
    e.stopPropagation();
    setStep(0);
    setStatus('loading');
    setRetryCount((c) => c + 1);
  };

  const handleError = () => {
    if (step < 4 && !src.startsWith('blob:') && !src.startsWith('data:') && !src.startsWith('/')) {
      setStep((s) => s + 1);
    } else {
      setStatus('error');
      onErrorChange?.(true);
    }
  };

  const handleLoad = (e: React.SyntheticEvent<HTMLImageElement>) => {
    const img = e.currentTarget;
    setStatus('loaded');
    onErrorChange?.(false);
    onCdnStepResolved?.(step);
    if (img.naturalWidth > 0 && img.naturalHeight > 0) {
      const ratio = img.naturalWidth / img.naturalHeight;
      setAspect(ratio);
      onDimensions?.(img.naturalWidth, img.naturalHeight);
    }
  };

  const clearLongPress = () => {
    if (longPressTimer.current != null) {
      window.clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  const startLongPress = () => {
    if (!onLongPress) return;
    touchMoved.current = false;
    clearLongPress();
    longPressTimer.current = window.setTimeout(() => {
      if (!touchMoved.current) onLongPress(resolved, pageNumber);
    }, 520);
  };

  const isWide = (aspect ?? 0) >= WIDE_ASPECT_THRESHOLD;
  const effectiveFit: Exclude<FitMode, 'smart-fit'> =
    fitMode === 'smart-fit' ? (isWide && !cropHalf ? 'fit-screen' : 'fit-width') : fitMode;

  const shouldRotate = rotateWide && !isWebtoon && !isDoubleSpread && !cropHalf && isWide;

  const cropReclaimTransform = (() => {
    if (!shouldCrop || !cropInsets) return '';
    const hTrim = cropInsets.left + cropInsets.right;
    const vTrim = cropInsets.top + cropInsets.bottom;
    const scaleX = hTrim > 0 && hTrim < 28 ? 1 / (1 - hTrim / 100) : 1;
    const scaleY = vTrim > 0 && vTrim < 28 ? 1 / (1 - vTrim / 100) : 1;
    const reclaimScale = Math.min(1.3, Math.max(scaleX, scaleY));
    return reclaimScale > 1.005 ? `scale(${reclaimScale.toFixed(3)})` : '';
  })();

  const cropStyle: CSSProperties = shouldCrop && cropInsets
    ? {
        clipPath: `inset(${cropInsets.top}% ${cropInsets.right}% ${cropInsets.bottom}% ${cropInsets.left}%)`,
        transform: cropReclaimTransform || undefined,
        transformOrigin: 'center center',
      }
    : {};

  const composeTransform = (extra: string) => (cropReclaimTransform ? `${extra} ${cropReclaimTransform}` : extra);

  const imgStyle: CSSProperties = (() => {
    const base: CSSProperties = {
      display: 'block',
      userSelect: 'none',
      WebkitUserSelect: 'none',
      opacity: status === 'loaded' ? 1 : 0,
      transition: 'opacity 160ms ease',
      ...cropStyle,
    };

    if (cropHalf) {
      return {
        ...base,
        width: '200%',
        maxWidth: 'none',
        height: effectiveFit === 'fit-height' || effectiveFit === 'fit-screen' ? '100%' : 'auto',
        objectFit: 'contain',
        transform: composeTransform(cropHalf === 'right' ? 'translateX(-50%)' : 'translateX(0)'),
      };
    }

    if (shouldRotate) {
      return {
        ...base,
        maxWidth: '92dvh',
        maxHeight: '92vw',
        width: 'auto',
        height: 'auto',
        objectFit: 'contain',
        transform: composeTransform('rotate(90deg)'),
      };
    }

    if (isWebtoon) {
      if (effectiveFit === 'original') {
        return { ...base, width: 'auto', maxWidth: 'none', height: 'auto', margin: '0 auto' };
      }
      if (effectiveFit === 'fit-height') {
        return { ...base, height: '100dvh', width: 'auto', maxWidth: '100%', objectFit: 'contain', margin: '0 auto' };
      }
      return { ...base, width: '100%', height: 'auto' };
    }

    if (isDoubleSpread) {
      if (effectiveFit === 'fit-width') {
        return { ...base, width: '100%', height: 'auto', maxHeight: 'none', objectFit: 'contain' };
      }
      if (effectiveFit === 'original') {
        return { ...base, width: 'auto', height: 'auto', maxWidth: 'none', maxHeight: 'none' };
      }
      return {
        ...base,
        maxHeight: '100%',
        maxWidth: '100%',
        width: 'auto',
        height: effectiveFit === 'fit-height' ? '100%' : 'auto',
        objectFit: 'contain',
      };
    }

    switch (effectiveFit) {
      case 'fit-height':
        return { ...base, height: '100%', width: 'auto', maxWidth: '100%', objectFit: 'contain' };
      case 'fit-screen':
        return { ...base, maxWidth: '100%', maxHeight: '100%', width: 'auto', height: 'auto', objectFit: 'contain' };
      case 'stretch':
        return { ...base, width: '100%', height: '100%', objectFit: 'fill' };
      case 'original':
        return { ...base, width: 'auto', height: 'auto', maxWidth: 'none', maxHeight: 'none' };
      case 'fit-width':
      default:
        return { ...base, width: '100%', height: 'auto' };
    }
  })();

  const safeWidth = Math.max(240, Math.round(containerWidth));
  const fallbackAspect = Math.max(0.2, aspect ?? defaultAspect);
  const wrapperStyle: CSSProperties = isWebtoon
    ? {
        position: 'relative',
        width: '100%',
        overflow: 'hidden',
        aspectRatio: status !== 'loaded' ? String(fallbackAspect) : undefined,
        contentVisibility: 'auto',
        containIntrinsicSize: `auto ${Math.round(safeWidth / fallbackAspect)}px`,
        background: status !== 'loaded' ? 'rgba(255, 255, 255, 0.03)' : undefined,
      }
    : cropHalf
      ? {
          position: 'relative',
          width: '100%',
          height: effectiveFit === 'fit-height' || effectiveFit === 'fit-screen' ? '100%' : 'auto',
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'flex-start',
        }
      : {
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          overflow: 'visible',
          width: isDoubleSpread ? '50%' : effectiveFit === 'fit-width' && !shouldRotate ? '100%' : 'auto',
          height: effectiveFit === 'fit-height' || effectiveFit === 'fit-screen' || shouldRotate ? '100%' : 'auto',
          maxWidth: '100%',
          maxHeight: effectiveFit === 'fit-height' || effectiveFit === 'fit-screen' || shouldRotate ? '100%' : undefined,
          minHeight: status !== 'loaded' ? 280 : undefined,
          minWidth: status !== 'loaded' && !isDoubleSpread ? 220 : undefined,
        };

  return (
    <div
      style={wrapperStyle}
      onTouchStart={startLongPress}
      onTouchMove={() => {
        touchMoved.current = true;
        clearLongPress();
      }}
      onTouchEnd={clearLongPress}
      onTouchCancel={clearLongPress}
      onContextMenu={(e) => {
        if (!onLongPress) return;
        e.preventDefault();
        onLongPress(resolved, pageNumber);
      }}
    >
      {status === 'loading' && (
        <div
          className="anx-shimmer"
          aria-label={`Loading page ${pageNumber}`}
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            color: KatanaColors.textLight,
            pointerEvents: 'none',
          }}
        >
          <span
            style={{
              fontSize: 12,
              fontWeight: 600,
              padding: '4px 10px',
              borderRadius: 99,
              background: 'rgba(9, 6, 12, 0.72)',
              border: `1px solid ${KatanaColors.border}`,
              color: KatanaColors.textMuted,
            }}
          >
            Page {pageNumber}
          </span>
        </div>
      )}

      {status === 'error' ? (
        <div
          onClick={(e) => e.stopPropagation()}
          style={{
            width: '100%',
            minHeight: 260,
            padding: 24,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 10,
            background: KatanaColors.surface,
            border: `1px solid ${KatanaColors.border}`,
            borderRadius: isWebtoon ? 0 : 12,
            textAlign: 'center',
          }}
        >
          <Icon name="broken_image" size={32} color={KatanaColors.accentSoft} />
          <div style={{ ...KatanaType.title, fontSize: 14 }}>Page {pageNumber} failed to load</div>
          <div style={{ ...KatanaType.small, maxWidth: 260 }}>
            All image mirrors timed out. Tap below to retry or switch servers in settings.
          </div>
          <button
            type="button"
            className="bare-button player-focusable"
            onClick={handleRetry}
            style={{
              marginTop: 4,
              minHeight: 44,
              padding: '0 20px',
              borderRadius: 99,
              background: KatanaColors.accent,
              color: '#FFFFFF',
              fontSize: 13,
              fontWeight: 600,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <Icon name="refresh" size={18} color="#FFFFFF" />
            Retry Page {pageNumber}
          </button>
        </div>
      ) : (
        <img
          key={`${resolved}#${reloadToken}`}
          ref={imgRef}
          src={resolved}
          alt={cropHalf ? `Page ${pageNumber} (${cropHalf} half)` : `Page ${pageNumber}`}
          loading={eager ? 'eager' : 'lazy'}
          fetchPriority={lowPriority ? 'low' : eager ? 'high' : 'auto'}
          decoding="async"
          draggable={false}
          onLoad={handleLoad}
          onError={handleError}
          style={imgStyle}
        />
      )}
    </div>
  );
}
