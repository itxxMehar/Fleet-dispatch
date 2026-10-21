import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/di/injection.dart';
import '../../core/realtime/drivers_locations_client.dart';
import '../../domain/entities/driver.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/tracked_driver.dart';
import '../../domain/usecases/get_driver.dart';
import '../shell/access_denied_page.dart';
import 'map_bloc.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapBloc(
        locationsClient: sl<DriversLocationsClient>(),
        getDriver: sl<GetDriver>(),
        me: me,
      )..add(const MapStarted()),
      child: _MapView(me: me),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        if (state.status == MapStatus.forbidden) {
          return const AccessDeniedPage(requiredPermission: 'driver:track');
        }

        final center = me.city?.center;
        final initial = LatLng(center?.lat ?? 25.2854, center?.lng ?? 51.5310);

        return Column(
          children: [
            _MapToolbar(state: state),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: initial,
                      initialZoom: 12,
                      onTap: (tapPosition, point) => context
                          .read<MapBloc>()
                          .add(const DriverSelected(null)),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'badrgotest',
                      ),
                      MarkerLayer(
                        markers: [
                          for (final driver in state.drivers)
                            Marker(
                              point: LatLng(driver.lat, driver.lng),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => context.read<MapBloc>().add(
                                  DriverSelected(driver.id),
                                ),
                                child: _DriverMarker(
                                  driver: driver,
                                  selected: driver.id == state.selectedId,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (state.status == MapStatus.connecting ||
                      state.status == MapStatus.reconnecting)
                    const Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _StatusBanner(
                        icon: Icons.sync,
                        label: 'Reconnecting to live driver locations…',
                      ),
                    ),
                  if (state.status == MapStatus.error && state.error != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _StatusBanner(
                        icon: Icons.error_outline,
                        label: state.error!,
                        tone: _BannerTone.error,
                      ),
                    ),
                  if (state.status == MapStatus.empty)
                    const Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _StatusBanner(
                        icon: Icons.location_off_outlined,
                        label:
                            'No active drivers with valid locations right now.',
                      ),
                    ),
                  if (state.selected != null)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      width: 320,
                      child: _DriverDetailCard(
                        tracked: state.selected!,
                        detail: state.selectedDetail,
                        canRead: context.read<MapBloc>().canReadDriver,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapToolbar extends StatelessWidget {
  const _MapToolbar({required this.state});

  final MapState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = state.status == MapStatus.live;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Live map',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: live
                    ? const Color(0xFFE7F6EE)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                live ? '${state.drivers.length} drivers' : state.status.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: live ? const Color(0xFF0B6B3A) : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker({required this.driver, required this.selected});

  final TrackedDriver driver;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = switch (driver.status) {
      DriverStatus.available => const Color(0xFF1B8F4A),
      DriverStatus.onTrip => const Color(0xFF0E6B7A),
      DriverStatus.offline => const Color(0xFF6B7280),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : color.withValues(alpha: 0.2),
          width: selected ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.navigation, color: Colors.white, size: 18),
    );
  }
}

enum _BannerTone { info, error }

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.label,
    this.tone = _BannerTone.info,
  });

  final IconData icon;
  final String label;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final error = tone == _BannerTone.error;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      color: error ? const Color(0xFFFDECEC) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: error ? const Color(0xFFB42318) : null),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _DriverDetailCard extends StatelessWidget {
  const _DriverDetailCard({
    required this.tracked,
    required this.detail,
    required this.canRead,
  });

  final TrackedDriver tracked;
  final Driver? detail;
  final bool canRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driver = detail;
    final trip = driver?.currentTrip;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tracked.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () =>
                      context.read<MapBloc>().add(const DriverSelected(null)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('Status: ${_statusLabel(tracked.status)}'),
            Text(
              'Location: ${tracked.lat.toStringAsFixed(5)}, '
              '${tracked.lng.toStringAsFixed(5)}',
            ),
            if (driver != null) ...[
              const SizedBox(height: 8),
              Text('Phone: ${driver.phone}'),
              Text('Rating: ${driver.rating.toStringAsFixed(1)}'),
              Text(
                'Vehicle: ${driver.vehicle.make} ${driver.vehicle.model} '
                '(${driver.vehicle.plate})',
              ),
              if (trip != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Current trip',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(trip.id),
                Text('Pickup: ${trip.pickup.address}'),
                Text('Drop-off: ${trip.dropoff.address}'),
                if (trip.rider != null) Text('Rider: ${trip.rider!.name}'),
              ] else if (tracked.status == DriverStatus.onTrip)
                const Text('Current trip: unavailable from API.'),
            ] else if (canRead)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Driver details require driver:read.'),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DriverStatus status) {
    return switch (status) {
      DriverStatus.available => 'Available',
      DriverStatus.onTrip => 'On trip',
      DriverStatus.offline => 'Offline',
    };
  }
}
