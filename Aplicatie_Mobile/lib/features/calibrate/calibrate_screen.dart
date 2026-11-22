import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/contract.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

/// Calibrarea în 3 pași. Fiecare pas trimite o comandă; mănușa confirmă prin flaguri.
/// [onDone] e folosit la prima pornire, ca să treacă la ecranul principal.
class CalibrateScreen extends ConsumerStatefulWidget {
  const CalibrateScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  ConsumerState<CalibrateScreen> createState() => _CalibrateScreenState();
}

class _CalibrateScreenState extends ConsumerState<CalibrateScreen> {
  int _step = 0;
  bool _busy = false;
  String? _error;

  static const _commands = [ControlCommand.calibrateOpen, ControlCommand.calibrateFist, ControlCommand.calibrateGyro];
  static const _waits = [Duration(milliseconds: 1500), Duration(milliseconds: 1500), Duration(milliseconds: 2800)];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(gloveSourceProvider).send(_commands[_step]);
    await Future<void>.delayed(_waits[_step]);
    if (!mounted) return;
    final p = ref.read(liveProvider).packet;
    // Pasul 1 nu are confirmare proprie; pasul 2 confirmă degetele, pasul 3 giroscopul.
    final confirmed = switch (_step) {
      0 => p != null,
      1 => p?.flexCalibrated ?? false,
      _ => p?.gyroCalibrated ?? false,
    };
    setState(() {
      _busy = false;
      if (!confirmed) {
        _error = S.calibrationFailed;
      } else {
        _step++;
      }
    });
    if (_step == 3) ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastCalibration: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final done = _step >= 3;
    return Scaffold(
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 20),
          minHeight: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BackHeader(
                title: S.calibrationTitle,
                trailing: Text(
                  done ? '' : 'Pasul ${_step + 1} din 3',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.accent : AppColors.track,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.okBg : AppColors.accentSoft),
                        child: Icon(
                          done ? Symbols.check_circle_rounded : _icons[_step],
                          size: 84,
                          fill: done ? 1 : 0,
                          color: done ? AppColors.connected : AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        done ? S.calibrationDone : S.calibrationInstructions[_step],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                      ),
                      if (done) ...[
                        const SizedBox(height: 8),
                        Text(
                          S.calibrationDoneBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      _StepRow(
                        number: i + 1,
                        label: S.calibrationSteps[i],
                        state: i < _step ? _Step.done : (i == _step ? _Step.current : _Step.todo),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.recording),
                ),
                const SizedBox(height: 8),
              ],
              GradientButton(
                label: done ? S.done : (_busy ? S.saving : S.calibrationButtons[_step]),
                onPressed: _busy ? null : (done ? () => widget.onDone != null ? widget.onDone!() : Navigator.of(context).pop() : _save),
              ),
              if (!done) ...[
                const SizedBox(height: 8),
                Text(
                  S.holdPosition,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const _icons = [Symbols.back_hand_rounded, Symbols.front_hand_rounded, Symbols.pan_tool_rounded];
}

enum _Step { done, current, todo }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.label, required this.state});

  final int number;
  final String label;
  final _Step state;

  @override
  Widget build(BuildContext context) {
    final active = state != _Step.todo;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.accent : null,
              border: active ? null : Border.all(color: AppColors.mutedDot, width: 2),
            ),
            child: state == _Step.done
                ? Icon(Symbols.check_rounded, color: AppColors.onAccent, size: 20)
                : Text(
                    '$number',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: active ? AppColors.onAccent : AppColors.textMuted),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 19, fontWeight: state == _Step.current ? FontWeight.w700 : FontWeight.w400)),
          ),
          if (state == _Step.current)
            Text(
              'acum',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accentDark),
            ),
        ],
      ),
    );
  }
}
