import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/api_exception.dart';
import '../../core/realtime/ops_events_client.dart';
import '../../core/realtime/sse_event.dart';
import '../../data/mappers/entity_mappers.dart';
import '../../domain/entities/driver.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/trip.dart';
import '../../domain/usecases/trip_actions.dart';
import '../connectivity/connectivity_bloc.dart';

enum TripsStatus { initial, loading, ready, loadingMore, error }

class TripsState extends Equatable {
  const TripsState({
    this.status = TripsStatus.initial,
    this.trips = const [],
    this.totalCount = 0,
    this.endCursor,
    this.hasNextPage = false,
    this.statusFilter = const {},
    this.search = '',
    this.from,
    this.to,
    this.error,
    this.actionError,
    this.actionBusy = false,
    this.highlightedIds = const {},
    this.detail,
    this.availableDrivers = const [],
  });

  final TripsStatus status;
  final List<Trip> trips;
  final int totalCount;
  final String? endCursor;
  final bool hasNextPage;
  final Set<TripStatus> statusFilter;
  final String search;
  final DateTime? from;
  final DateTime? to;
  final String? error;
  final String? actionError;
  final bool actionBusy;
  final Set<String> highlightedIds;
  final Trip? detail;
  final List<Driver> availableDrivers;

  bool get canRead => true; // gated by shell; actions check below

  TripsState copyWith({
    TripsStatus? status,
    List<Trip>? trips,
    int? totalCount,
    String? endCursor,
    bool clearEndCursor = false,
    bool? hasNextPage,
    Set<TripStatus>? statusFilter,
    String? search,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
    String? error,
    bool clearError = false,
    String? actionError,
    bool clearActionError = false,
    bool? actionBusy,
    Set<String>? highlightedIds,
    Trip? detail,
    bool clearDetail = false,
    List<Driver>? availableDrivers,
  }) {
    return TripsState(
      status: status ?? this.status,
      trips: trips ?? this.trips,
      totalCount: totalCount ?? this.totalCount,
      endCursor: clearEndCursor ? null : endCursor ?? this.endCursor,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      error: clearError ? null : error ?? this.error,
      actionError: clearActionError ? null : actionError ?? this.actionError,
      actionBusy: actionBusy ?? this.actionBusy,
      highlightedIds: highlightedIds ?? this.highlightedIds,
      detail: clearDetail ? null : detail ?? this.detail,
      availableDrivers: availableDrivers ?? this.availableDrivers,
    );
  }

  @override
  List<Object?> get props => [
    status,
    trips,
    totalCount,
    endCursor,
    hasNextPage,
    statusFilter,
    search,
    from,
    to,
    error,
    actionError,
    actionBusy,
    highlightedIds,
    detail,
    availableDrivers,
  ];
}

abstract class TripsEvent extends Equatable {
  const TripsEvent();

  @override
  List<Object?> get props => [];
}

class TripsStarted extends TripsEvent {
  const TripsStarted();
}

class RefreshTrips extends TripsEvent {
  const RefreshTrips();
}

class LoadMoreTrips extends TripsEvent {
  const LoadMoreTrips();
}

class SetStatusFilter extends TripsEvent {
  const SetStatusFilter(this.statuses);

  final Set<TripStatus> statuses;

  @override
  List<Object?> get props => [statuses];
}

class SetSearch extends TripsEvent {
  const SetSearch(this.search);

  final String search;

  @override
  List<Object?> get props => [search];
}

class SetDateRange extends TripsEvent {
  const SetDateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  @override
  List<Object?> get props => [from, to];
}

class OpenTripDetail extends TripsEvent {
  const OpenTripDetail(this.tripId);

  final String tripId;

  @override
  List<Object?> get props => [tripId];
}

class CloseTripDetail extends TripsEvent {
  const CloseTripDetail();
}

class AssignTripRequested extends TripsEvent {
  const AssignTripRequested({required this.tripId, required this.driverId});

  final String tripId;
  final String driverId;

  @override
  List<Object?> get props => [tripId, driverId];
}

class CancelTripRequested extends TripsEvent {
  const CancelTripRequested({required this.tripId, required this.reason});

  final String tripId;
  final String reason;

  @override
  List<Object?> get props => [tripId, reason];
}

class RefundTripRequested extends TripsEvent {
  const RefundTripRequested({
    required this.tripId,
    required this.amount,
    required this.reason,
  });

  final String tripId;
  final double amount;
  final String reason;

  @override
  List<Object?> get props => [tripId, amount, reason];
}

class TripSseReceived extends TripsEvent {
  const TripSseReceived(this.event);

  final SseEvent event;

  @override
  List<Object?> get props => [event];
}

class ClearTripHighlight extends TripsEvent {
  const ClearTripHighlight(this.tripId);

  final String tripId;

  @override
  List<Object?> get props => [tripId];
}

class TripsStopped extends TripsEvent {
  const TripsStopped();
}

class TripsBloc extends Bloc<TripsEvent, TripsState> {
  TripsBloc({
    required ListTrips listTrips,
    required GetTrip getTrip,
    required AssignTrip assignTrip,
    required CancelTrip cancelTrip,
    required RefundTrip refundTrip,
    required ListAvailableDrivers listAvailableDrivers,
    required OpsEventsClient eventsClient,
    required Me me,
    ConnectivityBloc? connectivity,
  }) : _listTrips = listTrips,
       _getTrip = getTrip,
       _assignTrip = assignTrip,
       _cancelTrip = cancelTrip,
       _refundTrip = refundTrip,
       _listDrivers = listAvailableDrivers,
       _events = eventsClient,
       _me = me,
       _connectivity = connectivity,
       super(const TripsState()) {
    on<TripsStarted>(_onStarted);
    on<RefreshTrips>(_onRefresh);
    on<LoadMoreTrips>(_onLoadMore);
    on<SetStatusFilter>(_onSetStatusFilter);
    on<SetSearch>(_onSetSearch);
    on<SetDateRange>(_onSetDateRange);
    on<OpenTripDetail>(_onOpenDetail);
    on<CloseTripDetail>(_onCloseDetail);
    on<AssignTripRequested>(_onAssign);
    on<CancelTripRequested>(_onCancel);
    on<RefundTripRequested>(_onRefund);
    on<TripSseReceived>(_onSse);
    on<ClearTripHighlight>(_onClearHighlight);
    on<TripsStopped>(_onStopped);
  }

  final ListTrips _listTrips;
  final GetTrip _getTrip;
  final AssignTrip _assignTrip;
  final CancelTrip _cancelTrip;
  final RefundTrip _refundTrip;
  final ListAvailableDrivers _listDrivers;
  final OpsEventsClient _events;
  final Me _me;
  final ConnectivityBloc? _connectivity;

  StreamSubscription<SseEvent>? _sseSub;
  StreamSubscription<ConnectivityState>? _recoverySub;
  final Map<String, Timer> _highlightTimers = {};
  static const _topics = {'trips'};
  static const _pageSize = 20;
  int _lastRecovery = 0;

  bool canAssign() => _me.can('trip', 'assign');
  bool canCancel() => _me.can('trip', 'cancel');
  bool canRefund() => _me.can('trip', 'refund');

  Future<void> _onStarted(TripsStarted event, Emitter<TripsState> emit) async {
    await _recoverySub?.cancel();
    _recoverySub = _connectivity?.stream.listen((state) {
      if (state.recoveryGeneration > _lastRecovery) {
        _lastRecovery = state.recoveryGeneration;
        add(const RefreshTrips());
      }
    });
    await _refresh(emit);
    await _listenLive();
  }

  Future<void> _onRefresh(RefreshTrips event, Emitter<TripsState> emit) async {
    await _refresh(emit);
  }

  Future<void> _refresh(Emitter<TripsState> emit) async {
    emit(
      state.copyWith(
        status: TripsStatus.loading,
        clearError: true,
        trips: const [],
        clearEndCursor: true,
        hasNextPage: false,
      ),
    );
    await _fetch(emit, reset: true);
  }

  Future<void> _onLoadMore(
    LoadMoreTrips event,
    Emitter<TripsState> emit,
  ) async {
    if (!state.hasNextPage || state.status == TripsStatus.loadingMore) {
      return;
    }
    emit(state.copyWith(status: TripsStatus.loadingMore));
    await _fetch(emit, reset: false);
  }

  Future<void> _onSetStatusFilter(
    SetStatusFilter event,
    Emitter<TripsState> emit,
  ) async {
    emit(state.copyWith(statusFilter: event.statuses));
    await _refresh(emit);
  }

  Future<void> _onSetSearch(SetSearch event, Emitter<TripsState> emit) async {
    emit(state.copyWith(search: event.search.trim()));
    await _refresh(emit);
  }

  Future<void> _onSetDateRange(
    SetDateRange event,
    Emitter<TripsState> emit,
  ) async {
    emit(
      state.copyWith(
        from: event.from,
        to: event.to,
        clearFrom: event.from == null,
        clearTo: event.to == null,
      ),
    );
    await _refresh(emit);
  }

  Future<void> _onOpenDetail(
    OpenTripDetail event,
    Emitter<TripsState> emit,
  ) async {
    try {
      final trip = await _getTrip(event.tripId);
      List<Driver> drivers = state.availableDrivers;
      if (canAssign() && trip.status == TripStatus.requested) {
        final page = await _listDrivers(cityId: trip.cityId);
        drivers = page.nodes;
      }
      emit(state.copyWith(detail: trip, availableDrivers: drivers));
    } on ApiException catch (error) {
      emit(state.copyWith(actionError: error.message));
    }
  }

  void _onCloseDetail(CloseTripDetail event, Emitter<TripsState> emit) {
    emit(state.copyWith(clearDetail: true));
  }

  Future<void> _onAssign(
    AssignTripRequested event,
    Emitter<TripsState> emit,
  ) async {
    if (!canAssign() || state.actionBusy) {
      return;
    }
    emit(state.copyWith(actionBusy: true, clearActionError: true));
    try {
      final trip = await _assignTrip(
        tripId: event.tripId,
        driverId: event.driverId,
      );
      _upsert(emit, trip, highlight: true);
      emit(state.copyWith(actionBusy: false, detail: trip));
    } on ApiException catch (error) {
      await _handleActionError(emit, error, event.tripId);
    }
  }

  Future<void> _onCancel(
    CancelTripRequested event,
    Emitter<TripsState> emit,
  ) async {
    if (!canCancel() || state.actionBusy) {
      return;
    }
    final trimmed = event.reason.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(actionError: 'A cancel reason is required.'));
      return;
    }
    emit(state.copyWith(actionBusy: true, clearActionError: true));
    try {
      final trip = await _cancelTrip(tripId: event.tripId, reason: trimmed);
      _upsert(emit, trip, highlight: true);
      emit(state.copyWith(actionBusy: false, detail: trip));
    } on ApiException catch (error) {
      await _handleActionError(emit, error, event.tripId);
    }
  }

  Future<void> _onRefund(
    RefundTripRequested event,
    Emitter<TripsState> emit,
  ) async {
    if (!canRefund() || state.actionBusy) {
      return;
    }
    Trip? trip = state.detail;
    if (trip == null || trip.id != event.tripId) {
      for (final item in state.trips) {
        if (item.id == event.tripId) {
          trip = item;
          break;
        }
      }
    }
    if (trip == null) {
      emit(
        state.copyWith(
          actionError: 'Trip not found locally. Refresh and retry.',
        ),
      );
      return;
    }
    final trimmed = event.reason.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(actionError: 'A refund reason is required.'));
      return;
    }
    final validation = RefundRules.validate(
      amount: event.amount,
      fare: trip.fare,
      refunded: trip.refunded,
    );
    if (validation != null) {
      emit(state.copyWith(actionError: validation));
      return;
    }
    emit(state.copyWith(actionBusy: true, clearActionError: true));
    try {
      final updated = await _refundTrip(
        tripId: event.tripId,
        amount: event.amount,
        reason: trimmed,
      );
      _upsert(emit, updated, highlight: true);
      emit(state.copyWith(actionBusy: false, detail: updated));
    } on ApiException catch (error) {
      await _handleActionError(emit, error, event.tripId);
    }
  }

  Future<void> _fetch(Emitter<TripsState> emit, {required bool reset}) async {
    try {
      final page = await _listTrips(
        status: state.statusFilter.isEmpty ? null : state.statusFilter.toList(),
        cityId: _me.city?.id,
        search: state.search.isEmpty ? null : state.search,
        from: state.from,
        to: state.to,
        first: _pageSize,
        after: reset ? null : state.endCursor,
      );
      final trips = reset ? page.nodes : [...state.trips, ...page.nodes];
      emit(
        state.copyWith(
          status: TripsStatus.ready,
          trips: trips,
          totalCount: page.totalCount,
          endCursor: page.endCursor,
          hasNextPage: page.hasNextPage,
          clearError: true,
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(status: TripsStatus.error, error: error.message));
    } catch (_) {
      emit(
        state.copyWith(
          status: TripsStatus.error,
          error: 'Unable to load trips. Please try again.',
        ),
      );
    }
  }

  Future<void> _handleActionError(
    Emitter<TripsState> emit,
    ApiException error,
    String tripId,
  ) async {
    var message = error.message;
    if (error.isConflict) {
      message =
          'This trip changed on the server ($message). Refreshing details…';
      try {
        final fresh = await _getTrip(tripId);
        _upsert(emit, fresh, highlight: true);
        emit(
          state.copyWith(
            actionBusy: false,
            actionError: message,
            detail: fresh,
          ),
        );
        return;
      } catch (_) {
        // fall through
      }
    }
    emit(state.copyWith(actionBusy: false, actionError: message));
  }

  void _upsert(Emitter<TripsState> emit, Trip trip, {bool highlight = false}) {
    final list = [...state.trips];
    final index = list.indexWhere((t) => t.id == trip.id);
    if (index >= 0) {
      list[index] = trip;
    } else {
      list.insert(0, trip);
    }
    final highlights = {...state.highlightedIds};
    if (highlight) {
      highlights.add(trip.id);
      _highlightTimers[trip.id]?.cancel();
      _highlightTimers[trip.id] = Timer(const Duration(seconds: 4), () {
        if (isClosed) {
          return;
        }
        add(ClearTripHighlight(trip.id));
      });
    }
    emit(state.copyWith(trips: list, highlightedIds: highlights));
  }

  void _onClearHighlight(ClearTripHighlight event, Emitter<TripsState> emit) {
    final next = {...state.highlightedIds}..remove(event.tripId);
    emit(state.copyWith(highlightedIds: next));
  }

  Future<void> _listenLive() async {
    await _sseSub?.cancel();
    final stream = await _events.subscribe(_topics);
    _sseSub = stream.listen(
      (event) {
        // EventSource auto-reconnects; any delivered event means the link is up.
        _connectivity?.add(const SseLinkStatusChanged(live: true));
        add(TripSseReceived(event));
      },
      onError: (_) {
        // Generic EventSource errors are not auth signals — banner only.
        _connectivity?.add(const SseLinkStatusChanged(live: false));
      },
    );
    _connectivity?.add(const SseLinkStatusChanged(live: true));
  }

  void _onSse(TripSseReceived event, Emitter<TripsState> emit) {
    final sse = event.event;
    if (sse.event != 'trip.created' && sse.event != 'trip.updated') {
      return;
    }
    final json = OpsEventsClient.decodeJsonMap(sse.data);
    if (json == null) {
      return;
    }
    final tripJson = json['trip'];
    if (tripJson is! Map) {
      return;
    }
    try {
      final trip = mapTrip(Map<String, dynamic>.from(tripJson));
      if (!_matchesFilters(trip) && sse.event == 'trip.created') {
        return;
      }
      if (!_matchesFilters(trip) && sse.event == 'trip.updated') {
        final list = state.trips.where((t) => t.id != trip.id).toList();
        emit(state.copyWith(trips: list));
        return;
      }
      _upsert(emit, trip, highlight: true);
      if (state.detail?.id == trip.id) {
        emit(state.copyWith(detail: trip));
      }
    } catch (_) {
      // Malformed live payload — ignore.
    }
  }

  bool _matchesFilters(Trip trip) {
    if (state.statusFilter.isNotEmpty &&
        !state.statusFilter.contains(trip.status)) {
      return false;
    }
    if (state.search.isNotEmpty) {
      final q = state.search.toLowerCase();
      final haystack = [
        trip.id,
        trip.pickup.address,
        trip.dropoff.address,
        trip.rider?.name ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(q)) {
        return false;
      }
    }
    if (state.from != null && trip.requestedAt.isBefore(state.from!)) {
      return false;
    }
    if (state.to != null && !trip.requestedAt.isBefore(state.to!)) {
      return false;
    }
    return true;
  }

  Future<void> _onStopped(TripsStopped event, Emitter<TripsState> emit) async {
    await _stop();
  }

  Future<void> _stop() async {
    await _sseSub?.cancel();
    _sseSub = null;
    await _recoverySub?.cancel();
    _recoverySub = null;
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    _highlightTimers.clear();
    await _events.unsubscribe(_topics);
  }

  @override
  Future<void> close() async {
    await _stop();
    return super.close();
  }
}
