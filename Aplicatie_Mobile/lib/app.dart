import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'core/strings.dart';
import 'core/tests.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/doctor/doctor_settings_screen.dart';
import 'features/doctor/patients_screen.dart';
import 'features/doctor/reports_screen.dart';
import 'features/doctor/weekly_summary.dart';
import 'features/history/history_screen.dart';
import 'features/live/live_screen.dart';
import 'features/medications/import_text_screen.dart';
import 'features/medications/scan_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/reminders/reminders_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tests/test_runner_screen.dart';
import 'services/feedback.dart';
import 'services/notification_service.dart';
import 'services/share_inbox.dart';
import 'state/providers.dart';
import 'state/reminder_providers.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class ManusaApp extends ConsumerWidget {
  const ManusaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    Haptics.enabled = ref.watch(hapticsProvider);
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
      home: const AuthGate(),
    );
  }
}

/// Alege ce se vede: autentificarea, prima pornire a pacientului sau aplicația rolului.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final onboardingDone = ref.watch(settingsProvider.select((s) => s.onboardingDone));
    if (user == null) return const LoginScreen();
    if (user.isDoctor) return const DoctorShell();
    return onboardingDone ? const PatientShell() : const OnboardingScreen();
  }
}

/// Fila aleasă în aplicația pacientului (Live, Istoric, Remindere, Setări). Se poate schimba de oriunde.
class PatientTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int tab) => state = tab;
}

final patientTabProvider = NotifierProvider<PatientTab, int>(PatientTab.new);

abstract final class Tabs {
  static const live = 0;
  static const history = 1;
  static const reminders = 2;
  static const settings = 3;
}

/// Aplicația pacientului: cele 4 file, bara de jos și mesajul de alertă.
class PatientShell extends ConsumerStatefulWidget {
  const PatientShell({super.key});

  @override
  ConsumerState<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends ConsumerState<PatientShell> {
  StreamSubscription<int>? _alerts;
  StreamSubscription<NotificationResponse>? _notes;
  StreamSubscription<SharedItem>? _shared;

  @override
  void initState() {
    super.initState();
    // Pornește urmărirea alertelor cât timp aplicația e deschisă.
    _alerts = ref.read(alertServiceProvider).alerts.listen(_showAlert);
    final service = ref.read(notificationsProvider);
    _notes = service.responses.listen(_onNote);
    final inbox = ref.read(shareInboxProvider);
    _shared = inbox.items.listen(_onShared);
    inbox.take().then((item) {
      if (item != null && mounted) _onShared(item);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!service.ready || !mounted) return;
      // Reminderele se reprogramează la fiecare pornire (ex. după o actualizare a aplicației).
      await ref.read(remindersActionsProvider).reschedule();
      final launch = await service.launchResponse();
      if (launch != null && mounted) _onNote(launch);
    });
  }

  @override
  void dispose() {
    _alerts?.cancel();
    _notes?.cancel();
    _shared?.cancel();
    super.dispose();
  }

  /// O rețetă trimisă din altă aplicație: textul merge la import, poza la scanare.
  void _onShared(SharedItem item) {
    ref.read(patientTabProvider.notifier).go(Tabs.reminders);
    final screen = item.imagePath != null ? ScanScreen(imagePath: item.imagePath) : ImportTextScreen(initial: item.text!.trim());
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// O apăsare pe o notificare: butoanele de doză se execută, restul deschid locul potrivit.
  Future<void> _onNote(NotificationResponse r) async {
    final tap = NoteTap.parse(r);
    final tabs = ref.read(patientTabProvider.notifier);
    switch (tap) {
      case DoseTap(action: final a?) when a.isNotEmpty:
        await handleDoseAction(tap, ref.read(medicationRepositoryProvider), ref.read(notificationsProvider));
        ref.read(remindersActionsProvider).refresh();
        if (a == NoteAction.taken) showMessage('Am notat doza.');
      case DoseTap() || OpenReminders():
        tabs.go(Tabs.reminders);
      case TestTap():
        tabs.go(Tabs.live);
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TestRunnerScreen(tests: TestKind.assessment)));
        }
      case null:
        break;
    }
  }

  void _showAlert(int index) {
    final fg = AppColors.isDark ? AppPalette.dark.onAccent : Colors.white;
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.recording,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              Icon(Symbols.warning_rounded, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${S.alertTitle}: indice $index',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(alertServiceProvider);
    final tab = ref.watch(patientTabProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // IndexedStack păstrează starea fiecărei file când treci de la una la alta.
        child: IndexedStack(index: tab, children: const [LiveScreen(), HistoryScreen(), RemindersScreen(), SettingsScreen()]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(patientTabProvider.notifier).go(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.ecg_heart_rounded),
            selectedIcon: Icon(Symbols.ecg_heart_rounded, fill: 1),
            label: S.tabLive,
          ),
          NavigationDestination(
            icon: Icon(Symbols.bar_chart_rounded),
            selectedIcon: Icon(Symbols.bar_chart_rounded, fill: 1),
            label: S.tabHistory,
          ),
          NavigationDestination(
            icon: Icon(Symbols.notifications_rounded),
            selectedIcon: Icon(Symbols.notifications_rounded, fill: 1),
            label: S.tabReminders,
          ),
          NavigationDestination(icon: Icon(Symbols.tune_rounded), selectedIcon: Icon(Symbols.tune_rounded, fill: 1), label: S.tabSettings),
        ],
      ),
    );
  }
}

/// Aplicația medicului: Pacienți, Rapoarte, Setări.
class DoctorShell extends ConsumerStatefulWidget {
  const DoctorShell({super.key});

  @override
  ConsumerState<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends ConsumerState<DoctorShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) syncWeeklySummary(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: const [PatientsScreen(), ReportsScreen(), DoctorSettingsScreen()]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.group_rounded),
            selectedIcon: Icon(Symbols.group_rounded, fill: 1),
            label: S.tabPatients,
          ),
          NavigationDestination(
            icon: Icon(Symbols.description_rounded),
            selectedIcon: Icon(Symbols.description_rounded, fill: 1),
            label: S.tabReports,
          ),
          NavigationDestination(icon: Icon(Symbols.tune_rounded), selectedIcon: Icon(Symbols.tune_rounded, fill: 1), label: S.tabSettings),
        ],
      ),
    );
  }
}

/// Arată mesaje scurte de oriunde din aplicație (ex. „Moment marcat”).
void showMessage(String text, {String? actionLabel, VoidCallback? onAction}) {
  _messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(seconds: actionLabel == null ? 4 : 5),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
