import 'package:flutter/material.dart';

/// Un set complet de culori: unul pentru tema deschisă, unul pentru cea întunecată.
/// Paleta „roz medical” din machete (vezi `PLAN_INTERFATA.md`).
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.cardBorder,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentDark,
    required this.accentSoft,
    required this.gradientStart,
    required this.gradientEnd,
    required this.track,
    required this.switchOff,
    required this.connected,
    required this.mutedDot,
    required this.recording,
    required this.recordingSoft,
    required this.recordingBorder,
    required this.recordingText,
    required this.warningBg,
    required this.warningFg,
    required this.warningBorder,
    required this.ok,
    required this.okBg,
    required this.okFg,
    required this.mod,
    required this.modBg,
    required this.modFg,
    required this.bad,
    required this.badBg,
    required this.badFg,
    required this.snackBg,
    required this.snackFg,
    required this.snackAction,
    required this.isDark,
  });

  final Color background, surface, surfaceRaised, border, borderStrong, cardBorder, divider, text, textMuted;
  final Color accent, onAccent, accentDark, accentSoft, gradientStart, gradientEnd, track, switchOff, connected, mutedDot;
  final Color recording, recordingSoft, recordingBorder, recordingText, warningBg, warningFg, warningBorder;
  final Color ok, okBg, okFg, mod, modBg, modFg, bad, badBg, badFg;
  final Color snackBg, snackFg, snackAction;
  final bool isDark;

  /// Tema deschisă: alb cald, roz pentru acțiuni, text prună în loc de negru.
  static const light = AppPalette(
    background: Color(0xFFFBF6F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFF7FA),
    border: Color(0xFFF1DFE7),
    borderStrong: Color(0xFFE3C9D5),
    cardBorder: Color(0xFFF6E9EF),
    divider: Color(0xFFF1DFE7),
    text: Color(0xFF24151D),
    textMuted: Color(0xFF6B5562),
    accent: Color(0xFFD6336C),
    onAccent: Color(0xFFFFFFFF),
    accentDark: Color(0xFFA3214F),
    accentSoft: Color(0xFFFCE7EF),
    gradientStart: Color(0xFFE8508A),
    gradientEnd: Color(0xFFB8285F),
    track: Color(0xFFF5E8EE),
    switchOff: Color(0xFFE3D3DA),
    connected: Color(0xFF2F9E77),
    mutedDot: Color(0xFF9C8792),
    recording: Color(0xFFC4232F),
    recordingSoft: Color(0xFFFBE3E5),
    recordingBorder: Color(0xFFF2B8BE),
    recordingText: Color(0xFF8E1621),
    warningBg: Color(0xFFFFF4D6),
    warningFg: Color(0xFF6B4B00),
    warningBorder: Color(0xFFF0D58A),
    ok: Color(0xFF2F9E77),
    okBg: Color(0xFFE3F4EE),
    okFg: Color(0xFF1D6B50),
    mod: Color(0xFFE8A33D),
    modBg: Color(0xFFFCF0DC),
    modFg: Color(0xFF7A4E0B),
    bad: Color(0xFFD92D3A),
    badBg: Color(0xFFFBE3E5),
    badFg: Color(0xFF8E1621),
    snackBg: Color(0xFF24151D),
    snackFg: Color(0xFFFFFFFF),
    snackAction: Color(0xFFFF9CC0),
    isDark: false,
  );

  /// Tema întunecată: aceleași roluri, cu contrast verificat pe fundal prună-negru.
  static const dark = AppPalette(
    background: Color(0xFF140D11),
    surface: Color(0xFF1E1419),
    surfaceRaised: Color(0xFF271A21),
    border: Color(0xFF3A2830),
    borderStrong: Color(0xFF543D49),
    cardBorder: Color(0xFF3A2830),
    divider: Color(0xFF33232B),
    text: Color(0xFFF7EAF0),
    textMuted: Color(0xFFBFA3B1),
    accent: Color(0xFFF06C9B),
    onAccent: Color(0xFF2A0F1B),
    accentDark: Color(0xFFFFB3CC),
    accentSoft: Color(0xFF3A1A28),
    gradientStart: Color(0xFFC2386F),
    gradientEnd: Color(0xFF7A1F47),
    track: Color(0xFF2E2027),
    switchOff: Color(0xFF4A3640),
    connected: Color(0xFF3FBF8F),
    mutedDot: Color(0xFF8E7783),
    recording: Color(0xFFF0505C),
    recordingSoft: Color(0xFF451A20),
    recordingBorder: Color(0xFF6B2830),
    recordingText: Color(0xFFFFB4BB),
    warningBg: Color(0xFF3D2C0E),
    warningFg: Color(0xFFF6D59A),
    warningBorder: Color(0xFF5C4316),
    ok: Color(0xFF3FBF8F),
    okBg: Color(0xFF173A2E),
    okFg: Color(0xFF8FE0C0),
    mod: Color(0xFFF0B04F),
    modBg: Color(0xFF3D2C0E),
    modFg: Color(0xFFF6D59A),
    bad: Color(0xFFF0505C),
    badBg: Color(0xFF451A20),
    badFg: Color(0xFFFFB4BB),
    snackBg: Color(0xFFF7EAF0),
    snackFg: Color(0xFF24151D),
    snackAction: Color(0xFFA3214F),
    isDark: true,
  );
}

/// Culorile curente. Se schimbă odată cu tema (vezi `ManusaApp`), apoi tot ecranul se redesenează.
abstract final class AppColors {
  static AppPalette _p = AppPalette.light;

  static void use(Brightness b) => _p = b == Brightness.dark ? AppPalette.dark : AppPalette.light;

  static bool get isDark => _p.isDark;
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceRaised => _p.surfaceRaised;
  static Color get border => _p.border;
  static Color get borderStrong => _p.borderStrong;
  static Color get cardBorder => _p.cardBorder;
  static Color get divider => _p.divider;
  static Color get text => _p.text;
  static Color get textMuted => _p.textMuted;
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;
  static Color get accentDark => _p.accentDark;
  static Color get accentSoft => _p.accentSoft;
  static Color get gradientStart => _p.gradientStart;
  static Color get gradientEnd => _p.gradientEnd;
  static Color get track => _p.track;
  static Color get switchOff => _p.switchOff;
  static Color get connected => _p.connected;
  static Color get mutedDot => _p.mutedDot;
  static Color get recording => _p.recording;
  static Color get recordingSoft => _p.recordingSoft;
  static Color get recordingBorder => _p.recordingBorder;
  static Color get recordingText => _p.recordingText;
  static Color get warningBg => _p.warningBg;
  static Color get warningFg => _p.warningFg;
  static Color get warningBorder => _p.warningBorder;
  static Color get ok => _p.ok;
  static Color get okBg => _p.okBg;
  static Color get okFg => _p.okFg;
  static Color get mod => _p.mod;
  static Color get modBg => _p.modBg;
  static Color get modFg => _p.modFg;
  static Color get bad => _p.bad;
  static Color get badBg => _p.badBg;
  static Color get badFg => _p.badFg;
  static Color get snackBg => _p.snackBg;
  static Color get snackFg => _p.snackFg;
  static Color get snackAction => _p.snackAction;

  /// Degetele pe grafic: mare și arătător în două nuanțe de roz, ca să se deosebească.
  static Color get fingerBar => _p.accent;

  /// Portocaliul pentru „se conectează” și „fără date”.
  static Color get amber => _p.mod;

  /// Degradeul butonului principal și al antetelor.
  static LinearGradient get gradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_p.gradientStart, _p.gradientEnd]);
}

/// Umbrele moi, rozalii, de pe tema deschisă. Pe tema întunecată cartonașele au doar margine.
abstract final class AppShadows {
  static List<BoxShadow> get card => AppColors.isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0D24151D), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x14A3214F), blurRadius: 24, offset: Offset(0, 8)),
        ];

  static List<BoxShadow> get button => AppColors.isDark
      ? const [BoxShadow(color: Color(0x59000000), blurRadius: 20, offset: Offset(0, 8))]
      : const [BoxShadow(color: Color(0x4DD6336C), blurRadius: 22, offset: Offset(0, 10))];

  static List<BoxShadow> get segment => AppColors.isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x1424151D), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x1AA3214F), blurRadius: 10, offset: Offset(0, 4)),
        ];
}

/// Cât de puternic e tremorul. Se arată mereu cu culoare ȘI cuvânt, niciodată doar cu culoare.
/// Roșul e doar pentru alerte; rozul e doar pentru brand și acțiuni.
enum Severity {
  mild('ușor'),
  moderate('moderat'),
  strong('puternic');

  const Severity(this.label);

  final String label;

  Color get background => switch (this) {
    mild => AppColors.okBg,
    moderate => AppColors.modBg,
    strong => AppColors.badBg,
  };

  Color get foreground => switch (this) {
    mild => AppColors.okFg,
    moderate => AppColors.modFg,
    strong => AppColors.badFg,
  };

  Color get dot => switch (this) {
    mild => AppColors.ok,
    moderate => AppColors.mod,
    strong => AppColors.bad,
  };

  /// Praguri provizorii pe indicele 0–100; se reglează după testele cu voluntari (Etapa 5).
  static Severity fromIndex(int index) {
    if (index < 30) return mild;
    if (index <= 60) return moderate;
    return strong;
  }
}

/// Dimensiuni minime gândite pentru o mână care tremură.
abstract final class AppSizes {
  static const buttonHeight = 64.0;
  static const radius = 24.0;
  static const buttonRadius = 20.0;
  static const gap = 12.0;
  static const pagePadding = 16.0;
}

/// Cifrele care se schimbă des au aceeași lățime, ca să nu „sară” pe ecran.
const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.accentDark,
    secondary: p.accentDark,
    onSecondary: p.onAccent,
    error: p.recording,
    onError: p.isDark ? const Color(0xFF2A0F1B) : Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    surfaceContainerHighest: p.surfaceRaised,
    outline: p.border,
    outlineVariant: p.track,
  );
  const font = 'Atkinson';
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: font,
    scaffoldBackgroundColor: p.background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 18, height: 1.35),
      bodyMedium: TextStyle(fontSize: 17, height: 1.35),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.1),
    ).apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.text, size: 24),
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w800, color: p.text),
      contentTextStyle: TextStyle(fontFamily: font, fontSize: 18, height: 1.35, color: p.text),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.snackBg,
      actionTextColor: p.snackAction,
      contentTextStyle: TextStyle(fontFamily: font, fontSize: 17, fontWeight: FontWeight.w700, color: p.snackFg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: TextStyle(color: p.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.switchOff),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: p.surface,
      indicatorColor: p.accentSoft,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(size: 26, color: states.contains(WidgetState.selected) ? p.accentDark : p.textMuted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w700,
          color: states.contains(WidgetState.selected) ? p.accentDark : p.textMuted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        shape: buttonShape,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.track,
        disabledForegroundColor: p.textMuted,
        textStyle: const TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: p.border, width: 2),
        backgroundColor: p.surface,
        foregroundColor: p.accentDark,
        textStyle: const TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: p.accentDark,
        textStyle: const TextStyle(fontFamily: font, fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
