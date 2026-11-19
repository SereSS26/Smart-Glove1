import 'package:flutter/material.dart';

/// Un set complet de culori: unul pentru tema deschisă, unul pentru cea întunecată.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentDark,
    required this.accentSoft,
    required this.track,
    required this.fingerBar,
    required this.connected,
    required this.mutedDot,
    required this.recording,
    required this.recordingSoft,
    required this.recordingBorder,
    required this.recordingText,
    required this.warningBg,
    required this.warningFg,
  });

  final Color background, surface, border, borderStrong, divider, text, textMuted;
  final Color accent, onAccent, accentDark, accentSoft, track, fingerBar, connected, mutedDot;
  final Color recording, recordingSoft, recordingBorder, recordingText, warningBg, warningFg;

  /// Culorile din machete.
  static const light = AppPalette(
    background: Color(0xFFEEF2F5),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFD5DDE4),
    borderStrong: Color(0xFFC3CED7),
    divider: Color(0xFFE1E7EC),
    text: Color(0xFF0F1E2B),
    textMuted: Color(0xFF4A5B6B),
    accent: Color(0xFF0A5C7A),
    onAccent: Color(0xFFFFFFFF),
    accentDark: Color(0xFF084A62),
    accentSoft: Color(0xFFDCEBF1),
    track: Color(0xFFE6ECF0),
    fingerBar: Color(0xFF2A7F9E),
    connected: Color(0xFF0A7A5C),
    mutedDot: Color(0xFF7D8C99),
    recording: Color(0xFFA3123A),
    recordingSoft: Color(0xFFFBE3E9),
    recordingBorder: Color(0xFFEDB9C6),
    recordingText: Color(0xFF6E0C27),
    warningBg: Color(0xFFFBE6C5),
    warningFg: Color(0xFF5C3600),
  );

  /// Tema întunecată: aceleași roluri, cu contrast verificat pe fundal închis.
  static const dark = AppPalette(
    background: Color(0xFF0E161D),
    surface: Color(0xFF17222C),
    border: Color(0xFF2A3A47),
    borderStrong: Color(0xFF3B4D5C),
    divider: Color(0xFF243340),
    text: Color(0xFFE8EEF2),
    textMuted: Color(0xFFA6B4C0),
    accent: Color(0xFF5BBCDD),
    onAccent: Color(0xFF052231),
    accentDark: Color(0xFFA5DCEF),
    accentSoft: Color(0xFF143B4C),
    track: Color(0xFF223140),
    fingerBar: Color(0xFF4AA6C9),
    connected: Color(0xFF45C796),
    mutedDot: Color(0xFF8595A3),
    recording: Color(0xFFC72E57),
    recordingSoft: Color(0xFF3A1722),
    recordingBorder: Color(0xFF6B2B3E),
    recordingText: Color(0xFFF4B6C6),
    warningBg: Color(0xFF3D2C0E),
    warningFg: Color(0xFFF6D59A),
  );
}

/// Culorile curente. Se schimbă odată cu tema (vezi `ManusaApp`), apoi tot ecranul se redesenează.
abstract final class AppColors {
  static AppPalette _p = AppPalette.light;

  static void use(Brightness b) => _p = b == Brightness.dark ? AppPalette.dark : AppPalette.light;

  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get border => _p.border;
  static Color get borderStrong => _p.borderStrong;
  static Color get divider => _p.divider;
  static Color get text => _p.text;
  static Color get textMuted => _p.textMuted;
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;
  static Color get accentDark => _p.accentDark;
  static Color get accentSoft => _p.accentSoft;
  static Color get track => _p.track;
  static Color get fingerBar => _p.fingerBar;
  static Color get connected => _p.connected;
  static Color get mutedDot => _p.mutedDot;
  static Color get recording => _p.recording;
  static Color get recordingSoft => _p.recordingSoft;
  static Color get recordingBorder => _p.recordingBorder;
  static Color get recordingText => _p.recordingText;
  static Color get warningBg => _p.warningBg;
  static Color get warningFg => _p.warningFg;

  /// Portocaliul pentru „se conectează” și „fără date”; se citește pe ambele teme.
  static const amber = Color(0xFFD97A00);
}

/// Cât de puternic e tremorul. Se arată mereu cu culoare ȘI cuvânt, niciodată doar cu culoare.
/// Pastilele au fundal deschis pe ambele teme, ca să rămână ușor de recunoscut.
enum Severity {
  mild('ușor', Color(0xFFDDF0F6), Color(0xFF0B4A5E), Color(0xFF5BB3CF)),
  moderate('moderat', Color(0xFFFBE6C5), Color(0xFF5C3600), Color(0xFFD97A00)),
  strong('puternic', Color(0xFFF6DCE3), Color(0xFF6E0C27), Color(0xFF8C1D40));

  const Severity(this.label, this.background, this.foreground, this.dot);

  final String label;
  final Color background;
  final Color foreground;
  final Color dot;

  /// Praguri provizorii pe indicele 0–100; se reglează după testele cu voluntari (Etapa 5).
  static Severity fromIndex(int index) {
    if (index < 30) return mild;
    if (index <= 60) return moderate;
    return strong;
  }
}

/// Dimensiuni minime gândite pentru o mână care tremură.
abstract final class AppSizes {
  static const buttonHeight = 68.0;
  static const radius = 20.0;
  static const gap = 12.0;
  static const pagePadding = 20.0;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.fingerBar,
    onSecondary: p.onAccent,
    error: p.recording,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    outline: p.border,
    outlineVariant: p.track,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Atkinson',
    scaffoldBackgroundColor: p.background,
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.1),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 18, height: 1.3),
      bodyMedium: TextStyle(fontSize: 17, height: 1.3),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    ).apply(bodyColor: p.text, displayColor: p.text),
    navigationBarTheme: NavigationBarThemeData(
      height: 84,
      backgroundColor: p.surface,
      indicatorColor: p.accentSoft,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(size: 28, color: states.contains(WidgetState.selected) ? p.accentDark : p.textMuted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Atkinson',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected) ? p.accentDark : p.textMuted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
        textStyle: const TextStyle(fontFamily: 'Atkinson', fontSize: 21, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
