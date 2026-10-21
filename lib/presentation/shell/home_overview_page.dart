import 'package:flutter/material.dart';

import '../../domain/entities/session.dart';
import 'nav_catalog.dart';

/// Authenticated landing content inside the shell (not a fake feature module).
class HomeOverviewPage extends StatelessWidget {
  const HomeOverviewPage({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = NavCatalog.visibleDestinations(
      me,
    ).where((d) => d.path != AppPaths.home).toList();

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${me.user.name}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the navigation to open modules you are allowed to access. '
                'Access is based on permissions from the server, not your role name.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Available modules',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Text(
                  'No feature modules are available for this account yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in visible)
                      ActionChip(
                        avatar: Icon(item.icon, size: 18),
                        label: Text(item.label),
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(item.path);
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
