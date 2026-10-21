import 'package:equatable/equatable.dart';

/// One Server-Sent Event from `GET /api/events`.
class SseEvent extends Equatable {
  const SseEvent({required this.event, required this.data, this.id});

  final String? id;
  final String event;
  final String data;

  @override
  List<Object?> get props => [id, event, data];
}
