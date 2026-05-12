# Data Model: Firebase Scrapbook

## Firestore Collection: `memories`

| Field | Type | Description |
|-------|------|-------------|
| id | string | Firestore Auto-ID |
| date | timestamp | Exact date/time of the memory |
| year | number | Redundant field for fast grouping/filtering |
| month | number | For chronological sorting within years |
| title | string | Headline |
| story | string | Full memory text |
| imageUrl | string | Firebase Storage download URL |
| category | string | "Travel", "Anniversary", "General" |
| ownerId | string | Firebase Auth UID for basic privacy rules |

## Firebase Storage: `memory_images/`
- Path: `memory_images/{userId}/{id}.jpg`

## Security Rules (Draft)
```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /memories/{memoryId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.ownerId;
    }
  }
}
```
