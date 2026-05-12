# Quickstart: Firebase Relationship Timeline

## Setup
1. Create a Firebase Project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Email/Password Authentication**.
3. Create a **Cloud Firestore** database.
4. Create a **Cloud Storage** bucket.
5. Install dependencies:
   ```bash
   npm install firebase framer-motion lucide-react
   ```
6. Create `src/firebase.js` with your project configuration.

## Implementation Details
- **Authentication**: Use `signInWithEmailAndPassword` and `createUserWithEmailAndPassword`.
- **Data Fetching**: Use `query(collection(db, "memories"), orderBy("date", "desc"))`.
- **Animations**: Use `LayoutGroup` from Framer Motion to handle timeline shifts when items are added/deleted.
