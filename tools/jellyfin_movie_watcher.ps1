param(
  [string]$LibraryPath = "$env:USERPROFILE\Videos\Movies",
  [string]$WatchPath = "$env:USERPROFILE\Downloads",
  [string]$JellyfinUrl = "http://localhost:8096",
  [string]$ApiKey = ""
)

$videoExtensions = @('.mp4', '.mkv', '.webm', '.m4v', '.avi', '.mov', '.ogv')

if (-not (Test-Path -LiteralPath $LibraryPath)) {
  New-Item -ItemType Directory -Path $LibraryPath -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $WatchPath)) {
  Write-Host "Watch path missing: $WatchPath"
  exit 1
}

function Move-DownloadedMovie([string]$File, [string]$Target) {
  try {
    Move-Item -LiteralPath $File -Destination $Target -Force -ErrorAction Stop
    Write-Host "Moved $([System.IO.Path]::GetFileName($File)) -> $Target"
    if ($ApiKey) {
      Invoke-RestMethod -Method Post -Uri "$JellyfinUrl/Library/Refresh?api_key=$ApiKey" | Out-Null
      Write-Host "Requested Jellyfin library refresh."
    }
    return $true
  } catch {
    Write-Host "Could not move $File yet: $($_.Exception.Message)"
    return $false
  }
}

Write-Host "Watching $WatchPath for finished movie downloads..."
Write-Host "Library: $LibraryPath"
Write-Host "Jellyfin: $JellyfinUrl"

while ($true) {
  try {
    $files = Get-ChildItem -LiteralPath $WatchPath -File -ErrorAction Stop |
      Where-Object { $videoExtensions -contains $_.Extension.ToLower() }

    foreach ($file in $files) {
      if ($file.LastWriteTime -gt (Get-Date).AddSeconds(-10)) {
        continue
      }

      $target = Join-Path $LibraryPath $file.Name
      if (-not (Test-Path -LiteralPath $target)) {
        Move-DownloadedMovie $file.FullName $target | Out-Null
      } elseif ($file.Length -eq (Get-Item -LiteralPath $target).Length) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
      }
    }
  } catch {
    Write-Host "Watcher pass failed: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 5
}
