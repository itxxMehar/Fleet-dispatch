import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/token_store.dart';
import '../../core/error/api_exception.dart';
import '../../domain/entities/session.dart';
import '../../domain/usecases/get_me.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';

enum SessionStatus {
  /// Before [RestoreSessionRequested] runs.
  initial,

  /// Restoring a persisted token via `/api/me`.
  restoring,

  /// No valid session — show sign-in.
  signedOut,

  /// Sign-in request in flight.
  authenticating,

  /// `/api/me` succeeded — authenticated UI may render.
  authenticated,
}

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.initial,
    this.me,
    this.error,
  });

  final SessionStatus status;
  final Me? me;
  final String? error;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated && me != null;

  bool get isBootstrapping =>
      status == SessionStatus.initial || status == SessionStatus.restoring;

  bool get isAuthenticating => status == SessionStatus.authenticating;

  bool get isSignedOut => status == SessionStatus.signedOut;

  SessionState copyWith({
    SessionStatus? status,
    Me? me,
    String? error,
    bool clearError = false,
    bool clearMe = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      me: clearMe ? null : me ?? this.me,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, me, error];
}

sealed class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => const [];
}

final class RestoreSessionRequested extends SessionEvent {
  const RestoreSessionRequested({this.force = false});

  final bool force;

  @override
  List<Object?> get props => [force];
}

final class SignInRequested extends SessionEvent {
  const SignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class SignOutRequested extends SessionEvent {
  const SignOutRequested();
}

final class RefreshMeRequested extends SessionEvent {
  const RefreshMeRequested();
}

/// Centralized 401 / expired-session path (REST, GraphQL, WS 4001).
final class SessionExpired extends SessionEvent {
  const SessionExpired();
}

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({
    required SignIn signIn,
    required SignOut signOut,
    required GetMe getMe,
    required TokenStore tokenStore,
  }) : _signIn = signIn,
       _signOut = signOut,
       _getMe = getMe,
       _tokenStore = tokenStore,
       super(const SessionState()) {
    on<RestoreSessionRequested>(_onRestore);
    on<SignInRequested>(_onSignIn);
    on<SignOutRequested>(_onSignOut);
    on<RefreshMeRequested>(_onRefreshMe);
    on<SessionExpired>(_onSessionExpired);
  }

  final SignIn _signIn;
  final SignOut _signOut;
  final GetMe _getMe;
  final TokenStore _tokenStore;

  final List<void Function()> _sessionClearedListeners = [];

  bool _restoreStarted = false;
  bool _handlingExpiry = false;
  bool _signingOut = false;

  /// Hook for SSE/WebSocket cleanup after local session is cleared.
  void addSessionClearedListener(void Function() listener) {
    _sessionClearedListeners.add(listener);
  }

  void removeSessionClearedListener(void Function() listener) {
    _sessionClearedListeners.remove(listener);
  }

  void _notifySessionCleared() {
    for (final listener in List<void Function()>.of(_sessionClearedListeners)) {
      listener();
    }
  }

  Future<void> _onRestore(
    RestoreSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    if (_restoreStarted && !event.force) {
      return;
    }
    _restoreStarted = true;
    emit(const SessionState(status: SessionStatus.restoring));

    await _tokenStore.restore();
    if (!_tokenStore.hasToken) {
      emit(const SessionState(status: SessionStatus.signedOut));
      return;
    }

    try {
      final me = await _getMe();
      emit(SessionState(status: SessionStatus.authenticated, me: me));
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        await _tokenStore.clear();
        _notifySessionCleared();
        emit(const SessionState(status: SessionStatus.signedOut));
        return;
      }
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          error: _messageFor(error),
        ),
      );
    } catch (_) {
      emit(
        const SessionState(
          status: SessionStatus.signedOut,
          error:
              'Unable to restore your session. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> _onSignIn(
    SignInRequested event,
    Emitter<SessionState> emit,
  ) async {
    if (state.isAuthenticating) {
      return;
    }

    emit(const SessionState(status: SessionStatus.authenticating));

    try {
      await _signIn(email: event.email, password: event.password);
      final me = await _getMe();
      emit(SessionState(status: SessionStatus.authenticated, me: me));
    } on ApiException catch (error) {
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          error: _messageFor(error),
        ),
      );
    } catch (_) {
      emit(
        const SessionState(
          status: SessionStatus.signedOut,
          error: 'Something went wrong while signing in. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRefreshMe(
    RefreshMeRequested event,
    Emitter<SessionState> emit,
  ) async {
    if (!state.isAuthenticated && !_tokenStore.hasToken) {
      return;
    }
    try {
      final me = await _getMe();
      emit(SessionState(status: SessionStatus.authenticated, me: me));
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        await _onSessionExpired(const SessionExpired(), emit);
      } else {
        emit(state.copyWith(error: _messageFor(error)));
      }
    }
  }

  Future<void> _onSessionExpired(
    SessionExpired event,
    Emitter<SessionState> emit,
  ) async {
    if (_handlingExpiry) {
      return;
    }
    if (state.status == SessionStatus.signedOut ||
        state.status == SessionStatus.restoring ||
        state.status == SessionStatus.initial) {
      return;
    }

    _handlingExpiry = true;
    try {
      await _tokenStore.clear();
      _notifySessionCleared();
      emit(
        const SessionState(
          status: SessionStatus.signedOut,
          error: 'Your session has expired. Please sign in again.',
        ),
      );
    } finally {
      _handlingExpiry = false;
    }
  }

  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<SessionState> emit,
  ) async {
    if (_signingOut) {
      return;
    }
    _signingOut = true;
    try {
      try {
        await _signOut();
      } catch (_) {
        if (_tokenStore.hasToken) {
          await _tokenStore.clear();
        }
      }
      _notifySessionCleared();
      emit(const SessionState(status: SessionStatus.signedOut));
    } finally {
      _signingOut = false;
    }
  }

  String _messageFor(ApiException error) {
    if (error.isNetwork) {
      return 'Unable to reach the server. Check your connection and try again.';
    }
    if (error.isUnavailable) {
      return 'The service is temporarily unavailable. Please try again shortly.';
    }
    if (error.message.trim().isEmpty) {
      return 'Request failed (${error.code}).';
    }
    return error.message;
  }
}
