import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';

/// MangaKatana's server switch is a cookie (`s_r`), not just the `?sv=`
/// query — without it, Server 2/3 requests silently return Server 1's
/// page URLs, so switching servers in the reader did nothing.
void main() {
  test('maps each reader server to the cookie the site uses', () {
    expect(KatanaService.cookieForServer(''), '');
    expect(KatanaService.cookieForServer('?sv=mk'), 's_r=sv2');
    expect(KatanaService.cookieForServer('?sv=3'), 's_r=sv3');
    expect(KatanaService.cookieForServer('?sv=evil'), '');
  });
}
