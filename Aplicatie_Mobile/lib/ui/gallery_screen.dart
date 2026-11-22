import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'ui.dart';

/// Ecran de probă, doar în modul de dezvoltare: toate piesele de interfață, pe tema curentă.
/// Schimbă tema din Setări ca să le vezi și pe cealaltă.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _source = 'wifi';
  String _period = 'week';
  int _threshold = 60;
  bool _switch = true;

  static const _trend = <double>[
    38,
    40,
    43,
    41,
    45,
    48,
    52,
    55,
    58,
    61,
    63,
    60,
    57,
    54,
    52,
    50,
    49,
    51,
    53,
    55,
    54,
    52,
    50,
    51,
    53,
    56,
    55,
    54,
    53,
    54,
  ];

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(title), const SizedBox(height: 10), ...children],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
          children: [
            const BackHeader(title: S.gallery, subtitle: 'toate piesele, pe tema curentă'),
            section('Siglă', [
              Row(
                children: [
                  const AppMark(size: 80),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.appTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        Text(S.tagline, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            section('Butoane', [
              GradientButton(label: S.startSession, icon: Symbols.play_arrow_rounded, onPressed: () {}),
              const SizedBox(height: 10),
              GradientButton(label: S.stopSession, icon: Symbols.stop_rounded, danger: true, onPressed: () {}),
              const SizedBox(height: 10),
              const GradientButton(label: 'Buton inactiv', onPressed: null),
              const SizedBox(height: 10),
              OutlineBigButton(icon: Symbols.edit_note_rounded, title: S.addNote, subtitle: S.addNoteHint, onPressed: () {}),
            ]),
            section('Alegeri', [
              ChoiceTiles<String>(
                options: const [
                  Choice('usb', 'USB', icon: Symbols.usb_rounded),
                  Choice('wifi', 'Wi-Fi', icon: Symbols.wifi_rounded),
                  Choice('demo', 'Demo', icon: Symbols.auto_awesome_rounded),
                ],
                selected: _source,
                onChanged: (v) => setState(() => _source = v),
              ),
              const SizedBox(height: 12),
              AppSegmented<String>(
                options: const [Choice('day', 'Zi'), Choice('week', 'Săptămână'), Choice('month', 'Lună')],
                selected: _period,
                onChanged: (v) => setState(() => _period = v),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(S.alertThreshold, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                          StepperField(
                            value: '$_threshold',
                            minusLabel: S.decrease,
                            plusLabel: S.increase,
                            onMinus: () => setState(() => _threshold = (_threshold - 5).clamp(20, 95)),
                            onPlus: () => setState(() => _threshold = (_threshold + 5).clamp(20, 95)),
                          ),
                        ],
                      ),
                    ),
                    SwitchRow(title: S.vibrateOnAlert, value: _switch, onChanged: (v) => setState(() => _switch = v)),
                  ],
                ),
              ),
            ]),
            section('Severitate și diferențe', [
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SeverityChip(Severity.mild),
                  SeverityChip(Severity.moderate),
                  SeverityChip(Severity.strong),
                  SeverityChip(Severity.moderate, prefix: '48'),
                ],
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DeltaBadge(percent: -12),
                  DeltaBadge(percent: 18),
                  DeltaBadge(percent: 6, lowerIsBetter: false),
                  DeltaBadge(percent: 0),
                ],
              ),
              const SizedBox(height: 10),
              const SimulatedBanner(S.simulatedBanner),
            ]),
            section('Cifre', [
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(128),
                ),
                children: const [
                  MetricTile(
                    label: 'Media indicelui',
                    value: '42',
                    badge: DeltaBadge(percent: -12, showWord: false),
                    sub: 'mai bine față de săptămâna trecută',
                  ),
                  MetricTile(label: 'Peste prag', value: '8 %', sub: 'din timpul înregistrat · prag 60'),
                ],
              ),
            ]),
            section('Tremor și degete', [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TremorRing(index: 54, threshold: _threshold),
                        const SizedBox(width: 16),
                        TremorRing(index: 72, threshold: _threshold, size: 72),
                        const SizedBox(width: 16),
                        TremorRing(index: null, threshold: _threshold, size: 72),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TrendChart(values: _trend, threshold: _threshold),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        LiveHand(fingers: [80, 65, null, null, null]),
                        SizedBox(width: 16),
                        LiveHand(fingers: [10, 25, 40, 60, 90], width: 90),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            section('Stare goală', [
              const AppCard(
                child: EmptyState(icon: Symbols.insights_rounded, text: S.noSessions),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
