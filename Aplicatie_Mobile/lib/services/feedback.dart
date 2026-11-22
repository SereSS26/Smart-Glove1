import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../state/providers.dart';

/// Vibrația scurtă la apăsare (confirmă apăsarea când mâna tremură). Se oprește din Setări › Aspect.
/// Semnalele testelor (3-2-1, final) nu depind de ea: acolo vibrația e informație, nu decor.
abstract final class Haptics {
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}

/// Citește cu voce instrucțiunile testelor (opțional, din Setări › Aspect).
class VoiceGuide {
  VoiceGuide(this.enabled);
  final bool enabled;
  FlutterTts? _tts;

  Future<void> say(String text) async {
    if (!enabled) return;
    try {
      if (_tts == null) {
        _tts = FlutterTts();
        await _tts!.setLanguage('ro-RO');
        await _tts!.setSpeechRate(0.45);
      }
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (_) {
      // Fără voce (telefon fără română instalată sau teste): instrucțiunile rămân pe ecran.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

/// Un comutator salvat în preferințe.
class PrefToggle extends Notifier<bool> {
  PrefToggle(this.key, this.fallback);
  final String key;
  final bool fallback;

  @override
  bool build() => ref.watch(prefsProvider).getBool(key) ?? fallback;

  Future<void> set(bool v) async {
    state = v;
    await ref.read(prefsProvider).setBool(key, v);
  }
}

final hapticsProvider = NotifierProvider<PrefToggle, bool>(() => PrefToggle('haptics', true));
final voiceGuideEnabledProvider = NotifierProvider<PrefToggle, bool>(() => PrefToggle('voiceGuide', false));
final voiceGuideProvider = Provider.autoDispose<VoiceGuide>((ref) {
  final v = VoiceGuide(ref.watch(voiceGuideEnabledProvider));
  ref.onDispose(v.stop);
  return v;
});
