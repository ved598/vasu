import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/splash.dart';
import 'screens/home.dart';
import 'screens/chat.dart';
import 'screens/settings.dart';
import 'screens/onboarding.dart';
import 'theme.dart';
import 'providers.dart';

class NovaApp extends ConsumerWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _buildRouter(ref);
    return MaterialApp.router(
      title: 'NOVA AI',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.dark,
      darkTheme: NovaTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }

  GoRouter _buildRouter(WidgetRef ref) {
    final prefs = ref.read(prefsProvider);
    final onboarded = prefs.getBool('onboarded') ?? false;

    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/',         builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboard',  builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/home',     builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/chat',     builder: (_, __) => const ChatScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
      redirect: (ctx, state) {
        if (state.matchedLocation == '/') return null;
        return null;
      },
    );
  }
}
