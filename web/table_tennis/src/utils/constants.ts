import type { OGameData } from '../types/index.js';

// ---------------------------------------------------------------------------
// Engine constants (mirrors game.js globals)
// ---------------------------------------------------------------------------
export const CANVAS = {
  minSquare: 500,
  maxSquare: 700,
  radian: Math.PI / 180,
} as const;

export const PHYSICS = {
  gravity: 3800,          // Ball.heightInc += 3800*delta  game.js:1608
  spinPowUser: 2.5,       // pow(spin*2.5,3) game.js:1596
  spinPowEnemy: 2.0,      // pow(spin*2,3)   game.js:1598
  spinClampUser: 3,       // ±3
  spinClampEnemy: 2,      // ±2
  bounceDamp: -0.85,      // heightInc *= -.85 game.js:1626
  offTableThreshold: -200,// height <= -200 → score game.js:1643
  trailMax: 5,
  netBounceY: 0.5,
} as const;

export const TABLE = {
  segsMobile: 75,
  segsDesktop: 150,
  sideMultiplier: 100,
  heightFactor: 235, // (tablePosY² * 235) * (1+offY/2)
  widthFactor: 233,  // tablePosX * 233/2
} as const;

export const SCORING = {
  winScore: 11,
  winBy: 2,
  maxScore: 99,
} as const;

// ---------------------------------------------------------------------------
// User country pool (40)
// ---------------------------------------------------------------------------
export const USER_COUNTRIES = [
  'CA','CN','BR','KG','DE','FR','HK','KZ','IE','IT',
  'JP','NL','PL','PT','KR','ES','RU','TR','GB','US',
  'CZ','AR','UA','IN','MX','EG','ID','IQ','IR','CL',
  'DK','CO','TH','TW','AM','UZ','SK','BY','UY','IL',
] as const;

// 10 cups × 6 opponents (mirrors aEnemyCountries game.js:2852)
// ---------------------------------------------------------------------------
export const ENEMY_CUPS: readonly (readonly string[])[] = [
  ['IS','GL','HW','CU','CA','US'],
  ['VE','CK','WS','CO','GY','CR'],
  ['PE','AR','UY','BO','CL','BR'],
  ['DZ','LY','ET','ZW','KE','ZA'],
  ['FR','NO','PT','IT','DE','GB'],
  ['AT','CZ','PL','TR','HU','GR'],
  ['IR','BD','MG','IN','PK','AE'],
  ['PG','NZ','AU','PH','ID','MY'],
  ['LA','VN','HK','JP','KR','CN'],
  ['LV','EE','LT','FI','UZ','RU'],
] as const;

export const SPARE_ENEMY = 'CH' as const;

export const MAP_MARKER_POS: readonly (readonly [number, number])[] = [
  [-203,-115], [-150,-31], [-136,98], [20,57], [-36,-109],
  [50,-72], [101,-16], [170,82], [192,-51], [143,-121],
] as const;

export const INITIAL_GAME_DATA: Readonly<OGameData> = {
  cupId: 0, gameId: 0, userId: null, enemyId: null, userScore: 0, enemyScore: 0,
};

// localStorage key
export const SAVE_KEY = 'tabletennisv3' as const;

// Fallback IDs: aLevelStore = [1,0,0…1234,0] → 1234 means firstRun
export const FIRST_RUN_USER_ID = 1234 as const;

// ---------------------------------------------------------------------------
// Audio sprite (Howler) – mirrors init in loadAssets tail game.js:??? 
// ---------------------------------------------------------------------------
export const AUDIO = {
  musicSrc: ['audio/music.ogg','audio/music.m4a'] as const,
  soundSrc: ['audio/sound.ogg'] as const,
} as const;
