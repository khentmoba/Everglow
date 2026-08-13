# Jellyfin Watch Party Tools

## jellyfin_movie_watcher.ps1

Moves finished video downloads from the browser Downloads folder into the
Jellyfin library folder, then asks Jellyfin to refresh the library.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\jellyfin_movie_watcher.ps1 `
  -ApiKey "your-jellyfin-api-key"
```

Leave it running while using the in-app Party Downloads screen. The API key
can be created in Jellyfin under Dashboard -> Advanced -> API Keys.
