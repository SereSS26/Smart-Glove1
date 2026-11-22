import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/prescription_parser.dart';
import '../../services/share_inbox.dart';
import '../../ui/ui.dart';
import 'import_text_screen.dart';
import 'review_medications_screen.dart';

/// „Scanează rețeta”: o poză (cameră sau galerie), textul citit pe telefon, apoi verificarea.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.imagePath, this.reader = readTextFromImage});

  /// O poză primită prin „Trimite către Mănușa”: se citește imediat.
  final String? imagePath;

  /// Cine citește textul din poză (ML Kit; în teste, altceva).
  final Future<String> Function(String path) reader;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) WidgetsBinding.instance.addPostFrameCallback((_) => _read(widget.imagePath!));
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 90);
      if (photo != null) await _read(photo.path);
    } catch (e) {
      showMessage(source == ImageSource.camera ? 'Nu am putut deschide camera.' : 'Nu am putut deschide galeria.');
    }
  }

  Future<void> _read(String path) async {
    setState(() => _reading = true);
    String text;
    try {
      text = await widget.reader(path);
    } catch (e) {
      if (mounted) setState(() => _reading = false);
      showMessage('Nu am putut citi poza. Încearcă una mai clară sau importă textul.');
      return;
    }
    if (!mounted) return;
    setState(() => _reading = false);
    final found = parsePrescription(text);
    final nav = Navigator.of(context);
    if (found.isEmpty) {
      // Nu am găsit nimic: arătăm ce s-a citit, ca să poată fi corectat.
      await nav.push(MaterialPageRoute<void>(builder: (_) => ImportTextScreen(initial: text, fromScan: true)));
      return;
    }
    await nav.push(MaterialPageRoute<void>(builder: (_) => ReviewMedicationsScreen(found: found)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
          children: [
            const BackHeader(title: 'Scanează rețeta', subtitle: 'Textul se citește pe telefon; poza nu pleacă nicăieri.'),
            const SizedBox(height: 18),
            if (_reading)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Citesc rețeta…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pentru o poză bună', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    for (final tip in [
                      'Pune rețeta pe o masă, în lumină bună.',
                      'Ține telefonul drept, deasupra ei.',
                      'Să se vadă toată pagina, fără umbre.',
                      'Scrisul de mână se citește greu; textul tipărit, bine.',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Symbols.check_rounded, size: 20, color: AppColors.ok),
                            const SizedBox(width: 8),
                            Expanded(child: Text(tip, style: const TextStyle(fontSize: 16, height: 1.35))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(label: 'Fă o poză', icon: Symbols.photo_camera_rounded, onPressed: () => _pick(ImageSource.camera)),
              const SizedBox(height: 12),
              OutlineBigButton(
                icon: Symbols.photo_library_rounded,
                title: 'Alege din galerie',
                subtitle: 'o poză făcută deja',
                onPressed: () => _pick(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const ImportTextScreen())),
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Am rețeta ca text'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
