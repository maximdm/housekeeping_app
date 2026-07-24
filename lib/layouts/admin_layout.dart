import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../widgets/background_texture.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final String? title;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final Widget? endDrawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool isFullAdmin;

  const AdminLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.title,
    this.appBarActions,
    this.floatingActionButton,
    this.endDrawer,
    this.scaffoldKey,
    this.isFullAdmin = true,
  });

  static final _navItems = [
    _NavItem('overview', Icons.dashboard_outlined, Icons.dashboard, '/admin/overview'),
    _NavItem('rooms', Icons.meeting_room_outlined, Icons.meeting_room, '/admin/rooms'),
    _NavItem('staff', Icons.people_outline, Icons.people, '/admin/staff'),
    _NavItem('chat', Icons.chat_outlined, Icons.chat, '/shared/chat'),
    _NavItem('notes', Icons.notes_outlined, Icons.notes, '/shared/notes'),
    _NavItem('aiChat', Icons.smart_toy_outlined, Icons.smart_toy, '/shared/chat/ai_chat'),
  ];

  List<_NavItem> get _visibleNavItems => _navItems;

  int get _selectedIndex {
    for (int i = 0; i < _visibleNavItems.length; i++) {
      if (currentRoute == _visibleNavItems[i].route) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return _buildDesktopLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        _buildSidebar(context, extended: true),
        Expanded(
          child: Scaffold(
            key: scaffoldKey,
            appBar: (title != null || appBarActions != null)
                ? AppBar(
                    title: title != null ? Text(title!) : null,
                    actions: appBarActions,
                  )
                : null,
            body: BackgroundTexture(child: child),
            endDrawer: endDrawer,
            floatingActionButton: floatingActionButton,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(title ?? localizations.tr('housekeeping')),
        automaticallyImplyLeading: false,
        actions: [
          ...?appBarActions,
          IconButton(
            icon: Icon(
              themeService.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: localizations.tr('toggleTheme'),
            onPressed: () => themeService.toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: localizations.tr('changePassword'),
            onPressed: () {
              Routefly.navigate('/staff/settings/change_password');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: localizations.tr('signOut'),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Routefly.navigate('/splash');
              }
            },
          ),
        ],
      ),
      body: BackgroundTexture(child: child),
      floatingActionButton: floatingActionButton,
      endDrawer: endDrawer,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index != _selectedIndex) {
            Routefly.navigate(_visibleNavItems[index].route);
          }
        },
        destinations: _visibleNavItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: localizations.tr(item.labelKey),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool extended}) {
    return Container(
      width: extended ? 240 : 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/icons/icon_hk_app.png',
                  width: 28,
                  height: 28,
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations.tr('housekeeping'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ..._visibleNavItems.map((item) => _buildNavItem(context, item, extended)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => themeService.toggle(),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        themeService.isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      if (extended) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            themeService.isDark ? localizations.tr('lightMode') : localizations.tr('darkMode'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Routefly.navigate('/staff/settings/change_password'),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      if (extended) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            localizations.tr('changePassword'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          _buildLogoutButton(context, extended),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, _NavItem item, bool extended) {
    final isSelected = currentRoute == item.route;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (!isSelected) {
                Routefly.navigate(item.route);
              }
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      key: ValueKey(isSelected),
                      color: color,
                      size: 22,
                    ),
                  ),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: color,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                        child: Text(localizations.tr(item.labelKey)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool extended) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Routefly.navigate('/splash');
            }
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                  size: 22,
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations.tr('signOut'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String labelKey;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem(this.labelKey, this.icon, this.activeIcon, this.route);
}
