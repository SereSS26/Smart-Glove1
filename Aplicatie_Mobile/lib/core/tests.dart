import 'contract.dart';

/// Testele ghidate din sesiune (vezi `PLAN_INTERFATA.md`, 3.3).
enum TestKind {
  rest('rest', 'Tremor în repaus', 'Sprijină mâna relaxată pe genunchi și nu o mișca.', 30, HandState.rest),
  postural('postural', 'Tremor postural', 'Ține brațul întins în față, cu palma în jos. Nu te uita la ecran.', 30, HandState.posture),
  kinetic('kinetic', 'Tremor în mișcare', 'Atinge-ți vârful nasului cu arătătorul, apoi întinde brațul. Repetă rar.', 30, HandState.action),
  tappingGlove(
    'tapping_glove',
    'Tapping cu mănușa',
    'Atinge degetul mare cu arătătorul, cât de repede și de larg poți.',
    15,
    HandState.action,
  ),
  tappingScreen(
    'tapping_screen',
    'Tapping pe ecran',
    'Atinge pe rând cele două cercuri, cât de repede poți. Merge și fără mănușă.',
    20,
    HandState.action,
  );

  const TestKind(this.id, this.title, this.instruction, this.seconds, this.state);

  final String id;
  final String title;
  final String instruction;
  final int seconds;
  final HandState state;

  bool get isTremor => this == rest || this == postural || this == kinetic;
  bool get isTapping => this == tappingGlove || this == tappingScreen;
  bool get needsGlove => this != tappingScreen;

  /// Unitatea rezultatului: indicele 0–100 sau atingeri pe secundă.
  String get unit => isTremor ? '' : 'atingeri/s';

  /// Evaluarea completă: primele 4 teste, la rând (cam 3 minute cu instrucțiunile).
  static const assessment = [rest, postural, kinetic, tappingGlove];

  static TestKind? byId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}
