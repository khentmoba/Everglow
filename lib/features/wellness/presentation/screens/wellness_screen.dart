import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../../heartbeat/data/services/mood_service.dart';
import '../../data/models/habit.dart';
import '../../data/models/workout.dart';
import '../../data/services/wellness_service.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  int _tabIndex = 0; // 0 habits, 1 workouts, 2 insights

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
        return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: [const RadialGlow(color: AppColors.auroraRose, alignment: Alignment(-0.6, -0.8), size: 0.85, opacity: 0.12)],
      showPetals: true,
      body: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Wellness',
                  subtitle: 'grow together • Habitica × wger',
                  icon: Icons.favorite_rounded,
                  hue: AppColors.auroraRose,
                  actions: [
                    EverglowIconButton(
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddDialog(auth),
                      semanticLabel: '''Add habit or workout''',
                      tooltip: '''Add''',
                      iconColor: AppColors.blushGold,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    activeColor: AppColors.auroraRose,
                    items: const [
                      SegmentItem('Habits', Icons.check_circle_rounded),
                      SegmentItem('Workouts', Icons.fitness_center_rounded),
                      SegmentItem('Insights', Icons.insights_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _tabIndex == 0
                      ? _HabitsTab(auth: auth)
                      : _tabIndex == 1
                      ? _WorkoutsTab(auth: auth)
                      : _InsightsTab(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(auth),
        backgroundColor: AppColors.deepRose,
        foregroundColor: Colors.white,
        child: Icon(
          _tabIndex == 1 ? Icons.fitness_center_rounded : Icons.add_rounded,
        ),
      ),
    );
  }

  void _showAddDialog(AuthService auth) {
    if (_tabIndex == 1) {
      _showAddWorkoutDialog(auth);
    } else {
      _showAddHabitDialog(auth);
    }
  }

  void _showAddHabitDialog(AuthService auth) {
    final titleCtrl = TextEditingController();
    HabitCategory cat = HabitCategory.health;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            backgroundColor: AppColors.velvet,
            title: Text(
              'New Habit 🌱',
              style: AppTypography.cormorantBold.copyWith(
                color: AppColors.petalWhite,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., Meditate together 10 min',
                    hintStyle: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: AppColors.twilight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: HabitCategory.values.map((c) {
                    final sel = cat == c;
                    return GestureDetector(
                      onTap: () => setDlg(() => cat = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.deepRose.withValues(alpha: 0.25)
                              : AppColors.twilight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? AppColors.blushGold : AppColors.border,
                          ),
                        ),
                        child: Text(
                          c.name,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: sel
                                ? AppColors.blushGold
                                : AppColors.petalWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  await WellnessService().addHabit(
                    Habit(
                      id: '',
                      title: title,
                      category: cat,
                      createdBy: auth.currentUser ?? 'unknown',
                      createdAt: DateTime.now(),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepRose,
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddWorkoutDialog(AuthService auth) {
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    WorkoutCategory cat = WorkoutCategory.other;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            backgroundColor: AppColors.velvet,
            title: Text(
              'Log Workout 💪',
              style: AppTypography.cormorantBold.copyWith(
                color: AppColors.petalWhite,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., Evening run • Yoga',
                    hintStyle: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: AppColors.twilight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Minutes',
                          labelStyle: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: AppColors.twilight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.twilight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<WorkoutCategory>(
                          value: cat,
                          isExpanded: true,
                          dropdownColor: AppColors.twilight,
                          underline: const SizedBox(),
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite,
                            fontSize: 12,
                          ),
                          items: WorkoutCategory.values
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setDlg(() => cat = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final mins = int.tryParse(durationCtrl.text.trim()) ?? 30;
                  await WellnessService().addWorkout(
                    Workout(
                      id: '',
                      title: title,
                      category: cat,
                      durationMinutes: mins,
                      createdBy: auth.currentUser ?? 'unknown',
                      date: DateTime.now(),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepRose,
                ),
                child: const Text('Log', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HabitsTab extends StatelessWidget {
  final AuthService auth;
  const _HabitsTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    final service = WellnessService();
    return EverglowStreamView<List<Habit>>(
      stream: service.watchHabits(),
      streamLabel: 'wellness-habits',
      errorMessage: 'Could not load habits',
      errorIcon: Icons.check_circle_outline_rounded,
      loadingView: const Padding(
        padding: EdgeInsets.all(16),
        child: EverglowSkeleton(height: 120, radius: 16),
      ),
      isEmpty: (habits) => habits.isEmpty,
      emptyView: const EverglowEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No habits yet',
        subtitle: 'Create a shared habit — Habitica style streaks',
        ctaLabel: null,
      ),
      builder: (context, habits) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: habits.length,
          itemBuilder: (context, idx) {
            final h = habits[idx];
            final doneToday = h.isCompletedToday;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelGlass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: doneToday
                      ? AppColors.success.withValues(alpha: 0.22)
                      : AppColors.moonlight.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: doneToday ? 'Mark ${h.title} as not done' : 'Mark ${h.title} as done',
                    child: FocusableActionDetector(
                      shortcuts: const {
                        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                      },
                      actions: {
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) {
                            service.toggleCompleteToday(h.id, auth.currentUser ?? '');
                            return null;
                          },
                        ),
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => service.toggleCompleteToday(
                            h.id,
                            auth.currentUser ?? '',
                          ),
                          child: Container(
                            width: 44,
                            height: 44,
                      decoration: BoxDecoration(
                        color: doneToday
                            ? AppColors.success
                            : AppColors.twilight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: doneToday
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        doneToday ? Icons.check_rounded : Icons.circle_outlined,
                        size: 18,
                        color: doneToday
                            ? Colors.white
                            : AppColors.petalWhite.withValues(alpha: 0.6),
                      ),
                    ),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title,
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 13,
                            color: AppColors.petalWhite,
                            decoration: doneToday
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.auroraLilac.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                h.category.name,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10,
                                  color: AppColors.auroraLilac,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 12,
                              color: AppColors.warmAmber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${h.streak} day streak',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 10,
                                color: AppColors.warmAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'best ${h.longestStreak}',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 10,
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => service.deleteHabit(h.id),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.petalWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WorkoutsTab extends StatelessWidget {
  final AuthService auth;
  const _WorkoutsTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    final service = WellnessService();
    return EverglowStreamView<List<Workout>>(
      stream: service.watchWorkouts(),
      streamLabel: 'wellness-workouts',
      errorMessage: 'Could not load workouts',
      errorIcon: Icons.fitness_center_rounded,
      isEmpty: (workouts) => workouts.isEmpty,
      emptyView: const EverglowEmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'No workouts yet',
        subtitle: 'Log a wger-style workout together',
        ctaLabel: null,
      ),
      builder: (context, workouts) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: workouts.length,
          itemBuilder: (context, idx) {
            final w = workouts[idx];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelGlass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.auroraTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _workoutIcon(w.category),
                      size: 18,
                      color: AppColors.auroraTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.title,
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 13,
                            color: AppColors.petalWhite,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${w.durationMinutes} min • ${w.category.name} • ${w.date.month}/${w.date.day} • by ${w.createdBy}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => service.deleteWorkout(w.id),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.petalWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _workoutIcon(WorkoutCategory c) {
    switch (c) {
      case WorkoutCategory.strength:
        return Icons.fitness_center_rounded;
      case WorkoutCategory.cardio:
        return Icons.directions_run_rounded;
      case WorkoutCategory.flexibility:
        return Icons.self_improvement_rounded;
      case WorkoutCategory.sports:
        return Icons.sports_basketball_rounded;
      case WorkoutCategory.other:
        return Icons.sports_gymnastics_rounded;
    }
  }
}

class _InsightsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final wellness = WellnessService();
    final moods = MoodService();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        FutureBuilder<Map<String, int>>(
          future: wellness.getWeeklyStreaks(),
          builder: (context, snap) {
            final data =
                snap.data ?? {'total': 0, 'completedToday': 0, 'avgStreak': 0};
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panelGlass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        size: 16,
                        color: AppColors.blushGold,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Insight',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStat(
                        '${data['completedToday']}/${data['total']}',
                        'done today',
                        AppColors.success,
                      ),
                      _buildDivider(),
                      _buildStat(
                        '${data['avgStreak']}',
                        'avg streak',
                        AppColors.warmAmber,
                      ),
                      _buildDivider(),
                      _buildStat(
                        '${data['total']}',
                        'habits',
                        AppColors.auroraLilac,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Habitica gamifies consistency — keep your streaks together!',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppColors.petalWhite.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.twilight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.mood_rounded,
                    size: 16,
                    color: AppColors.auroraLilac,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mood × Wellness',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 12,
                      color: AppColors.petalWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Link your heartbeat moods to workouts — coming soon: correlate moodScore vs activity. Data from moods collection (last 7 days).',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder(
                stream: moods.watchLatestMood('khentsgdz'),
                builder: (context, snap) {
                  final mood = snap.data;
                  if (mood == null) {
                    return Text(
                      'No mood data yet',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.petalWhite.withValues(alpha: 0.5),
                      ),
                    );
                  }
                  return Text(
                    'Khent latest: ${mood.moodEmoji} ${mood.moodScore}/5 • ${mood.timestamp.month}/${mood.timestamp.day}',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppColors.auroraLilac,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label, Color hue) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: AppTypography.outfitBold.copyWith(fontSize: 16, color: hue),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 10,
            color: AppColors.petalWhite.withValues(alpha: 0.6),
          ),
        ),
      ],
    ),
  );

  Widget _buildDivider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppColors.border,
  );
}