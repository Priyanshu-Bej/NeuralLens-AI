import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/scripts/ui/script_actions.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/pressable.dart';

/// Shell for the three primary tabs: a floating glass tab bar plus a
/// create button, with page content scrolling underneath.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.layers_outlined, Icons.layers_rounded, 'Library'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = context.nl.background;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 0.9)],
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: Space.md),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter - 4,
              Space.lg,
              Space.gutter - 4,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GlassPanel(
                    radius: Radii.pill,
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      children: [
                        for (var i = 0; i < _destinations.length; i++)
                          Expanded(
                            child: _NavItem(
                              icon: _destinations[i].$1,
                              selectedIcon: _destinations[i].$2,
                              label: _destinations[i].$3,
                              selected: shell.currentIndex == i,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                shell.goBranch(
                                  i,
                                  initialLocation: i == shell.currentIndex,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                const _CreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.emphasized,
          height: 54,
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? c.accentText : c.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.text.labelMedium!.copyWith(
                  fontSize: 11,
                  color: selected ? c.textPrimary : c.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Pressable(
      scale: 0.9,
      child: Tooltip(
        message: 'Create',
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: c.brandGradient,
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: context.isDark ? 0.3 : 0.5),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                showCreateSheet(context);
              },
              child: SizedBox.square(
                dimension: 64,
                child: Icon(Icons.add_rounded, size: 30, color: c.onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
