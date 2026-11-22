import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../auth/auth.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../../services/feedback.dart';

/// Autentificarea, pe tot ecranul: fundal roz, sigla și un card cu e-mail și parolă.
/// Butoanele „Conturi demo” completează și intră dintr-o apăsare (dispar odată cu Supabase).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _remember = true;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signIn(_email.text, _password.text, remember: _remember);
    } on AuthException catch (e) {
      Haptics.medium();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _demo(AppUser user) {
    _email.text = user.email;
    _password.text = user.isDoctor ? 'medic123' : 'pacient123';
    _signIn();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF7A1F47), Color(0xFF4A1330), Color(0xFF1E0A14)]
                  : const [Color(0xFFE2457F), Color(0xFFC42A63), Color(0xFF8F1A4B)],
            ),
          ),
          child: Stack(
            children: [
              // Pete de lumină, discrete, pe marginile ecranului.
              Positioned(
                left: -120,
                top: 260,
                child: _Glow(size: 300, color: Colors.white.withValues(alpha: dark ? 0.08 : 0.22)),
              ),
              Positioned(
                right: -110,
                bottom: -80,
                child: _Glow(size: 320, color: const Color(0xFFFFA0C4).withValues(alpha: dark ? 0.18 : 0.4)),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                      child: Column(
                        children: [
                          const _Brand(),
                          const SizedBox(height: 24),
                          _card(),
                          const SizedBox(height: 18),
                          const Text(
                            'Nu este dispozitiv medical. Valorile sunt orientative.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x4D5A0E2E), blurRadius: 48, offset: Offset(0, 24))],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bine ai venit', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text('Intră în contul tău', style: TextStyle(fontSize: 17, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            _label('E-mail'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(hintText: 'nume@exemplu.ro'),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            _label('Parolă'),
            TextField(
              controller: _password,
              focusNode: _passwordFocus,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Parola ta',
                suffixIcon: IconButton(
                  iconSize: 26,
                  constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                  tooltip: _showPassword ? 'Ascunde parola' : 'Arată parola',
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Symbols.visibility_off_rounded : Symbols.visibility_rounded, color: AppColors.textMuted),
                ),
              ),
              onSubmitted: (_) => _signIn(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Symbols.error_rounded, size: 20, color: AppColors.recording),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.recording),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            MergeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _remember = !_remember),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                      const Text('Ține-mă minte', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GradientButton(label: _busy ? 'Se verifică…' : 'Intră', onPressed: _busy ? null : _signIn, height: 60),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('conturi demo', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _demo(HardcodedAuth.patient),
                    icon: const Icon(Symbols.person_rounded),
                    label: const Text('Pacient'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _demo(HardcodedAuth.doctor),
                    icon: const Icon(Symbols.stethoscope_rounded),
                    label: const Text('Medic'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMuted),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          ),
          alignment: Alignment.center,
          child: const HandPulseLogo(size: 54),
        ),
        const SizedBox(height: 12),
        const Text(
          S.appTitle,
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
        ),
        const SizedBox(height: 4),
        const Text(
          S.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
