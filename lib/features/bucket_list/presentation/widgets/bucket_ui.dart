import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/bucket_item.dart';

const String bucketAssigneeKhent = 'khentsgdz';
const String bucketAssigneeClair = 'clairjassen';

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
