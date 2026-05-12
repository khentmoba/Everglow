# Quickstart: Academy OpenTDB Integration

## Developer Setup

1. **Install Dependencies**:
   Ensure your `pubspec.yaml` contains:
   ```yaml
   dependencies:
     html_unescape: ^2.0.0
     shared_preferences: ^2.2.0
     crypto: ^3.0.3
     http: ^1.1.0
   ```
   Run `flutter pub get`.

2. **TriviaApiService Usage**:
   ```dart
   final triviaService = TriviaApiService();
   await triviaService.initSession();
   
   // Trigger auto-fill logic
   if (needsMoreQuestions) {
     final newQuestions = await triviaService.fetchQuestions(categoryId: 18);
     await firestoreService.saveQuestions(newQuestions);
   }
   ```

3. **Firestore Security Rules**:
   Ensure `academy_questions` allows read access for authenticated users and write access for the background sync logic.

## Verification

### Manual Test
1. Open the Academy Hub.
2. Select 'Solo Study' for 'Engineering'.
3. Verify the "Downloading..." animation appears if questions are low.
4. Verify questions appear correctly without `&quot;` etc.

### Unit Test
- Mock the `http.Client` to test `TriviaApiService` response code handling (0, 4, 5).
- Test HTML decoding for a variety of entities.
- Test category mapping logic.
