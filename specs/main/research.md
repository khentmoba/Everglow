# Research: Firebase Integration for Relationship Timeline

## Decision: Firebase Suite (Auth, Firestore, Storage)
**Rationale**: 
- User requested Firebase.
- Firestore handles real-time updates and simple querying by year/category.
- Firebase Auth supports Email/Password which can be adapted for Username/Password.
- Firebase Storage is ideal for high-fidelity polaroid images.

## Decision: Username/Password Login Pattern
**Rationale**:
Since Firebase Auth requires an email, we will implement a "Username to Email" mapping (e.g., `username@scrapbook.local`) or simply treat the input field as the email during registration. This ensures the "private intimate" feel without requiring a real email from the couple.

## Decision: Firestore Schema (Grouped by Year)
**Rationale**:
We will store memories as a collection. To efficiently "group by year" on the client, we have two options:
1.  **Client-side grouping**: Fetch all and group in React. (Good for small datasets).
2.  **Year-based subcollections**: (Overkill for a personal scrapbook).
*Conclusion*: Fetch and group client-side for now, but optimize with a `year` field for filtering.

## Decision: Image Uploads
**Rationale**: 
Using `firebase/storage` with `getDownloadURL`. We will store the URL in the Firestore document for each memory.

## Alternatives Considered
- **Supabase**: Rejected (User specifically asked for Firebase).
- **LocalStorage**: Rejected (User upgraded to Firebase for persistence and sync).

## Open Questions
- **Firebase Project Config**: I will need the Firebase config object once the user sets up the project. I'll provide a placeholder path for it.
