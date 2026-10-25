# Anime multi-server expansion

Added four high-reliability anime servers to Everglow's anime player:
- **TryEmbed** (`tryembed.us.cc`): Dedicated anime embed keyed by AniList (with MAL fallback) supporting Sub and Dub audio options. Unsandboxed with origin sent.
- **VidCore** (`vidcore.org`): Clean, fast EdgeOne CDN player keyed on TMDB ID, sandboxed.
- **Rive** (`rivestream.us`): 1080p ValhallaStream proxy player keyed on TMDB ID, sandboxed.
- **Fmov** (`fmov.my`): 16-upstream multi-server aggregator keyed on TMDB ID, sandboxed.

## Proof shots

- `anime-servers-phone.png` — Real release web build running at 430px mobile viewport in Agent Mode with the HUD collapsed, showing all seven servers (`Everglow`, `Megavid`, `CineSrc`, `TryEmbed`, `VidCore`, `Rive`, `Fmov`) and `SUB` / `DUB` audio toggle chips below the video player.
