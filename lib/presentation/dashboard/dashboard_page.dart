import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/realtime/ops_events_client.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/kpis.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/value_objects.dart';
import '../../domain/usecases/get_kpis.dart';
import '../connectivity/connectivity_bloc.dart';
import '../shell/access_denied_page.dart';
import 'dashboard_bloc.dart';
import 'trips_series_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardBloc(
        getKpis: sl<GetKpis>(),
        eventsClient: sl<OpsEventsClient>(),
        me: me,
        connectivity: sl.isRegistered<ConnectivityBloc>()
            ? sl<ConnectivityBloc>()
            : null,
      )..add(const DashboardStarted()),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.forbidden) {
          return const AccessDeniedPage(requiredPermission: 'kpi:read');
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (state.live)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _LiveBadge(),
                      ),
                    SegmentedButton<KpiRange>(
                      segments: const [
                        ButtonSegment(
                          value: KpiRange.last24h,
                          label: Text('Last 24h'),
                        ),
                        ButtonSegment(
                          value: KpiRange.last7d,
                          label: Text('Last 7d'),
                        ),
                      ],
                      selected: {state.range},
                      onSelectionChanged:
                          state.status == DashboardStatus.loading
                          ? null
                          : (values) {
                              context.read<DashboardBloc>().add(
                                KpiRangeChanged(values.first),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (state.status == DashboardStatus.loading &&
                    state.kpis == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.status == DashboardStatus.error &&
                    state.kpis == null)
                  _ErrorPanel(
                    message: state.error ?? 'Failed to load KPIs.',
                    onRetry: () => context.read<DashboardBloc>().add(
                      const LoadKpisRequested(),
                    ),
                  )
                else if (state.kpis != null) ...[
                  _KpiGrid(kpis: state.kpis!),
                  const SizedBox(height: 20),
                  TripsSeriesChart(
                    series: state.kpis!.series,
                    rangeLabel: state.range == KpiRange.last24h
                        ? 'Last 24 hours'
                        : 'Last 7 days',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF0F7B4A)),
          SizedBox(width: 6),
          Text(
            'Live',
            style: TextStyle(
              color: Color(0xFF0F7B4A),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final Kpis kpis;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _KpiCard(label: 'Active trips', value: '${kpis.trips.active}'),
      _KpiCard(label: 'Completed', value: '${kpis.trips.completed}'),
      _KpiCard(
        label: 'Cancellation rate',
        value: '${(kpis.trips.cancellationRate * 100).toStringAsFixed(1)}%',
      ),
      _KpiCard(label: 'Available drivers', value: '${kpis.drivers.available}'),
      _KpiCard(label: 'Drivers on trip', value: '${kpis.drivers.onTrip}'),
      _KpiCard(label: 'Open alerts', value: '${kpis.openAlerts}'),
      ...kpis.revenue.map(
        (money) => _KpiCard(
          label: 'Revenue (${money.currency})',
          value: _money(money),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 4
            : width >= 600
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: cards,
        );
      },
    );
  }

  String _money(Money money) =>
      '${money.currency} ${money.amount.toStringAsFixed(2)}';
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2C0)),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
