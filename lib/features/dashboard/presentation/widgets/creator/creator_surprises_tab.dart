import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/services/creator_service.dart';
import '../../../../../features/guardian/data/models/guardian_message.dart';

class CreatorSurprisesTab extends StatefulWidget {
  final CreatorService creatorService;

  const CreatorSurprisesTab({super.key, required this.creatorService});

  @override
  State<CreatorSurprisesTab> createState() => _CreatorSurprisesTabState();
}

class _CreatorSurprisesTabState extends State<CreatorSurprisesTab> {
  // Guardian whisper
  final _whisperController = TextEditingController();
  bool _isSendingWhisper = false;

  // Love burst
  final _burstController = TextEditingController();
  bool _isSendingBurst = false;

  // Teaser countdown
  final _teaserTitleController = TextEditingController();
  final _teaserDescController = TextEditingController();
  DateTime _teaserDate = DateTime.now().add(const Duration(days: 7));
  bool _isSavingTeaser = false;

  // Date night spotlight
  final _spotTitleController = TextEditingController();
  final _spotNoteController = TextEditingController();
  String _spotMediaType = 'movie';
  bool _isSavingSpot = false;

  static const List<String> _whisperIdeas = [
    'You are doing amazing today, my love ✨',
    'Khent left your favorite snack ready for movie night 🍿',
    'Take a deep breath — I am so proud of you 💕',
    'Check the Letterbox… something secret is waiting 💌',
  ];

  late Stream<List<GuardianMessage>> _whispersStream;
  late Stream<Map<String, dynamic>?> _spotStream;

  @override
  void initState() {
    super.initState();
    try {
      _whispersStream =
          widget.creatorService.watchGuardianWhispers(limit: 5);
    } catch (_) {
      _whispersStream = Stream.value(const []);
    }
    try {
      _spotStream = widget.creatorService.watchTonightFeature();
    } catch (_) {
      _spotStream = Stream.value(null);
    }
  }

  @override
  void dispose() {
    _whisperController.dispose();
    _burstController.dispose();
    _teaserTitleController.dispose();
    _teaserDescController.dispose();
    _spotTitleController.dispose();
    _spotNoteController.dispose();
    super.dispose();
  }

  AuthService? _tryAuth() {
    try {
      return context.read<AuthService>();
    } catch (_) {
      return null;
    }
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

  Future<void> _sendWhisper() async {
    final text = _whisperController.text.trim();
    if (text.isEmpty) {
      _snack('Write a whisper first ✨');
      return;
    }
    setState(() => _isSendingWhisper = true);
    try {
      await widget.creatorService.sendGuardianWhisper(text);
      _whisperController.clear();
      _snack('Whisper sent — Guardian will greet Clair 🐱✨');
    } catch (e) {
      _snack('Failed to send whisper: $e');
    } finally {
      if (mounted) setState(() => _isSendingWhisper = false);
    }
  }

  Future<void> _sendBurst() async {
    final text = _burstController.text.trim();
    if (text.isEmpty) {
      _snack('Write a love burst first 💕');
      return;
    }
    final author = _tryAuth()?.currentUser ?? 'khentsgdz';
    setState(() => _isSendingBurst = true);
    try {
      await widget.creatorService.sendLoveBurst(
        message: text,
        author: author,
      );
      _burstController.clear();
      _snack('Love burst dropped into the Starlight Jar ⭐');
    } catch (e) {
      _snack('Failed to send burst: $e');
    } finally {
      if (mounted) setState(() => _isSendingBurst = false);
    }
  }

  Future<void> _saveTeaser() async {
    final title = _teaserTitleController.text.trim();
    if (title.isEmpty) {
      _snack('Give the countdown a title ✨');
      return;
    }
    final createdBy = _tryAuth()?.currentUser ?? 'khentsgdz';
    setState(() => _isSavingTeaser = true);
    try {
      await widget.creatorService.createTeaserCountdown(
        title: title,
        date: _teaserDate,
        description: _teaserDescController.text.trim().isEmpty
            ? 'Something special is coming ✨'
            : _teaserDescController.text.trim(),
        createdBy: createdBy,
      );
      _teaserTitleController.clear();
      _teaserDescController.clear();
      _snack('Secret countdown pinned to Upcoming ✨');
    } catch (e) {
      _snack('Failed to pin countdown: $e');
    } finally {
      if (mounted) setState(() => _isSavingTeaser = false);
    }
  }

  Future<void> _saveSpotlight() async {
    final title = _spotTitleController.text.trim();
    if (title.isEmpty) {
      _snack('Pick a title for tonight ✨');
      return;
    }
    final setBy = _tryAuth()?.currentUser ?? 'khentsgdz';
    setState(() => _isSavingSpot = true);
    try {
      await widget.creatorService.setTonightFeature(
        title: title,
        mediaType: _spotMediaType,
        note: _spotNoteController.text.trim(),
        setBy: setBy,
      );
      _snack('Tonight’s feature spotlight is live 🍿');
    } catch (e) {
      _snack('Failed to set spotlight: $e');
    } finally {
      if (mounted) setState(() => _isSavingSpot = false);
    }
  }

  Future<void> _clearSpotlight() async {
    try {
      await widget.creatorService.clearTonightFeature();
      _snack('Spotlight cleared');
    } catch (e) {
      _snack('Failed to clear: $e');
    }
  }

  Future<void> _deleteWhisper(String id) async {
    try {
      await widget.creatorService.deleteGuardianWhisper(id);
      _snack('Whisper removed');
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionCard(
            emoji: '🐱',
            title: 'Guardian Whisperer',
            subtitle:
                'Write a secret note — the Guardian cat delivers it to Clair next time she opens Everglow.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _whisperIdeas.map((idea) {
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _whisperController.text = idea),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.velvet.withValues(alpha: 0.6),
                          borderRadius: AppRadius.radiusFull,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          idea,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _whisperController,
                  hint: 'e.g., You are glowing today, my love ✨',
                  icon: Icons.pets_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Send Whisper 🐱',
                  isLoading: _isSendingWhisper,
                  onPressed: _isSendingWhisper ? null : _sendWhisper,
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<GuardianMessage>>(
                  stream: _whispersStream,
                  builder: (context, snapshot) {
                    final whispers = snapshot.data ?? [];
                    if (whispers.isEmpty) {
                      return Text(
                        'No active whispers. Clair sees normal Guardian quotes.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active whispers (${whispers.length})',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppColors.blushGold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...whispers.map(
                          (w) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.velvet.withValues(alpha: 0.5),
                              borderRadius: AppRadius.radiusMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    w.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.outfitWhite.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove whisper',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () => _deleteWhisper(w.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            emoji: '⭐',
            title: 'Instant Love Burst',
            subtitle:
                'Drop a glowing surprise note straight into the Starlight Jar for Clair to find.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInput(
                  controller: _burstController,
                  hint: 'e.g., Thinking of you — you make every day softer 💕',
                  icon: Icons.auto_awesome_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Send Love Burst ⭐',
                  isLoading: _isSendingBurst,
                  onPressed: _isSendingBurst ? null : _sendBurst,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            emoji: '⏳',
            title: 'Secret Teaser Countdown',
            subtitle:
                'Pin a mysterious countdown on Upcoming without spoiling the surprise.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInput(
                  controller: _teaserTitleController,
                  hint: 'e.g., Something special is coming…',
                  icon: Icons.celebration_rounded,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                _buildInput(
                  controller: _teaserDescController,
                  hint: 'Optional hint (kept vague on purpose)',
                  icon: Icons.edit_note_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _teaserDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 3650),
                      ),
                    );
                    if (picked != null) {
                      setState(() => _teaserDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.velvet.withValues(alpha: 0.55),
                      borderRadius: AppRadius.radiusLg,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppColors.blushGold,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(_teaserDate),
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Pin Secret Countdown ⏳',
                  isLoading: _isSavingTeaser,
                  onPressed: _isSavingTeaser ? null : _saveTeaser,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            emoji: '🍿',
            title: 'Date Night Spotlight',
            subtitle:
                'Feature tonight’s pick at the top of your shared night — with a sweet note from you.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _spotStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final active = data != null &&
                        (data['active'] as bool? ?? false);
                    if (!active) {
                      return Text(
                        'No spotlight right now. Set one below for tonight 🍿',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      );
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            AppColors.blushGold.withValues(alpha: 0.12),
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(
                          color:
                              AppColors.blushGold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Now featuring: ${data['title'] ?? 'Untitled'}',
                                  style:
                                      AppTypography.outfitBold.copyWith(
                                    fontSize: 13,
                                    color: AppColors.petalWhite,
                                  ),
                                ),
                                if ((data['note'] as String?)
                                        ?.isNotEmpty ==
                                    true)
                                  Text(
                                    data['note'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.outfitWhite.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _clearSpotlight,
                            child: Text(
                              'Clear',
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: AppColors.auroraRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildInput(
                  controller: _spotTitleController,
                  hint: 'e.g., Spirited Away — 8 PM with ramen 🍜',
                  icon: Icons.movie_rounded,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['movie', 'tv', 'anime'].map((type) {
                    final selected = _spotMediaType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(type.toUpperCase()),
                        labelStyle:
                            AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.petalWhite
                              : AppColors.textMedium,
                        ),
                        selectedColor:
                            AppColors.deepRose.withValues(alpha: 0.28),
                        backgroundColor:
                            AppColors.velvet.withValues(alpha: 0.4),
                        side: BorderSide(
                          color: selected
                              ? AppColors.deepRose.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusFull,
                        ),
                        onSelected: (_) =>
                            setState(() => _spotMediaType = type),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _buildInput(
                  controller: _spotNoteController,
                  hint: 'Sweet note for Clair (optional)',
                  icon: Icons.favorite_outline_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'Spotlight Tonight 🍿',
                  isLoading: _isSavingSpot,
                  onPressed: _isSavingSpot ? null : _saveSpotlight,
                ),
              ],
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

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.outfitWhite.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.outfitWhite.copyWith(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.velvet.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.45),
          ),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null
            ? AppColors.deepRose.withValues(alpha: 0.48)
            : AppColors.deepRose,
        foregroundColor: AppColors.petalWhite,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.petalWhite),
              ),
            )
          : Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
