# Data Model: Living Archive Timeline

**Feature**: 004-living-archive-timeline  
**Date**: 2026-05-08  
**Status**: Final

## Entity: Milestone

Represents a single relationship memory or life event stored in the Living Archive.

### Firestore Collection

```
Collection: milestones
Path:        milestones/{milestoneId}
Ordering:    date ASC (chronological, oldest first)
Access:      Private — Firebase Auth required (existing app-wide gate)
```

### Document Schema

| Field      | Firestore Type | Dart Type  | Required | Description |
|------------|---------------|------------|----------|-------------|
| `id`       | Document ID    | `String`   | ✅        | Auto-generated Firestore document ID |
| `title`    | `String`       | `String`   | ✅        | Short name of the milestone (e.g., "First Date") |
| `description` | `String`    | `String`   | ✅        | Full text description of the memory |
| `date`     | `Timestamp`    | `DateTime` | ✅        | Date the milestone occurred; used for chronological ordering |
| `imageUrl` | `String`       | `String?`  | ❌        | Absolute URL to an image (Firebase Storage URL or external). Absent/null means text-only card. |

### Dart Class

```dart
// lib/features/dashboard/domain/models/milestone.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Milestone {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String? imageUrl;

  const Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.imageUrl,
  });

  factory Milestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Milestone(
      id:          doc.id,
      title:       data['title']       as String,
      description: data['description'] as String,
      date:        (data['date'] as Timestamp).toDate(),
      imageUrl:    data['imageUrl']    as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title':       title,
      'description': description,
      'date':        Timestamp.fromDate(date),
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}
```

### Validation Rules

- `title`: non-empty string, max 80 characters (enforced at write time, not at read time for resilience).
- `description`: non-empty string (no hard length limit for display — cards expand gracefully).
- `date`: must be a valid Firestore `Timestamp`; absent `date` field causes the `fromFirestore` factory to throw — treated as a corrupt document and excluded from the stream via stream-level error handling.
- `imageUrl`: optional; if present, expected to be a valid HTTPS URL pointing to Firebase Storage or another accessible host. Invalid URLs are caught by `Image.network`'s `errorBuilder` at render time.

### Example Firestore Document

```json
{
  "title": "First Date",
  "description": "We went to that little café by the river. It rained the whole time but we didn't care at all.",
  "date": "Timestamp(2026-02-14T18:30:00Z)",
  "imageUrl": "https://firebasestorage.googleapis.com/v0/b/everglow.appspot.com/o/milestones%2Ffirst_date.jpg?alt=media"
}
```

```json
{
  "title": "Moved In Together",
  "description": "Boxes everywhere, takeaway pizza, and the happiest chaos.",
  "date": "Timestamp(2026-04-01T09:00:00Z)"
}
```
*(No `imageUrl` field → text-only card)*

## Service Contract

```dart
// lib/features/dashboard/data/services/milestone_service.dart

class MilestoneService {
  Stream<List<Milestone>> get milestones { ... }
}
```

| Method / Getter | Return Type | Behaviour |
|-----------------|------------|-----------|
| `milestones` | `Stream<List<Milestone>>` | Persistent real-time listener on `milestones` collection, ordered by `date` ASC. Emits on every Firestore change. |

## Display Contract (UI Layer)

| Data Point | Source Field | Rendered As |
|------------|-------------|-------------|
| Title | `title` | Bold text, `Quicksand` font, `Colors.pink[900]` |
| Date | `date` (formatted) | `DateFormat('d MMMM yyyy')` → `14 February 2024`, `Colors.pink[400]`, smaller weight |
| Description | `description` | Regular text, `Colors.pink[800]`, wraps naturally |
| Image | `imageUrl` (if non-null) | `ClipRRect` with top-only border radius 32, `Image.network` with error fallback |

## Seed Data (for development/testing)

```dart
// Can be called once from a dev utility or Firestore console import
final samples = [
  {
    'title': 'First Message',
    'description': 'The very first "hello" that started everything.',
    'date': Timestamp.fromDate(DateTime(2025, 12, 1)),
  },
  {
    'title': 'First Date',
    'description': 'Coffee that turned into a five-hour walk.',
    'date': Timestamp.fromDate(DateTime(2026, 2, 14)),
    'imageUrl': null, // omit field for text-only
  },
  {
    'title': 'First Trip Together',
    'description': 'Got lost three times. Best three times ever.',
    'date': Timestamp.fromDate(DateTime(2026, 3, 20)),
  },
];
```
