// lib/core/theme/app_breakpoints.dart, app_spacing.dart and app_radius.dart.

export type Breakpoint = 'mobile' | 'tablet' | 'desktop';

export const AppBreakpoint = {
  mobile: 600,
  tablet: 1024,
  desktop: 1440,
  of(width: number): Breakpoint {
    if (width >= 1024) return 'desktop';
    if (width >= 600) return 'tablet';
    return 'mobile';
  },
  isMobile: (width: number) => width < 600,
};

export function responsive<T>(width: number, values: Record<Breakpoint, T>): T {
  return values[AppBreakpoint.of(width)];
}

export const AppSpacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  x2: 24,
  x3: 32,
  x4: 48,
  x5: 64,
  x6: 80,
  section: (width: number) => (width >= 1024 ? 80 : width >= 600 ? 64 : 48),
  pageH: (width: number) => (width >= 1024 ? 48 : width >= 600 ? 32 : 16),
};

export const AppRadius = { xs: 8, sm: 12, md: 14, lg: 16, xl: 20, x2: 24, x3: 28, full: 999 };
