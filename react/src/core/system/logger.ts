// Port of lib/core/utils/logger.dart (console only for now).
export const Logger = {
  d: (msg: string) => {
    if (import.meta.env.DEV) console.debug(`[Everglow] ${msg}`);
  },
  i: (msg: string) => console.info(`[Everglow] ${msg}`),
  w: (msg: string) => console.warn(`[Everglow] ${msg}`),
  e: (msg: string, error?: unknown) => console.error(`[Everglow] ${msg}`, error ?? ''),
};
