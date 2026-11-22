import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../ui/ui.dart';
import 'review_medications_screen.dart';

/// „Importă din notițe”: lipești textul rețetei (din Notițe, WhatsApp, Keep) și aplicația găsește medicamentele.
class ImportTextScreen extends StatefulWidget {
  const ImportTextScreen({super.key, this.initial = '', this.fromScan = false});

  final String initial;

  /// Textul vine din scanare și nu s-a găsit nimic: îl poți corecta aici.
  final bool fromScan;

  @override
  State<ImportTextScreen> createState() => _ImportTextScreenState();
}

class _ImportTextScreenState extends State<ImportTextScreen> {
  late final _text = TextEditingController(text: widget.initial);
  bool _nothing = false;

  @override
  void initState() {
    super.initState();
    _nothing = widget.fromScan;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t == null || t.isEmpty) return;
    setState(() {
      _text.text = _text.text.trim().isEmpty ? t : '${_text.text.trim()}\n$t';
      _nothing = false;
    });
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    await openReview(context, _text.text, onNothing: () => setState(() => _nothing = true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
          children: [
            BackHeader(
              title: widget.fromScan ? 'Corectează textul' : 'Importă din notițe',
              subtitle: widget.fromScan
                  ? 'Asta am citit din poză. Corectează ce e greșit.'
                  : 'Lipește textul rețetei: câte un medicament pe rând.',
            ),
            const SizedBox(height: 14),
            OutlineBigButton(
              icon: Symbols.content_paste_rounded,
              title: 'Lipește',
              subtitle: 'textul copiat din altă aplicație',
              onPressed: _paste,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 14,
              style: const TextStyle(fontSize: 18, height: 1.4),
              decoration: const InputDecoration(hintText: 'ex.\nMadopar 250 mg 1 cp de 3 ori pe zi\nRivotril 0,5 mg ½ cp la culcare'),
              onChanged: (_) => setState(() => _nothing = false),
            ),
            if (_nothing) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Text(
                  'Nu am găsit niciun medicament. Scrie fiecare medicament pe un rând, cu concentrația (ex. 250 mg) și doza.',
                  style: TextStyle(fontSize: 16, color: AppColors.warningFg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(label: 'Caută medicamentele', icon: Symbols.search_rounded, onPressed: _text.text.trim().isEmpty ? null : _find),
            const SizedBox(height: 16),
            Text(
              'Merge și direct din altă aplicație: alegi textul, apeși „Trimite” și alegi Mănușa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
