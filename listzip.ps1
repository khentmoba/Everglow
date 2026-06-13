Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead("D:\khent\ttt-game\game.zip")
foreach ($entry in $zip.Entries) {
    Write-Output ("{0} - {1} bytes" -f $entry.Name, $entry.Length)
}
$zip.Dispose()
