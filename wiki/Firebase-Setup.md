# Firebase Setup

## Project Configuration

- **Project ID:** `everglow-1c6db`
- **Region:** Default Firebase location

## Required Services

### 1. Authentication

Enable **Email/Password** sign-in method.

The app uses anonymous auth as a fallback and email/password for the main accounts:
- `khentsgdz` (Khent)
- `clairjassen` (Clair)

### 2. Cloud Firestore

Create a Firestore database in production mode.

**Required collections:**

| Collection | Security Rules |
|------------|----------------|
| `milestones` | Auth read/write |
| `notes` | Auth read/write |
| `moods` | Auth read/write |
| `sanctuary_messages` | Auth read/write |
| `starlight_jar` | Auth read/write |
| `canvas_strokes` | Auth read/write |
| `live_canvas` | Auth read/write |
| `date_ideas` | Auth read, write for seeding |
| `guardian_messages` | Auth read, write for seeding |
| `academy_questions` | Auth read, write for seeding |
| `active_matches` | Auth read/write |
| `watch_list` | Auth read/write |
| `users/{uid}/progress` | Auth read/write |
| `users/{uid}/garden_stats` | Auth read/write |

### 3. Firebase Storage

Create a Storage bucket.

**Storage paths:**
- `memories/{userId}/` — User memory images
- `milestones/` — Milestone photos (public read)

### 4. Firebase Hosting

Enable Hosting for the `build/web` directory.

**Configuration** (in `firebase.json`):
```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      { "source": "/version.json", "headers": [{"key": "Cache-Control", "value": "no-cache"}] },
      { "source": "/sw.js", "headers": [{"key": "Cache-Control", "value": "no-cache"}] },
      { "source": "/index.html", "headers": [{"key": "Cache-Control", "value": "no-cache"}] }
    ]
  }
}
```

## Admin SDK

Download the admin SDK JSON from:
**Firebase Console → Project Settings → Service Accounts → Generate New Private Key**

Place it in the project root:
```
everglow-1c6db-firebase-adminsdk-*.json
```

**Note:** This file is gitignored for security. Copy it manually to new machines.

## Emulator Ports

| Service | Port |
|---------|------|
| Auth | 9099 |
| Functions | 5001 |
| Firestore | 8080 |
| Database | 9000 |
| Hosting | 5000 |
| Storage | 9199 |
| Pubsub | 8085 |
| Eventarc | 9299 |
| Data Connect | 9399 |
| Tasks | 9499 |

## Firestore Initialization

In `main.dart`, Firestore is initialized with unlimited cache:

```dart
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Security Rules

### Storage Rules (`storage.rules`)
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /memories/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    match /milestones/{allPaths=**} {
      allow read, write: if true;
    }
  }
}
```

## Deployment

```bash
# Build Flutter web
flutter build web --release

# Deploy everything
firebase deploy

# Deploy only hosting
firebase deploy --only hosting

# Deploy with message
firebase deploy -m "Deploy new feature"
```
