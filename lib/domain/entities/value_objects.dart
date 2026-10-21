import 'package:equatable/equatable.dart';

class Money extends Equatable {
  const Money({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  List<Object?> get props => [amount, currency];
}

class GeoPoint extends Equatable {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}

class Place extends Equatable {
  const Place({required this.address, required this.lat, required this.lng});

  final String address;
  final double lat;
  final double lng;

  GeoPoint get location => GeoPoint(lat: lat, lng: lng);

  @override
  List<Object?> get props => [address, lat, lng];
}

class Vehicle extends Equatable {
  const Vehicle({
    required this.make,
    required this.model,
    required this.plate,
    required this.color,
  });

  final String make;
  final String model;
  final String plate;
  final String color;

  @override
  List<Object?> get props => [make, model, plate, color];
}

class PageResult<T> extends Equatable {
  const PageResult({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<T> data;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  @override
  List<Object?> get props => [data, page, pageSize, total, totalPages];
}

class CursorPage<T> extends Equatable {
  const CursorPage({
    required this.nodes,
    required this.hasNextPage,
    required this.totalCount,
    this.endCursor,
  });

  final List<T> nodes;
  final bool hasNextPage;
  final int totalCount;
  final String? endCursor;

  @override
  List<Object?> get props => [nodes, hasNextPage, totalCount, endCursor];
}

class PermissionSet {
  const PermissionSet(this._actionsByResource);

  final Map<String, List<String>> _actionsByResource;

  Map<String, List<String>> get asMap => {
    for (final entry in _actionsByResource.entries)
      entry.key: List<String>.from(entry.value),
  };

  bool can(String resource, String action) {
    final actions = _actionsByResource[resource];
    return actions != null && actions.contains(action);
  }

  factory PermissionSet.fromRest(Map<String, dynamic> json) {
    return PermissionSet({
      for (final entry in json.entries)
        entry.key: (entry.value as List).map((e) => e.toString()).toList(),
    });
  }

  factory PermissionSet.fromGraphQl(List<dynamic> items) {
    final map = <String, List<String>>{};
    for (final item in items) {
      final row = Map<String, dynamic>.from(item as Map);
      map[row['resource'] as String] = (row['actions'] as List)
          .map((e) => e.toString())
          .toList();
    }
    return PermissionSet(map);
  }
}
