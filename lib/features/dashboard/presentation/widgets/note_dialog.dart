import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/hidden_note.dart';

/// An intimate, romantic love letter dialog for the Letterbox.
///
/// Designed with keepsake stationery styling:
/// - Opened envelope flap header with centered crimson & gold wax seal
/// - Interactive wax seal tap with bouncy flutter & sweet love message
/// - Corner filigree flourishes & celestial starlight sparkles
/// - Vintage postmark unlock date badge
/// - Dancing Script / Caveat typography with romantic divider
/// - Sweet "Forever & always" sign-off and "Keep close to heart" action
/// - Proportioned for phones, tablets, and web without horizontal stretching
class NoteDialog extends StatefulWidget {
  final HiddenNote note;

  const NoteDialog({super.key, required this.note});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sealController;
  late final Animation<double> _sealScaleAnimation;
  bool _showSealHeart = false;

  @override
  void initState() {
    super.initState();
    _sealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _sealScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0).chain(
          CurveTween(curve: Curves.bounceOut),
        ),
        weight: 60,
      ),
    ]).animate(_sealController);
  }

  @override
  void dispose() {
    _sealController.dispose();
    super.dispose();
  }

  void _onSealTap() {
    if (AppMotion.reduced) return;
    _sealController.forward(from: 0.0);
    setState(() => _showSealHeart = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showSealHeart = false);
    });
  }

  String _formatUnlockDate(DateTime date) {
    try {
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final dateString = _formatUnlockDate(note.unlockDate);
    final isShort = note.content.length <= 90 && !note.content.contains('\n');
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480, // Keeps romantic stationery proportions on all screen sizes
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF381E3E), // Warm deep wine velvet
                  AppColors.velvet,
                  AppColors.inkDeep,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.inkDeep.withValues(alpha: 0.8),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.25),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.auroraGold.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  // Stationery corner filigree frame and ambient starlight
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _StationeryBorderPainter(),
                      ),
                    ),
                  ),

                  // Main letter content layout
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Envelope Flap & Centered Wax Seal Header
                      _buildEnvelopeHeader(context),

                      // Interactive "Sealed with love" toast banner
                      _buildSealToast(),

                      // Scrollable parchment content
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: screenHeight * 0.58,
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Vintage postmark date badge
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.inkDeep.withValues(
                                        alpha: 0.45,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.blushGold.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome,
                                          size: 10,
                                          color: AppColors.auroraGold,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            dateString.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.outfitBold
                                                .copyWith(
                                                  fontSize: 9.5,
                                                  letterSpacing: 0.8,
                                                  color: AppColors.blushGold
                                                      .withValues(alpha: 0.85),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Title in cursive script
                                Text(
                                  note.title.isNotEmpty
                                      ? note.title
                                      : 'A Secret Letter',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.handwrittenTitle()
                                      .copyWith(
                                        fontSize: 32,
                                        color: AppColors.blushGold,
                                        height: 1.2,
                                        shadows: [
                                          Shadow(
                                            color: AppColors.inkDeep.withValues(
                                              alpha: 0.9,
                                            ),
                                            offset: const Offset(0, 2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                ),
                                const SizedBox(height: 12),

                                // Romantic flourish divider
                                _buildFlourishDivider(),
                                const SizedBox(height: 20),

                                // Letter body text
                                Text(
                                  note.content,
                                  textAlign: isShort
                                      ? TextAlign.center
                                      : TextAlign.start,
                                  style: AppTypography.handwrittenBody()
                                      .copyWith(
                                        fontSize: isShort ? 28 : 22,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.95,
                                        ),
                                        height: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 28),

                                // Romantic sign-off
                                _buildSignOff(isShort),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Footer action button
                      _buildFooter(context),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvelopeHeader(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.twilight.withValues(alpha: 0.65),
        border: Border(
          bottom: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Envelope flap V-crease fold lines
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _EnvelopeFlapPainter(),
              ),
            ),
          ),

          // Left Letterbox badge
          Positioned(
            left: 18,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: AppColors.auroraRose,
                ),
                const SizedBox(width: 6),
                Text(
                  'LETTERBOX',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: AppColors.blushGold.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Mathematically Centered Wax Seal Medallion
          Center(
            child: GestureDetector(
              onTap: _onSealTap,
              child: Tooltip(
                message: 'Sealed with love',
                child: AnimatedBuilder(
                  animation: _sealScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _sealScaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.25, -0.3),
                        radius: 0.85,
                        colors: [
                          AppColors.auroraRose,
                          AppColors.deepRose,
                          AppColors.roseDark,
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.rosePressed.withValues(alpha: 0.5),
                          border: Border.all(
                            color: AppColors.blushGold.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: AppColors.blushGold,
                            size: 18,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1.2),
                                blurRadius: 2.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Right Close Icon Button
          Positioned(
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.moonlight.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.roseQuartz,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSealToast() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _showSealHeart ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _showSealHeart ? 28 : 0,
        margin: EdgeInsets.only(top: _showSealHeart ? 4 : 0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.deepRose, AppColors.auroraRose],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 11,
                  color: AppColors.petalWhite,
                ),
                const SizedBox(width: 5),
                Text(
                  'Sealed with love for Clair',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10.5,
                    color: AppColors.petalWhite,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlourishDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.blushGold.withValues(alpha: 0.4),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.favorite_rounded,
          size: 9,
          color: AppColors.auroraRose.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blushGold.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignOff(bool isShort) {
    return Align(
      alignment: isShort ? Alignment.center : Alignment.centerRight,
      child: Column(
        crossAxisAlignment:
            isShort ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [
          Text(
            'Forever & always,',
            style: AppTypography.handwrittenTitle().copyWith(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: AppColors.softLavender.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'With all my love',
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                  color: AppColors.blushGold.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.favorite_rounded,
                size: 13,
                color: AppColors.auroraRose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.deepRose.withValues(alpha: 0.28),
                    AppColors.plum.withValues(alpha: 0.38),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_outline_rounded,
                    size: 14,
                    color: AppColors.blushGold,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Keep close to heart',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering opened envelope flap creases leading to the wax seal.
class _EnvelopeFlapPainter extends CustomPainter {
  const _EnvelopeFlapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blushGold.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // V-shaped flap lines leading to the wax seal
    canvas.drawLine(
      const Offset(0, 0),
      Offset(centerX - 24, centerY),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(centerX + 24, centerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter rendering delicate vintage stationery borders, flourishes, and star sparkles.
class _StationeryBorderPainter extends CustomPainter {
  const _StationeryBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 50 || size.height <= 50) return;

    // Inner hairline frame inset
    const double inset = 10.0;
    const double radius = 20.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - (inset * 2),
        size.height - (inset * 2),
      ),
      const Radius.circular(radius),
    );

    final framePaint = Paint()
      ..color = AppColors.blushGold.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rrect, framePaint);

    // Corner bracket flourishes
    final flourishPaint = Paint()
      ..color = AppColors.blushGold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const double flLen = 14.0;
    const double flOffset = 18.0;

    // Top-Left
    canvas.drawLine(
      const Offset(flOffset, flOffset + flLen),
      const Offset(flOffset, flOffset),
      flourishPaint,
    );
    canvas.drawLine(
      const Offset(flOffset, flOffset),
      const Offset(flOffset + flLen, flOffset),
      flourishPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - flOffset - flLen, flOffset),
      Offset(size.width - flOffset, flOffset),
      flourishPaint,
    );
    canvas.drawLine(
      Offset(size.width - flOffset, flOffset),
      Offset(size.width - flOffset, flOffset + flLen),
      flourishPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(flOffset, size.height - flOffset - flLen),
      Offset(flOffset, size.height - flOffset),
      flourishPaint,
    );
    canvas.drawLine(
      Offset(flOffset, size.height - flOffset),
      Offset(flOffset + flLen, size.height - flOffset),
      flourishPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - flOffset - flLen, size.height - flOffset),
      Offset(size.width - flOffset, size.height - flOffset),
      flourishPaint,
    );
    canvas.drawLine(
      Offset(size.width - flOffset, size.height - flOffset - flLen),
      Offset(size.width - flOffset, size.height - flOffset),
      flourishPaint,
    );

    // 4-point celestial star sparkles in corners
    final starPaint = Paint()
      ..color = AppColors.blushGold.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;

    _drawSparkle(canvas, const Offset(flOffset + 14, flOffset + 14), 4.5, starPaint);
    _drawSparkle(canvas, Offset(size.width - flOffset - 14, flOffset + 14), 4.5, starPaint);
    _drawSparkle(canvas, Offset(flOffset + 14, size.height - flOffset - 14), 4.5, starPaint);
    _drawSparkle(canvas, Offset(size.width - flOffset - 14, size.height - flOffset - 14), 4.5, starPaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
