# Quickstart: Date Randomizer

## Overview
The Date Randomizer is a gamified dashboard feature that picks a random date idea from a Firestore collection.

## Setup Steps

### 1. Assets Configuration
- Create `assets/data/date_ideas_seed.json` with an array of date ideas.
- Update `pubspec.yaml`:
  ```yaml
  flutter:
    assets:
      - assets/data/
  ```

### 2. Implementation Order
1. **Domain**: Create `DateIdea` class with `fromFirestore` and `toMap` methods.
2. **Data Source**: Implement `DateIdeaService` to:
   - Seed data if collection is empty.
   - Fetch all ideas into a `List<DateIdea>`.
   - Provide a `getRandomIdea()` method.
3. **Presentation**: 
   - Build `RandomizerCard` using `AnimationController` for the heart rotation.
   - Build `CelebrationDialog` with `showGeneralDialog` and `AnimateDo`.
4. **Integration**: Add `RandomizerCard` to the dashboard layout.

## Verification
- Run `flutter test` (add unit tests for random logic).
- Verify 1.5s animation timing.
- Check Firestore for seeded data.
