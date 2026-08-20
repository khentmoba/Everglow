import 'package:go_router/go_router.dart';
import '../screens/vault_screen.dart';

final List<GoRoute> vaultRoutes = [
  GoRoute(path: '/vault', builder: (_, _) => const VaultScreen()),
];
