import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/bucket_item.dart';

/// Shared look-and-feel for the bucket list ("Starlit Journey").
///
/// One home for every hue, icon, and label so the screen, cards, board,
/// and sheets always agree. All colors come from [AppColors] tokens.

// ── Assignees ─────────────────────────────────────────────────

/// Usernames of the couple. Kept here so every bucket widget agrees.
const String bucketAssigneeKhent = 'khentsgdz';
const String bucketAssigneeClair = 'clairjassen';

/// Display name for an assignee (`null` = nobody yet).
String bucketAssigneeLabel(String? username) {
  switch (username) {
    case bucketAssigneeKhent:
      return 'Khent';
    case bucketAssigneeClair:
      return 'Clair';
    case null:
      return 'Unassigned';
    default:
      return username;
  }
}

/// Tint for an assignee pill.
Color bucketAssigneeHue(String? username) {
  switch (username) {
    case bucketAssigneeKhent:
      return AppColors.auroraTeal;
    case bucketAssigneeClair:
      return AppColors.auroraRose;
    default:
      return AppColors.mutedPurple;
  }
}

/// Icon for an assignee pill.
IconData bucketAssigneeIcon(String? username) {
  switch (username) {
    case bucketAssigneeKhent:
      return Icons.person_rounded;
    case bucketAssigneeClair:
      return Icons.favorite_rounded;
    default:
      return Icons.person_outline_rounded;
  }
}

/// Next assignee when tapping to cycle: nobody → Khent → Clair → nobody.
String? bucketNextAssignee(String? current) {
  switch (current) {
    case null:
      return bucketAssigneeKhent;
    case bucketAssigneeKhent:
      return bucketAssigneeClair;
    default:
      return null;
  }
}

// ── Status ────────────────────────────────────────────────────

/// Tint for a dream status.
Color bucketStatusHue(BucketStatus status) {
  switch (status) {
    case BucketStatus.wish:
      return AppColors.blushGold;
    case BucketStatus.planned:
      return AppColors.auroraTeal;
    case BucketStatus.completed:
      return AppColors.success;
  }
}

/// Icon for a dream status.
IconData bucketStatusIcon(BucketStatus status) {
  switch (status) {
    case BucketStatus.wish:
      return Icons.auto_awesome_rounded;
    case BucketStatus.planned:
      return Icons.map_rounded;
    case BucketStatus.completed:
      return Icons.check_circle_rounded;
  }
}

/// Short warm label for a dream status.
String bucketStatusLabel(BucketStatus status) {
  switch (status) {
    case BucketStatus.wish:
      return 'Wished';
    case BucketStatus.planned:
      return 'Planned';
    case BucketStatus.completed:
      return 'Fulfilled';
  }
}

// ── Priority ──────────────────────────────────────────────────

/// Tint for a dream priority.
Color bucketPriorityHue(BucketPriority priority) {
  switch (priority) {
    case BucketPriority.low:
      return AppColors.softLavender;
    case BucketPriority.medium:
      return AppColors.blushGold;
    case BucketPriority.high:
      return AppColors.warmAmber;
    case BucketPriority.urgent:
      return AppColors.error;
  }
}

/// Short label for a dream priority (fits small pills).
String bucketPriorityShortLabel(BucketPriority priority) {
  switch (priority) {
    case BucketPriority.low:
      return 'Low';
    case BucketPriority.medium:
      return 'Med';
    case BucketPriority.high:
      return 'High';
    case BucketPriority.urgent:
      return 'Urgent';
  }
}

// ── Category ──────────────────────────────────────────────────

/// Tint for a dream category tile + pill.
Color bucketCategoryHue(BucketCategory category) {
  switch (category) {
    case BucketCategory.travel:
      return AppColors.auroraTeal;
    case BucketCategory.experience:
      return AppColors.softLavender;
    case BucketCategory.food:
      return AppColors.warmAmber;
    case BucketCategory.adventure:
      return AppColors.success;
    case BucketCategory.milestone:
      return AppColors.blushGold;
    case BucketCategory.other:
      return AppColors.roseQuartz;
  }
}

// ── Starfield ─────────────────────────────────────────────────

/// Deterministic starfield for the journey hero background.
///
/// Seeded, so every build paints the same sky. Static (no animation loop)
/// to keep 60fps on web and respect reduced motion.
class BucketStarsPainter extends CustomPainter {
  const BucketStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(11);
    for (var i = 0; i < 48; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.4;
      final a = 0.10 + rng.nextDouble() * 0.45;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = AppColors.petalWhite.withValues(alpha: a),
      );
    }
    // A few golden sparkles (plus-shapes).
    final sparkle = Paint()
      ..color = AppColors.blushGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final s = 3 + rng.nextDouble() * 3;
      canvas.drawLine(Offset(x - s, y), Offset(x + s, y), sparkle);
      canvas.drawLine(Offset(x, y - s), Offset(x, y + s), sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
