/// Returns true when [lat]/[lng] are finite and within WGS-84 bounds.
bool isValidCoordinate(num? lat, num? lng) {
  if (lat == null || lng == null) {
    return false;
  }
  final la = lat.toDouble();
  final ln = lng.toDouble();
  if (la.isNaN || ln.isNaN || la.isInfinite || ln.isInfinite) {
    return false;
  }
  return la >= -90 && la <= 90 && ln >= -180 && ln <= 180;
}
