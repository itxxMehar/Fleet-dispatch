import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/api_exception.dart';
import '../../core/realtime/ops_events_client.dart';
import '../../core/realtime/sse_event.dart';
import '../../data/mappers/entity_mappers.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/kpis.dart';
import '../../domain/entities/session.dart';
import '../../domain/usecases/get_kpis.dart';
import '../connectivity/connectivity_bloc.dart';

enum DashboardStatus { initial, loading, ready, error, forbidden }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.range = KpiRange.last24h,
    this.kpis,
    this.error,
    this.live = false,
  });

  final DashboardStatus status;
  final KpiRange range;
  final Kpis? kpis;
  final String? error;
  final bool live;

  DashboardState copyWith({
    DashboardStatus? status,
    KpiRange? range,
    Kpis? kpis,
    String? error,
    bool? live,
    bool clearError = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      range: range ?? this.range,
      kpis: kpis ?? this.kpis,
      error: clearError ? null : error ?? this.error,
      live: live ?? this.live,
    );
  }

  @override
  List<Object?> get props => [status, range, kpis, error, live];
}

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => const [];
}

final class DashboardStarted extends DashboardEvent {
  const DashboardStarted();
}

final class LoadKpisRequested extends DashboardEvent {
  const LoadKpisRequested({this.range});

  final KpiRange? range;

  @override
  List<Object?> get props => [range];
}

final class KpiRangeChanged extends DashboardEvent {
  const KpiRangeChanged(this.range);

  final KpiRange range;

  @override
  List<Object?> get props => [range];
}

final class KpiSseReceived extends DashboardEvent {
  const KpiSseReceived(this.event);

  final SseEvent event;

  @override
  List<Object?> get props => [event];
}

final class DashboardSseLinkLost extends DashboardEvent {
  const DashboardSseLinkLost();
}

final class DashboardSseLinkUp extends DashboardEvent {
  const DashboardSseLinkUp();
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetKpis getKpis,
    required OpsEventsClient eventsClient,
    required Me me,
    ConnectivityBloc? connectivity,
  }) : _getKpis = getKpis,
       _events = eventsClient,
       _me = me,
       _connectivity = connectivity,
       super(const DashboardState()) {
    on<DashboardStarted>(_onStarted);
    on<LoadKpisRequested>(_onLoad);
    on<KpiRangeChanged>(_onRangeChanged);
    on<KpiSseReceived>(_onSseEvent);
    on<DashboardSseLinkLost>(_onSseLost);
    on<DashboardSseLinkUp>(_onSseUp);
  }

  final GetKpis _getKpis;
  final OpsEventsClient _events;
  final Me _me;
  final ConnectivityBloc? _connectivity;

  StreamSubscription<SseEvent>? _sseSub;
  StreamSubscription<ConnectivityState>? _recoverySub;
  static const _topics = {'kpi'};
  int _lastRecovery = 0;

  bool get canReadKpis => _me.can('kpi', 'read');

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    if (!canReadKpis) {
      emit(const DashboardState(status: DashboardStatus.forbidden));
      return;
    }
    await _recoverySub?.cancel();
    _recoverySub = _connectivity?.stream.listen((state) {
      if (state.recoveryGeneration > _lastRecovery) {
        _lastRecovery = state.recoveryGeneration;
        add(const LoadKpisRequested());
      }
    });
    await _onLoad(const LoadKpisRequested(), emit);
    await _listenLive(emit);
  }

  Future<void> _onRangeChanged(
    KpiRangeChanged event,
    Emitter<DashboardState> emit,
  ) async {
    await _onLoad(LoadKpisRequested(range: event.range), emit);
  }

  Future<void> _onLoad(
    LoadKpisRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (!canReadKpis) {
      emit(const DashboardState(status: DashboardStatus.forbidden));
      return;
    }
    final nextRange = event.range ?? state.range;
    emit(
      state.copyWith(
        status: DashboardStatus.loading,
        range: nextRange,
        clearError: true,
      ),
    );
    try {
      final kpis = await _getKpis(cityId: _me.city?.id, range: nextRange);
      emit(
        state.copyWith(
          status: DashboardStatus.ready,
          kpis: kpis,
          clearError: true,
        ),
      );
    } on ApiException catch (error) {
      if (error.isForbidden) {
        emit(const DashboardState(status: DashboardStatus.forbidden));
        return;
      }
      emit(state.copyWith(status: DashboardStatus.error, error: error.message));
    } catch (_) {
      emit(
        state.copyWith(
          status: DashboardStatus.error,
          error: 'Unable to load KPIs. Please try again.',
        ),
      );
    }
  }

  Future<void> _listenLive(Emitter<DashboardState> emit) async {
    await _sseSub?.cancel();
    final stream = await _events.subscribe(_topics);
    _sseSub = stream.listen(
      (event) {
        _connectivity?.add(const SseLinkStatusChanged(live: true));
        add(KpiSseReceived(event));
      },
      onError: (_) {
        _connectivity?.add(const SseLinkStatusChanged(live: false));
        add(const DashboardSseLinkLost());
      },
    );
    _connectivity?.add(const SseLinkStatusChanged(live: true));
    emit(state.copyWith(live: true));
  }

  void _onSseEvent(KpiSseReceived event, Emitter<DashboardState> emit) {
    if (event.event.event != 'kpi' || state.range != KpiRange.last24h) {
      return;
    }
    final json = OpsEventsClient.decodeJsonMap(event.event.data);
    if (json == null) {
      return;
    }
    try {
      final kpis = mapKpis(json);
      emit(
        state.copyWith(
          status: DashboardStatus.ready,
          kpis: kpis,
          live: true,
          clearError: true,
        ),
      );
    } catch (_) {
      // Ignore malformed live payloads.
    }
  }

  void _onSseLost(DashboardSseLinkLost event, Emitter<DashboardState> emit) {
    emit(state.copyWith(live: false));
  }

  void _onSseUp(DashboardSseLinkUp event, Emitter<DashboardState> emit) {
    emit(state.copyWith(live: true));
  }

  Future<void> _tearDown() async {
    await _sseSub?.cancel();
    _sseSub = null;
    await _recoverySub?.cancel();
    _recoverySub = null;
    await _events.unsubscribe(_topics);
  }

  @override
  Future<void> close() async {
    await _tearDown();
    return super.close();
  }
}
