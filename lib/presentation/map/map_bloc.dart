import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/api_exception.dart';
import '../../core/realtime/drivers_locations_client.dart';
import '../../data/mappers/entity_mappers.dart';
import '../../domain/entities/driver.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/tracked_driver.dart';
import '../../domain/usecases/get_driver.dart';

enum MapStatus {
  initial,
  connecting,
  live,
  reconnecting,
  empty,
  error,
  forbidden,
}

class MapState extends Equatable {
  const MapState({
    this.status = MapStatus.initial,
    this.drivers = const [],
    this.selectedId,
    this.selectedDetail,
    this.error,
    this.lastSnapshotAt,
  });

  final MapStatus status;
  final List<TrackedDriver> drivers;
  final String? selectedId;
  final Driver? selectedDetail;
  final String? error;
  final DateTime? lastSnapshotAt;

  TrackedDriver? get selected {
    if (selectedId == null) {
      return null;
    }
    for (final d in drivers) {
      if (d.id == selectedId) {
        return d;
      }
    }
    return null;
  }

  MapState copyWith({
    MapStatus? status,
    List<TrackedDriver>? drivers,
    String? selectedId,
    bool clearSelected = false,
    Driver? selectedDetail,
    bool clearDetail = false,
    String? error,
    bool clearError = false,
    DateTime? lastSnapshotAt,
  }) {
    return MapState(
      status: status ?? this.status,
      drivers: drivers ?? this.drivers,
      selectedId: clearSelected ? null : selectedId ?? this.selectedId,
      selectedDetail: clearDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      error: clearError ? null : error ?? this.error,
      lastSnapshotAt: lastSnapshotAt ?? this.lastSnapshotAt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    drivers,
    selectedId,
    selectedDetail,
    error,
    lastSnapshotAt,
  ];
}

sealed class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => const [];
}

final class MapStarted extends MapEvent {
  const MapStarted();
}

final class MapPhaseUpdated extends MapEvent {
  const MapPhaseUpdated(this.phase);

  final DriversSocketPhase phase;

  @override
  List<Object?> get props => [phase];
}

final class MapSnapshotReceived extends MapEvent {
  const MapSnapshotReceived(this.frame);

  final Map<String, dynamic> frame;

  @override
  List<Object?> get props => [frame];
}

final class DriverSelected extends MapEvent {
  const DriverSelected(this.id);

  final String? id;

  @override
  List<Object?> get props => [id];
}

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc({
    required DriversLocationsClient locationsClient,
    required GetDriver getDriver,
    required Me me,
  }) : _locations = locationsClient,
       _getDriver = getDriver,
       _me = me,
       super(const MapState()) {
    on<MapStarted>(_onStarted);
    on<MapPhaseUpdated>(_onPhase);
    on<MapSnapshotReceived>(_onFrame);
    on<DriverSelected>(_onSelectDriver);
  }

  final DriversLocationsClient _locations;
  final GetDriver _getDriver;
  final Me _me;

  StreamSubscription<Map<String, dynamic>>? _frameSub;
  StreamSubscription<DriversSocketPhase>? _phaseSub;

  bool get canTrack => _me.can('driver', 'track');
  bool get canReadDriver => _me.can('driver', 'read');

  Future<void> _onStarted(MapStarted event, Emitter<MapState> emit) async {
    if (!canTrack) {
      emit(const MapState(status: MapStatus.forbidden));
      return;
    }
    await _phaseSub?.cancel();
    await _frameSub?.cancel();
    _phaseSub = _locations.phases.listen((phase) {
      add(MapPhaseUpdated(phase));
    });
    _frameSub = _locations.frames.listen((frame) {
      add(MapSnapshotReceived(frame));
    });
    emit(state.copyWith(status: MapStatus.connecting, clearError: true));
    await _locations.ensureSubscribed();
  }

  void _onPhase(MapPhaseUpdated event, Emitter<MapState> emit) {
    if (!canTrack) {
      return;
    }
    switch (event.phase) {
      case DriversSocketPhase.connecting:
        emit(state.copyWith(status: MapStatus.connecting));
      case DriversSocketPhase.reconnecting:
        emit(state.copyWith(status: MapStatus.reconnecting));
      case DriversSocketPhase.connected:
        emit(
          state.copyWith(
            status: state.drivers.isEmpty ? MapStatus.empty : MapStatus.live,
            clearError: true,
          ),
        );
      case DriversSocketPhase.unauthorized:
        emit(
          state.copyWith(
            status: MapStatus.error,
            error: 'Live map session expired. Sign in again.',
          ),
        );
      case DriversSocketPhase.disconnected:
        emit(state.copyWith(status: MapStatus.error, error: 'Disconnected.'));
    }
  }

  void _onFrame(MapSnapshotReceived event, Emitter<MapState> emit) {
    final frame = event.frame;
    if (frame['type'] != DriversLocationsClient.channel) {
      return;
    }
    final payload = frame['payload'];
    if (payload is! Map) {
      return;
    }
    final drivers = mapDriversLocationsPayload(
      Map<String, dynamic>.from(payload),
    );
    final at = payload['at'];
    DateTime? snapshotAt;
    if (at is String) {
      snapshotAt = DateTime.tryParse(at);
    }
    emit(
      state.copyWith(
        status: drivers.isEmpty ? MapStatus.empty : MapStatus.live,
        drivers: drivers,
        lastSnapshotAt: snapshotAt,
        clearError: true,
      ),
    );
  }

  Future<void> _onSelectDriver(
    DriverSelected event,
    Emitter<MapState> emit,
  ) async {
    final id = event.id;
    if (id == null) {
      emit(state.copyWith(clearSelected: true, clearDetail: true));
      return;
    }
    emit(state.copyWith(selectedId: id, clearDetail: true));
    if (!canReadDriver) {
      return;
    }
    try {
      final detail = await _getDriver(id);
      if (state.selectedId == id) {
        emit(state.copyWith(selectedDetail: detail));
      }
    } on ApiException catch (error) {
      emit(state.copyWith(error: error.message));
    } catch (_) {
      // Keep marker selection even if detail fetch fails.
    }
  }

  Future<void> _tearDown() async {
    await _frameSub?.cancel();
    await _phaseSub?.cancel();
    _frameSub = null;
    _phaseSub = null;
    await _locations.disconnect();
  }

  @override
  Future<void> close() async {
    await _tearDown();
    return super.close();
  }
}
