import '../repositories/auth_repository.dart';

class SignOut {
  const SignOut(this._authRepository);

  final AuthRepository _authRepository;

  Future<void> call() => _authRepository.signOut();
}
