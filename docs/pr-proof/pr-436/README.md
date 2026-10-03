# Anime Watch Motchi Sidebar Proof

## Change

- In the anime section only, added a temporary Motchi AI chat sidebar that is available exclusively when watching an anime (`watchItem != null`).
- Sidebar is completely hidden when browsing anime (Home, Browse, Schedule, History, Search, My List).
- When watching an anime:
  - Top header (`AnimeXTopHeader`) shows a Motchi button with avatar for couple users.
  - Floating trigger button (`AnimeXMotchiFloatingTrigger`) is visible at bottom-right when the sidebar is closed.
  - Clicking either trigger slides open `AnimeXMotchiSidebar` with full anime context (title, episode number, lore, recommendations).
- Temporary & unsaved: does not write to Firestore `ai_conversations/assistant` or `motchi_sessions`.
- Preserves full agent capabilities: couple memories, tools, DeepThink reasoning toggle, and real-time streaming.
- Exiting the watch page cleanly resets and closes the chat.

## Proof screenshots

Captured with synthetic demo data:
- `shot-phone.png`: Phone layout (430x932) on the watch page with the temporary Motchi sidebar open, showing Motchi avatar, `TEMPORARY` badge, DeepThink toggle, anime suggestion chips, and composer.
- `shot-tablet.png`: Tablet layout (800x1024) showing the sidebar alongside the anime player.
- `shot-desktop.png`: Desktop layout (1280x800) showing the docked right-hand Motchi sidebar while watching.
- `shot-watching-trigger.png`: Floating trigger button on the watch page when Motchi sidebar is closed.

No private user or couple data was accessed or included.
