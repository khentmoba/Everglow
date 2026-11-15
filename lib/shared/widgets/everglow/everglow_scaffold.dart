import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_breakpoints.dart';
import 'everglow_background.dart';
import 'everglow_app_bar.dart';
import 'everglow_pill_nav.dart';

class EverglowScaffold extends StatelessWidget {
  final Widget body;
  final EverglowAppBar? appBar;
  final List<EverglowNavItem>? navItems;
  final int? navIndex;
  final ValueChanged<int>? onNavTap;
  final bool extendBody;
  final Color? backgroundColor;
  final List<RadialGlow>? glows;
  final bool showPetals;
  final double? centerMaxWidth;
  final Widget? floatingActionButton;

  const EverglowScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.navItems,
    this.navIndex,
    this.onNavTap,
    this.extendBody = true,
    this.backgroundColor,
    this.glows,
    this.showPetals = false,
    this.centerMaxWidth,
    this.floatingActionButton,
  });

  const EverglowScaffold.cinema({
    super.key,
    required this.body,
    this.appBar,
    this.navItems,
    this.navIndex,
    this.onNavTap,
    this.extendBody = true,
    this.backgroundColor = AppColors.animeBackground,
    this.showPetals = false,
    this.centerMaxWidth,
    this.floatingActionButton,
  }) : glows = const [
         RadialGlow(
           color: AppColors.deepRose,
           alignment: Alignment(-0.8, -0.9),
           size: 0.7,
           opacity: 0.12,
         ),
         RadialGlow(
           color: AppColors.softLavender,
           alignment: Alignment(0.9, 0.8),
           size: 0.65,
           opacity: 0.08,
         ),
       ];

  @override
  Widget build(BuildContext context) {
    final maxWidth = centerMaxWidth ?? _responsiveMaxWidth(context);
    final hasNav = navItems != null && navItems!.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.twilight,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          if (glows != null)
            EverglowBackground(
              baseColor: backgroundColor ?? AppColors.twilight,
              glows: glows!,
              showPetals: showPetals,
            )
          else
            EverglowBackground(
              baseColor: backgroundColor ?? AppColors.twilight,
              showPetals: showPetals,
            ),

          SafeArea(
            bottom: !hasNav,
            child: Column(
              children: [
                ?appBar,

                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (hasNav)
            EverglowPillNav(
              items: navItems!,
              currentIndex: navIndex ?? 0,
              onTap: onNavTap ?? (_) {},
            ),
        ],
      ),
    );
  }

  double _responsiveMaxWidth(BuildContext context) {
    final bp = AppBreakpoint.of(context);
    return switch (bp) {
      BreakpointSize.mobile => 500,
      BreakpointSize.tablet => 720,
      BreakpointSize.desktop => 960,
    };
  }
}
