import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../data/services/ai_service.dart';

class MotchiPreferencesScreen extends StatefulWidget {
  const MotchiPreferencesScreen({super.key});

  @override
  State<MotchiPreferencesScreen> createState() =>
      _MotchiPreferencesScreenState();
}

class _MotchiPreferencesScreenState extends State<MotchiPreferencesScreen> {
  Map<String, dynamic>? _preferences;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final result = await context.read<AIService>().companionOperation('load');
      if (mounted) {
        setState(
          () => _preferences = Map<String, dynamic>.from(
            result['preferences'] as Map,
          ),
        );
      }
    } catch (e) {
      Logger.e('Motchi preferences failed to load', error: e);
      if (mounted) {
        setState(() => _error = 'Could not load your preferences. Try again.');
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AIService>().companionOperation(
        'preferences',
        value: _preferences,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your Motchi preferences are saved.')),
      );
      if (Navigator.of(context).canPop()) Navigator.pop(context);
    } catch (e) {
      Logger.e('Motchi preferences failed to save', error: e);
      if (mounted) {
        setState(() => _error = 'Could not save your preferences. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _hour(int hour) =>
      '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'AM' : 'PM'}';

  Widget _hours(String label, String field) => DropdownButtonFormField<int>(
    initialValue: _preferences![field] as int,
    decoration: InputDecoration(labelText: label),
    items: List.generate(
      24,
      (h) => DropdownMenuItem(value: h, child: Text(_hour(h))),
    ),
    onChanged: _saving
        ? null
        : (value) => setState(() => _preferences![field] = value),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.inkDeep,
    appBar: AppBar(
      title: const Text('Motchi preferences'),
      backgroundColor: AppColors.inkDeep,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _preferences == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_error == null)
                      const CircularProgressIndicator()
                    else ...[
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const Text(
                      'A little help, at your pace.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'These choices are just for you. Reminders you ask for still arrive at their scheduled time.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _preferences!['nudges'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Helpful nudges',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('At most once a day'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('At most once a week'),
                        ),
                        DropdownMenuItem(value: 'off', child: Text('Off')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _preferences!['nudges'] = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Morning and evening recaps'),
                      subtitle: const Text('Includes the weekly recap.'),
                      value: _preferences!['digests'] == true,
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _preferences!['digests'] = value,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Quiet hours · Philippine time'),
                    const SizedBox(height: AppSpacing.md),
                    _hours('Quiet hours start', 'quietStart'),
                    const SizedBox(height: AppSpacing.md),
                    _hours('Quiet hours end', 'quietEnd'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Choose the same start and end time to turn quiet hours off. Messages skipped during quiet hours are not queued.',
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    EverglowButton(
                      onPressed: _saving ? null : _save,
                      label: _saving ? 'Saving…' : 'Save preferences',
                      enabled: !_saving,
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}
