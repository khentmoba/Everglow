# Quickstart: Everglow Jukebox

## Environment Setup

Create or update your `.env` file in the project root with the following:

```env
LASTFM_API_KEY=your_api_key_here
LASTFM_USER_KHENT=your_khent_username
LASTFM_USER_CLAIR=your_clair_username
```

## Dependencies

Run the following to add necessary packages:

```bash
flutter pub add http marquee confetti url_launcher flutter_dotenv
```

## Running the Feature

1. Ensure the `DashboardScreen` includes the `JukeboxWidget`.
2. Start the application:
   ```bash
   flutter run
   ```
3. The Jukebox should appear in the dashboard scroll view and start polling every 30 seconds.
