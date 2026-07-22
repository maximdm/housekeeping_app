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

  const AdminLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.title,
    this.appBarActions,
    this.floatingActionButton,
    this.endDrawer,
    this.scaffoldKey,
  });

  static const _navItems = [
    _NavItem('Overview', Icons.dashboard_outlined, Icons.dashboard, '/admin/overview'),
    _NavItem('Rooms', Icons.meeting_room_outlined, Icons.meeting_room, '/admin/rooms'),
    _NavItem('Staff', Icons.people_outline, Icons.people, '/admin/staff'),
    _NavItem('Chat', Icons.chat_outlined, Icons.chat, '/shared/chat'),
    _NavItem('Notes', Icons.notes_outlined, Icons.notes, '/shared/notes'),
    _NavItem('AI Chat', Icons.smart_toy_outlined, Icons.smart_toy, '/shared/chat/ai_chat'),
  ];

  int get _selectedIndex {
    for (int i = 0; i < _navItems.length; i++) {
      if (currentRoute == _navItems[i].route) return i;
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
        title: Text(title ?? 'Housekeeping'),
        automaticallyImplyLeading: false,
        actions: [
          ...?appBarActions,
          IconButton(
            icon: Icon(
              themeService.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => themeService.toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Change Password',
            onPressed: () {
              Routefly.navigate('/staff/settings/change_password');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
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
      floatingActionButton: floatingActionButton ?? FloatingActionButton(
        heroTag: 'admin_chat_fab',
        onPressed: () {
          Routefly.navigate('/shared/chat');
        },
        tooltip: 'Team Chat',
        child: const Icon(Icons.chat_bubble_outline),
      ),
      endDrawer: endDrawer,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index != _selectedIndex) {
            Routefly.navigate(_navItems[index].route);
          }
        },
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
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
                Icon(
                  Icons.cleaning_services_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Housekeeping',
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
          ..._navItems.map((item) => _buildNavItem(context, item, extended)),
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
                            themeService.isDark ? 'Light Mode' : 'Dark Mode',
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
                            'Change Password',
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
                        child: Text(item.label),
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
                      'Sign Out',
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
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem(this.label, this.icon, this.activeIcon, this.route);
}
