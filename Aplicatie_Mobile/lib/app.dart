import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/history/history_screen.dart';
import 'features/live/live_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'state/providers.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class ManusaApp extends ConsumerWidget {
  const ManusaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(settingsProvider.select((s) => s.onboardingDone));
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) {
        final brightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        AppColors.use(brightness);
        // La schimbarea temei se reconstruiește tot ecranul, ca toate culorile să se actualizeze.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          // Iconițele din bara de stare (ora, bateria) se văd pe ambele teme.
          value: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: KeyedSubtree(key: ValueKey(brightness), child: child!),
        );
      },
      home: onboardingDone ? const HomeShell() : const OnboardingScreen(),
    );
  }
}

/// Cadrul principal: cele 3 file, bara de jos și mesajul de alertă.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;
  StreamSubscription<int>? _alerts;

  @override
  void initState() {
    super.initState();
    // Pornește urmărirea alertelor cât timp aplicația e deschisă.
    _alerts = ref.read(alertServiceProvider).alerts.listen(_showAlert);
  }

  @override
  void dispose() {
    _alerts?.cancel();
    super.dispose();
  }

  void _showAlert(int index) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.recording,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Text(
            '${S.alertTitle}: indice $index',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(alertServiceProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // IndexedStack păstrează starea fiecărei file când treci de la una la alta.
        child: IndexedStack(index: _tab, children: const [LiveScreen(), HistoryScreen(), SettingsScreen()]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: S.tabLive),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: S.tabHistory),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: S.tabSettings),
        ],
      ),
    );
  }
}

/// Arată mesaje scurte de oriunde din aplicație (ex. „Moment marcat”).
void showMessage(String text) {
  _messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
}
