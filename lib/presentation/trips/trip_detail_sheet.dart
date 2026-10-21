import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/trip.dart';
import '../../domain/usecases/trip_actions.dart';
import 'trip_status_label.dart';
import 'trips_bloc.dart';

class TripDetailSheet extends StatelessWidget {
  const TripDetailSheet({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripsBloc, TripsState>(
      builder: (context, state) {
        final current = state.detail ?? trip;
        final bloc = context.read<TripsBloc>();
        final timeline = tripTimeline(
          TripTimestamps(
            requestedAt: current.requestedAt,
            assignedAt: current.assignedAt,
            startedAt: current.startedAt,
            completedAt: current.completedAt,
            cancelledAt: current.cancelledAt,
          ),
        );

        return AlertDialog(
          title: Text(current.id),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${tripStatusLabel(current.status)}'),
                  const SizedBox(height: 8),
                  Text('City: ${current.city?.name ?? current.cityId}'),
                  Text('Rider: ${current.rider?.name ?? current.riderId}'),
                  if (current.rider?.phone != null)
                    Text('Rider phone: ${current.rider!.phone}'),
                  Text(
                    'Driver: ${current.driver?.name ?? current.driverId ?? 'Unassigned'}',
                  ),
                  const SizedBox(height: 12),
                  Text('Pickup: ${current.pickup.address}'),
                  Text(
                    '(${current.pickup.lat.toStringAsFixed(4)}, ${current.pickup.lng.toStringAsFixed(4)})',
                  ),
                  const SizedBox(height: 8),
                  Text('Drop-off: ${current.dropoff.address}'),
                  Text(
                    '(${current.dropoff.lat.toStringAsFixed(4)}, ${current.dropoff.lng.toStringAsFixed(4)})',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fare: ${current.fare.currency} ${current.fare.amount.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Refunded: ${current.refunded.currency} ${current.refunded.amount.toStringAsFixed(2)}',
                  ),
                  if (current.refundReason != null)
                    Text('Refund reason: ${current.refundReason}'),
                  if (current.cancelReason != null)
                    Text('Cancel reason: ${current.cancelReason}'),
                  const SizedBox(height: 16),
                  Text(
                    'Timeline',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final event in timeline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${tripStatusLabel(event.status)} · ${_fmt(event.at)}',
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (bloc.canAssign() &&
                      current.status == TripStatus.requested)
                    _AssignSection(tripId: current.id),
                  if (bloc.canCancel() &&
                      (current.status == TripStatus.requested ||
                          current.status == TripStatus.assigned ||
                          current.status == TripStatus.inProgress))
                    _CancelSection(tripId: current.id),
                  if (bloc.canRefund() &&
                      current.status == TripStatus.completed)
                    _RefundSection(trip: current),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.actionBusy
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _fmt(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _AssignSection extends StatefulWidget {
  const _AssignSection({required this.tripId});

  final String tripId;

  @override
  State<_AssignSection> createState() => _AssignSectionState();
}

class _AssignSectionState extends State<_AssignSection> {
  String? _driverId;

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<TripsBloc>();
    final drivers = bloc.state.availableDrivers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text('Assign driver', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _driverId,
          items: [
            for (final driver in drivers)
              DropdownMenuItem(
                value: driver.id,
                child: Text('${driver.name} (${driver.id})'),
              ),
          ],
          onChanged: bloc.state.actionBusy
              ? null
              : (value) => setState(() => _driverId = value),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Available driver',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: bloc.state.actionBusy || _driverId == null
              ? null
              : () => bloc.add(
                  AssignTripRequested(
                    tripId: widget.tripId,
                    driverId: _driverId!,
                  ),
                ),
          child: bloc.state.actionBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}

class _CancelSection extends StatefulWidget {
  const _CancelSection({required this.tripId});

  final String tripId;

  @override
  State<_CancelSection> createState() => _CancelSectionState();
}

class _CancelSectionState extends State<_CancelSection> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<TripsBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text('Cancel trip', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _reason,
          enabled: !bloc.state.actionBusy,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Reason',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: bloc.state.actionBusy
              ? null
              : () => bloc.add(
                  CancelTripRequested(
                    tripId: widget.tripId,
                    reason: _reason.text,
                  ),
                ),
          child: const Text('Cancel trip'),
        ),
      ],
    );
  }
}

class _RefundSection extends StatefulWidget {
  const _RefundSection({required this.trip});

  final Trip trip;

  @override
  State<_RefundSection> createState() => _RefundSectionState();
}

class _RefundSectionState extends State<_RefundSection> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final remaining = RefundRules.remainingAmount(
      widget.trip.fare,
      widget.trip.refunded,
    );
    _amount.text = remaining.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<TripsBloc>();
    final remaining = RefundRules.remainingAmount(
      widget.trip.fare,
      widget.trip.refunded,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          'Refund (${widget.trip.fare.currency})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text('Remaining refundable: ${remaining.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          enabled: !bloc.state.actionBusy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Amount',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reason,
          enabled: !bloc.state.actionBusy,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Reason',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: bloc.state.actionBusy
              ? null
              : () {
                  final parsed = double.tryParse(_amount.text.trim());
                  if (parsed == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount.')),
                    );
                    return;
                  }
                  bloc.add(
                    RefundTripRequested(
                      tripId: widget.trip.id,
                      amount: parsed,
                      reason: _reason.text,
                    ),
                  );
                },
          child: const Text('Issue refund'),
        ),
      ],
    );
  }
}
