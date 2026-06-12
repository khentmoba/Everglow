import 'dart:math' as math;
import 'package:flutter/material.dart';

enum GameMode { solo, multiplayer }

class Obstacle {
  final double x;
  final double y;
  final double width;
  final double height;
  const Obstacle(this.x, this.y, this.width, this.height);

  double get left => x;
  double get right => x + width;
  double get top => y;
  double get bottom => y + height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
}

class Player {
  String id;
  String displayName;
  double x;
  double y;
  double angle;
  int hp;
  int maxHp;
  int kills;
  bool alive;
  Color color;
  Color accentColor;
  bool isLocal;
  double respawnTimer;

  Player({
    required this.id,
    required this.displayName,
    required this.x,
    required this.y,
    this.angle = 0,
    this.hp = 100,
    this.maxHp = 100,
    this.kills = 0,
    this.alive = true,
    required this.color,
    required this.accentColor,
    this.isLocal = false,
    this.respawnTimer = 0,
  });
}

class Bullet {
  double x;
  double y;
  final double vx;
  final double vy;
  final double damage;
  final double range;
  final double speed;
  double traveled;
  final String shooterId;
  final bool isLocal;
  final double createdAtMs;

  Bullet({
    required this.x,
    required this.y,
    required double angle,
    required this.speed,
    required this.damage,
    required this.range,
    required this.shooterId,
    this.isLocal = false,
    int? createdAtMs,
  })  : vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        traveled = 0,
        createdAtMs = (createdAtMs ?? DateTime.now().millisecondsSinceEpoch).toDouble();

  double get angle => math.atan2(vy, vx);
}

class Target {
  double x;
  double y;
  double vx;
  double vy;
  int hp;
  bool alive;
  double respawnTimer;
  final double radius;

  Target({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.hp = 60,
    this.alive = true,
    this.respawnTimer = 0,
    this.radius = 16,
  });
}

class DamageEvent {
  final String victimId;
  final String shooterId;
  final double amount;

  DamageEvent({
    required this.victimId,
    required this.shooterId,
    required this.amount,
  });
}

class AssaultArena {
  final double width;
  final double height;
  final List<Obstacle> obstacles;

  const AssaultArena({
    this.width = 1000,
    this.height = 1000,
    this.obstacles = const [],
  });
}

class AssaultGameConfig {
  final double playerRadius = 14.0;
  final double playerSpeed = 220.0;
  final double bulletSpeed = 720.0;
  final double bulletDamage = 18.0;
  final double bulletRange = 520.0;
  final double fireCooldownMs = 220;
  final double respawnSeconds = 0;
  final int targetRespawnMs = 1500;
  final int targetCount = 5;
}

class JoystickAxis {
  double x = 0.0;
  double y = 0.0;

  bool get isActive => x.abs() > 0.05 || y.abs() > 0.05;

  void reset() {
    x = 0.0;
    y = 0.0;
  }
}

typedef DamageCallback = void Function(DamageEvent event);
typedef ShotCallback = void Function(Bullet bullet);

class AssaultGame {
  final AssaultArena arena;
  final AssaultGameConfig config;
  final GameMode mode;
  final Map<String, Player> players = {};
  final List<Bullet> bullets = [];
  final List<Target> targets = [];
  final List<DamageEvent> damageLog = [];

  double _lastFireMs = 0;
  double _matchTime = 0;
  int _totalScore = 0;
  bool _finished = false;
  String? _winnerId;

  DamageCallback? onLocalDamageDealt;
  ShotCallback? onLocalShotFired;

  AssaultGame({
    required this.mode,
    AssaultArena? arena,
    AssaultGameConfig? config,
  })  : arena = arena ?? defaultArena(),
        config = config ?? AssaultGameConfig() {
    if (mode == GameMode.solo) {
      _spawnInitialTargets();
    }
  }

  static AssaultArena defaultArena() {
    return const AssaultArena(
      width: 1000,
      height: 1000,
      obstacles: [
        Obstacle(180, 180, 220, 50),
        Obstacle(600, 180, 220, 50),
        Obstacle(180, 770, 220, 50),
        Obstacle(600, 770, 220, 50),
        Obstacle(460, 460, 80, 80),
        Obstacle(80, 460, 60, 80),
        Obstacle(860, 460, 60, 80),
      ],
    );
  }

  void addPlayer(Player player) {
    players[player.id] = player;
  }

  void _spawnInitialTargets() {
    final rand = math.Random(7);
    for (int i = 0; i < config.targetCount; i++) {
      _spawnTarget(rand);
    }
  }

  void _spawnTarget(math.Random rand) {
    double x;
    double y;
    int safety = 0;
    do {
      x = 80 + rand.nextDouble() * (arena.width - 160);
      y = 80 + rand.nextDouble() * (arena.height - 160);
      safety++;
    } while (_collidesAnyObstacle(x, y, 18) && safety < 20);

    final angle = rand.nextDouble() * math.pi * 2;
    final speed = 30 + rand.nextDouble() * 50;
    targets.add(Target(
      x: x,
      y: y,
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
    ));
  }

  void update(
    double dt, {
    required JoystickAxis moveInput,
    required JoystickAxis aimInput,
    required bool firePressed,
    required String localPlayerId,
  }) {
    _matchTime += dt;

    final local = players[localPlayerId];
    if (local != null && local.alive) {
      if (moveInput.isActive) {
        final mag = math.sqrt(moveInput.x * moveInput.x + moveInput.y * moveInput.y);
        final nx = moveInput.x / mag;
        final ny = moveInput.y / mag;
        final newX = local.x + nx * config.playerSpeed * dt;
        final newY = local.y + ny * config.playerSpeed * dt;
        local.x = _clampToWorld(newX, config.playerRadius);
        local.y = _clampToWorld(newY, config.playerRadius);
      }

      if (aimInput.isActive) {
        local.angle = math.atan2(aimInput.y, aimInput.x);
      } else if (moveInput.isActive) {
        local.angle = math.atan2(moveInput.y, moveInput.x);
      }

      final nowMs = _matchTime * 1000;
      if (firePressed && (nowMs - _lastFireMs) >= config.fireCooldownMs) {
        _lastFireMs = nowMs;
        _fireBullet(local);
      }
    }

    for (final p in players.values) {
      if (!p.alive && p.respawnTimer > 0) {
        p.respawnTimer -= dt;
        if (p.respawnTimer <= 0) {
          p.hp = p.maxHp;
          p.alive = true;
        }
      }
    }

    final List<Bullet> toRemove = [];
    for (final b in bullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.traveled += b.speed * dt;

      if (b.x < 0 || b.x > arena.width || b.y < 0 || b.y > arena.height) {
        toRemove.add(b);
        continue;
      }

      if (_collidesAnyObstacle(b.x, b.y, 2)) {
        toRemove.add(b);
        continue;
      }

      for (final p in players.values) {
        if (p.id == b.shooterId || !p.alive) continue;
        final dx = p.x - b.x;
        final dy = p.y - b.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= config.playerRadius + 4) {
          p.hp = math.max(0, p.hp - b.damage.round());
          if (p.hp <= 0) {
            p.alive = false;
            p.respawnTimer = config.respawnSeconds;
            final shooter = players[b.shooterId];
            if (shooter != null) {
              shooter.kills += 1;
            }
          }
          final event = DamageEvent(
            victimId: p.id,
            shooterId: b.shooterId,
            amount: b.damage,
          );
          damageLog.add(event);
          if (b.isLocal) {
            onLocalDamageDealt?.call(event);
          }
          toRemove.add(b);
          break;
        }
      }

      if (toRemove.contains(b)) continue;

      for (final t in targets) {
        if (!t.alive) continue;
        final dx = t.x - b.x;
        final dy = t.y - b.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= t.radius + 2) {
          t.hp -= b.damage.round();
          if (t.hp <= 0) {
            t.alive = false;
            t.respawnTimer = config.targetRespawnMs / 1000;
            if (b.shooterId == localPlayerId) {
              _totalScore += 1;
            }
          }
          toRemove.add(b);
          break;
        }
      }

      if (b.traveled >= b.range) {
        toRemove.add(b);
      }
    }

    bullets.removeWhere(toRemove.contains);

    if (mode == GameMode.solo) {
      for (final t in targets) {
        if (!t.alive) {
          t.respawnTimer -= dt;
          if (t.respawnTimer <= 0) {
            t.hp = 60;
            t.alive = true;
            final rand = math.Random();
            double nx;
            double ny;
            int safety = 0;
            do {
              nx = 80 + rand.nextDouble() * (arena.width - 160);
              ny = 80 + rand.nextDouble() * (arena.height - 160);
              safety++;
            } while (_collidesAnyObstacle(nx, ny, t.radius) && safety < 20);
            t.x = nx;
            t.y = ny;
            final angle = rand.nextDouble() * math.pi * 2;
            final speed = 30 + rand.nextDouble() * 50;
            t.vx = math.cos(angle) * speed;
            t.vy = math.sin(angle) * speed;
          }
        } else {
          t.x += t.vx * dt;
          t.y += t.vy * dt;
          if (t.x < 40 || t.x > arena.width - 40) t.vx = -t.vx;
          if (t.y < 40 || t.y > arena.height - 40) t.vy = -t.vy;
        }
      }
    }

    if (mode == GameMode.multiplayer && !_finished) {
      final dead = players.values.where((p) => !p.alive).toList();
      if (dead.length == 1) {
        final deadPlayer = dead.first;
        final winner = players.values.firstWhere(
          (p) => p.id != deadPlayer.id,
          orElse: () => deadPlayer,
        );
        _winnerId = winner.id == deadPlayer.id ? null : winner.id;
        _finished = true;
      }
    }
  }

  bool _collidesAnyObstacle(double x, double y, double r) {
    for (final o in arena.obstacles) {
      final closestX = x.clamp(o.left, o.right);
      final closestY = y.clamp(o.top, o.bottom);
      final dx = x - closestX;
      final dy = y - closestY;
      if (dx * dx + dy * dy <= r * r) return true;
    }
    return false;
  }

  double _clampToWorld(double v, double padding) {
    return v.clamp(padding, arena.width - padding);
  }

  void _fireBullet(Player p) {
    final muzzleDistance = config.playerRadius + 4;
    final ox = p.x + math.cos(p.angle) * muzzleDistance;
    final oy = p.y + math.sin(p.angle) * muzzleDistance;
    final bullet = Bullet(
      x: ox,
      y: oy,
      angle: p.angle,
      speed: config.bulletSpeed,
      damage: config.bulletDamage,
      range: config.bulletRange,
      shooterId: p.id,
      isLocal: p.isLocal,
    );
    bullets.add(bullet);
    onLocalShotFired?.call(bullet);
  }

  void registerRemoteShot({
    required String shooterId,
    required double originX,
    required double originY,
    required double angle,
    required double speed,
    required double damage,
    required double range,
    required int createdAtMs,
  }) {
    final alreadyExists = bullets.any(
      (b) =>
          b.shooterId == shooterId &&
          (b.createdAtMs - createdAtMs).abs() < 50 &&
          (b.x - originX).abs() < 4 &&
          (b.y - originY).abs() < 4,
    );
    if (alreadyExists) return;

    final bullet = Bullet(
      x: originX,
      y: originY,
      angle: angle,
      speed: speed,
      damage: damage,
      range: range,
      shooterId: shooterId,
      isLocal: false,
      createdAtMs: createdAtMs,
    );
    bullets.add(bullet);
  }

  double get matchTime => _matchTime;
  int get score => _totalScore;
  bool get isFinished => _finished;
  String? get winnerId => _winnerId;

  void reset() {
    bullets.clear();
    damageLog.clear();
    _matchTime = 0;
    _lastFireMs = 0;
    _totalScore = 0;
    _finished = false;
    _winnerId = null;
    for (final p in players.values) {
      p.hp = p.maxHp;
      p.alive = true;
      p.kills = 0;
      p.angle = 0;
    }
    targets.clear();
    if (mode == GameMode.solo) {
      _spawnInitialTargets();
    }
  }
}
