import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../auth/auth.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Cercul cu inițialele utilizatorului.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.size = 48, this.background, this.foreground});

  final String initials;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background ?? AppColors.accentSoft),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: foreground ?? AppColors.accentDark),
      ),
    );
  }
}

/// Cartonașul de profil din Setări: inițiale, nume, e-mail și, la pacient, medicul și codul.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, Widget value) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
          ),
          value,
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(initials: user.initials, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('${user.details} · ${user.email}', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (!user.isDoctor) ...[
            const SizedBox(height: 8),
            Divider(color: AppColors.divider),
            row(S.myDoctor, const Text('Dr. Andreea Pavel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            row(
              S.myCode,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(user.code ?? '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Butonul „Ieși din cont”, cu confirmare.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.recording,
        side: BorderSide(color: AppColors.recordingBorder, width: 2),
        minimumSize: const Size.fromHeight(56),
      ),
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text(S.logoutConfirm),
            content: const Text(S.logoutBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
                onPressed: () => Navigator.pop(c, true),
                child: const Text(S.logout),
              ),
            ],
          ),
        );
        if (ok == true) await ref.read(authProvider.notifier).signOut();
      },
      icon: const Icon(Symbols.logout_rounded),
      label: const Text(S.logout),
    );
  }
}
