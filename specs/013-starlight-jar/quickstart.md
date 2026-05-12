# Quickstart: Starlight Jar

## Development Setup
1. Ensure Firebase is configured for the project.
2. The `starlight_jar` collection will be auto-created upon the first note submission.

## Testing the Feature
### 1. Dropping a Star
- Click the "Drop a Star" button on the dashboard.
- Enter a note.
- Verify the star falls from the top of the screen into the jar.
- Check Firestore to confirm the document is created with correct `author` and `timestamp`.

### 2. Reading a Note
- Tap the glass jar.
- Verify the shake animation (1s).
- Verify a star floats out and a dialog appears with a random note.
- Click "Close" and verify the star returns to the jar.

### 3. Verification of Constraints
- Add more than 100 notes (manually or via script) and verify only 100 stars are rendered.
- Verify the "Drop" button is disabled for empty input.
