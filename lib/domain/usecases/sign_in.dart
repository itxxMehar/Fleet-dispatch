import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._authRepository);

  final AuthRepository _authRepository;

  Future<SessionUser> call({required String email, required String password}) {
    return _authRepository.signIn(email: email, password: password);
  }
}
