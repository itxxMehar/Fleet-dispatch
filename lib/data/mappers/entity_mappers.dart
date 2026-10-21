import '../../core/realtime/geo_validation.dart';
import '../../domain/entities/alert.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/driver.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/kpis.dart';
import '../../domain/entities/rider.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/tracked_driver.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/value_objects.dart';
import 'json_readers.dart';

Money mapMoney(Map<String, dynamic> json) {
  return Money(
    amount: readDouble(json['amount']),
    currency: json['currency'] as String,
  );
}

GeoPoint mapGeoPoint(Map<String, dynamic> json) {
  return GeoPoint(lat: readDouble(json['lat']), lng: readDouble(json['lng']));
}

Place mapPlace(Map<String, dynamic> json) {
  final location = json['location'];
  if (location is Map) {
    final point = mapGeoPoint(Map<String, dynamic>.from(location));
    return Place(
      address: json['address'] as String,
      lat: point.lat,
      lng: point.lng,
    );
  }
  return Place(
    address: json['address'] as String,
    lat: readDouble(json['lat']),
    lng: readDouble(json['lng']),
  );
}

Vehicle mapVehicle(Map<String, dynamic> json) {
  return Vehicle(
    make: json['make'] as String,
    model: json['model'] as String,
    plate: json['plate'] as String,
    color: json['color'] as String,
  );
}

City mapCity(Map<String, dynamic> json) {
  final pricing = json['pricing'] is Map
      ? Map<String, dynamic>.from(json['pricing'] as Map)
      : null;
  final center = json['center'] is Map
      ? mapGeoPoint(Map<String, dynamic>.from(json['center'] as Map))
      : const GeoPoint(lat: 0, lng: 0);
  return City(
    id: json['id'] as String,
    name: json['name'] as String,
    countryCode: (json['countryCode'] as String?) ?? '',
    currency: (json['currency'] as String?) ?? '',
    timezone: (json['timezone'] as String?) ?? '',
    center: center,
    baseFare: pricing != null
        ? readDouble(pricing['baseFare'])
        : readDouble(json['baseFare'] ?? 0),
    perKm: pricing != null
        ? readDouble(pricing['perKm'])
        : readDouble(json['perKm'] ?? 0),
    createdAt: readDate(json['createdAt']),
    activeTrips: json['activeTrips'] == null
        ? null
        : readInt(json['activeTrips']),
    availableDrivers: json['availableDrivers'] == null
        ? null
        : readInt(json['availableDrivers']),
  );
}

SessionUser mapSessionUser(Map<String, dynamic> json) {
  return SessionUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: parseAppRole((json['role'] as String?) ?? 'viewer'),
    banned: json['banned'] as bool? ?? false,
    cityId: json['cityId'] as String?,
    banReason: json['banReason'] as String?,
  );
}

Me mapMe(Map<String, dynamic> json) {
  final userJson = Map<String, dynamic>.from(json['user'] as Map);
  final role = parseAppRole(json['role'] as String);
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  return Me(
    user: SessionUser(
      id: userJson['id'] as String,
      name: userJson['name'] as String,
      email: userJson['email'] as String,
      role: role,
      banned: false,
      cityId: city?.id ?? userJson['cityId'] as String?,
    ),
    role: role,
    roleDescription: json['roleDescription'] as String? ?? '',
    city: city,
    permissions: PermissionSet.fromRest(
      Map<String, dynamic>.from(json['permissions'] as Map),
    ),
  );
}

Me mapGraphQlMe(Map<String, dynamic> json) {
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  return Me(
    user: SessionUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: parseAppRole(json['role'] as String),
      banned: false,
      cityId: city?.id,
    ),
    role: parseAppRole(json['role'] as String),
    roleDescription: json['roleDescription'] as String? ?? '',
    city: city,
    permissions: PermissionSet.fromGraphQl(
      json['permissions'] as List? ?? const [],
    ),
  );
}

DriverLocation? mapDriverLocation(Object? json) {
  if (json is! Map) {
    return null;
  }
  final map = Map<String, dynamic>.from(json);
  return DriverLocation(
    lat: readDouble(map['lat']),
    lng: readDouble(map['lng']),
    heading: readDouble(map['heading'] ?? 0),
  );
}

Driver mapDriver(Map<String, dynamic> json) {
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  final locationJson = json['location'];
  DriverLocation? location = mapDriverLocation(locationJson);
  if (json.containsKey('heading') && json['location'] is Map) {
    final point = mapGeoPoint(
      Map<String, dynamic>.from(json['location'] as Map),
    );
    location = DriverLocation(
      lat: point.lat,
      lng: point.lng,
      heading: readDouble(json['heading'] ?? 0),
    );
  }
  Trip? currentTrip;
  if (json['currentTrip'] is Map) {
    currentTrip = mapTrip(
      Map<String, dynamic>.from(json['currentTrip'] as Map),
    );
  }
  return Driver(
    id: json['id'] as String,
    cityId: (json['cityId'] as String?) ?? city?.id ?? '',
    name: json['name'] as String,
    phone: json['phone'] as String,
    status: parseDriverStatus(gqlEnumToSnake(json['status'] as String)),
    rating: readDouble(json['rating'] ?? 0),
    vehicle: json['vehicle'] is Map
        ? mapVehicle(Map<String, dynamic>.from(json['vehicle'] as Map))
        : const Vehicle(make: '', model: '', plate: '', color: ''),
    location: location,
    lastSeenAt: readDate(json['lastSeenAt']),
    createdAt: readRequiredDate(json['createdAt'] ?? json['lastSeenAt']),
    updatedAt: readDate(json['updatedAt']),
    city: city,
    currentTrip: currentTrip,
  );
}

/// Parses one entry from WebSocket `drivers.locations` payload.drivers[].
/// Returns null when coordinates are missing or out of range.
TrackedDriver? mapTrackedDriver(Map<String, dynamic> json) {
  final latRaw = json['lat'];
  final lngRaw = json['lng'];
  if (latRaw is! num || lngRaw is! num) {
    return null;
  }
  if (!isValidCoordinate(latRaw, lngRaw)) {
    return null;
  }
  final statusRaw = json['status'];
  if (statusRaw is! String) {
    return null;
  }
  final id = json['id'];
  final name = json['name'];
  if (id is! String || name is! String) {
    return null;
  }
  return TrackedDriver(
    id: id,
    cityId: (json['cityId'] as String?) ?? '',
    name: name,
    status: parseDriverStatus(gqlEnumToSnake(statusRaw)),
    lat: latRaw.toDouble(),
    lng: lngRaw.toDouble(),
    heading: json['heading'] is num ? (json['heading'] as num).toDouble() : 0,
    lastSeenAt: readDate(json['lastSeenAt']),
  );
}

List<TrackedDriver> mapDriversLocationsPayload(Map<String, dynamic> payload) {
  final drivers = payload['drivers'];
  if (drivers is! List) {
    return const [];
  }
  final out = <TrackedDriver>[];
  for (final item in drivers) {
    if (item is! Map) {
      continue;
    }
    final mapped = mapTrackedDriver(Map<String, dynamic>.from(item));
    if (mapped != null) {
      out.add(mapped);
    }
  }
  return out;
}

Rider mapRider(Map<String, dynamic> json) {
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  return Rider(
    id: json['id'] as String,
    cityId: (json['cityId'] as String?) ?? city?.id ?? '',
    name: json['name'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String?,
    rating: readDouble(json['rating']),
    createdAt: readRequiredDate(json['createdAt']),
    updatedAt: readDate(json['updatedAt']),
    tripCount: json['tripCount'] == null ? null : readInt(json['tripCount']),
  );
}

Trip mapTrip(Map<String, dynamic> json) {
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  final rider = json['rider'] is Map
      ? mapRider(Map<String, dynamic>.from(json['rider'] as Map))
      : null;
  final driver = json['driver'] is Map
      ? mapDriver(Map<String, dynamic>.from(json['driver'] as Map))
      : null;
  return Trip(
    id: json['id'] as String,
    cityId: (json['cityId'] as String?) ?? city?.id ?? '',
    riderId: (json['riderId'] as String?) ?? rider?.id ?? '',
    driverId: json['driverId'] as String? ?? driver?.id,
    status: parseTripStatus(gqlEnumToSnake(json['status'] as String)),
    pickup: mapPlace(Map<String, dynamic>.from(json['pickup'] as Map)),
    dropoff: mapPlace(Map<String, dynamic>.from(json['dropoff'] as Map)),
    distanceKm: readDouble(json['distanceKm']),
    fare: mapMoney(Map<String, dynamic>.from(json['fare'] as Map)),
    refunded: mapMoney(Map<String, dynamic>.from(json['refunded'] as Map)),
    refundReason: json['refundReason'] as String?,
    cancelReason: json['cancelReason'] as String?,
    cancelledBy: json['cancelledBy'] as String?,
    requestedAt: readRequiredDate(json['requestedAt']),
    assignedAt: readDate(json['assignedAt']),
    startedAt: readDate(json['startedAt']),
    completedAt: readDate(json['completedAt']),
    cancelledAt: readDate(json['cancelledAt']),
    updatedAt: readDate(json['updatedAt']),
    city: city,
    rider: rider,
    driver: driver,
  );
}

OpsAlert mapAlert(Map<String, dynamic> json) {
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  final trip = json['trip'] is Map ? json['trip'] as Map : null;
  final driver = json['driver'] is Map ? json['driver'] as Map : null;
  return OpsAlert(
    id: json['id'] as String,
    cityId: (json['cityId'] as String?) ?? city?.id ?? '',
    cityName: city?.name,
    type: parseAlertType(gqlEnumToSnake(json['type'] as String)),
    severity: parseAlertSeverity(gqlEnumToSnake(json['severity'] as String)),
    message: json['message'] as String,
    tripId: json['tripId'] as String? ?? trip?['id'] as String?,
    driverId: json['driverId'] as String? ?? driver?['id'] as String?,
    createdAt: readRequiredDate(json['createdAt']),
    acknowledgedAt: readDate(json['acknowledgedAt']),
    acknowledgedBy: json['acknowledgedBy'] as String?,
  );
}

DriverMessage mapDriverMessage(Map<String, dynamic> json) {
  return DriverMessage(
    id: json['id'] as String,
    driverId: json['driverId'] as String,
    cityId: json['cityId'] as String,
    direction: parseMessageDirection(json['direction'] as String),
    body: json['body'] as String,
    sentBy: json['sentBy'] as String?,
    createdAt: readRequiredDate(json['createdAt']),
  );
}

PageResult<T> mapPage<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) mapItem,
) {
  final data = (json['data'] as List)
      .map((e) => mapItem(Map<String, dynamic>.from(e as Map)))
      .toList();
  return PageResult(
    data: data,
    page: readInt(json['page']),
    pageSize: readInt(json['pageSize']),
    total: readInt(json['total']),
    totalPages: readInt(json['totalPages']),
  );
}

CursorPage<T> mapConnection<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) mapItem,
) {
  final pageInfo = Map<String, dynamic>.from(json['pageInfo'] as Map);
  final nodes = (json['nodes'] as List)
      .map((e) => mapItem(Map<String, dynamic>.from(e as Map)))
      .toList();
  return CursorPage(
    nodes: nodes,
    hasNextPage: pageInfo['hasNextPage'] as bool,
    totalCount: readInt(json['totalCount']),
    endCursor: pageInfo['endCursor'] as String?,
  );
}

Kpis mapKpis(Map<String, dynamic> json) {
  final city = json['city'] is Map
      ? mapCity(Map<String, dynamic>.from(json['city'] as Map))
      : null;
  final trips = Map<String, dynamic>.from(json['trips'] as Map);
  final drivers = Map<String, dynamic>.from(json['drivers'] as Map);
  List<Money> moneyList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((e) => mapMoney(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  return Kpis(
    range: parseKpiRange(gqlEnumToSnake(json['range'] as String)),
    cityId: json['cityId'] as String? ?? city?.id,
    generatedAt: readRequiredDate(json['generatedAt']),
    trips: TripCounts(
      requested: readInt(trips['requested'] ?? 0),
      assigned: readInt(trips['assigned'] ?? 0),
      inProgress: readInt(trips['inProgress'] ?? trips['in_progress'] ?? 0),
      completed: readInt(trips['completed']),
      cancelled: readInt(trips['cancelled']),
      active: readInt(trips['active']),
      cancellationRate: readDouble(trips['cancellationRate'] ?? 0),
    ),
    revenue: moneyList(json['revenue']),
    averageFare: moneyList(json['averageFare']),
    refunds: moneyList(json['refunds']),
    drivers: DriverCounts(
      available: readInt(drivers['available']),
      onTrip: readInt(drivers['onTrip'] ?? drivers['on_trip'] ?? 0),
      offline: readInt(drivers['offline']),
      total: readInt(drivers['total'] ?? 0),
    ),
    openAlerts: readInt(json['openAlerts']),
    series: (json['series'] is List)
        ? (json['series'] as List).map((e) {
            final row = Map<String, dynamic>.from(e as Map);
            return SeriesPoint(
              bucket: readRequiredDate(row['bucket']),
              total: readInt(row['total']),
              completed: readInt(row['completed']),
              cancelled: readInt(row['cancelled']),
            );
          }).toList()
        : const [],
  );
}

AdminUser mapAdminUser(Map<String, dynamic> json) {
  return AdminUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    cityId: json['cityId'] as String?,
    banned: json['banned'] as bool,
    banReason: json['banReason'] as String?,
    createdAt: readRequiredDate(json['createdAt']),
  );
}
