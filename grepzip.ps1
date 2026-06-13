Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead("D:\khent\ttt-game\game.zip")
$v1 = $zip.GetEntry("v1.js").Open()
$reader = New-Object System.IO.StreamReader($v1)
$content = $reader.ReadToEnd()
$reader.Close()
$zip.Dispose()
Select-String -InputObject $content -Pattern "postMessage|parent\." -AllMatches | Select-Object -First 15
