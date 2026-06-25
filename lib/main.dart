import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shared/providers/app_provider.dart';
import 'shared/theme.dart';
import 'features/selection/selection_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/restaurant/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'Nexora',
      theme: RestoTheme.lightTheme,
      darkTheme: RestoTheme.darkTheme,
      themeMode: provider.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            final focus = FocusManager.instance.primaryFocus;
            if (focus != null && focus.hasFocus) {
              focus.unfocus();
            }
          },
          child: child,
        );
      },
      home: const PortalNavigator(),
    );
  }
}

class PortalNavigator extends StatelessWidget {
  const PortalNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    switch (provider.currentMode) {
      case AppMode.selection:
        return const SelectionScreen();
      case AppMode.staffAuth:
        return const LoginScreen();
      case AppMode.staffPortal:
        return const DashboardScreen();
    }
  }
}
