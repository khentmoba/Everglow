# API Reference

## External Services

### TMDB (The Movie Database)

Used for movie/TV search in the Cinema feature.

**Base URL:** `https://api.themoviedb.org/3`

**Endpoints:**
- `GET /search/movie?query={query}` — Search movies
- `GET /search/tv?query={query}` — Search TV shows
- `GET /movie/{id}` — Get movie details
- `GET /tv/{id}` — Get TV show details

**Auth:** API key in `lib/core/constants/api_keys.dart`

**Documentation:** [developers.themoviedb.org](https://developers.themoviedb.org/3/getting-started)

---

### OpenTDB (Open Trivia Database)

Used for trivia questions in the Academy feature.

**Base URL:** `https://opentdb.com/api.php`

**Endpoints:**
- `GET /api.php?amount={n}&category={id}&type=multiple` — Get trivia questions

**Category Mapping:**

| Category | OpenTDB ID |
|----------|------------|
| General Knowledge | 9 |
| Books | 10 |
| Film | 11 |
| Music | 12 |
| Cartoons | 32 |
| Tourism | 22 |
| Engineering | 18 |
| Celebrities | 26 |

**Session Tokens:** Managed via `SharedPreferences` to prevent duplicate questions.

**Rate Limit:** 1 request per 5 seconds per session.

**Documentation:** [opentdb.com/api_doc.php](https://opentdb.com/api_doc.php)

---

### Last.fm

Used for music status in the Jukebox feature.

**Base URL:** `https://ws.audioscrobbler.com/2.0/`

**Endpoints:**
- `GET /?method=user.getrecenttracks&user={user}&api_key={key}&format=json` — Get recent tracks

**Polling:** Every 30 seconds for both users.

**Documentation:** [www.last.fm/api](https://www.last.fm/api)

---

## Firebase Services

### Firestore Collections

#### `moods`
```json
{
  "username": "khentsgdz",
  "moodScore": 4,
  "moodEmoji": "😊",
  "timestamp": "2026-06-12T10:00:00Z"
}
```

#### `sanctuary_messages`
```json
{
  "sender": "Khent",
  "senderUid": "abc123",
  "text": "Hello!",
  "timestamp": "2026-06-12T10:00:00Z"
}
```

#### `academy_questions`
```json
{
  "id": "abc123",
  "questionText": "What is 2+2?",
  "options": ["3", "4", "5", "6"],
  "correctOptionIndex": 1,
  "category": "general",
  "createdAt": "2026-06-12T10:00:00Z",
  "source": "local_seed"
}
```

#### `active_matches`
```json
{
  "hostId": "abc123",
  "participantId": "def456",
  "hostScore": 3,
  "participantScore": 2,
  "status": "in_progress",
  "currentQuestionId": "q789",
  "questionIndex": 5,
  "category": "general"
}
```

#### `starlight_jar`
```json
{
  "content": "I'm grateful for you",
  "author": "Khent",
  "timestamp": "2026-06-12T10:00:00Z"
}
```

#### `watch_list`
```json
{
  "tmdbId": 550,
  "title": "Fight Club",
  "mediaType": "movie",
  "posterPath": "/pB8BM7pdSp6B6Ih7QI4S2t0POoT.jpg",
  "status": "want_to_watch",
  "addedAt": "2026-06-12T10:00:00Z"
}
```

#### `users/{uid}/progress`
```json
{
  "uid": "abc123",
  "xpTotal": 5200,
  "level": 6,
  "streak": 14,
  "lastActivity": "2026-06-12T10:00:00Z"
}
```

#### `users/{uid}/garden_stats`
```json
{
  "currentStage": 3,
  "lastVisit": "2026-06-12T10:00:00Z",
  "streakCount": 7,
  "totalInteractions": 42
}
```

---

## Service Accounts

### Auth Service

```dart
// Login with passcode
await authService.loginWithPasscode('khentsgdz');

// Current user
final user = authService.currentUser;

// Sign out
await authService.signOut();
```

### XP Service

```dart
// Add XP
await xpService.addXp(amount: 50);

// Get progress
final progress = await xpService.getProgress();

// Check level up
final leveledUp = await xpService.checkLevelUp();
```

### Academy Service

```dart
// Seed questions from local JSON
await academyService.seedQuestions();

// Start matchmaking
final match = await academyService.startMatchmaking(category: 'general');

// Submit answer
await academyService.submitAnswer(matchId: 'abc', answerIndex: 2);
```

### Chat Service

```dart
// Send message
await chatService.sendMessage(text: 'Hello!');

// Listen to messages
chatService.getMessages().listen((messages) {
  // Update UI
});
```
