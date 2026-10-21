import '../entities/session.dart';

abstract class AuthRepository {
  Future<SessionUser> signIn({required String email, required String password});

  Future<void> signOut();

  Future<SessionUser?> getSession();
}
