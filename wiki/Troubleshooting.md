# Troubleshooting

## Common Issues

### Build Fails

**Error:** `flutter build web` fails

**Fix:**
```bash
flutter clean
flutter pub get
flutter build web --release
```

---

### Firebase Not Loading

**Error:** White screen or console errors about Firebase

**Fix:**
1. Check `firebase_options.dart` exists and has correct config
2. Ensure `everglow-1c6db-firebase-adminsdk-*.json` is in project root
3. Verify Firebase services are enabled in console

---

### Questions Not Seeding

**Error:** Academy shows no questions

**Fix:**
1. Check `assets/data/academy_questions_seed.json` exists
2. Verify `pubspec.yaml` includes the assets:
   ```yaml
   assets:
     - assets/data/
   ```
3. Check Firestore rules allow write to `academy_questions`

---

### Gateway Stuck Loading

**Error:** Gateway stays on "initialLoad" state

**Fix:**
1. Clear browser cache
2. Check Firestore is not in offline-only mode
3. Verify Firebase Auth is enabled

---

### Music Not Syncing

**Error:** Jukebox shows no music status

**Fix:**
1. Verify Last.fm usernames are correct in `JukeboxProvider`
2. Check Last.fm API is accessible
3. Ensure both users have scrobbled recently

---

### Canvas Not Syncing

**Error:** Drawings don't appear for partner

**Fix:**
1. Check Firestore rules for `canvas_strokes` and `live_canvas`
2. Verify both users are authenticated
3. Check browser console for Firestore errors

---

### Deploy Fails

**Error:** GitHub Actions workflow fails

**Fix:**
1. Check `FIREBASE_SERVICE_ACCOUNT_EVERGLOW_1C6DB` secret is set
2. Verify Flutter version compatibility
3. Check workflow logs for specific errors

---

### API Key Invalid

**Error:** TMDB returns 401

**Fix:**
1. Get a new key at [themoviedb.org](https://www.themoviedb.org/settings/api)
2. Update `lib/core/constants/api_keys.dart`
3. Rebuild the app

---

## Reset Procedures

### Reset User Progress
```dart
// Delete Firestore document
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('progress')
    .doc('main')
    .delete();
```

### Reset Garden
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('garden_stats')
    .doc('main')
    .delete();
```

### Reset All Data
```bash
# Using Firebase CLI
firebase firestore:delete --recursive academy_questions
firebase firestore:delete --recursive moods
# ... etc
```

### Clear Local Cache
```dart
// In Flutter
await FirebaseFirestore.instance.clearPersistence();

// Or clear SharedPreferences
final prefs = await SharedPreferences.getInstance();
await prefs.clear();
```

---

## Performance Tips

1. **Firestore Queries** — Always use `.limit()` when possible
2. **Image Uploads** — Compress before uploading
3. **Real-time Listeners** — Unsubscribe when screen is disposed
4. **Build Size** — Use `flutter build web --dart2js-optimization=O2` for smaller builds

---

## Getting Help

1. Check Firebase Console for errors
2. Open browser DevTools (F12) for console logs
3. Run `flutter doctor` to check environment
4. Check GitHub Actions logs for deploy issues
