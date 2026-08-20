/** Table Tennis World Tour — typed domain model
 *  Decompiled from web/table_tennis/assets/js/game.js (5300 lines, Famobi 1.0.2)
 *  All numeric ranges verified against original runtime.
 */
export type CanvasCtx = CanvasRenderingContext2D;
export interface Rect {
    x: number;
    y: number;
    w: number;
    h: number;
}
export interface AtlasFrame {
    x: number;
    y: number;
    width: number;
    height: number;
}
export type AtlasMap = Record<string, AtlasFrame>;
export interface SpriteAnims {
    [name: string]: number[];
}
export interface AssetData {
    img: HTMLImageElement | HTMLCanvasElement;
    loaded?: boolean;
    oData: {
        spriteWidth: number;
        spriteHeight: number;
        oAtlasData: AtlasMap;
        oAnims?: SpriteAnims;
    };
}
export interface FileSpec {
    id: string;
    file: string;
    oAtlasData?: AtlasMap;
    oAnims?: SpriteAnims;
}
export type GameState = 'loading' | 'splash' | 'start' | 'chooseCountry' | 'map' | 'gameIntro' | 'game' | 'pause' | 'gameComplete' | 'credits' | 'load';
export interface OGameData {
    cupId: number;
    gameId: number;
    userId: number | null;
    enemyId: number | null;
    userScore: number;
    enemyScore: number;
}
export type ControlState = 0 | 1;
/** Normalised table coords: X ∈ [-1,1], Y ∈ [0,1] (0=enemy baseline, 1=user) */
export interface TablePos {
    x: number;
    y: number;
}
export interface HitData {
    x: number;
    y: number;
    speed: number;
    spin: number;
}
export interface BallTrailPoint {
    x: number;
    y: number;
    height: number;
    scale: number;
}
export type HitAreaType = 'image' | 'rect';
export interface HitAreaImageOpts {
    oImgData: AssetData;
    aPos: [number, number];
    align?: [number, number];
    id: string;
    scale?: number;
    noMove?: boolean;
}
export interface HitAreaRectOpts {
    aRect: [number, number, number, number];
    align?: [number, number];
}
export type HitAreaOpts = HitAreaImageOpts | HitAreaRectOpts;
export interface HitData2D {
    x: number;
    y: number;
    isDown: boolean;
    isBeingDragged: boolean;
    isDraggable?: boolean;
    multiTouch?: boolean;
    hasLeft?: boolean;
}
export type HitCallback = (id: string, data: HitData2D) => void;
export type KeyCallback = (id: string, data: {
    isDown: boolean;
}) => void;
export interface OImageIds {
    table0: string;
    net: string;
    ball: string;
    ballShadow: string;
    userBatCentre: string;
    batShadow: string;
    ballTrail0: string;
    ballTrail1: string;
    ballTrail2: string;
    ballTrail3: string;
    ballTrail4: string;
    enemyBat0: string;
    enemyBat1: string;
    enemyBat2: string;
    enemyBat3: string;
    enemyBat4: string;
    enemyBat5: string;
    enemyBat6: string;
    userBatEdge: string;
    tableClip: string;
    tableEdge: string;
    tableBg0: string;
    tableBg1: string;
    tableBg2: string;
    tableBg3: string;
    tableBg4: string;
    tableBgBottom: string;
    scoreCard: string;
    table1: string;
    table2: string;
    table3: string;
    tableLegs: string;
    finger: string;
    bounceMark: string;
    playBut: string;
    infoBut: string;
    muteBut0: string;
    muteBut1: string;
    backBut: string;
    cupsBut: string;
    restartBut: string;
    moreGamesBut: string;
    pauseBut: string;
    resetBut: string;
    changeCountryBut: string;
    control0OnBut: string;
    control1OnBut: string;
    quitBut: string;
    control0OffBut: string;
    control1OffBut: string;
    tickBut: string;
    moreBut: string;
    titleLogo: string;
    titleBats: string;
    titleFadeBar: string;
    countryBut: string;
    vsText: string;
    flare: string;
    winIcon: string;
    loseIcon: string;
    globeLogo: string;
    cup0: string;
    cup1: string;
    cup2: string;
    cup3: string;
    titleBall: string;
    map: string;
    mapMarker0: string;
    mapMarker1: string;
    mapMarker2: string;
    tutScreen: string;
    [k: string]: string;
}
export type SoundId = 'hit0' | 'hit1' | 'hit2' | 'hit3' | 'hit4' | 'hit5' | 'bounce0' | 'bounce1' | 'bounce2' | 'bounce3' | 'bounce4' | 'bounce5' | 'userPoint' | 'enemyPoint' | 'winGame' | 'loseGame' | 'cheer0' | 'cheer1' | 'cheer2' | 'cheer3' | 'gameStart' | 'firework' | 'hitNet' | 'silence';
export interface TTLocalPaddleMsg {
    type: 'LOCAL_PADDLE';
    y: number;
}
export interface TTLocalBallMsg {
    type: 'LOCAL_BALL';
    x: number;
    y: number;
    vx: number;
    vy: number;
}
export interface TTLocalScoreMsg {
    type: 'LOCAL_SCORE';
    hostScore: number;
    guestScore: number;
}
export type TTLocalMsg = TTLocalPaddleMsg | TTLocalBallMsg | TTLocalScoreMsg;
export interface TTRemotePaddleMsg {
    type: 'REMOTE_PADDLE';
    y: number;
}
export interface TTRemoteBallMsg {
    type: 'REMOTE_BALL';
    x: number;
    y: number;
    vx: number;
    vy: number;
}
export interface TTRemoteScoreMsg {
    type: 'REMOTE_SCORE';
    hostScore: number;
    guestScore: number;
}
export interface TTStartMpMsg {
    type: 'START_MP';
    isHost: boolean;
    side: 'near' | 'far';
}
export type TTRemoteMsg = TTRemotePaddleMsg | TTRemoteBallMsg | TTRemoteScoreMsg | TTStartMpMsg;
export interface BallStateDTO {
    x: number;
    y: number;
    vx: number;
    vy: number;
}
//# sourceMappingURL=index.d.ts.map