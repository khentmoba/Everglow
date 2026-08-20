import type { AtlasFrame } from '../types/index.js';
/** Typed port of Utils.CountryFlags game.js:2310 */
export declare class CountryFlags {
    aAllCountryCodes: Record<number, string>;
    aIds: number[];
    private atlasW;
    constructor(countries: readonly string[], randomise?: boolean);
    getBData(id: number): AtlasFrame & {
        bX: number;
        bY: number;
        bWidth: number;
        bHeight: number;
    };
    getIdFromISO(iso: string): number;
}
//# sourceMappingURL=country_flags.d.ts.map