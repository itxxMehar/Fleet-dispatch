import '../../domain/entities/enums.dart';

String tripStatusLabel(TripStatus status) {
  return switch (status) {
    TripStatus.requested => 'Requested',
    TripStatus.assigned => 'Assigned',
    TripStatus.inProgress => 'In progress',
    TripStatus.completed => 'Completed',
    TripStatus.cancelled => 'Cancelled',
  };
}

List<({TripStatus status, DateTime at})> tripTimeline(TripTimestamps trip) {
  final events = <({TripStatus status, DateTime at})>[
    (status: TripStatus.requested, at: trip.requestedAt),
  ];
  if (trip.assignedAt != null) {
    events.add((status: TripStatus.assigned, at: trip.assignedAt!));
  }
  if (trip.startedAt != null) {
    events.add((status: TripStatus.inProgress, at: trip.startedAt!));
  }
  if (trip.completedAt != null) {
    events.add((status: TripStatus.completed, at: trip.completedAt!));
  }
  if (trip.cancelledAt != null) {
    events.add((status: TripStatus.cancelled, at: trip.cancelledAt!));
  }
  return events;
}

/// Minimal timestamps needed to build a status timeline without GraphQL extras.
class TripTimestamps {
  const TripTimestamps({
    required this.requestedAt,
    this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final DateTime requestedAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
}
