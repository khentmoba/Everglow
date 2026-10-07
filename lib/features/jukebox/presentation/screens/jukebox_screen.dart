import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/everglow/everglow_app_bar.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../widgets/jukebox_widget.dart';

class JukeboxScreen extends StatelessWidget {
  const JukeboxScreen({super.key});

  @override
  Widget build(BuildContext context) => const EverglowScaffold(
    appBar: EverglowAppBar(title: 'Jukebox'),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: JukeboxWidget(),
    ),
  );
}
