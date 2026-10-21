import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/realtime/ops_events_client.dart';
import '../../domain/entities/alert.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session.dart';
import '../../domain/usecases/alert_actions.dart';
import '../connectivity/connectivity_bloc.dart';
import '../shell/access_denied_page.dart';
import 'alerts_bloc.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AlertsBloc(
        listAlerts: sl<ListAlerts>(),
        acknowledgeAlert: sl<AcknowledgeAlert>(),
        eventsClient: sl<OpsEventsClient>(),
        me: me,
        connectivity: sl.isRegistered<ConnectivityBloc>()
            ? sl<ConnectivityBloc>()
            : null,
      )..add(const AlertsStarted()),
      child: const _AlertsView(),
    );
  }
}

class _AlertsView extends StatelessWidget {
  const _AlertsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AlertsBloc, AlertsState>(
      listenWhen: (p, c) =>
          p.actionError != c.actionError && c.actionError != null,
      listener: (context, state) {
        final message = state.actionError;
        if (message == null) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        if (state.status == AlertsStatus.forbidden) {
          return const AccessDeniedPage(requiredPermission: 'alert:read');
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Alerts',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (state.live)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          'Live',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: const Color(0xFF0B6B3A),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: state.status == AlertsStatus.loading
                          ? null
                          : () => context.read<AlertsBloc>().add(
                              const LoadAlertsRequested(),
                            ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.totalCount} total · critical SOS alerts are highlighted',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.status == AlertsStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.status == AlertsStatus.error)
                  _ErrorPane(
                    message: state.error ?? 'Failed to load alerts.',
                    onRetry: () => context.read<AlertsBloc>().add(
                      const LoadAlertsRequested(),
                    ),
                  )
                else if (state.alerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('No alerts in scope.')),
                  )
                else
                  for (final alert in state.alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AlertTile(
                        alert: alert,
                        canAcknowledge: context
                            .read<AlertsBloc>()
                            .canAcknowledge,
                        busy: state.acknowledgingId == alert.id,
                        onAcknowledge: () => context.read<AlertsBloc>().add(
                          AcknowledgeAlertRequested(alert.id),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.canAcknowledge,
    required this.busy,
    required this.onAcknowledge,
  });

  final OpsAlert alert;
  final bool canAcknowledge;
  final bool busy;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sos =
        alert.type == AlertType.sos || alert.severity == AlertSeverity.critical;
    final border = sos ? const Color(0xFFB42318) : const Color(0xFFD0D5DD);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sos ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: sos ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (sos)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB42318),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _typeLabel(alert.type),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _severityLabel(alert.severity),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.message),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(_formatTime(alert.createdAt)),
                Text(alert.cityName ?? alert.cityId),
                if (alert.tripId != null) Text('Trip ${alert.tripId}'),
                if (alert.driverId != null) Text('Driver ${alert.driverId}'),
                Text(alert.isOpen ? 'Open' : 'Acknowledged'),
              ],
            ),
            if (alert.isOpen && canAcknowledge) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: busy ? null : onAcknowledge,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Acknowledge'),
                ),
              ),
            ] else if (!alert.isOpen && alert.acknowledgedBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Acknowledged by ${alert.acknowledgedBy}'
                  '${alert.acknowledgedAt != null ? ' · ${_formatTime(alert.acknowledgedAt!)}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(AlertType type) {
    return switch (type) {
      AlertType.sos => 'SOS',
      AlertType.highDemand => 'High demand',
      AlertType.noDriverAvailable => 'No driver available',
      AlertType.refundIssued => 'Refund issued',
    };
  }

  String _severityLabel(AlertSeverity severity) {
    return switch (severity) {
      AlertSeverity.critical => 'Critical',
      AlertSeverity.warning => 'Warning',
      AlertSeverity.info => 'Info',
    };
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
