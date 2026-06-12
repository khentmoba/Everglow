# Getting Started

## Prerequisites

- **Flutter SDK** ^3.11.3 ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Git**
- A modern web browser (Chrome recommended)

## Installation

```bash
# Clone the repository
git clone https://github.com/khentmoba/Everglow.git
cd Everglow

# Install dependencies
flutter pub get

# Run in Chrome
flutter run -d chrome
```

## First Run

1. The app opens at the **Gateway** — an animated door with a passcode input
2. Enter `1111` for Clair's account or `2222` for Khent's account
3. The door animates open and you're taken to the **Dashboard**

## Firebase Setup

If you're setting up from scratch:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable these services:
   - **Authentication** (Email/Password)
   - **Cloud Firestore**
   - **Firebase Storage**
   - **Firebase Hosting**
3. Download the admin SDK JSON and place it in the project root:
   ```
   everglow-1c6db-firebase-adminsdk-*.json
   ```
4. The `firebase_options.dart` is auto-generated. To regenerate:
   ```bash
   flutterfire configure
   ```

## Environment Variables

The TMDB API key is in `lib/core/constants/api_keys.dart`. Get your free key at [themoviedb.org](https://www.themoviedb.org/settings/api).

## Running Locally

```bash
# Standard run
flutter run -d chrome

# With hot reload (default)
flutter run -d chrome --hot

# Build for production
flutter build web --release
```

## Running with Firebase Emulators

```bash
# Start emulators
firebase emulators:start

# In another terminal
flutter run -d chrome
```

The emulators run on:
- Auth: port 9099
- Firestore: port 8080
- Storage: port 9199
- Hosting: port 5000
