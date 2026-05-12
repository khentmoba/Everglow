# Quickstart: Everglow Canvas

## Setup
1. Ensure Firebase is initialized in `main.dart`.
2. Verify the `canvas_strokes` collection exists in Firestore (it will be created automatically on the first save).

## Development Flow
1. **Model**: Define `DoodleStroke` model in `lib/features/canvas/models/doodle_stroke.dart`.
2. **Service**: Implement `CanvasService` in `lib/features/canvas/services/canvas_service.dart` with Firestore streaming and saving.
3. **UI**: Build `CanvasScreen` in `lib/features/canvas/screens/canvas_screen.dart`.
4. **Drawing Logic**: 
   - Use `GestureDetector` to capture `onPanUpdate`.
   - Update a local `List<Offset>` for the active stroke.
   - On `onPanEnd`, normalize points and save to Firestore via `CanvasService`.
5. **Rendering**:
   - Create `CanvasPainter` (extending `CustomPainter`).
   - Draw all strokes from the stream + the local active stroke.

## Navigation
Add a button to `DashboardScreen` (using `Icons.brush`) that navigates to `/canvas`.
Use `Navigator.push` with a `PageRouteBuilder` for a smooth scale/fade transition.
