// const meQuery = r'''
// query Me {
//   me {
//     id
//     name
//     email
//     role
//     roleDescription
//     city { id name countryCode currency timezone center { lat lng } baseFare perKm }
//     permissions { resource actions }
//   }
// }
// ''';

const kpisQuery = r'''
query Kpis($cityId: ID, $range: KpiRange) {
  kpis(cityId: $cityId, range: $range) {
    range
    generatedAt
    city { id name countryCode currency timezone center { lat lng } baseFare perKm }
    trips { requested assigned inProgress completed cancelled active cancellationRate }
    revenue { amount currency }
    averageFare { amount currency }
    refunds { amount currency }
    drivers { available onTrip offline total }
    openAlerts
    series { bucket total completed cancelled }
  }
}
''';

const tripsQuery = r'''
query Trips($filter: TripFilter, $first: Int, $after: String) {
  trips(filter: $filter, first: $first, after: $after) {
    totalCount
    pageInfo { endCursor hasNextPage }
    nodes {
      id
      status
      distanceKm
      requestedAt
      assignedAt
      startedAt
      completedAt
      cancelledAt
      refundReason
      cancelReason
      cancelledBy
      fare { amount currency }
      refunded { amount currency }
      pickup { address location { lat lng } }
      dropoff { address location { lat lng } }
      city { id name countryCode currency timezone center { lat lng } baseFare perKm }
      rider { id name phone email rating createdAt city { id name countryCode currency timezone center { lat lng } baseFare perKm } }
      driver { id name phone status rating lastSeenAt createdAt vehicle { make model plate color } location { lat lng } heading city { id name countryCode currency timezone center { lat lng } baseFare perKm } }
    }
  }
}
''';

const tripQuery = r'''
query Trip($id: ID!) {
  trip(id: $id) {
    id
    status
    distanceKm
    requestedAt
    assignedAt
    startedAt
    completedAt
    cancelledAt
    refundReason
    cancelReason
    cancelledBy
    fare { amount currency }
    refunded { amount currency }
    pickup { address location { lat lng } }
    dropoff { address location { lat lng } }
    city { id name countryCode currency timezone center { lat lng } baseFare perKm }
    rider { id name phone email rating createdAt city { id name countryCode currency timezone center { lat lng } baseFare perKm } }
    driver { id name phone status rating lastSeenAt createdAt vehicle { make model plate color } location { lat lng } heading city { id name countryCode currency timezone center { lat lng } baseFare perKm } }
  }
}
''';

const driversQuery = r'''
query Drivers($filter: DriverFilter, $first: Int, $after: String) {
  drivers(filter: $filter, first: $first, after: $after) {
    totalCount
    pageInfo { endCursor hasNextPage }
    nodes {
      id
      name
      phone
      status
      rating
      heading
      lastSeenAt
      createdAt
      vehicle { make model plate color }
      location { lat lng }
      city { id name countryCode currency timezone center { lat lng } baseFare perKm }
    }
  }
}
''';

const driverQuery = r'''
query Driver($id: ID!) {
  driver(id: $id) {
    id
    name
    phone
    status
    rating
    heading
    lastSeenAt
    createdAt
    vehicle { make model plate color }
    location { lat lng }
    city { id name countryCode currency timezone center { lat lng } baseFare perKm }
    currentTrip {
      id
      status
      distanceKm
      requestedAt
      fare { amount currency }
      refunded { amount currency }
      pickup { address location { lat lng } }
      dropoff { address location { lat lng } }
      rider { id name phone email rating createdAt }
    }
  }
}
''';

const alertsQuery = r'''
query Alerts($filter: AlertFilter, $first: Int, $after: String) {
  alerts(filter: $filter, first: $first, after: $after) {
    totalCount
    pageInfo { endCursor hasNextPage }
    nodes {
      id
      type
      severity
      message
      createdAt
      acknowledgedAt
      acknowledgedBy
      city { id name countryCode currency timezone center { lat lng } baseFare perKm }
      trip { id }
      driver { id }
    }
  }
}
''';
