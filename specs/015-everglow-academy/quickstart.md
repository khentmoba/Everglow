# Quickstart: Everglow Academy

## Prerequisites
- Firebase Firestore emulator or project access.
- Seed data for `academy_questions` (Engineering and Tourism).

## Local Development & Testing

1. **Seeding Questions**:
   - Use the `AcademyService.seedQuestions()` helper (to be implemented) to populate Firestore.
2. **Launching the Hub**:
   - Navigate to the Dashboard and scroll to the bottom.
   - Tap the **Academy Portal** card.
3. **Testing Solo Mode**:
   - Select "Solo Study", pick a category, and complete 10 questions.
   - Verify `studyPoints` in your user document are updated.
4. **Testing 1v1 Challenge (Requires 2 Tabs)**:
   - Tab 1 (User: Khent): Start "1v1 Challenge", wait.
   - Tab 2 (User: Clair): Join "1v1 Challenge".
   - Play through the match. Verify real-time sync of questions and scores.
   - Complete match and verify Podium screen.

## Key Files
- `lib/features/academy/services/academy_service.dart`: Main logic hub.
- `lib/features/academy/screens/game_board_screen.dart`: The multiplayer heart.
