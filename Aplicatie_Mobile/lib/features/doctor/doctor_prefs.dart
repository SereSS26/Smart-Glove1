import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Preferințele medicului: rezumatul săptămânal și exportul implicit.
class DoctorPrefs {
  const DoctorPrefs({this.weeklySummary = true, this.pdf = true, this.days = 30});

  final bool weeklySummary;
  final bool pdf;
  final int days;

  DoctorPrefs copyWith({bool? weeklySummary, bool? pdf, int? days}) =>
      DoctorPrefs(weeklySummary: weeklySummary ?? this.weeklySummary, pdf: pdf ?? this.pdf, days: days ?? this.days);
}

class DoctorPrefsNotifier extends Notifier<DoctorPrefs> {
  @override
  DoctorPrefs build() {
    final p = ref.watch(prefsProvider);
    return DoctorPrefs(weeklySummary: p.getBool('doc.weekly') ?? true, pdf: p.getBool('doc.pdf') ?? true, days: p.getInt('doc.days') ?? 30);
  }

  void update(DoctorPrefs Function(DoctorPrefs p) change) {
    state = change(state);
    final p = ref.read(prefsProvider);
    p.setBool('doc.weekly', state.weeklySummary);
    p.setBool('doc.pdf', state.pdf);
    p.setInt('doc.days', state.days);
  }
}

final doctorPrefsProvider = NotifierProvider<DoctorPrefsNotifier, DoctorPrefs>(DoctorPrefsNotifier.new);
