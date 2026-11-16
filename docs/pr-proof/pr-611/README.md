# Cinema playback failover proof (PR #611)

`shot-player.png` shows the local release web build (`dart tool/build_web.dart -- --release --no-source-maps`) served on loopback at 430x932 phone width in Agent Mode (`?agent=1`), opening `/cinema/video/279246?type=tv&s=1&e=1&title=The%20Remarried%20Empress&agent=1` after failing over from Celestia to Everglow with the player ready.
