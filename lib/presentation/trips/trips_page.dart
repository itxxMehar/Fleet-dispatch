import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/realtime/ops_events_client.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session.dart';
import '../../domain/usecases/trip_actions.dart';
import '../connectivity/connectivity_bloc.dart';
import 'trip_detail_sheet.dart';
import 'trip_status_label.dart';
import 'trips_bloc.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TripsBloc(
        listTrips: sl<ListTrips>(),
        getTrip: sl<GetTrip>(),
        assignTrip: sl<AssignTrip>(),
        cancelTrip: sl<CancelTrip>(),
        refundTrip: sl<RefundTrip>(),
        listAvailableDrivers: sl<ListAvailableDrivers>(),
        eventsClient: sl<OpsEventsClient>(),
        me: me,
        connectivity: sl.isRegistered<ConnectivityBloc>()
            ? sl<ConnectivityBloc>()
            : null,
      )..add(const TripsStarted()),
      child: const _TripsView(),
    );
  }
}

class _TripsView extends StatefulWidget {
  const _TripsView();

  @override
  State<_TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<_TripsView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openTrip(BuildContext context, String tripId) async {
    final bloc = context.read<TripsBloc>();
    final wait = bloc.stream.firstWhere(
      (s) => s.detail?.id == tripId || s.actionError != null,
    );
    bloc.add(OpenTripDetail(tripId));
    await wait;
    if (!context.mounted) {
      return;
    }
    final detail = bloc.state.detail;
    if (detail == null || detail.id != tripId) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: TripDetailSheet(trip: detail),
      ),
    );
    bloc.add(const CloseTripDetail());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TripsBloc, TripsState>(
      listenWhen: (p, c) =>
          c.actionError != null && c.actionError != p.actionError,
      listener: (context, state) {
        final message = state.actionError;
        if (message == null) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: BlocBuilder<TripsBloc, TripsState>(
        builder: (context, state) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: _FiltersBar(
                      searchController: _searchController,
                      state: state,
                    ),
                  ),
                  Expanded(
                    child: _TripsBody(
                      state: state,
                      onOpen: (id) => _openTrip(context, id),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({required this.searchController, required this.state});

  final TextEditingController searchController;
  final TripsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TripsBloc>();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Trip id, address, rider',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) => bloc.add(SetSearch(value)),
          ),
        ),
        FilterChip(
          label: const Text('Requested'),
          selected: state.statusFilter.contains(TripStatus.requested),
          onSelected: (selected) =>
              _toggle(context, TripStatus.requested, selected),
        ),
        FilterChip(
          label: const Text('Assigned'),
          selected: state.statusFilter.contains(TripStatus.assigned),
          onSelected: (selected) =>
              _toggle(context, TripStatus.assigned, selected),
        ),
        FilterChip(
          label: const Text('In progress'),
          selected: state.statusFilter.contains(TripStatus.inProgress),
          onSelected: (selected) =>
              _toggle(context, TripStatus.inProgress, selected),
        ),
        FilterChip(
          label: const Text('Completed'),
          selected: state.statusFilter.contains(TripStatus.completed),
          onSelected: (selected) =>
              _toggle(context, TripStatus.completed, selected),
        ),
        FilterChip(
          label: const Text('Cancelled'),
          selected: state.statusFilter.contains(TripStatus.cancelled),
          onSelected: (selected) =>
              _toggle(context, TripStatus.cancelled, selected),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: state.from != null && state.to != null
                  ? DateTimeRange(start: state.from!, end: state.to!)
                  : null,
            );
            if (range != null) {
              bloc.add(
                SetDateRange(
                  from: range.start.toUtc(),
                  to: range.end.add(const Duration(days: 1)).toUtc(),
                ),
              );
            }
          },
          icon: const Icon(Icons.date_range),
          label: Text(
            state.from == null
                ? 'Date range'
                : '${_fmt(state.from!)} – ${_fmt(state.to!)}',
          ),
        ),
        if (state.from != null)
          TextButton(
            onPressed: () => bloc.add(const SetDateRange()),
            child: const Text('Clear dates'),
          ),
        TextButton(
          onPressed: state.status == TripsStatus.loading
              ? null
              : () => bloc.add(const RefreshTrips()),
          child: const Text('Refresh'),
        ),
      ],
    );
  }

  void _toggle(BuildContext context, TripStatus status, bool selected) {
    final next = {...context.read<TripsBloc>().state.statusFilter};
    if (selected) {
      next.add(status);
    } else {
      next.remove(status);
    }
    context.read<TripsBloc>().add(SetStatusFilter(next));
  }

  String _fmt(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _TripsBody extends StatelessWidget {
  const _TripsBody({required this.state, required this.onOpen});

  final TripsState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.status == TripsStatus.loading && state.trips.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == TripsStatus.error && state.trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error ?? 'Failed to load trips.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  context.read<TripsBloc>().add(const RefreshTrips()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.trips.isEmpty) {
      return const Center(child: Text('No trips match these filters.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${state.totalCount} trips'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('Trip')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('City')),
                    DataColumn(label: Text('Rider')),
                    DataColumn(label: Text('Driver')),
                    DataColumn(label: Text('Fare')),
                    DataColumn(label: Text('Requested')),
                  ],
                  rows: [
                    for (final trip in state.trips)
                      DataRow(
                        color: state.highlightedIds.contains(trip.id)
                            ? WidgetStatePropertyAll(
                                Colors.teal.withValues(alpha: 0.08),
                              )
                            : null,
                        onSelectChanged: (_) => onOpen(trip.id),
                        cells: [
                          DataCell(Text(trip.id)),
                          DataCell(Text(tripStatusLabel(trip.status))),
                          DataCell(Text(trip.city?.name ?? trip.cityId)),
                          DataCell(Text(trip.rider?.name ?? trip.riderId)),
                          DataCell(
                            Text(trip.driver?.name ?? trip.driverId ?? '—'),
                          ),
                          DataCell(
                            Text(
                              '${trip.fare.currency} ${trip.fare.amount.toStringAsFixed(2)}',
                            ),
                          ),
                          DataCell(Text(_fmtTime(trip.requestedAt))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (state.hasNextPage)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: state.status == TripsStatus.loadingMore
                  ? null
                  : () => context.read<TripsBloc>().add(const LoadMoreTrips()),
              child: state.status == TripsStatus.loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more'),
            ),
          ),
      ],
    );
  }

  String _fmtTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
