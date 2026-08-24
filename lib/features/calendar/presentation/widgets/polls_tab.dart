import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_error_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../data/models/date_poll.dart';
import '../../data/services/calendar_poll_service.dart';
import '../../data/services/calendar_service.dart';
import '../../domain/models/calendar_event.dart';
import 'add_poll_dialog.dart';

class PollsTab extends StatelessWidget {
  const PollsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pollService = CalendarPollService();
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser ?? '';

    return StreamBuilder<List<DatePoll>>(
      stream: pollService.watchAll(),
      builder: (context, snap) {
        if (snap.hasError) {
          return EverglowErrorState(
            message: 'Could not load polls',
            onRetry: () {},
            icon: Icons.poll_outlined,
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: EverglowSkeleton(
              width: double.infinity,
              height: 100,
              radius: 16,
            ),
          );
        }
        final polls = snap.data!;
        if (polls.isEmpty) {
          return EverglowEmptyState(
            icon: Icons.how_to_vote_rounded,
            title: 'No date polls yet',
            subtitle:
                'Create a Rallly-style poll to pick the perfect date together',
            ctaLabel: 'Create Poll',
            onCta: () => _showAddPoll(context),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: polls.length,
          itemBuilder: (context, idx) =>
              _PollCard(poll: polls[idx], currentUser: currentUser),
        );
      },
    );
  }

  void _showAddPoll(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddPollDialog());
  }
}

class _PollCard extends StatelessWidget {
  final DatePoll poll;
  final String currentUser;

  const _PollCard({required this.poll, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final isClosed = poll.status == PollStatus.closed;
    final myVote = poll.votes[currentUser];
    final tally = poll.tally;
    final winningId = poll.winningOptionId;
    final totalVotes = poll.votes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClosed
              ? AppColors.softLavender.withValues(alpha: 0.2)
              : AppColors.blushGold.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isClosed
                      ? AppColors.softLavender.withValues(alpha: 0.15)
                      : AppColors.warmAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isClosed ? 'Closed' : 'Open',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isClosed
                        ? AppColors.softLavender
                        : AppColors.warmAmber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.title,
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 14,
                    color: AppTheme.petalWhite,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: AppTheme.petalWhite.withValues(alpha: 0.5),
                ),
                onPressed: () => _showPollMenu(context, poll, currentUser),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (poll.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              poll.description,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                color: AppTheme.petalWhite.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'by ${poll.createdBy} • ${DateFormat.MMMd().format(poll.createdAt)} • $totalVotes vote${totalVotes == 1 ? '' : 's'}',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 10,
              color: AppTheme.petalWhite.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          ...poll.options.map((opt) {
            final count = tally[opt.id] ?? 0;
            final isWinning = opt.id == winningId && totalVotes > 0;
            final isMyVote = myVote == opt.id;
            final pct = totalVotes == 0 ? 0.0 : count / totalVotes;
            return GestureDetector(
              onTap: isClosed
                  ? null
                  : () => _vote(context, poll, opt.id, currentUser),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMyVote
                      ? AppColors.deepRose.withValues(alpha: 0.18)
                      : AppColors.twilight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMyVote
                        ? AppColors.blushGold
                        : isWinning
                        ? AppColors.warmAmber.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isMyVote
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isMyVote
                              ? AppColors.blushGold
                              : AppTheme.petalWhite.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt.label,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 13,
                              fontWeight: isMyVote
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ),
                        if (isWinning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warmAmber.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Leading',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warmAmber,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '$count',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 13,
                            color: isMyVote
                                ? AppColors.blushGold
                                : AppTheme.petalWhite.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: AppColors.moonlight.withValues(
                          alpha: 0.12,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          isMyVote ? AppColors.blushGold : AppColors.auroraTeal,
                        ),
                      ),
                    ),
                    if (poll.votes.entries
                        .where((e) => e.value == opt.id)
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: poll.votes.entries
                            .where((e) => e.value == opt.id)
                            .map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.moonlight.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  e.key,
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 10,
                                    color: AppTheme.petalWhite.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          if (!isClosed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _vote(
                      context,
                      poll,
                      poll.options.first.id,
                      currentUser,
                    ),
                    icon: const Icon(
                      Icons.how_to_vote_rounded,
                      size: 14,
                      color: AppColors.blushGold,
                    ),
                    label: Text(
                      'Vote',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.blushGold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.blushGold.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _finalizePoll(context, poll),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Finalize',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (poll.decidedOptionId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warmAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warmAmber.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    size: 16,
                    color: AppColors.warmAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Decided: ${poll.options.firstWhere((o) => o.id == poll.decidedOptionId, orElse: () => poll.options.first).label}',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.warmAmber,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => CalendarPollService().reopen(poll.id),
                    child: Text(
                      'Reopen',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _vote(
    BuildContext context,
    DatePoll poll,
    String optionId,
    String username,
  ) {
    if (username.isEmpty) return;
    CalendarPollService().vote(poll.id, username, optionId);
  }

  void _finalizePoll(BuildContext context, DatePoll poll) async {
    final winning = poll.winningOptionId;
    if (winning == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No votes yet'),
          backgroundColor: AppColors.deepRose,
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.velvet,
        title: Text(
          'Finalize poll?',
          style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite),
        ),
        content: Text(
          'This will close the poll and create a calendar event for the winning date.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppTheme.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Finalize',
              style: TextStyle(color: AppColors.blushGold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await CalendarPollService().close(poll.id, winning);
    // Create calendar event for winners
    final opt = poll.options.firstWhere((o) => o.id == winning);
    final event = CalendarEvent(
      id: '',
      title: poll.title,
      description: 'Decided via poll: ${poll.title}',
      date: opt.date,
      type: CalendarEventType.dateNight,
      createdBy: poll.createdBy,
      attendees: poll.votes.keys.toList(),
    );
    await CalendarService().addEvent(event);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Poll finalized & event created!'),
          backgroundColor: AppColors.deepRose,
        ),
      );
    }
  }

  void _showPollMenu(BuildContext context, DatePoll poll, String currentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                'Delete poll',
                style: AppTypography.outfitWhite.copyWith(
                  color: Colors.redAccent,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await CalendarPollService().delete(poll.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
