import 'package:go_router/go_router.dart';

import '../screens/gallery_screen.dart';

/// Routes owned by the gallery feature.
final List<GoRoute> galleryRoutes = [
  GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
];
