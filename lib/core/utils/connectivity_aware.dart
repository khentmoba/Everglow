import 'connectivity_service.dart';
import 'logger.dart';

mixin ConnectivityAware {
  Future<T> withConnectivity<T>(
    Future<T> Function() operation, {
    required T fallback,
    String? context,
  }) async {
    if (!ConnectivityService.instance.isOnline) {
      Logger.w('${context ?? 'Request'} skipped: device is offline');
      return fallback;
    }
    try {
      return await operation();
    } catch (e) {
      Logger.e('${context ?? 'Request'} failed', error: e);
      return fallback;
    }
  }
}
