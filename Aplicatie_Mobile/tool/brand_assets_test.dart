import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/ui/logo.dart';

/// Generează imaginile pentru iconița aplicației și ecranul de pornire, din aceeași siglă ca în aplicație.
/// Nu e un test propriu-zis și nu rulează cu `flutter test`. Se pornește manual:
///   flutter test tool/brand_assets_test.dart
///   dart run flutter_launcher_icons
///   dart run flutter_native_splash:create
void main() {
  const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8508A), Color(0xFFB8285F)],
  );

  Future<void> render(WidgetTester tester, String path, double size, Widget child) async {
    tester.view.physicalSize = Size(size, size);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(dimension: size, child: child),
          ),
        ),
      ),
    );
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
  }

  Widget logo(double size) => Center(child: HandPulseLogo(size: size));

  testWidgets('iconița, întreagă (iPhone și Android vechi)', (tester) async {
    await render(
      tester,
      'assets/brand/icon.png',
      1024,
      DecoratedBox(decoration: const BoxDecoration(gradient: gradient), child: logo(1024 * 0.62)),
    );
  });

  testWidgets('iconița adaptivă: fundal și siglă', (tester) async {
    await render(tester, 'assets/brand/icon_background.png', 1024, const DecoratedBox(decoration: BoxDecoration(gradient: gradient)));
    // Sigla stă în zona sigură din mijloc (Android taie marginile după forma iconiței).
    await render(tester, 'assets/brand/icon_foreground.png', 1024, logo(1024 * 0.44));
  });

  testWidgets('ecranul de pornire', (tester) async {
    await render(tester, 'assets/brand/splash_logo.png', 576, logo(576 * 0.8));
    // Android 12+: iconița e tăiată într-un cerc de 2/3 din imagine.
    await render(tester, 'assets/brand/splash_icon_android12.png', 1152, logo(1152 * 0.42));
  });
}
