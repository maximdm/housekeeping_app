import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forui/forui.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';
import 'main.route.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

part 'main.g.dart';

final themeService = ThemeService();
final localizations = AppLocalizations.instance;
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
ScaffoldMessengerState get appMessenger => scaffoldMessengerKey.currentState!;

Timer? _snackBarDismissTimer;

void showTimedSnackBar(SnackBar snackbar) {
  _snackBarDismissTimer?.cancel();
  appMessenger.clearSnackBars();
  final duration = snackbar.duration;
  appMessenger.showSnackBar(snackbar);
  if (duration < const Duration(hours: 1)) {
    _snackBarDismissTimer = Timer(duration, () {
      appMessenger.hideCurrentSnackBar();
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  await DatabaseHelper.init();
  await NotificationService().init();
  await themeService.init();
  await localizations.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const HousekeepingApp());
}

@Main('lib/app')
class HousekeepingApp extends StatelessWidget {
  const HousekeepingApp({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);

    final lightColors = FTheme.neutral.light.touch.colors.copyWith(
      primary: red,
      primaryForeground: const Color(0xFFFFFFFF),
      destructive: red,
    );
    final lightTheme = FThemeData(touch: true, colors: lightColors);

    final darkColors = FTheme.neutral.dark.touch.colors.copyWith(
      primary: red,
      primaryForeground: const Color(0xFFFFFFFF),
      destructive: red,
    );
    final darkTheme = FThemeData(touch: true, colors: darkColors);

    return ListenableBuilder(
      listenable: Listenable.merge([themeService, localizations]),
      builder: (context, _) {
        final isDark = themeService.isDark;
        final activeTheme = isDark ? darkTheme : lightTheme;

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ro'),
          ],
          locale: Locale(localizations.localeCode),
          theme: lightTheme.toApproximateMaterialTheme().copyWith(
                iconTheme: const IconThemeData(color: red),
                appBarTheme: const AppBarTheme(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: red,
                  indicatorColor: Colors.white.withValues(alpha: 0.2),
                  labelTextStyle: WidgetStateProperty.all(
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(color: Colors.white);
                    }
                    return IconThemeData(color: Colors.white.withValues(alpha: 0.7));
                  }),
                ),
              ),
          darkTheme: darkTheme.toApproximateMaterialTheme().copyWith(
                iconTheme: const IconThemeData(color: red),
                appBarTheme: const AppBarTheme(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: red,
                  indicatorColor: Colors.white.withValues(alpha: 0.2),
                  labelTextStyle: WidgetStateProperty.all(
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(color: Colors.white);
                    }
                    return IconThemeData(color: Colors.white.withValues(alpha: 0.7));
                  }),
                ),
              ),
          builder: (context, child) => FTheme(
            data: activeTheme,
            child: FTooltipGroup(
              child: child!,
            ),
          ),
          routerConfig: Routefly.routerConfig(
            routes: routes,
            initialPath: '/splash',
          ),
        );
      },
    );
  }
}
