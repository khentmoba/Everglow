import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/motchi_reply_details.dart';

/// A compact receipt under the reply, kept when the conversation reloads.
class MotchiReplyDetailsCard extends StatelessWidget {
  final MotchiReplyDetails details;
  final ValueChanged<String>? onCorrectMemory;
  final VoidCallback? onOpenMemoryBook;
  final VoidCallback? onContinue;

  const MotchiReplyDetailsCard({
    super.key,
    required this.details,
    this.onCorrectMemory,
    this.onOpenMemoryBook,
    this.onContinue,
  });

  Future<void> _inspectMemory(
    BuildContext context,
    Map<String, dynamic> memory,
  ) async {
    final controller = TextEditingController(text: '${memory['fact'] ?? ''}');
    final correction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: const Text('Memory behind this reply'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MotchiReplyDetails.owner(memory),
                style: AppTypography.labelSmall(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${memory['fact'] ?? ''}', style: AppTypography.bodySmall()),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'This is the saved fact Motchi cited for this reply. If it has changed, tell her the correct version.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Correct version'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (onCorrectMemory != null)
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && text != memory['fact']) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text('Ask Motchi to correct it'),
            ),
        ],
      ),
    );
    // Wait for the dialog's closing transition before disposing its field.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (correction != null && context.mounted) {
      onCorrectMemory?.call(
        'Correct the saved memory with memory_id "${memory['id']}": "$correction". Use edit_memory to update this exact id, not remember_fact; update only this fact and do not turn one person\'s preference into a shared preference.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (details.steps.isNotEmpty || details.interrupted) ...[
            Text('What happened', style: AppTypography.labelSmall()),
            const SizedBox(height: AppSpacing.xs),
            Text(details.summary, style: AppTypography.bodySmall()),
            for (final step in details.steps) ...[
              const SizedBox(height: AppSpacing.sm),
              _StepRow(step: step),
            ],
          ],
          if (details.needsAttention && onContinue != null)
            TextButton(
              onPressed: onContinue,
              child: const Text('Help finish unfinished steps'),
            ),
          if (details.memories.isNotEmpty) ...[
            if (details.steps.isNotEmpty) const SizedBox(height: AppSpacing.md),
            Text('Memories Motchi cited', style: AppTypography.labelSmall()),
            Text(
              'These saved facts helped shape this reply.',
              style: AppTypography.bodySmall(),
            ),
            for (final memory in details.memories)
              TextButton(
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: () => _inspectMemory(context, memory),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology_outlined,
                      size: 18,
                      color: AppColors.softLavender,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${MotchiReplyDetails.owner(memory)} · ${memory['fact']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            if (onOpenMemoryBook != null)
              TextButton(
                onPressed: onOpenMemoryBook,
                child: const Text('Open Memory Book'),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final Map<String, dynamic> step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final status = '${step['status']}';
    final (icon, label, color) = switch (status) {
      'done' => (Icons.check_circle_outline, 'Done', AppColors.softLavender),
      'waiting' => (Icons.help_outline, 'Waiting for you', AppColors.blushGold),
      'failed' => (Icons.error_outline, 'Did not complete', AppColors.error),
      'unscheduled' => (
        Icons.schedule,
        'Saved, but not scheduled',
        AppColors.blushGold,
      ),
      _ => (Icons.help_outline, 'Could not confirm', AppColors.blushGold),
    };
    final tool = '${step['tool'] ?? ''}'.replaceAll('_', ' ');
    final title = '${step['title'] ?? ''}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color, semanticLabel: label),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '$label · $tool${title.isEmpty ? '' : '\n$title'}',
            style: AppTypography.bodySmall(),
          ),
        ),
      ],
    );
  }
}
