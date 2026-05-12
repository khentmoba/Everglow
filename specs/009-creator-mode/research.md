# Research: Creator Mode

**Feature**: Creator Mode Admin Panel | **Date**: 2026-05-11

## Decision: Image Picker & Storage
- **Decision**: Use the `image_picker` package for picking images and `firebase_storage` for uploads.
- **Rationale**: Standard Flutter approach for web/mobile. `image_picker` supports `XFile` which works across platforms.
- **Alternatives considered**: 
    - `file_picker`: More powerful but overkill for simple image picking.
    - Direct URL input: Rejected by user in favor of Picker.

## Decision: TabBar for Mode Switching
- **Decision**: Use a custom-styled `TabBar` with a `TabController` for switching between "Add Memory" and "Drop a Letter".
- **Rationale**: Flutter's native `TabBar` is highly customizable. I can style the indicator and labels to match the pink "Everglow" theme (soft rounded indicator, bouncy animations).
- **Alternatives considered**:
    - `cupertino_segmented_control`: Looks too "iOS default", doesn't fit the "bespoke" constitution.

## Decision: Scrollable Modal UX
- **Decision**: Wrap the form in a `SingleChildScrollView` and use `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))` to handle keyboard overlap.
- **Rationale**: Standard practice to ensure the "Submit" button remains visible and clickable when the keyboard is active.
- **Alternatives considered**: 
    - `isScrollControlled: true` in `showModalBottomSheet`: Required to allow the modal to take up more height and scroll properly.

## Decision: Firestore Model Integration
- **Decision**: Use existing `Milestone` and `HiddenNote` models. Add a `CreatorService` or extend `MilestoneService`/`LetterboxService` to handle `add` operations.
- **Rationale**: DRY principle. Models already exist and are being used for streaming data.
