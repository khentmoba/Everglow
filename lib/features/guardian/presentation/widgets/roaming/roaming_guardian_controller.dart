import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import 'package:flutter/foundation.dart';

/// Which paint layer the roaming Guardian currently occupies.
///
/// [CatDepth.behind] renders below the dashboard content (the cat strolls
/// behind cards and buttons), [CatDepth.front] renders above everything.
enum CatDepth { behind, front }

/// What the roaming Guardian is doing right now.
enum RoamingActivity { idle, wandering, zoomies, turning }

/// Pure simulation for the dashboard's roaming Guardian.
///
/// Owns position, depth, activity and facing so the two paint layers (front /
/// behind) always render a perfectly synced cat. The layer widgets listen to
/// this controller and apply transforms; the controller itself has no
/// rendering dependencies, which keeps it fully unit-testable.
class RoamingGuardianController extends ChangeNotifier {
  RoamingGuardianController({
    math.Random? random,
    this.tickInterval = const Duration(milliseconds: 33),
  }) : _random = random ?? math.Random();

  final math.Random _random;
  final Duration tickInterval;

  Timer? _timer;

  Size _bounds = Size.zero;
  Offset _position = Offset.zero;
  Offset _target = Offset.zero;
  CatDepth _depth = CatDepth.front;
  RoamingActivity _activity = RoamingActivity.idle;
  double _facing = 1;
  double _walkSpeed = 90;
  double _zoomSpeed = 330;
  double _elapsed = 0;
  Duration _activityRemaining = Duration.zero;
  bool _turnedOnce = false;
  bool _dragging = false;
  bool _hovered = false;

  /// Chance the cat switches paint depth when it sets out on a new stroll.
  static const double depthSwitchChance = 0.45;

  /// Chance the cat bursts into a zoomie dash when leaving idle.
  static const double zoomieChance = 0.16;

  /// Chance the cat does an in-place spin instead of walking.
  static const double turnChance = 0.12;

  static const Duration _turnDuration = Duration(milliseconds: 640);

  // ── Public state ────────────────────────────────────────────────────────

  Size get bounds => _bounds;
  Offset get position => _position;
  Offset get target => _target;
  CatDepth get depth => _depth;
  RoamingActivity get activity => _activity;
  double get facing => _facing;
  double get elapsed => _elapsed;
  bool get isDragging => _dragging;
  bool get isHovered => _hovered;
  bool get isMoving =>
      _activity == RoamingActivity.wandering ||
      _activity == RoamingActivity.zoomies;

  double get _edgeInset {
    if (_bounds.isEmpty) return 48;
    return _bounds.width < 420 ? 52 : 58;
  }

  /// Size of the visible cat, scaled with the viewport.
  double get catSize {
    final width = _bounds.width;
    if (width <= 0) return 84;
    if (width < 420) return 72;
    if (width < 900) return 84;
    return 96;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Called by the layer whenever the viewport size is known. Lazily starts
  /// the roaming ticker on the first non-empty size. Intentionally does not
  /// notify listeners: the layer that reports the size rebuilds in the same
  /// frame anyway, and notifying from inside build would be unsafe.
  void attach(Size size) {
    final changed = size != _bounds;
    final firstBounds = _bounds.isEmpty && !size.isEmpty;
    _bounds = size;
    if (changed && !_bounds.isEmpty) {
      _position = _clamp(_position);
      if (!_isInside(_target)) {
        _target = _randomTarget();
      }
    }
    if (firstBounds) {
      _position = Offset(
        _bounds.width * (0.35 + _random.nextDouble() * 0.3),
        _bounds.height * (0.45 + _random.nextDouble() * 0.25),
      );
      _depth = _random.nextDouble() < 0.55
          ? CatDepth.front
          : CatDepth.behind;
      _activity = RoamingActivity.idle;
      _activityRemaining = Duration(
        milliseconds: 500 + _random.nextInt(700),
      );
    }
    if (changed || firstBounds) {
      _ensureTicking();
    }
  }

  /// Starts the periodic ticker explicitly (also started lazily on attach).
  void start() => _ensureTicking();

  /// Stops the ticker. Safe to call multiple times.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _ensureTicking() {
    if (_timer != null) return;
    _timer = Timer.periodic(tickInterval, (timer) => tick(tickInterval));
  }

  // ── Simulation ──────────────────────────────────────────────────────────

  /// Advances the simulation by [elapsed]. Public so tests can drive it
  /// deterministically without real timers.
  void tick(Duration elapsed) {
    if (_bounds.isEmpty || _dragging) {
      return;
    }
    final dt = (elapsed.inMicroseconds / Duration.microsecondsPerSecond)
        .clamp(0.0, 0.1);
    _elapsed += dt;

    switch (_activity) {
      case RoamingActivity.idle:
        _activityRemaining -= elapsed;
        if (_activityRemaining <= Duration.zero) {
          _leaveIdle();
        }
      case RoamingActivity.wandering:
        if (_stepTowardTarget(dt, _walkSpeed)) {
          _startIdle(1200 + _random.nextInt(2200));
        }
      case RoamingActivity.zoomies:
        _activityRemaining -= elapsed;
        if (_stepTowardTarget(dt, _zoomSpeed) ||
            _activityRemaining <= Duration.zero) {
          _startIdle(700 + _random.nextInt(1400));
        }
      case RoamingActivity.turning:
        _activityRemaining -= elapsed;
        if (!_turnedOnce &&
            _activityRemaining <= _turnDuration ~/ 2) {
          _turnedOnce = true;
          _facing *= -1;
        }
        if (_activityRemaining <= Duration.zero) {
          _startIdle(1000 + _random.nextInt(1600));
        }
    }
    notifyListeners();
  }

  bool _stepTowardTarget(double dt, double speed) {
    final delta = _target - _position;
    final distance = delta.distance;
    if (distance < 4) {
      _position = _clamp(_target);
      return true;
    }
    final step = speed * dt;
    if (distance <= step) {
      _position = _clamp(_target);
      return true;
    }
    final direction = delta / distance;
    _position = _clamp(_position + direction * step);
    if (direction.dx.abs() > 0.04) {
      _facing = direction.dx < 0 ? -1 : 1;
    }
    return false;
  }

  void _leaveIdle() {
    final roll = _random.nextDouble();
    if (roll < zoomieChance) {
      _startZoomies();
    } else if (roll < zoomieChance + turnChance) {
      _startTurning();
    } else {
      _startWander();
    }
  }

  void _startIdle(int millis) {
    _activity = RoamingActivity.idle;
    _activityRemaining = Duration(milliseconds: millis);
  }

  void _startWander() {
    _rollDepth();
    _target = _randomTarget();
    _walkSpeed = 80 + _random.nextDouble() * 55;
    _activity = RoamingActivity.wandering;
  }

  void _startZoomies() {
    _rollDepth();
    _target = _randomTarget();
    _zoomSpeed = 300 + _random.nextDouble() * 130;
    _activityRemaining = Duration(milliseconds: 650 + _random.nextInt(850));
    _activity = RoamingActivity.zoomies;
  }

  void _startTurning() {
    _activity = RoamingActivity.turning;
    _activityRemaining = _turnDuration;
    _turnedOnce = false;
  }

  void _rollDepth() {
    if (_random.nextDouble() < depthSwitchChance) {
      _depth = _depth == CatDepth.behind ? CatDepth.front : CatDepth.behind;
    }
  }

  Offset _randomTarget() {
    if (_bounds.isEmpty) return _position;
    final inset = _edgeInset;
    return Offset(
      inset + _random.nextDouble() * (_bounds.width - inset * 2),
      inset + _random.nextDouble() * (_bounds.height - inset * 2),
    );
  }

  bool _isInside(Offset point) {
    if (_bounds.isEmpty) return true;
    final inset = _edgeInset;
    return point.dx >= inset &&
        point.dx <= _bounds.width - inset &&
        point.dy >= inset &&
        point.dy <= _bounds.height - inset;
  }

  Offset _clamp(Offset point) {
    if (_bounds.isEmpty) return point;
    final inset = _edgeInset;
    return Offset(
      point.dx.clamp(inset, _bounds.width - inset),
      point.dy.clamp(inset, _bounds.height - inset),
    );
  }

  // ── Interaction ─────────────────────────────────────────────────────────

  /// User grabbed the cat: freeze roaming and lift it to the front layer.
  void beginDrag() {
    if (_dragging) return;
    _dragging = true;
    _depth = CatDepth.front;
    _activity = RoamingActivity.idle;
    notifyListeners();
  }

  /// Real-time drag: move the cat with the pointer, clamped to the viewport.
  void dragBy(Offset delta) {
    if (!_dragging) return;
    _position = _clamp(_position + delta);
    if (delta.dx.abs() > 0.4) {
      _facing = delta.dx < 0 ? -1 : 1;
    }
    notifyListeners();
  }

  /// User released the cat: it immediately sets off roaming from the drop
  /// point.
  void endDrag() {
    if (!_dragging) return;
    _dragging = false;
    if (_random.nextDouble() < 0.3) {
      _rollDepth();
    }
    _startWander();
    notifyListeners();
  }

  /// Double tap: startled zoomie burst toward a fresh target.
  void burst() {
    if (_dragging) return;
    _rollDepth();
    _startZoomies();
    notifyListeners();
  }

  void setHovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    notifyListeners();
  }

  /// Test helper / manual override to flip paint depth.
  void flipDepth() {
    _depth = _depth == CatDepth.behind ? CatDepth.front : CatDepth.behind;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
