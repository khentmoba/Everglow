// Typed bundle — fully reverse engineered Table Tennis World Tour
// Source: web/table_tennis/src/* (TS 5.3, ES2020, strict)
// Build: npx tsc --project src/tsconfig.json && esbuild src/index.ts --bundle --format=iife --outfile=assets/js/dist/bundle.js
// Runtime: single classic script — no legacy fallback required.
export * from '../src/types/index.js';
export * from '../src/utils/constants.js';
export declare class Game {
  constructor(canvasId?: string);
  extGameLoad(): void;
  resizeCanvas(): void;
  readonly oGameData: import('../src/types/index.js').OGameData;
  readonly canvas: HTMLCanvasElement;
}
export declare const TTMultiplayer: import('../src/mp_bridge.js').TTMultiplayerAPI;
