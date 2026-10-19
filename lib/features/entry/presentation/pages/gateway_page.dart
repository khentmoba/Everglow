import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/router/route_helpers.dart';
import 'package:go_router/go_router.dart';
import '../state/gateway_state.dart';
import '../../../../core/utils/connectivity_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../dashboard/presentation/widgets/dashboard_load_veil.dart';
import '../widgets/animated_door.dart';
import '../widgets/passcode_input.dart';
import '../widgets/petal_shower.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/agent/agent_mode.dart';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  final GatewayNotifier _notifier = GatewayNotifier();
  bool _hasNavigated = false;
  GatewayState? _lastProcessedState;

  @override
  void initState() {
    super.initState();
    _notifier.addListener(_onStateChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifier.verifyCouplePasscode = (code) =>
        context.read<AuthService>().verifyCouplePasscode(code);
    _notifier.tryOfflineUnlock = (code) =>
        context.read<AuthService>().tryOfflineRememberedLogin(code);
    _notifier.hasOfflineRememberedCode = () =>
        context.read<AuthService>().hasOfflineRememberedCode;
  }

  bool get _isLocalDev =>
      kDebugMode ||
      (kIsWeb &&
          (Uri.base.host == 'localhost' ||
              Uri.base.host == '127.0.0.1' ||
              Uri.base.host == '0.0.0.0'));

  /// Where to go after a successful login: back to the deep-linked page
  /// when the router remembered one (`/?from=...`), else the default home.
  String _postLoginTarget({
    required bool cinemaOnly,
    required String fallback,
  }) {
    final uri = GoRouterState.of(context).uri;
    return deepLinkTarget(uri, cinemaOnly: cinemaOnly) ?? fallback;
  }

  Future<void> _onStateChange() async {
    if (!mounted) return;

    // Always rebuild so the passcode dots follow typing/deleting.
    // Input length changes don't change GatewayState, so the
    // state-equality guard below would otherwise skip the rebuild
    // and the yellow dot would get stuck after the first digit.
    setState(() {});

    final newState = _notifier.currentState;
    if (newState == _lastProcessedState) return;
    _lastProcessedState = newState;

    if (newState == GatewayState.unlocking) {
      final authService = context.read<AuthService>();
      final isCinemaOnlyAccess = authService.isCinemaOnlyUser;
      if (!isCinemaOnlyAccess) {
        DashboardLoadVeil.requestPasscodeLoader();
      }
      final authTask = authService.ensureAuthenticated();

      unawaited(
        authTask
            .then((_) {
              unawaited(
                TMDBService().migrateWatchListOwnership().catchError((e) {
                  Logger.e('Watchlist migration background error', error: e);
                  return 0;
                }),
              );
            })
            .catchError((e) {
              Logger.e('Error during passcode login', error: e);
              unawaited(authService.ensureAuthenticated().catchError((_) {}));
            })
            .whenComplete(() {
              if (authService.lastAuthError != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      authService.lastAuthError!,
                      style: const TextStyle(color: AppColors.petalWhite),
                    ),
                    backgroundColor: Colors.orange.shade700,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }),
      );

      final navDelay = Future.delayed(const Duration(milliseconds: 900));
      Future.wait([navDelay, authTask.catchError((_) {})]).then((_) {
        if (!mounted || _hasNavigated) return;
        // Never enter the app without a real Firebase session — or an
        // offline-remembered one (saved user + own code while unreachable),
        // which renders cached Firestore data with an offline banner.
        // Without either, every stream fails and the dashboard renders
        // false-empty shelves.
        final hasRealSession =
            authService.user != null && !authService.isAnonymousSession;
        if (!hasRealSession && !authService.isOfflineMode) {
          // The code validated but no Firebase session exists (offline or
          // anonymous): a connection problem, never a wrong code.
          _notifier.setFailureReason(GatewayFailureReason.connection);
          _notifier.updateState(GatewayState.error);
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted || _hasNavigated) return;
            _notifier.clearInput();
            _notifier.updateState(GatewayState.awaitingInput);
          });
          return;
        }
        if (isCinemaOnlyAccess) {
          _hasNavigated = true;
          context.go(_postLoginTarget(cinemaOnly: true, fallback: '/cinema'));
        } else {
          _notifier.updateState(GatewayState.revealingSite);
        }
      });
    } else if (newState == GatewayState.revealingSite) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _notifier.updateState(GatewayState.complete);
      });
    } else if (newState == GatewayState.complete) {
      if (!_hasNavigated) {
        _hasNavigated = true;
        context.go(_postLoginTarget(cinemaOnly: false, fallback: '/dashboard'));
      }
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_onStateChange);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.currentState;
    final isRevealing =
        state == GatewayState.revealingSite || state == GatewayState.complete;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.inkDeep, AppColors.twilight, AppColors.velvet],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Aurora glows behind everything.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.7, -0.8),
                      radius: 0.9,
                      colors: [
                        AppColors.deepRose.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.85, 0.9),
                      radius: 0.9,
                      colors: [
                        AppColors.softLavender.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildMainContent(),
            if (_notifier.currentState != GatewayState.complete)
              _buildGatewayOverlay(),
            // Petals drift over the scene while the door is closed.
            Positioned.fill(
              child: IgnorePointer(child: PetalShower(isVisible: !isRevealing)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayOverlay() {
    final state = _notifier.currentState;
    final isRevealing =
        state == GatewayState.revealingSite || state == GatewayState.complete;

    return IgnorePointer(
      ignoring: state == GatewayState.revealingSite,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: isRevealing ? 1.0 : 0.0),
        duration: AppMotion.orZero(const Duration(milliseconds: 1100)),
        curve: Curves.easeInQuint,
        builder: (context, zoom, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop only. The door itself is painted above this clip
              // because ClipPath also removes hit-testing inside the cut
              // hole, which would make the keypad/handle unclickable.
              IgnorePointer(
                child: ClipPath(
                  clipper: _DoorMaskClipper(
                    zoom: zoom,
                    scale: _doorScale(context),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.inkDeep, AppColors.twilight],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: AnimatedDoor(
                  isUnlocked:
                      state == GatewayState.unlocking ||
                      state == GatewayState.revealingSite ||
                      state == GatewayState.complete,
                  isError: state == GatewayState.error,
                  isRevealing:
                      state == GatewayState.revealingSite ||
                      state == GatewayState.complete,
                  isLoaded: state != GatewayState.initialLoad,
                  onEntranceComplete: () {
                    if (_notifier.currentState == GatewayState.initialLoad) {
                      _notifier.updateState(GatewayState.awaitingInput);
                    }
                  },
                  keypad: AnimatedSwitcher(
                    duration: AppMotion.orZero(
                      const Duration(milliseconds: 500),
                    ),
                    child:
                        (state == GatewayState.initialLoad ||
                            state == GatewayState.awaitingInput ||
                            state == GatewayState.evaluating ||
                            state == GatewayState.error)
                        ? Transform.scale(
                            scale: 0.8,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PasscodeInput(
                                  input: _notifier.currentInput,
                                  isError: state == GatewayState.error,
                                  isVerifying: state == GatewayState.evaluating,
                                  failureReason: _notifier.lastFailureReason,
                                  onDigitPressed: _notifier.appendDigit,
                                  onBackspace: _notifier.backspace,
                                ),
                                const _OfflineRememberHint(),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              if (_isLocalDev &&
                  (state == GatewayState.initialLoad ||
                      state == GatewayState.awaitingInput ||
                      state == GatewayState.error))
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildDevLoginBar()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDevLoginBar() {
    final destinations = <({String label, String route, IconData icon})>[
      (label: 'Cinema', route: '/cinema', icon: Icons.movie_rounded),
      (label: 'Anime', route: '/anime', icon: Icons.smart_display_rounded),
      (
        label: 'Mangacelestia',
        route: '/manga',
        icon: Icons.auto_stories_rounded,
      ),
      (label: 'Books', route: '/books', icon: Icons.menu_book_rounded),
      (label: 'Dashboard', route: '/dashboard', icon: Icons.home_rounded),
      (
        label: 'Sanctuary',
        route: '/sanctuary',
        icon: Icons.chat_bubble_rounded,
      ),
      (label: 'Gallery', route: '/gallery', icon: Icons.photo_library_rounded),
      (label: 'Journal', route: '/journal', icon: Icons.book_rounded),
      (label: 'Tonight', route: '/tonight', icon: Icons.nightlife_rounded),
      (
        label: 'Play Zone',
        route: '/play-zone',
        icon: Icons.sports_esports_rounded,
      ),
      (label: 'Academy', route: '/academy', icon: Icons.school_rounded),
      (label: 'Garden', route: '/garden', icon: Icons.local_florist_rounded),
      (label: 'Starlight', route: '/starlight', icon: Icons.star_rounded),
      (
        label: 'Calendar',
        route: '/calendar',
        icon: Icons.calendar_month_rounded,
      ),
      (label: 'Trip Kit', route: '/trips', icon: Icons.flight_takeoff_rounded),
      (label: 'Jukebox', route: '/jukebox', icon: Icons.music_note_rounded),
      (label: 'Canvas', route: '/canvas', icon: Icons.palette_rounded),
      (
        label: 'Bucket List',
        route: '/bucket-list',
        icon: Icons.checklist_rounded,
      ),
      (
        label: 'Money',
        route: '/money',
        icon: Icons.account_balance_wallet_rounded,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 860),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.auroraGold.withValues(alpha: 0.40),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: AppColors.auroraGold,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Agent Fast-Jump:',
                style: TextStyle(
                  color: AppColors.petalWhite.withValues(alpha: 0.90),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _devUserChip('👤 Khent', () => _agentLogin('khentsgdz')),
              const SizedBox(width: 6),
              _devUserChip('🌸 Clair', () => _agentLogin('clairjassen')),
              const SizedBox(width: 6),
              _devUserChip('🍿 Guest', () => _agentLogin('breyan')),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final dest in destinations) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _agentJump(dest.route),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inkDeep.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.blushGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              dest.icon,
                              size: 13,
                              color: AppColors.auroraGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dest.label,
                              style: const TextStyle(
                                color: AppColors.petalWhite,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _agentLogin(String profile) {
    AgentMode.enable(profile: profile);
    context.read<AuthService>().enableAgentSession(profile: profile);
    final isCinema = profile == 'breyan';
    _hasNavigated = true;
    final destination = _postLoginTarget(
      cinemaOnly: isCinema,
      fallback: isCinema ? '/cinema' : '/dashboard',
    );
    context.go(destination);
  }

  void _agentJump(String route, {String profile = 'khentsgdz'}) {
    AgentMode.enable(profile: profile);
    context.read<AuthService>().enableAgentSession(profile: profile);
    _hasNavigated = true;
    context.go(route);
  }

  Widget _devUserChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.petalWhite,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final state = _notifier.currentState;
    final isRevealing =
        state == GatewayState.revealingSite || state == GatewayState.complete;

    // Lightweight placeholder — mirrors Dashboard's EverglowBackground so the
    // door reveal feels continuous, but doesn't open any Firestore streams.
    // The old code mounted a full DashboardScreen here, which was disposed
    // 1100ms later when `go('/dashboard')` mounted a second instance and
    // caused the XP bar (and every other stream) to flash shrink->show.
    return AnimatedOpacity(
      opacity: isRevealing ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: isRevealing
          ? const Stack(
              children: [
                Positioned.fill(
                  child: EverglowBackground(
                    baseColor: AppColors.inkDeep,
                    glows: [
                      RadialGlow(
                        color: AppColors.deepRose,
                        alignment: Alignment(-0.7, -0.85),
                        size: 0.9,
                        opacity: 0.14,
                      ),
                      RadialGlow(
                        color: AppColors.softLavender,
                        alignment: Alignment(0.85, 0.95),
                        size: 0.8,
                        opacity: 0.10,
                      ),
                      RadialGlow(
                        color: AppColors.auroraGold,
                        alignment: Alignment(0.1, 0.45),
                        size: 0.6,
                        opacity: 0.05,
                      ),
                    ],
                    showPetals: false,
                  ),
                ),
                Center(child: _GatewayRevealMark()),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Quiet mark shown behind the door while it swings open (~1s).
///
/// Deliberately has NO percent: the reveal is a fixed animation, not a
/// measured load, so any number here would be fake — and it used to hit a
/// fake 100% right before the dashboard's REAL percent started over from
/// the bottom. The dashboard veil is the one honest loader.
class _GatewayRevealMark extends StatelessWidget {
  const _GatewayRevealMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.favorite_rounded,
          color: AppColors.auroraRose,
          size: 26,
        ),
        const SizedBox(height: 10),
        Text(
          'EVERGLOW',
          style: TextStyle(
            color: AppColors.petalWhite.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'opening your story…',
          style: TextStyle(
            color: AppColors.petalWhite.withValues(alpha: 0.45),
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _DoorMaskClipper extends CustomClipper<Path> {
  final double zoom;
  final double scale;

  _DoorMaskClipper({this.zoom = 0.0, this.scale = 1.0});

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final double baseWidth = 330 * scale;
    final double baseHeight = 560 * scale;
    final double zoomScale = 1.0 + (4.0 * zoom);

    final double doorWidth = baseWidth * zoomScale;
    final double doorHeight = baseHeight * zoomScale;

    final Rect doorRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: doorWidth - (8 * zoomScale),
      height: doorHeight - (8 * zoomScale),
    );

    final archRadius = math.min(doorRect.width / 2, doorRect.height * 0.24);
    final hole = Path()
      ..moveTo(doorRect.left, doorRect.bottom)
      ..lineTo(doorRect.left, doorRect.top + archRadius)
      ..quadraticBezierTo(
        doorRect.left,
        doorRect.top,
        doorRect.left + archRadius,
        doorRect.top,
      )
      ..lineTo(doorRect.right - archRadius, doorRect.top)
      ..quadraticBezierTo(
        doorRect.right,
        doorRect.top,
        doorRect.right,
        doorRect.top + archRadius,
      )
      ..lineTo(doorRect.right, doorRect.bottom)
      ..close();

    return Path.combine(PathOperation.difference, path, hole);
  }

  @override
  bool shouldReclip(_DoorMaskClipper oldClipper) =>
      oldClipper.zoom != zoom || oldClipper.scale != scale;
}

/// Matches [AnimatedDoor]'s internal responsive scaling so the reveal
/// mask hugs the door on narrow viewports.
double _doorScale(BuildContext context) {
  final viewport = MediaQuery.sizeOf(context);
  return math.min(
    1.0,
    math.min((viewport.width - 24) / 330, (viewport.height - 48) / 560),
  );
}

/// Quiet reassurance on the gate when offline with a remembered user:
/// Clair still types her usual code and her saved copy opens.
/// Hidden whenever online or on a fresh device with nobody remembered.
class _OfflineRememberHint extends StatelessWidget {
  const _OfflineRememberHint();

  @override
  Widget build(BuildContext context) {
    String? remembered;
    try {
      remembered = context.select<AuthService, String?>((a) => a.currentUser);
    } catch (_) {
      // No auth provider above us (tests, odd shells): no hint, like the
      // AppErrorPage fallback. Production always provides AuthService.
      return const SizedBox.shrink();
    }
    final name = remembered == 'clairjassen'
        ? 'Clair'
        : remembered == 'khentsgdz'
        ? 'Khent'
        : null;
    if (name == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onConnectivityChanged,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, snapshot) {
        if (snapshot.data ?? true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10, left: 24, right: 24),
          child: Text(
            'No connection \u2014 welcome back, $name. Your code still opens your saved copy.',
            textAlign: TextAlign.center,
            maxLines: 3,
            style: TextStyle(
              color: AppColors.blushGold.withValues(alpha: 0.92),
              fontSize: 12,
              height: 1.25,
            ),
          ),
        );
      },
    );
  }
}
