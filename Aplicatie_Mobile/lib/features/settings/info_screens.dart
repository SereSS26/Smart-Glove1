import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Pagină simplă de text: antet + secțiuni cu titlu și paragrafe.
class _TextPage extends StatelessWidget {
  const _TextPage({required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 24),
          children: [
            BackHeader(title: title),
            const SizedBox(height: 16),
            for (final (heading, body) in sections) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(body, style: const TextStyle(fontSize: 18, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => const _TextPage(
    title: S.about,
    sections: [
      (S.disclaimerTitle, S.disclaimerBody),
      ('Datele tale', S.dataStaysLocal),
      ('Ce măsoară', 'Frecvența tremorului (în Hz), intensitatea lui pe o scară de la 0 la 100 și cât de îndoit e fiecare deget.'),
      (S.appTitle, S.aboutVersion),
    ],
  );
}

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _TextPage(
    title: S.instructions,
    sections: [
      ('1. Pune mănușa', 'Senzorii stau pe dosul degetelor, iar cutiuța pe dosul mâinii. Pornește mănușa.'),
      ('2. Conectează', 'Din Setări › Mănușă, caută mănușa și apasă Conectează. Data viitoare se conectează singură.'),
      ('3. Calibrează', 'O dată pe zi sau când pui mănușa: mână deschisă, pumn strâns, apoi mâna nemișcată 2 secunde.'),
      (
        '4. Înregistrează',
        'În Live apasă Pornește sesiunea. Alege ce faci (repaus, postură, acțiune), adaugă o notă dacă vrei și oprește sesiunea la final.',
      ),
      ('5. Arată medicului', 'În Istoric deschide o sesiune și apasă Trimite raport PDF. Alegi tu cui îl trimiți.'),
      ('Alerte', 'Când tremorul stă peste prag 5 secunde, telefonul îți arată o notificare. Pragul îl schimbi din Setări.'),
    ],
  );
}
