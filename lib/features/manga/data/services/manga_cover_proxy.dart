import 'katana_service.dart';
import 'mangadex_service.dart';

/// Routes a manga cover URL to its correct image proxy.
///
/// Each cover host needs its own Cloud Function (host allow-lists
/// differ per proxy):
///   * MangaDex (`uploads.mangadex.org`, `*.mangadex.network`) ->
///     `proxyMangaImage`
///   * MangaKatana / MangaKakalot (`mangakatana.com`,
///     `*.mangakakalot.com`, `*.mkklcdnv6temp.com`, ...) ->
///     `proxyMangaKatana`
///   * Comick (`meo.comick.pictures`, sends `Access-Control-Allow-Origin: *`)
///     and any other host -> direct (no proxy needed)
///
/// Already-proxied URLs (any `proxyManga*` / `proxyScanlation`) are
/// returned as-is so we never double-wrap (double-wrapping 400s on
/// the server because `cloudfunctions.net` is not an allowed host).
///
/// Used by the dashboard Reading shelf and the manga details drawer
/// so old library entries with direct Katana URLs (saved before covers
/// were proxied at save time) still load on web, where the Katana CDN
/// sends no CORS headers and direct `Image.network` fails.
String proxyMangaCoverUrl(String url) {
  if (url.isEmpty) return url;
  if (url.contains('proxyManga') || url.contains('proxyScanlation')) {
    return url;
  }
  if (!url.startsWith('http')) return url;
  if (url.contains('mangadex.org') || url.contains('mangadex.network')) {
    return MangaDexService().proxiedImageUrl(url);
  }
  // Safe for non-Katana hosts: returns them unchanged.
  return KatanaService.proxyImageUrl(url);
}
