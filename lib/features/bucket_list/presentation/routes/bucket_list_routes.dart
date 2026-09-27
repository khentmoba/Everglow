import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/bucket_list_screen.dart' deferred as bucket_lib;

/// Routes owned by the bucket list feature.
final List<GoRoute> bucketListRoutes = [
  GoRoute(
    path: '/bucket-list',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Bucket List',
      loadLibrary: bucket_lib.loadLibrary,
      builder: () => bucket_lib.BucketListScreen(),
    ),
  ),
];
