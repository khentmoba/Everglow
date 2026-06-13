Add-Type -AssemblyName System.IO.Compression.FileSystem
$content = [System.IO.File]::ReadAllText("D:\khent\ttt-game\index.html")
$marker = "data:application/x-zip-compressed;base64,"
$idx = $content.IndexOf($marker)
$start = $idx + $marker.Length
# Find the end (next double quote)
$end = $content.IndexOf('"', $start)
$b64 = $content.Substring($start, $end - $start)
Write-Host "Base64 length: $($b64.Length)"
$bytes = [Convert]::FromBase64String($b64)
Write-Host "Zip size: $($bytes.Length) bytes"
[IO.File]::WriteAllBytes("D:\khent\ttt-game\game.zip", $bytes)
Write-Host "Saved to game.zip"
