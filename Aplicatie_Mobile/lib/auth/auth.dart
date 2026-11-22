import 'package:shared_preferences/shared_preferences.dart';

/// Rolul contului. Vine din cont (mai târziu din baza de date), nu dintr-un comutator pe ecran.
enum UserRole { patient, doctor }

/// Utilizatorul autentificat.
class AppUser {
  const AppUser({required this.id, required this.name, required this.email, required this.role, required this.details, this.code});

  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// Pacient: vârsta și diagnosticul; medic: specialitatea.
  final String details;

  /// Codul pacientului pentru legarea de medic (folosit după conectarea la server).
  final String? code;

  bool get isDoctor => role == UserRole.doctor;

  /// „Ion Popescu” → „IP”.
  String get initials => name.replaceAll('Dr. ', '').split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();

  /// „Ion Popescu” → „Ion”; la medic, „Dr. Pavel”.
  String get shortName => isDoctor ? 'Dr. ${name.split(' ').last}' : name.split(' ').first;
}

/// Eroare de autentificare, cu mesaj gata de afișat.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Autentificarea. Ecranele lucrează doar cu interfața asta; azi conturile sunt scrise în cod
/// ([HardcodedAuth]), mai târziu vine `SupabaseAuth`, fără ca ecranele să se schimbe.
abstract class AuthRepository {
  /// Contul ținut minte de data trecută, sau null.
  AppUser? restore();
  Future<AppUser> signIn(String email, String password, {bool remember = true});
  Future<void> signOut();
}

/// Conturi demonstrative, doar pentru prototip. Dispar odată cu Supabase.
class HardcodedAuth implements AuthRepository {
  HardcodedAuth(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'authUserId';

  static const patient = AppUser(
    id: 'p-ion',
    name: 'Ion Popescu',
    email: 'pacient@manusa.ro',
    role: UserRole.patient,
    details: '68 ani · Parkinson',
    code: 'K7P-3QX',
  );
  static const doctor = AppUser(
    id: 'd-pavel',
    name: 'Dr. Andreea Pavel',
    email: 'medic@manusa.ro',
    role: UserRole.doctor,
    details: 'Neurolog',
  );

  static const _passwords = {'pacient@manusa.ro': 'pacient123', 'medic@manusa.ro': 'medic123'};
  static const accounts = [patient, doctor];

  @override
  AppUser? restore() {
    final id = _prefs.getString(_key);
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<AppUser> signIn(String email, String password, {bool remember = true}) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || password.isEmpty) throw const AuthException('Scrie e-mailul și parola.');
    final user = accounts.where((a) => a.email == e).firstOrNull;
    if (user == null || _passwords[e] != password) throw const AuthException('E-mailul sau parola nu se potrivesc.');
    if (remember) {
      await _prefs.setString(_key, user.id);
    } else {
      await _prefs.remove(_key);
    }
    return user;
  }

  @override
  Future<void> signOut() => _prefs.remove(_key);
}
