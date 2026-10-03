# Anime server naming proof

## Change

- In the anime section only, renamed the Mega Play provider to `Everglow` (`name: 'Everglow'`).
- Renamed the previous `Everglow` server (the TMDB-keyed `embed.html` shell around CineSrc) to its actual name `CineSrc` (`name: 'CineSrc'`).
- Kept Mega Play's streaming implementation intact (`megaplay.buzz` stream with AniList/MAL routes).
- Updated `normalizeServerName` so legacy `'Mega Play'` and `'MegaPlay'` saved choices normalize to `'Everglow'`.
- Updated player episode change listener to check for `CineSrc`.
- Cinema servers remain completely untouched.

## Proof screenshots

Captured with synthetic demo data:
- `shot-phone.png`: Phone layout showing the server selector with `Everglow` active by default, `Megavid`, `CineSrc`, and the SUB/DUB toggle.
- `shot-anime-servers.png`: Desktop/tablet layout showing `[ Everglow ] [ Megavid ] [ CineSrc ]` with `Everglow` highlighted.

No private user or couple data was accessed or included.
