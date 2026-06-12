import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../game/assault_game.dart';

class AssaultGamePainter extends CustomPainter {
  final AssaultGame game;
  final double cameraX;
  final double cameraY;
  final double scale;
  final String localId;
  final List<List<Offset>> muzzleFlashes;

  AssaultGamePainter({
    required this.game,
    required this.cameraX,
    required this.cameraY,
    required this.scale,
    required this.localId,
    required this.muzzleFlashes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final viewW = size.width;
    final viewH = size.height;
    final arenaW = game.arena.width;
    final arenaH = game.arena.height;

    final bg = Paint()
      ..shader = const RadialGradient(
        colors: [AppTheme.velvet, AppTheme.twilight],
        center: Alignment(-0.2, -0.3),
        radius: 1.4,
      ).createShader(Rect.fromLTWH(0, 0, viewW, viewH));
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), bg);

    canvas.save();
    canvas.translate(viewW / 2 - cameraX * scale, viewH / 2 - cameraY * scale);
    canvas.scale(scale, scale);

    _drawGrid(canvas, arenaW, arenaH);
    _drawObstacles(canvas);
    _drawTargets(canvas);
    _drawPlayers(canvas);
    _drawBullets(canvas);
    _drawMuzzleFlashes(canvas);
    _drawArenaBorder(canvas, arenaW, arenaH);

    canvas.restore();

    _drawMinimap(canvas, viewW, viewH, arenaW, arenaH);
  }

  void _drawGrid(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    const step = 50.0;
    for (double x = 0; x <= w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }
    for (double y = 0; y <= h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
  }

  void _drawObstacles(Canvas canvas) {
    final fill = Paint()..color = const Color(0xFF1F1424);
    final stroke = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final o in game.arena.obstacles) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(o.x, o.y, o.width, o.height),
        const Radius.circular(8),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, stroke);

      final highlight = Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.deepRose.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(o.x, o.y, o.width, o.height));
      canvas.drawRRect(r, highlight);
    }
  }

  void _drawTargets(Canvas canvas) {
    for (final t in game.targets) {
      if (!t.alive) continue;
      final center = Offset(t.x, t.y);
      final glow = Paint()
        ..color = AppTheme.warmAmber.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, t.radius + 4, glow);
      canvas.drawCircle(
        center,
        t.radius,
        Paint()..color = AppTheme.warmAmber.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        center,
        t.radius - 4,
        Paint()..color = AppTheme.blushGold,
      );
      final ring = Paint()
        ..color = AppTheme.twilight.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, t.radius, ring);
    }
  }

  void _drawPlayers(Canvas canvas) {
    for (final p in game.players.values) {
      if (!p.alive) continue;
      final center = Offset(p.x, p.y);

      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center + const Offset(0, 4), game.config.playerRadius, shadow);

      final glow = Paint()
        ..color = p.color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, game.config.playerRadius + 4, glow);

      final body = Paint()..color = p.color;
      canvas.drawCircle(center, game.config.playerRadius, body);

      final ring = Paint()
        ..color = p.accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, game.config.playerRadius, ring);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(p.angle);
      final gun = Paint()..color = p.accentColor;
      final gunRect = Rect.fromLTWH(
        game.config.playerRadius - 4,
        -3,
        18,
        6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(gunRect, const Radius.circular(2)),
        gun,
      );
      canvas.restore();

      _drawHealthBar(canvas, p);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: p.displayName,
          style: TextStyle(
            color: AppTheme.petalWhite,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [
              const Shadow(
                blurRadius: 4,
                color: Colors.black,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          center.dx - labelPainter.width / 2,
          center.dy - game.config.playerRadius - 22,
        ),
      );

      if (p.id == localId) {
        final indicator = Paint()
          ..color = AppTheme.blushGold.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(
          center,
          game.config.playerRadius + 8,
          indicator,
        );
      }
    }
  }

  void _drawHealthBar(Canvas canvas, Player p) {
    final barW = 34.0;
    final barH = 5.0;
    final x = p.x - barW / 2;
    final y = p.y - game.config.playerRadius - 12;
    final bg = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, barH),
        const Radius.circular(2),
      ),
      bg,
    );
    final pct = (p.hp / p.maxHp).clamp(0.0, 1.0);
    final fillColor = pct > 0.5
        ? AppTheme.softLavender
        : pct > 0.25
            ? AppTheme.warmAmber
            : AppTheme.deepRose;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW * pct, barH),
        const Radius.circular(2),
      ),
      Paint()..color = fillColor,
    );
  }

  void _drawBullets(Canvas canvas) {
    for (final b in game.bullets) {
      final trail = Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.blushGold.withValues(alpha: 0.0),
            AppTheme.blushGold.withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromCircle(center: Offset(b.x, b.y), radius: 14));
      canvas.drawCircle(Offset(b.x, b.y), 10, trail);

      final glow = Paint()
        ..color = AppTheme.blushGold
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(b.x, b.y), 4, glow);
      canvas.drawCircle(
        Offset(b.x, b.y),
        3,
        Paint()..color = AppTheme.petalWhite,
      );
    }
  }

  void _drawMuzzleFlashes(Canvas canvas) {
    for (final flash in muzzleFlashes) {
      for (final p in flash) {
        final star = Paint()
          ..color = AppTheme.warmAmber.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(p, 12, star);
        canvas.drawCircle(
          p,
          6,
          Paint()..color = AppTheme.petalWhite,
        );
      }
    }
  }

  void _drawArenaBorder(Canvas canvas, double w, double h) {
    final border = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), border);
  }

  void _drawMinimap(Canvas canvas, double viewW, double viewH, double arenaW, double arenaH) {
    final mmW = 110.0;
    final mmH = 110.0;
    final margin = 16.0;
    final mmRect = Rect.fromLTWH(
      viewW - mmW - margin,
      viewH - mmH - margin,
      mmW,
      mmH,
    );

    final bg = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mmRect, const Radius.circular(10)),
      bg,
    );
    final border = Paint()
      ..color = AppTheme.moonlight.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(mmRect, const Radius.circular(10)),
      border,
    );

    final scaleX = mmW / arenaW;
    final scaleY = mmH / arenaH;

    for (final o in game.arena.obstacles) {
      final r = Rect.fromLTWH(
        mmRect.left + o.x * scaleX,
        mmRect.top + o.y * scaleY,
        o.width * scaleX,
        o.height * scaleY,
      );
      canvas.drawRect(
        r,
        Paint()..color = AppTheme.moonlight.withValues(alpha: 0.5),
      );
    }

    for (final p in game.players.values) {
      if (!p.alive) continue;
      canvas.drawCircle(
        Offset(
          mmRect.left + p.x * scaleX,
          mmRect.top + p.y * scaleY,
        ),
        3,
        Paint()..color = p.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AssaultGamePainter old) => true;
}
