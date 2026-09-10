import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/models/presence_status.dart';
import '../../../../../core/perf/perf_settings.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/presence_service.dart';
import '../../../../../core/system/app_update_browser.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/services/creator_service.dart';
import '../../../../../features/heartbeat/data/models/user_mood.dart';
import '../../../../../features/heartbeat/data/services/mood_service.dart';

class CreatorSystemTab extends StatefulWidget {
  final CreatorService creatorService;

  const CreatorSystemTab({super.key, required this.creatorService});

  @override
  State<CreatorSystemTab> createState() => _CreatorSystemTabState();
}

class _CreatorSystemTabState extends State<CreatorSystemTab> {
  Map<String, dynamic>? _health;
  bool _isCheckingHealth = false;
  String? _healthError;

  bool _isRepairing = false;
  int? _repairedCount;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.velvet,
      ),
    );
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isCheckingHealth = true;
      _healthError = null;
    });
    try {
      final result = await widget.creatorService.fetchHealthStatus();
      if (!mounted) return;
      setState(() {
        _health = result;
        final status = (result['status'] as String?) ?? 'unknown';
        if (status != 'ok') {
          _healthError = result['error']?.toString() ??
              result['message']?.toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _health = null;
        _healthError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isCheckingHealth = false);
    }
  }

  Future<void> _repairAssets() async {
    setState(() {
      _isRepairing = true;
      _repairedCount = null;
    });
    try {
      final count = await widget.creatorService.repairMilestoneAssets();
      if (!mounted) return;
      setState(() => _repairedCount = count);
      _snack(
        count == 0
            ? 'Milestone photos already healthy ✨'
            : 'Repaired $count milestone photo${count == 1 ? '' : 's'} ✨',
      );
    } catch (e) {
      _snack('Repair failed: $e');
    } finally {
      if (mounted) setState(() => _isRepairing = false);
    }
  }

  Future<void> _clearCaches() async {
    setState(() => _isClearingCache = true);
    try {
      await widget.creatorService.clearLocalCaches();
      _snack('Local caches cleared ✨');
    } catch (e) {
      _snack('Cache clear failed: $e');
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  void _sendTestToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💌 Everglow test notification',
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 13,
                color: AppColors.blushGold,
              ),
            ),
            Text(
              'If you can read this, in-app toasts + navigation context are working.',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                color: AppColors.petalWhite.withValues(alpha: 0.85),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppColors.velvet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  AuthService? _tryAuth() {
    try {
      return context.read<AuthService>();
    } catch (_) {
      return null;
    }
  }

  PresenceService? _tryPresence() {
    try {
      return context.read<PresenceService>();
    } catch (_) {
      return null;
    }
  }

  MoodService? _tryMood() {
    try {
      return context.read<MoodService>();
    } catch (_) {
      // MoodService is often not provided at app root — fall back to
      // a direct instance (Firestore-backed) for the inspector.
      try {
        return MoodService();
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kept for the creator_modal regression guard.
          Text(
            'System Tools',
            textAlign: TextAlign.center,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 16,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Maintenance actions for the Everglow workspace.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          // ── Backend health ──
          _buildSectionCard(
            emoji: '🛰️',
            title: 'Backend Health',
            subtitle: 'One-tap ping to Cloud Functions + Firestore.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isCheckingHealth)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.blushGold,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_health != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill(
                        label:
                            'API ${(_health!['status'] as String?) ?? 'unknown'}',
                        ok: (_health!['status'] as String?) == 'ok',
                      ),
                      _buildPill(
                        label:
                            'Firestore ${((_health!['checks'] as Map?)?['firestore'] ?? 'unknown')}',
                        ok: ((_health!['checks'] as Map?)?['firestore']) ==
                            'ok',
                      ),
                      if ((_health!['version'] as String?) != null)
                        _buildPill(
                          label: 'v${_health!['version']}',
                          ok: true,
                        ),
                    ],
                  )
                else
                  Text(
                    _healthError ?? 'Health check has not run yet.',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (_healthError != null && _health != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _healthError!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isCheckingHealth ? null : _checkHealth,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.blushGold,
                  ),
                  label: Text(
                    'Ping backend health',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 13,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.blushGold.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusLg,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Partner sync ──
          _buildSectionCard(
            emoji: '💞',
            title: 'Partner Sync',
            subtitle: 'Is Clair online? Last heartbeat, doodle, and mood.',
            child: _buildPartnerSync(),
          ),
          const SizedBox(height: 16),

          // ── Maintenance ──
          _buildSectionCard(
            emoji: '🧰',
            title: 'Quick Maintenance',
            subtitle: 'Safe one-tap repairs when something looks stuck.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToolRow(
                  icon: Icons.auto_fix_high_rounded,
                  title: 'Repair milestone photos',
                  subtitle: _repairedCount == null
                      ? 'Fix old .png paths → .jpg'
                      : 'Last run fixed $_repairedCount photo${_repairedCount == 1 ? '' : 's'}',
                  isLoading: _isRepairing,
                  onTap: _isRepairing ? null : _repairAssets,
                ),
                const SizedBox(height: 10),
                _buildToolRow(
                  icon: Icons.cleaning_services_rounded,
                  title: 'Clear local caches',
                  subtitle: 'Letterbox disk cache + offline previews',
                  isLoading: _isClearingCache,
                  onTap: _isClearingCache ? null : _clearCaches,
                ),
                const SizedBox(height: 10),
                _buildToolRow(
                  icon: Icons.notifications_active_rounded,
                  title: 'Send test notification',
                  subtitle: 'Preview the in-app toast channel',
                  isLoading: false,
                  onTap: _sendTestToast,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Performance (dev tooling) ──
          _buildPerformanceCard(),
        ],
      ),
    );
  }

  /// Frame meter + render scale.
  ///
  /// These two switches are how we measure Everglow on the only device where
  /// "the dashboard feels heavy" is true: Khent's phone, in the installed PWA,
  /// where a query string can't be edited and Safari's remote inspector isn't
  /// reachable.
  Widget _buildPerformanceCard() {
    final deviceDpr = MediaQuery.devicePixelRatioOf(context);
    return _buildSectionCard(
      emoji: '📈',
      title: 'Performance',
      subtitle:
          'Measure real frames on the phone, and trade pixels for smoothness.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: PerfSettings.frameMeter,
            builder: (context, on, _) => _buildToolRow(
              icon: on ? Icons.speed_rounded : Icons.speed_outlined,
              title: on ? 'Frame meter: on' : 'Frame meter: off',
              subtitle: 'FPS, jank % and build/raster ms — top-left corner',
              isLoading: false,
              onTap: () => PerfSettings.setFrameMeter(!on),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Render scale',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 13,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'How many device pixels each logical pixel gets. Lower means fewer '
            'pixels to draw every frame. Now ${deviceDpr.toStringAsFixed(2)}x '
            '— reload to apply.',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<double?>(
            valueListenable: PerfSettings.renderScale,
            builder: (context, scale, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildScaleChip(
                  'Device',
                  scale == null,
                  () => PerfSettings.setRenderScale(null),
                ),
                _buildScaleChip(
                  '2.0x',
                  scale == 2.0,
                  () => PerfSettings.setRenderScale(2.0),
                ),
                _buildScaleChip(
                  '1.5x',
                  scale == 1.5,
                  () => PerfSettings.setRenderScale(1.5),
                ),
              ],
            ),
          ),
          if (AppUpdateBrowser.instance.supported) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => AppUpdateBrowser.instance.reload(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.blushGold,
              ),
              label: Text(
                'Reload to apply',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 13,
                  color: AppColors.petalWhite,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusLg,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScaleChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blushGold.withValues(alpha: 0.18)
              : AppColors.velvet.withValues(alpha: 0.55),
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: selected
                ? AppColors.blushGold.withValues(alpha: 0.55)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 12,
            color: selected ? AppColors.petalWhite : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerSync() {
    final auth = _tryAuth();
    final presence = _tryPresence();
    final mood = _tryMood();

    if (auth == null || presence == null) {
      return Text(
        'Partner sync needs the live app context (open Creator Tools from the dashboard).',
        style: AppTypography.outfitWhite.copyWith(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      );
    }

    final partnerUid = auth.partnerUid;
    if (partnerUid == null || partnerUid.isEmpty) {
      return Text(
        'No partner linked to this account yet.',
        style: AppTypography.outfitWhite.copyWith(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      );
    }

    final partnerName = auth.partnerName;
    final partnerUsername = auth.currentUser == 'khentsgdz'
        ? 'clairjassen'
        : 'khentsgdz';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<PresenceStatus>(
          stream: presence.watchPresence(partnerUid),
          builder: (context, snapshot) {
            final status = snapshot.data;
            final now = DateTime.now();
            final online =
                status != null && status.isOnlineAt(now);
            final lastSeen = status?.lastSeen;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.velvet.withValues(alpha: 0.55),
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? AppColors.blushGold
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online
                              ? '$partnerName is online now ✨'
                              : '$partnerName is offline',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 13,
                            color: AppColors.petalWhite,
                          ),
                        ),
                        Text(
                          lastSeen == null
                              ? 'No heartbeat seen yet'
                              : 'Last seen ${_formatAgo(now.difference(lastSeen))} ago',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        if (mood != null)
          StreamBuilder<UserMood?>(
            stream: mood.watchLatestMood(partnerUsername),
            builder: (context, snapshot) {
              final latest = snapshot.data;
              if (latest == null) {
                return Text(
                  'No mood shared by $partnerName today yet.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                );
              }
              return Row(
                children: [
                  Text(
                    latest.moodEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$partnerName feels ${latest.moodEmoji} (${latest.moodScore}/5)',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        else
          Text(
            'Mood service unavailable in this context.',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
      ],
    );
  }

  String _formatAgo(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  Widget _buildPill({required String label, required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.blushGold.withValues(alpha: 0.15)
            : AppColors.auroraRose.withValues(alpha: 0.15),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(
          color: ok
              ? AppColors.blushGold.withValues(alpha: 0.4)
              : AppColors.auroraRose.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? AppColors.blushGold : AppColors.auroraRose,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 11,
              color: AppColors.petalWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.45),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 15,
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildToolRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.55),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.blushGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 13,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.blushGold),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
