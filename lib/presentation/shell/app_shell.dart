import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/session.dart';
import '../connectivity/maintenance_overlay.dart';
import '../session/session_bloc.dart';
import 'nav_catalog.dart';
import 'nav_destination.dart';
import 'session_context_label.dart';
import 'shell_content.dart';

const double _desktopBreakpoint = 900;
const double _sidebarExpandedWidth = 232;
const double _sidebarCollapsedWidth = 72;

/// Responsive operations-console chrome: sidebar / drawer + top bar + content.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.initialPath});

  final String initialPath;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  String get _path => NavCatalog.normalizePath(widget.initialPath);

  void _openPath(String path, {bool closeDrawer = false}) {
    final normalized = NavCatalog.normalizePath(path);
    if (closeDrawer) {
      Navigator.of(context).pop();
    }
    if (normalized == _path) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(normalized);
  }

  String _pageTitle(Me me) {
    final destination = NavCatalog.byPath(_path);
    if (destination == null) {
      return 'Not found';
    }
    if (!destination.isAllowed(me)) {
      return 'Access denied';
    }
    return destination.label;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        final me = state.me;
        if (me == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final visible = NavCatalog.visibleDestinations(me);
        final width = MediaQuery.sizeOf(context).width;
        final useRail = width >= _desktopBreakpoint;

        return Stack(
          children: [
            Scaffold(
              appBar: _ShellAppBar(
                title: _pageTitle(me),
                me: me,
                showMenuButton: !useRail,
                onSignOut: () =>
                    context.read<SessionBloc>().add(const SignOutRequested()),
              ),
              drawer: useRail
                  ? null
                  : _ShellDrawer(
                      destinations: visible,
                      currentPath: _path,
                      onSelect: (path) => _openPath(path, closeDrawer: true),
                    ),
              body: Column(
                children: [
                  const RealtimeReconnectingBanner(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (useRail)
                          _ShellSidebar(
                            destinations: visible,
                            currentPath: _path,
                            collapsed: _sidebarCollapsed,
                            onToggleCollapse: () {
                              setState(
                                () => _sidebarCollapsed = !_sidebarCollapsed,
                              );
                            },
                            onSelect: _openPath,
                          ),
                        Expanded(
                          child: ColoredBox(
                            color: const Color(0xFFF3F6F7),
                            child: ShellContent(me: me, path: _path),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const MaintenanceOverlay(),
          ],
        );
      },
    );
  }
}

class _ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellAppBar({
    required this.title,
    required this.me,
    required this.showMenuButton,
    required this.onSignOut,
  });

  final String title;
  final Me me;
  final bool showMenuButton;
  final VoidCallback onSignOut;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final city = SessionContextLabel.cityDisplay(me);
    final role = SessionContextLabel.roleWire(me.role);

    return AppBar(
      automaticallyImplyLeading: showMenuButton,
      titleSpacing: showMenuButton ? null : 20,
      title: Text(title),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                me.user.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$role · $city',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _ShellSidebar extends StatelessWidget {
  const _ShellSidebar({
    required this.destinations,
    required this.currentPath,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final String currentPath;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = collapsed ? _sidebarCollapsedWidth : _sidebarExpandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: const Color(0xFF0B1F2A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? 12 : 16,
                16,
                collapsed ? 12 : 8,
                8,
              ),
              child: Row(
                children: [
                  if (!collapsed)
                    Expanded(
                      child: Text(
                        'badrgo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    onPressed: onToggleCollapse,
                    color: Colors.white70,
                    icon: Icon(
                      collapsed ? Icons.chevron_right : Icons.chevron_left,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final item in destinations)
                    _NavTile(
                      destination: item,
                      selected: item.path == currentPath,
                      collapsed: collapsed,
                      dense: false,
                      onTap: () => onSelect(item.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.destinations,
    required this.currentPath,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final String currentPath;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0B1F2A)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'badrgo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final item in destinations)
                    _NavTile(
                      destination: item,
                      selected: item.path == currentPath,
                      collapsed: false,
                      dense: true,
                      onTap: () => onSelect(item.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.dense,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool collapsed;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return ListTile(
        leading: Icon(destination.icon),
        title: Text(destination.label),
        selected: selected,
        onTap: onTap,
      );
    }

    final fg = selected ? Colors.white : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF1A4A5C) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Tooltip(
            message: destination.label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12,
                vertical: 12,
              ),
              child: collapsed
                  ? Center(child: Icon(destination.icon, color: fg, size: 22))
                  : Row(
                      children: [
                        Icon(destination.icon, color: fg, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            destination.label,
                            style: TextStyle(
                              color: fg,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
