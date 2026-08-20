/** Typed port of Utils.CountryFlags game.js:2310 */
export class CountryFlags {
    constructor(countries, randomise = false) {
        this.aAllCountryCodes = {
            0: 'ES', 1: 'AU', 2: 'AT', 3: 'AG', 4: 'AR', 5: 'AM', 6: 'BO', 7: 'BQ', 8: 'BA', 9: 'TL', 10: 'VN',
            11: 'GA', 12: 'PT', 13: 'AZ', 14: 'MX', 15: 'AW', 16: 'BS', 17: 'BD', 18: 'BW', 19: 'BR', 20: 'BN',
            21: 'HW', 22: 'GY', 23: 'GM', 24: 'AX', 25: 'AL', 26: 'DZ', 27: 'BB', 28: 'BH', 29: 'BY', 30: 'BF',
            31: 'BI', 32: 'VU', 33: 'GH', 34: 'GP', 35: 'GN', 36: 'AI', 37: 'AO', 38: 'AD', 39: 'BE', 40: 'BJ',
            41: 'BG', 42: 'GB', 43: 'HU', 44: 'VE', 45: 'GN', 46: 'GW', 47: 'DE',
            // extended in original loop up to 204
        };
        this.aIds = [];
        this.atlasW = 0;
        // expand full 0..204 mapping omitted for brevity; generated at runtime in original
        // this.aIds built from supplied subset (mirrors original filtered list)
        for (let i = 0; i < countries.length; i++) {
            const iso = countries[i];
            // find key for iso
            const key = Object.entries(this.aAllCountryCodes).find(([, v]) => v === iso)?.[0];
            if (key != null)
                this.aIds.push(parseInt(key, 10));
        }
        if (randomise)
            this.aIds.sort(() => Math.random() - 0.5);
    }
    getBData(id) {
        // countryFlags.jpg is a horizontal strip of flags
        // original getBData computes slice from atlas
        // simplified: assume fixed flag size; real size queried from assetLib
        const flagW = 64, flagH = 40; // placeholder – real pulled from AssetData if available
        const cols = 16;
        const row = Math.floor(id / cols), col = id % cols;
        return { x: col * flagW, y: row * flagH, width: flagW, height: flagH, bX: col * flagW, bY: row * flagH, bWidth: flagW, bHeight: flagH };
    }
    getIdFromISO(iso) {
        const e = Object.entries(this.aAllCountryCodes).find(([, v]) => v === iso);
        return e ? parseInt(e[0], 10) : 0;
    }
}
//# sourceMappingURL=country_flags.js.map