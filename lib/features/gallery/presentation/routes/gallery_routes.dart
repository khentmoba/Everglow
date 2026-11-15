import 'package:go_router/go_router.dart';

import '../screens/gallery_screen.dart';

final List<GoRoute> galleryRoutes = [
  GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
];
