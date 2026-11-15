import 'katana_service.dart';
import 'mangadex_service.dart';

String proxyMangaCoverUrl(String url) {
  if (url.isEmpty) return url;
  if (url.toLowerCase().contains('mangakatana')) {
    url = KatanaService.rewriteAvifToWebp(url);
  }
  if (url.contains('proxyManga') || url.contains('proxyScanlation')) {
    return url;
  }
  if (!url.startsWith('http')) return url;
  if (url.contains('mangadex.org') || url.contains('mangadex.network')) {
    return MangaDexService().proxiedImageUrl(url);
  }
  return KatanaService.proxyImageUrl(url);
}
