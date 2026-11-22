import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/history_stats.dart';

/// Calendarul lunii: fiecare zi colorată după media ei (ușor / moderat / puternic), cu ziua de azi conturată.
class MonthHeatmap extends StatelessWidget {
  const MonthHeatmap({super.key, required this.cells, required this.leadingBlanks});

  final List<DayCell> cells;
  final int leadingBlanks;

  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final withData = cells.where((c) => c.value != null).length;
    final items = <Widget>[
      for (final w in _weekdays)
        Center(
          child: Text(
            w,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted),
          ),
        ),
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (final c in cells) _cell(c),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Calendarul lunii: $withData zile cu date',
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.15,
            children: items,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legend(Severity.mild),
            _legend(Severity.moderate),
            _legend(Severity.strong),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.text, width: 2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('azi', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(DayCell c) {
    final v = c.value;
    final sev = v == null ? null : Severity.fromIndex(v.round());
    return Semantics(
      label: v == null ? 'ziua ${c.day}: fără date' : 'ziua ${c.day}: ${v.round()}, ${sev!.label}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: sev?.background ?? Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.today
                ? AppColors.text
                : (v == null && !c.future ? AppColors.border : (c.future ? AppColors.divider : Colors.transparent)),
            width: c.today ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${c.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: c.today ? FontWeight.w800 : FontWeight.w700,
            color: sev?.foreground ?? (c.future ? AppColors.mutedDot : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _legend(Severity s) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: s.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: s.dot),
        ),
      ),
      const SizedBox(width: 6),
      Text(s.label, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
    ],
  );
}
