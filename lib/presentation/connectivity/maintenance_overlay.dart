import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_bloc.dart';

/// Full-screen maintenance / unreachable overlay. Session stays authenticated.
class MaintenanceOverlay extends StatelessWidget {
  const MaintenanceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      buildWhen: (p, c) => p.health != c.health || p.polling != c.polling,
      builder: (context, state) {
        if (!state.showMaintenance && !state.showUnreachable) {
          return const SizedBox.shrink();
        }
        final health = state.health;
        final maintenance = health.isMaintenance;
        return Positioned.fill(
          child: Material(
            color: const Color(0xF20B1F2A),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          maintenance
                              ? Icons.construction_outlined
                              : Icons.wifi_off_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          maintenance
                              ? 'Service under maintenance'
                              : 'Connection problem',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          health.message ??
                              (maintenance
                                  ? 'The operations API is temporarily unavailable.'
                                  : 'Unable to reach the health endpoint.'),
                          textAlign: TextAlign.center,
                        ),
                        if (health.reason != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Reason: ${health.reason}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (health.since != null) ...[
                          const SizedBox(height: 8),
                          _ElapsedSince(since: health.since!),
                        ],
                        if (health.retryAfterSeconds != null) ...[
                          const SizedBox(height: 8),
                          Text('Suggested retry: ${health.retryAfterSeconds}s'),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: state.polling
                              ? null
                              : () => context.read<ConnectivityBloc>().add(
                                  const HealthCheckRequested(),
                                ),
                          child: state.polling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Check again'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your session is still signed in.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RealtimeReconnectingBanner extends StatelessWidget {
  const RealtimeReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      buildWhen: (p, c) =>
          p.showRealtimeReconnecting != c.showRealtimeReconnecting,
      builder: (context, state) {
        if (!state.showRealtimeReconnecting) {
          return const SizedBox.shrink();
        }
        return Material(
          color: const Color(0xFFFFF4E5),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Realtime connection interrupted — reconnecting…',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ElapsedSince extends StatelessWidget {
  const _ElapsedSince({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now().toUtc(),
      ),
      initialData: DateTime.now().toUtc(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now().toUtc();
        final elapsed = now.difference(since.toUtc());
        final label = elapsed.inHours > 0
            ? '${elapsed.inHours}h ${elapsed.inMinutes.remainder(60)}m'
            : elapsed.inMinutes > 0
            ? '${elapsed.inMinutes}m ${elapsed.inSeconds.remainder(60)}s'
            : '${elapsed.inSeconds}s';
        return Text('Ongoing for $label');
      },
    );
  }
}
