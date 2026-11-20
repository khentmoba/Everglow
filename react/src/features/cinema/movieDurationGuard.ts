export type MovieDurationCheck =
  | { kind: 'ok' }
  | { kind: 'decoy'; actualMinutes: number; expectedMinutes: number }
  | { kind: 'mismatch'; actualMinutes: number; expectedMinutes: number };

export function checkMovieStreamDuration(
  actualSeconds: number,
  expectedMinutes: number | null | undefined,
): MovieDurationCheck {
  if (!Number.isFinite(actualSeconds) || actualSeconds <= 0) return { kind: 'ok' };
  if (expectedMinutes == null || !Number.isFinite(expectedMinutes) || expectedMinutes < 45) {
    return { kind: 'ok' };
  }
  const actualMinutes = Math.round(actualSeconds / 60);
  const roundedExpected = Math.round(expectedMinutes);
  if (actualSeconds < 15 * 60) {
    return { kind: 'decoy', actualMinutes, expectedMinutes: roundedExpected };
  }
  const expectedSeconds = expectedMinutes * 60;
  const tolerance = Math.max(12 * 60, expectedSeconds * 0.15);
  if (Math.abs(actualSeconds - expectedSeconds) > tolerance) {
    return { kind: 'mismatch', actualMinutes, expectedMinutes: roundedExpected };
  }
  return { kind: 'ok' };
}

export function formatMinutesShort(minutes: number): string {
  const m = Math.max(0, Math.round(minutes));
  const h = Math.floor(m / 60);
  const rem = m % 60;
  if (h <= 0) return `${rem}m`;
  return `${h}h ${String(rem).padStart(2, '0')}m`;
}
