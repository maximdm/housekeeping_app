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

  static const _tabs = [
    _TabItem('Tasks', Icons.checklist_outlined, Icons.checklist, 0),
    _TabItem('Rooms', Icons.meeting_room_outlined, Icons.meeting_room, 1),
    _TabItem('Chat', Icons.chat_outlined, Icons.chat, 2),
    _TabItem('AI', Icons.smart_toy_outlined, Icons.smart_toy, 3),
    _TabItem('Notes', Icons.notes_outlined, Icons.notes, 4),
  ];

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Routefly.navigate('/staff/home/staff_dashboard');
        break;
      case 1:
        Routefly.navigate('/staff/home/staff_rooms');
        break;
      case 2:
        Routefly.navigate('/shared/chat');
        break;
      case 3:
        Routefly.navigate('/shared/chat/ai_chat');
        break;
      case 4:
        Routefly.navigate('/shared/notes');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int index;

  const _TabItem(this.label, this.icon, this.activeIcon, this.index);
}
