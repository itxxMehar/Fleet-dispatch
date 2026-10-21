import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/api_exception.dart';
import '../../core/realtime/ops_events_client.dart';
import '../../core/realtime/sse_event.dart';
import '../../data/mappers/entity_mappers.dart';
import '../../domain/entities/alert.dart';
import '../../domain/entities/session.dart';
import '../../domain/usecases/alert_actions.dart';
import '../connectivity/connectivity_bloc.dart';

enum AlertsStatus { initial, loading, ready, error, forbidden }

class AlertsState extends Equatable {
  const AlertsState({
    this.status = AlertsStatus.initial,
    this.alerts = const [],
    this.totalCount = 0,
    this.error,
    this.actionError,
    this.acknowledgingId,
    this.live = false,
  });

  final AlertsStatus status;
  final List<OpsAlert> alerts;
  final int totalCount;
  final String? error;
  final String? actionError;
  final String? acknowledgingId;
  final bool live;

  AlertsState copyWith({
    AlertsStatus? status,
    List<OpsAlert>? alerts,
    int? totalCount,
    String? error,
    bool clearError = false,
    String? actionError,
    bool clearActionError = false,
    String? acknowledgingId,
    bool clearAcknowledging = false,
    bool? live,
  }) {
    return AlertsState(
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      totalCount: totalCount ?? this.totalCount,
      error: clearError ? null : error ?? this.error,
      actionError: clearActionError ? null : actionError ?? this.actionError,
      acknowledgingId: clearAcknowledging
          ? null
          : acknowledgingId ?? this.acknowledgingId,
      live: live ?? this.live,
    );
  }

  @override
  List<Object?> get props => [
    status,
    alerts,
    totalCount,
    error,
    actionError,
    acknowledgingId,
    live,
  ];
}

sealed class AlertsEvent extends Equatable {
  const AlertsEvent();

  @override
  List<Object?> get props => const [];
}

final class AlertsStarted extends AlertsEvent {
  const AlertsStarted();
}

final class LoadAlertsRequested extends AlertsEvent {
  const LoadAlertsRequested();
}

final class AcknowledgeAlertRequested extends AlertsEvent {
  const AcknowledgeAlertRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class AlertSseReceived extends AlertsEvent {
  const AlertSseReceived(this.event);

  final SseEvent event;

  @override
  List<Object?> get props => [event];
}

final class AlertsSseLinkLost extends AlertsEvent {
  const AlertsSseLinkLost();
}

class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  AlertsBloc({
    required ListAlerts listAlerts,
    required AcknowledgeAlert acknowledgeAlert,
    required OpsEventsClient eventsClient,
    required Me me,
    ConnectivityBloc? connectivity,
  }) : _listAlerts = listAlerts,
       _acknowledgeAlert = acknowledgeAlert,
       _events = eventsClient,
       _me = me,
       _connectivity = connectivity,
       super(const AlertsState()) {
    on<AlertsStarted>(_onStarted);
    on<LoadAlertsRequested>(_onLoad);
    on<AcknowledgeAlertRequested>(_onAcknowledge);
    on<AlertSseReceived>(_onSseEvent);
    on<AlertsSseLinkLost>(_onSseLost);
  }

  final ListAlerts _listAlerts;
  final AcknowledgeAlert _acknowledgeAlert;
  final OpsEventsClient _events;
  final Me _me;
  final ConnectivityBloc? _connectivity;

  StreamSubscription<SseEvent>? _sseSub;
  StreamSubscription<ConnectivityState>? _recoverySub;
  static const _topics = {'alerts'};
  int _lastRecovery = 0;

  bool get canRead => _me.can('alert', 'read');
  bool get canAcknowledge => _me.can('alert', 'acknowledge');

  Future<void> _onStarted(
    AlertsStarted event,
    Emitter<AlertsState> emit,
  ) async {
    if (!canRead) {
      emit(const AlertsState(status: AlertsStatus.forbidden));
      return;
    }
    await _recoverySub?.cancel();
    _recoverySub = _connectivity?.stream.listen((state) {
      if (state.recoveryGeneration > _lastRecovery) {
        _lastRecovery = state.recoveryGeneration;
        add(const LoadAlertsRequested());
      }
    });
    await _onLoad(const LoadAlertsRequested(), emit);
    await _listenLive(emit);
  }

  Future<void> _onLoad(
    LoadAlertsRequested event,
    Emitter<AlertsState> emit,
  ) async {
    if (!canRead) {
      emit(const AlertsState(status: AlertsStatus.forbidden));
      return;
    }
    emit(state.copyWith(status: AlertsStatus.loading, clearError: true));
    try {
      final page = await _listAlerts(cityId: _me.city?.id, first: 50);
      emit(
        state.copyWith(
          status: AlertsStatus.ready,
          alerts: page.nodes,
          totalCount: page.totalCount,
          clearError: true,
        ),
      );
    } on ApiException catch (error) {
      if (error.isForbidden) {
        emit(const AlertsState(status: AlertsStatus.forbidden));
        return;
      }
      emit(state.copyWith(status: AlertsStatus.error, error: error.message));
    } catch (_) {
      emit(
        state.copyWith(
          status: AlertsStatus.error,
          error: 'Unable to load alerts. Please try again.',
        ),
      );
    }
  }

  Future<void> _onAcknowledge(
    AcknowledgeAlertRequested event,
    Emitter<AlertsState> emit,
  ) async {
    if (!canAcknowledge || state.acknowledgingId != null) {
      return;
    }
    emit(state.copyWith(acknowledgingId: event.id, clearActionError: true));
    try {
      final updated = await _acknowledgeAlert(event.id);
      _upsert(updated, emit);
      emit(state.copyWith(clearAcknowledging: true));
    } on ApiException catch (error) {
      emit(
        state.copyWith(clearAcknowledging: true, actionError: error.message),
      );
    } catch (_) {
      emit(
        state.copyWith(
          clearAcknowledging: true,
          actionError: 'Acknowledge failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _listenLive(Emitter<AlertsState> emit) async {
    await _sseSub?.cancel();
    final stream = await _events.subscribe(_topics);
    _sseSub = stream.listen(
      (event) {
        _connectivity?.add(const SseLinkStatusChanged(live: true));
        add(AlertSseReceived(event));
      },
      onError: (_) {
        _connectivity?.add(const SseLinkStatusChanged(live: false));
        add(const AlertsSseLinkLost());
      },
    );
    _connectivity?.add(const SseLinkStatusChanged(live: true));
    emit(state.copyWith(live: true));
  }

  void _onSseEvent(AlertSseReceived event, Emitter<AlertsState> emit) {
    if (event.event.event != 'alert.created' &&
        event.event.event != 'alert.acknowledged') {
      return;
    }
    final json = OpsEventsClient.decodeJsonMap(event.event.data);
    if (json == null) {
      return;
    }
    final alertJson = json['alert'];
    if (alertJson is! Map) {
      return;
    }
    try {
      final alert = mapAlert(Map<String, dynamic>.from(alertJson));
      _upsert(alert, emit);
    } catch (_) {
      // Ignore malformed live payloads.
    }
  }

  void _onSseLost(AlertsSseLinkLost event, Emitter<AlertsState> emit) {
    emit(state.copyWith(live: false));
  }

  void _upsert(OpsAlert alert, Emitter<AlertsState> emit) {
    final list = [...state.alerts];
    final index = list.indexWhere((a) => a.id == alert.id);
    if (index >= 0) {
      list[index] = alert;
    } else {
      list.insert(0, alert);
    }
    emit(
      state.copyWith(
        status: AlertsStatus.ready,
        alerts: list,
        totalCount: index >= 0 ? state.totalCount : state.totalCount + 1,
      ),
    );
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
