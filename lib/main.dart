import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:suika_multi_player/config/theme.dart';
import 'package:suika_multi_player/screens/splash_screen.dart';
import 'package:suika_multi_player/utils/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('!!! FLUTTER ERROR: ${details.exception}');
    FlutterError.presentError(details);
  };

  final prefs = await SharedPreferences.getInstance();

  try {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(900, 600));
    await windowManager.setSize(const Size(1100, 720));
    await windowManager.center();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  } catch (e) {
    debugPrint('windowManager init error: $e');
  }

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SuikaApp(),
  ));
}

class SuikaApp extends StatelessWidget {
  const SuikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suika Mulit Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            Positioned(
              top: 0, right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.minimize_rounded, size: 16, color: Colors.white54),
                    onPressed: () => windowManager.minimize(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.crop_square_rounded, size: 16, color: Colors.white54),
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                    onPressed: () => windowManager.close(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

