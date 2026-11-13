import 'package:flutter/material.dart';

import '../../../core/system/tv_mode.dart';

/// Adds consistent Enter/Space/Select activation to custom Everglow controls.
///
/// Pointer handling stays with the wrapped widget; this only supplies the
/// keyboard equivalent and a focusable anchor for assistive navigation.
class EverglowKeyboardActivation extends StatelessWidget {
  final Widget child;
  final VoidCallback? onActivate;
  final bool enabled;

  const EverglowKeyboardActivation({
    super.key,
    required this.child,
    required this.onActivate,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final canActivate = enabled && onActivate != null;

    return FocusableActionDetector(
      enabled: canActivate,
      shortcuts: TvMode.activateShortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (canActivate) onActivate!();
            return null;
          },
        ),
      },
      child: child,
    );
  }
}
