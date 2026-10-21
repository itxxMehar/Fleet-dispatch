import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/realtime/drivers_locations_client.dart';
import '../../data/repositories/health_repository.dart';
import '../../domain/entities/health_status.dart';

enum RealtimeLink { unknown, live, reconnecting, down }

class ConnectivityState extends Equatable {
  const ConnectivityState({
    this.health = const HealthStatus(availability: ServiceAvailability.healthy),
    this.sse = RealtimeLink.unknown,
    this.websocket = RealtimeLink.unknown,
    this.recoveryGeneration = 0,
    this.polling = false,
  });

  final HealthStatus health;
  final RealtimeLink sse;
  final RealtimeLink websocket;
  final int recoveryGeneration;
  final bool polling;

  bool get showMaintenance => health.isMaintenance;
  bool get showUnreachable => health.isUnreachable;
  bool get showRealtimeReconnecting =>
      health.isHealthy &&
      (sse == RealtimeLink.reconnecting ||
          websocket == RealtimeLink.reconnecting);

  ConnectivityState copyWith({
    HealthStatus? health,
    RealtimeLink? sse,
    RealtimeLink? websocket,
    int? recoveryGeneration,
    bool? polling,
  }) {
    return ConnectivityState(
      health: health ?? this.health,
      sse: sse ?? this.sse,
      websocket: websocket ?? this.websocket,
      recoveryGeneration: recoveryGeneration ?? this.recoveryGeneration,
      polling: polling ?? this.polling,
    );
  }

  @override
  List<Object?> get props => [
    health,
    sse,
    websocket,
    recoveryGeneration,
    polling,
  ];
}

sealed class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();

  @override
  List<Object?> get props => const [];
}

final class ConnectivityStarted extends ConnectivityEvent {
  const ConnectivityStarted();
}

final class HealthCheckRequested extends ConnectivityEvent {
  const HealthCheckRequested();
}

final class SseLinkStatusChanged extends ConnectivityEvent {
  const SseLinkStatusChanged({required this.live});

  final bool live;

  @override
  List<Object?> get props => [live];
}

final class WebsocketPhaseChanged extends ConnectivityEvent {
  const WebsocketPhaseChanged(this.phase);

  final DriversSocketPhase phase;

  @override
  List<Object?> get props => [phase];
}

final class ConnectivityStopped extends ConnectivityEvent {
  const ConnectivityStopped();
}

/// Polls `/api/health` with bounded backoff and tracks WebSocket link status.
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  ConnectivityBloc({
    required HealthRepository healthRepository,
    required DriversLocationsClient locationsClient,
  }) : _health = healthRepository,
       _locations = locationsClient,
       super(const ConnectivityState()) {
    on<ConnectivityStarted>(_onStarted);
    on<HealthCheckRequested>(_onHealthCheck);
    on<SseLinkStatusChanged>(_onSseLink);
    on<WebsocketPhaseChanged>(_onWsPhase);
    on<ConnectivityStopped>(_onStopped);
  }

  final HealthRepository _health;
  final DriversLocationsClient _locations;

  Timer? _timer;
  int _failStreak = 0;
  bool _started = false;
  bool _degraded = false;
  StreamSubscription<DriversSocketPhase>? _wsPhaseSub;

  Future<void> _onStarted(
    ConnectivityStarted event,
    Emitter<ConnectivityState> emit,
  ) async {
    if (_started) {
      return;
    }
    _started = true;
    await _wsPhaseSub?.cancel();
    _wsPhaseSub = _locations.phases.listen((phase) {
      add(WebsocketPhaseChanged(phase));
    });
    add(const HealthCheckRequested());
  }

  Future<void> _onHealthCheck(
    HealthCheckRequested event,
    Emitter<ConnectivityState> emit,
  ) async {
    emit(state.copyWith(polling: true));
    final status = await _health.check();
    var generation = state.recoveryGeneration;

    if (!status.isHealthy) {
      _failStreak += 1;
      _degraded = true;
    } else {
      _failStreak = 0;
      if (_degraded) {
        generation += 1;
        _degraded = false;
      }
    }

    emit(
      state.copyWith(
        health: status,
        recoveryGeneration: generation,
        polling: false,
      ),
    );
    _scheduleNext(status);
  }

  void _onSseLink(SseLinkStatusChanged event, Emitter<ConnectivityState> emit) {
    emit(
      state.copyWith(
        sse: event.live ? RealtimeLink.live : RealtimeLink.reconnecting,
      ),
    );
  }

  void _onWsPhase(
    WebsocketPhaseChanged event,
    Emitter<ConnectivityState> emit,
  ) {
    final link = switch (event.phase) {
      DriversSocketPhase.connected => RealtimeLink.live,
      DriversSocketPhase.connecting ||
      DriversSocketPhase.reconnecting => RealtimeLink.reconnecting,
      DriversSocketPhase.unauthorized ||
      DriversSocketPhase.disconnected => RealtimeLink.down,
    };
    emit(state.copyWith(websocket: link));
  }

  Future<void> _onStopped(
    ConnectivityStopped event,
    Emitter<ConnectivityState> emit,
  ) async {
    _timer?.cancel();
    _timer = null;
    await _wsPhaseSub?.cancel();
    _wsPhaseSub = null;
    _started = false;
  }

  void _scheduleNext(HealthStatus status) {
    _timer?.cancel();
    final seconds = status.isHealthy
        ? 30
        : math.min(
            60,
            status.retryAfterSeconds ?? (2 * math.pow(2, _failStreak).toInt()),
          );
    _timer = Timer(Duration(seconds: seconds), () {
      add(const HealthCheckRequested());
    });
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _wsPhaseSub?.cancel();
    return super.close();
  }
}
