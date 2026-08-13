import 'package:go_router/go_router.dart';

import '../screens/bucket_list_screen.dart';

/// Routes owned by the bucket list feature.
final List<GoRoute> bucketListRoutes = [
  GoRoute(path: '/bucket-list', builder: (_, _) => const BucketListScreen()),
];
