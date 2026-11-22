import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clinic_repository.dart';
import '../../data/medications.dart';
import '../../state/clinic_providers.dart';
import '../../state/providers.dart';
import 'doctor_prefs.dart';

const weeklySummaryId = 50000;

/// Textul rezumatului: câți pacienți, câți de urmărit și de ce.
String weeklySummaryText(List<PatientSummary> all) {
  final watch = all.where((s) => s.needsAttention).toList();
  final head =
      '${all.length} ${all.length == 1 ? 'pacient' : 'pacienți'} · ${watch.isEmpty ? 'niciunul de urmărit' : '${watch.length} de urmărit'}';
  if (watch.isEmpty) return '$head.';
  return '$head: ${watch.map((s) => '${s.patient.name} (${s.reasons.first})').join(', ')}.';
}

/// Programează (sau oprește) rezumatul de luni, 09:00, din datele de acum. Se reface la fiecare deschidere.
Future<void> syncWeeklySummary(WidgetRef ref) async {
  final notes = ref.read(notificationsProvider);
  if (!notes.ready) return;
  if (!ref.read(doctorPrefsProvider).weeklySummary) {
    await notes.cancelId(weeklySummaryId);
    return;
  }
  final all = await ref.read(patientSummariesProvider.future);
  await notes.scheduleOne(
    PlannedNote(
      id: weeklySummaryId,
      channel: NoteChannel.other,
      title: 'Rezumatul săptămânii',
      body: weeklySummaryText(all),
      payload: jsonEncode({'t': 'weekly'}),
      time: '09:00',
      weekday: DateTime.monday,
    ),
  );
}
