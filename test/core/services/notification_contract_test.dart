import 'package:everglow/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM trigger types map to app routes', () {
    const routes = {
      'chat_message': '/sanctuary',
      'mood_update': '/dashboard',
      'starlight_drop': '/starlight',
      'watchlist_update': '/cinema',
      'gallery_photo': '/gallery',
      'watch_party_invite': '/dashboard',
      'milestone': '/dashboard',
    };

    routes.forEach((type, route) {
      expect(routeFromNotification({'type': type}), route);
    });
  });
}
