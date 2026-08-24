import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adds consistent Enter/Space activation to custom Everglow controls.
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
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
      },
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
