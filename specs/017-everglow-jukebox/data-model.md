# Data Model: Everglow Jukebox

## Entities

### MusicStatus
Represents the current or last heard track for a user.

| Field | Type | Description |
| :--- | :--- | :--- |
| `username` | String | Last.fm username |
| `trackName` | String | Title of the track |
| `artistName` | String | Name of the artist |
| `albumName` | String | Name of the album |
| `imageUrl` | String? | URL to the album artwork |
| `isPlaying` | bool | Whether the track is currently playing (`nowplaying` attribute) |
| `spotifyUrl` | String | Constructed search URL for Spotify |
| `timestamp` | DateTime? | When the track was played (if not live) |

## Relationships
- `JukeboxWidget` listens to a stream of `Map<String, MusicStatus>` (keyed by username).
