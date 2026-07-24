import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../widgets/background_texture.dart';

class StaffLayout extends StatelessWidget {
  final Widget child;
  final int currentTabIndex;
  final String? title;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final Widget? endDrawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const StaffLayout({
    super.key,
    required this.child,
    required this.currentTabIndex,
    this.title,
    this.appBarActions,
    this.floatingActionButton,
    this.endDrawer,
    this.scaffoldKey,
  });

  static final _tabs = [
    _TabItem('tasks', Icons.checklist_outlined, Icons.checklist, 0),
    _TabItem('notes', Icons.notes_outlined, Icons.notes, 1),
    _TabItem('rooms', Icons.meeting_room_outlined, Icons.meeting_room, 2),
    _TabItem('chat', Icons.chat_outlined, Icons.chat, 3),
    _TabItem('aiChat', Icons.smart_toy_outlined, Icons.smart_toy, 4),
  ];

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Routefly.navigate('/staff/home/staff_dashboard');
        break;
      case 1:
        Routefly.navigate('/shared/notes');
        break;
      case 2:
        Routefly.navigate('/staff/home/staff_rooms');
        break;
      case 3:
        Routefly.navigate('/shared/chat');
        break;
      case 4:
        Routefly.navigate('/shared/chat/ai_chat');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        selectedIndex: currentTabIndex,
        onDestinationSelected: (index) => _onTabTapped(context, index),
        destinations: _tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: localizations.tr(tab.labelKey),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String labelKey;
  final IconData icon;
  final IconData activeIcon;
  final int index;

  const _TabItem(this.labelKey, this.icon, this.activeIcon, this.index);
}
