import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'api.dart';

Json? coordinatesOf(Json record) {
  for (final source in [
    record,
    object(record['location_point']),
    object(record['location']),
    object(record['location_data']),
    object(object(record['location'])['location_point']),
    object(object(record['location_data'])['location_point']),
    object(record['extras']),
  ]) {
    final lat = num.tryParse(string(source['latitude'] ?? source['lat']));
    final lng = num.tryParse(
      string(source['longitude'] ?? source['lng'] ?? source['lon']),
    );
    if (lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180) {
      return {'latitude': lat.toDouble(), 'longitude': lng.toDouble()};
    }
    final point = source['coordinates'];
    if (point is List &&
        point.length >= 2 &&
        point[0] is num &&
        point[1] is num) {
      final x = point[0] as num, y = point[1] as num;
      if (x.isFinite && y.isFinite && y.abs() <= 90 && x.abs() <= 180) {
        return {'latitude': y.toDouble(), 'longitude': x.toDouble()};
      }
    }
  }
  return null;
}

const defaultDiscoveryCoordinates = <String, dynamic>{
  'latitude': 41.0082,
  'longitude': 28.9784,
};
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException('Location services are disabled');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw ApiException('Location permission is required');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
}

Json nearbyPerson(Json raw, Json origin) {
  final point = coordinatesOf(raw);
  String distance = string(
    raw['distance'] ?? raw['distance_km'] ?? raw['distanceKm'],
  );
  if (point != null &&
      origin['latitude'] is num &&
      origin['longitude'] is num) {
    const radians = math.pi / 180;
    final lat = (origin['latitude'] as num).toDouble();
    final lng = (origin['longitude'] as num).toDouble();
    final nextLat = (point['latitude'] as num).toDouble();
    final nextLng = (point['longitude'] as num).toDouble();
    final a =
        math.pow(math.sin((nextLat - lat) * radians / 2), 2) +
        math.cos(lat * radians) *
            math.cos(nextLat * radians) *
            math.pow(math.sin((nextLng - lng) * radians / 2), 2);
    final km =
        6371 *
        2 *
        math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt((1 - a).clamp(0, 1)));
    distance = km.toStringAsFixed(km < 10 ? 1 : 0);
  }
  final birth = DateTime.tryParse(string(raw['date_of_birth']));
  int? age;
  if (birth != null) {
    final now = DateTime.now();
    age =
        now.year -
        birth.year -
        ((now.month < birth.month ||
                now.month == birth.month && now.day < birth.day)
            ? 1
            : 0);
  }
  return {
    ...raw,
    'age': ?age,
    'distance': distance.replaceAll(RegExp(r'\s*km$'), ''),
    'online': raw['online'] == true || raw['is_online'] == true,
  };
}

/// helpers/chatLocation.ts: location-only messages still need nonempty content.
String locationMapUrl(Json location) {
  final point = coordinatesOf(location);
  if (point == null) throw ApiException('Invalid location');
  String rounded(num value) {
    final n = double.parse(value.toStringAsFixed(6));
    return n == n.roundToDouble() ? n.toInt().toString() : '$n';
  }

  return 'https://maps.google.com/?q=${rounded(point['latitude'])},${rounded(point['longitude'])}';
}

String locationMessageText(String text, Json? location) {
  final point = coordinatesOf(location ?? {}), uri = Uri.tryParse(text.trim());
  if (point == null ||
      uri == null ||
      ![
        'maps.google.com',
        'maps.apple.com',
        'www.google.com',
        'google.com',
      ].contains(uri.host)) {
    return text;
  }
  final parts = (uri.queryParameters['q'] ?? uri.queryParameters['ll'] ?? '')
      .split(',');
  if (parts.length != 2) return text;
  final lat = double.tryParse(parts[0]), lng = double.tryParse(parts[1]);
  return lat != null &&
          lng != null &&
          (lat - point['latitude']).abs() < .000001 &&
          (lng - point['longitude']).abs() < .000001
      ? ''
      : text;
}
