// The shape Home will have while its rails arrive, drawn instead of a spinner.
import type { CSSProperties } from 'react';
import { NetflixColors } from './cinemaTypes';
import { rowCardWidth } from './NetflixUi';

export function CinemaHomeSkeleton({
  isDesktop,
  viewportHeight,
  viewportWidth,
}: {
  isDesktop: boolean;
  viewportHeight: number;
  viewportWidth: number;
}) {
  const heroHeight = isDesktop ? 560 : Math.max(380, Math.min(540, Math.round(viewportHeight * 0.58)));
  // The placeholders must be the size of the real ones, or the page jumps.
  const cardWidth = rowCardWidth(isDesktop, viewportWidth);
  const bar = (w: number | string, h: number, extra: CSSProperties = {}): CSSProperties => ({
    width: w,
    height: h,
    borderRadius: h / 2,
    background: 'rgba(255,255,255,0.08)',
    ...extra,
  });
  return (
    <div aria-busy="true" aria-label="Loading Cinema">
      <div style={{ height: heroHeight, background: NetflixColors.surface, padding: '0 16px', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
        <div style={bar('32%', 12)} />
        <div style={{ height: 14 }} />
        <div style={bar('68%', 32)} />
        <div style={{ height: 12 }} />
        <div style={bar('84%', 10)} />
        <div style={{ height: 18 }} />
        <div style={{ display: 'flex', gap: 10, marginBottom: 40 }}>
          <div style={bar(104, 40)} />
          <div style={bar(120, 40)} />
        </div>
      </div>
      {[0, 1].map((rail) => (
        <div key={rail} style={{ padding: '26px 16px 0' }}>
          <div style={bar(160, 16)} />
          <div style={{ height: 10 }} />
          <div style={bar(230, 10, { background: 'rgba(255,255,255,0.05)' })} />
          <div style={{ height: 12 }} />
          <div style={{ display: 'flex', gap: 8, overflow: 'hidden' }}>
            {Array.from({ length: isDesktop ? 7 : 4 }).map((_, i) => (
              <div
                key={i}
                style={{
                  width: cardWidth,
                  height: cardWidth * 1.5,
                  borderRadius: 6,
                  background: 'rgba(255,255,255,0.06)',
                  flexShrink: 0,
                }}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

