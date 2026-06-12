# Features Overview

## Gateway

The entry point with an animated door and passcode input.

- **Passcode `1111`** — Logs in as Clair
- **Passcode `2222`** — Logs in as Khent
- Door animation plays on successful entry
- Petal shower effect during transition

**Files:** `lib/features/entry/`

---

## Dashboard

The main hub after login. Displays:

- **Anniversary Counter** — Real-time counter since Feb 14, 2026 (years, months, days, hours, minutes, seconds)
- **XP Progress Bar** — Current level and XP
- **Feature Cards** — Access to all other features
- **Partner Status** — Shows partner's current mood
- **Creator Mode** — Admin tools (Khent only)

**Files:** `lib/features/dashboard/`

---

## Heartbeat

Daily mood tracking system.

- Submit your daily mood with an emoji and score (1-5)
- See your partner's latest mood via `PartnerStatusIndicator`
- Guardian cat prompts you if you haven't checked in today

**Firestore collection:** `moods`

**Files:** `lib/features/heartbeat/`

---

## Guardian

An animated cat mascot that lives on the dashboard.

- Displays random messages every 3-7 minutes
- Every 7th message mentions your partner's mood
- Prompts you to check in if you haven't submitted today
- Messages are seeded from `assets/data/guardian_messages_seed.json`

**Firestore collection:** `guardian_messages`

**Files:** `lib/features/guardian/`

---

## Academy

A trivia game with 8 categories and two modes.

### Categories
Engineering, Tourism, Music, General Knowledge, Cartoons, Celebrities, Film, Books

### Modes
- **Solo Study** — Practice trivia at your own pace
- **1v1 Challenge** — Real-time head-to-head with your partner

### How It Works
1. Questions are auto-seeded from local JSON files on first load
2. Additional questions fetched from OpenTDB API when supply is low
3. Matchmaking pairs both users for 1v1 games
4. Score tracking with XP rewards

**Firestore collections:** `academy_questions`, `active_matches`

**Files:** `lib/features/academy/`

---

## Cinema

A shared movie and TV watch list.

- Search movies/TV shows via TMDB API
- Add titles to your shared watch list
- Mark as "Want to Watch", "Watching", or "Watched"
- Poster images loaded from TMDB

**Firestore collection:** `watch_list`

**Files:** `lib/features/cinema/`

---

## Sanctuary

A private real-time chat for the couple.

- Messages sync instantly via Firestore
- Heart-themed UI with animated message bubbles
- Diagnostic tools and cache reset available

**Firestore collection:** `sanctuary_messages`

**Files:** `lib/features/chat/`

---

## Starlight Jar

A virtual jar for gratitude notes and memories.

- Drop "star" notes into the jar
- View random stars from the past
- Notes include author and timestamp

**Firestore collection:** `starlight_jar`

**Files:** `lib/features/starlight_jar/`

---

## Canvas

A collaborative drawing board.

- Draw with pen or eraser tools
- Real-time sync between both users
- Undo/redo support
- Stroke simplification for performance

**Firestore collections:** `canvas_strokes`, `live_canvas`

**Files:** `lib/features/canvas/`

---

## Daily Bloom

A virtual garden that grows with daily visits.

- Visit daily to grow your lily flower
- Bloom stages 0-5 based on total interactions
- Streak tracking for consecutive days

**Firestore collection:** `users/{uid}/garden_stats`

**Files:** `lib/features/daily_bloom/`

---

## Date Randomizer

A date idea generator with 1000+ ideas.

- Shake the card to get a random date idea
- Confetti celebration on reveal
- Ideas seeded from `assets/data/date_ideas_seed.json`

**Firestore collection:** `date_ideas`

**Files:** `lib/features/date_randomizer/`

---

## Jukebox

Live music status from Last.fm.

- Polls Last.fm every 30 seconds for both users
- Shows currently playing or recently played tracks
- Vinyl record animation
- "Listen Along" popup with Spotify link

**Files:** `lib/features/jukebox/`

---

## XP System

Gamification layer across the app.

- Earn XP through activities (mood check-ins, trivia, etc.)
- Level up every 1000 XP
- Streak tracking for consecutive days
- Sound effects on level up

**Firestore collection:** `users/{uid}/progress`

**Files:** `lib/features/xp/`
