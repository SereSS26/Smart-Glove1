import '../../core/contract.dart';

/// O sesiune înregistrată.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.activity,
    required this.note,
    required this.avgFrequency,
    required this.avgIndex,
    required this.maxIndex,
    required this.alertCount,
    required this.simulated,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Activitatea aleasă cel mai mult timp în sesiune.
  final HandState activity;
  final String note;

  /// Media frecvenței doar pe secundele cu tremor; null dacă n-a fost tremor.
  final double? avgFrequency;
  final int avgIndex;
  final int maxIndex;
  final int alertCount;
  final bool simulated;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  factory SessionRecord.fromRow(Map<String, Object?> r) => SessionRecord(
    id: r['id']! as int,
    startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at']! as int),
    endedAt: r['ended_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['ended_at']! as int),
    activity: HandState.fromCode(r['activity']! as int),
    note: r['note']! as String,
    avgFrequency: (r['avg_freq'] as num?)?.toDouble(),
    avgIndex: r['avg_index']! as int,
    maxIndex: r['max_index']! as int,
    alertCount: r['alert_count']! as int,
    simulated: (r['simulated']! as int) == 1,
  );
}

/// Un eșantion pe secundă dintr-o sesiune.
class SampleRecord {
  const SampleRecord({
    required this.at,
    required this.frequency,
    required this.rms,
    required this.index,
    required this.state,
    required this.fingers,
  });

  final DateTime at;
  final double frequency;
  final double rms;
  final int index;
  final HandState state;
  final List<int?> fingers;

  Map<String, Object?> toRow(int sessionId) => {
    'session_id': sessionId,
    't': at.millisecondsSinceEpoch,
    'freq': frequency,
    'rms': rms,
    'idx': index,
    'state': state.code,
    for (var i = 0; i < fingers.length; i++) 'f${i + 1}': fingers[i],
  };

  factory SampleRecord.fromRow(Map<String, Object?> r) => SampleRecord(
    at: DateTime.fromMillisecondsSinceEpoch(r['t']! as int),
    frequency: (r['freq']! as num).toDouble(),
    rms: (r['rms']! as num).toDouble(),
    index: r['idx']! as int,
    state: HandState.fromCode(r['state']! as int),
    fingers: [for (var i = 1; i <= GloveContract.fingerCount; i++) r['f$i'] as int?],
  );
}

enum EventKind { alert, mark, note }

/// O alertă, un moment marcat sau o notă din timpul sesiunii.
class EventRecord {
  const EventRecord({required this.at, required this.kind, this.text = ''});

  final DateTime at;
  final EventKind kind;
  final String text;

  factory EventRecord.fromRow(Map<String, Object?> r) => EventRecord(
    at: DateTime.fromMillisecondsSinceEpoch(r['t']! as int),
    kind: EventKind.values.byName(r['kind']! as String),
    text: r['text']! as String,
  );
}
