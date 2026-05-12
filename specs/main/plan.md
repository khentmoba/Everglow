# Implementation Plan: Vertical Relationship Timeline (Firebase Edition)

**Branch**: `main` | **Date**: 2026-04-21 | **Spec**: [spec.md](file:///C:/APPLICATIONS/Everglow/specs/main/spec.md)
**Input**: Updated feature specification including Firebase backend requirements.

## Summary
Implement a high-fidelity "Vertical Relationship Timeline" React component integrated with Firebase for full CRUD functionality, authentication, and image storage. The design preserves the "Modern Nostalgia" aesthetic while adding persistence and security.

## Technical Context

**Language/Version**: React (Vite-based preferably)
**Primary Dependencies**: 
- `firebase`: Database, Storage, and Auth SDK.
- `framer-motion`: Scroll-based fade-in animations and layout transitions.
- `lucide-react`: UI icons for hearts, filters, and editing.
- `tailwind-css`: Layout and "Modern Nostalgia" styling.
**Storage**: 
- **Firestore**: Memory documents and year grouping metadata.
- **Firebase Storage**: High-res polaroid images.
**Testing**: Manual verification across responsive breakpoints and interaction states.
**Constraints**: Firebase must be used as the single source of truth for all data.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Design: PREMIUM/Wowed (Check).
- Dynamic Interaction: YES (Auth flows + Realtime Firestore sync).
- Visual Excellence: YES (Polaroid styling + Framer Motion).

## Project Structure

### Documentation

```text
specs/main/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── spec.md
```

### Source Code

```text
src/
├── components/
│   ├── scrapbook/
│   │   ├── Timeline.jsx       # Groups by year, handles scroll logic
│   │   ├── TimelineCard.jsx   # Individual polaroid + expansion
│   │   ├── MemoryForm.jsx     # Add/Edit modal/drawer
│   │   └── FilterBar.jsx      # Year/Category chips
│   ├── auth/
│   │   └── Login.jsx          # Intimate minimalist login screen
│   └── ui/
│       └── Polaroid.jsx       # Reusable base styling
├── firebase/
│   └── config.js              # Initialization & Exports
├── hooks/
│   └── useMemories.js         # Realtime Firestore listener
└── App.jsx
```

## Verification Plan

### Automated Tests
- N/A

### Manual Verification
1.  **Auth Flow**: Sign in with a dummy username/password and verify redirect to timeline.
2.  **CRUD Flow**:
    - Add a new memory with an image upload; verify it appears in the correct "Year" section.
    - Edit an existing memory; verify changes persist on refresh.
    - Delete a memory; verify the timeline adjusts without gaps.
3.  **Animations**: Scroll through the timeline and verify cards animate smoothly `whileInView`.
4.  **Responsiveness**: Verify that the central vertical line and cards stack correctly on mobile.
