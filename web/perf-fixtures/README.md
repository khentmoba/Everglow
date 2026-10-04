# Synthetic benchmark posters

Four generated 720×1080 JPEGs: seeded texture, rings and labels only. No people,
private data, stock-photo license or network service is involved. The benchmark
requests these same-origin files through the production poster widget.

They are static files, not part of the Dart boot payload, and are requested only
by the compile-time-gated benchmark. Different content means old photo-based
benchmark numbers are not a comparable baseline.
