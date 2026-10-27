import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'api.dart';
import 'geo.dart';

class PlacePage {
  final List<Json> places;
  final String? next;
  const PlacePage(this.places, [this.next]);
}

/// Original NativeLocationPicker providers, without account authorization headers.
class PlaceSearch {
  final Dio client;
  final String googleKey;
  PlaceSearch({
    Dio? client,
    this.googleKey = const String.fromEnvironment('GOOGLE_PLACES_KEY'),
  }) : client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 15),
               headers: const {'User-Agent': userAgent},
             ),
           );

  /// Photon (komoot) answers 403 to Dart's default `Dart/x.y (dart:io)`
  /// agent; React Native's fetch sent the app's CFNetwork agent instead.
  static const userAgent = 'Coolvibes/1.0 (+https://coolvibes.lgbt)';
  static double deltaForBounds(double longitude, double latitude) =>
      (math.max(longitude.abs(), latitude.abs()) * 1.15).clamp(.02, 60);
  static double zoomForDelta(double delta) =>
      (math.log(360 / delta) / math.ln2).clamp(2, 20);
  Future<PlacePage> fetch({
    required double latitude,
    required double longitude,
    String query = '',
    String language = 'en',
    String? page,
    CancelToken? cancelToken,
  }) async {
    if (googleKey.isEmpty) {
      final response = await client.get<dynamic>(
        'https://photon.komoot.io/${query.trim().isEmpty ? 'reverse' : 'api/'}',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'limit': 25,
          'lang': ['de', 'fr', 'en'].contains(language) ? language : 'en',
          if (query.trim().isEmpty)
            'radius': 2
          else ...{
            'q': query.trim(),
            'location_bias_scale': .2,
          },
        },
        cancelToken: cancelToken,
      );
      final rows = object(response.data)['features'] as List? ?? [];
      final nearby = query.trim().isEmpty;
      final seen = <String>{};
      final places = [
        for (var i = 0; i < rows.length; i++)
          if (!nearby || isVenue(object(object(rows[i])['properties'])))
            ?photonPlace(object(rows[i]), i),
      ].where((p) => seen.add('${p['name']}|${p['address']}')).toList();
      // Telegram's nearby venues are ordered by distance from the pin.
      if (nearby) {
        places.sort(
          (a, b) => distance(
            a,
            latitude,
            longitude,
          ).compareTo(distance(b, latitude, longitude)),
        );
      }
      return PlacePage(places);
    }
    if (page != null) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    final response = await client.get<dynamic>(
      'https://maps.googleapis.com/maps/api/place/${query.trim().isEmpty ? 'nearbysearch' : 'textsearch'}/json',
      queryParameters: {
        'key': googleKey,
        'location': '$latitude,$longitude',
        'radius': query.trim().isEmpty ? 2000 : 200000,
        if (query.trim().isEmpty)
          'type': 'point_of_interest'
        else
          'query': query.trim(),
        'pagetoken': ?page,
      },
      cancelToken: cancelToken,
    );
    final data = object(response.data);
    if (!['OK', 'ZERO_RESULTS'].contains(data['status'])) {
      throw ApiException('Places could not be loaded');
    }
    return PlacePage([
      for (final value in data['results'] as List? ?? [])
        ?googlePlace(object(value)),
    ], data['next_page_token'] as String?);
  }

  /// Reverse results include roads, tram lines, stops and districts; the
  /// nearby list holds venues only (Telegram's Foursquare venue search).
  static bool isVenue(Json p) =>
      const {
        'amenity',
        'shop',
        'tourism',
        'leisure',
        'historic',
        'office',
        'craft',
        'healthcare',
        'club',
        'sport',
        'building',
      }.contains(p['osm_key']) &&
      !const {
        'yes',
        'house',
        'residential',
        'apartments',
      }.contains(p['osm_value']) &&
      string(p['name']).isNotEmpty;

  static double distance(Json place, double latitude, double longitude) {
    final dLat = (place['latitude'] as num) - latitude;
    final dLng =
        ((place['longitude'] as num) - longitude) *
        math.cos(latitude * math.pi / 180);
    return dLat * dLat + dLng * dLng;
  }

  /// Foursquare-style category (VenueIconResources `venueColors` keys).
  static String venueType(String key, String value) {
    const food = {
      'restaurant',
      'cafe',
      'fast_food',
      'food_court',
      'ice_cream',
      'bakery',
      'confectionery',
      'pastry',
      'deli',
      'coffee',
      'tea',
    };
    const nightlife = {
      'bar',
      'pub',
      'nightclub',
      'biergarten',
      'hookah_lounge',
    };
    const medical = {
      'pharmacy',
      'hospital',
      'clinic',
      'doctors',
      'dentist',
      'chemist',
      'veterinary',
    };
    const education = {
      'school',
      'university',
      'college',
      'kindergarten',
      'library',
      'dancing_school',
      'language_school',
      'music_school',
      'driving_school',
    };
    const arts = {
      'arts_centre',
      'theatre',
      'cinema',
      'museum',
      'gallery',
      'casino',
      'attraction',
      'artwork',
      'zoo',
      'theme_park',
    };
    const travel = {
      'bus_station',
      'ferry_terminal',
      'fuel',
      'car_rental',
      'parking',
      'taxi',
      'information',
      'viewpoint',
    };
    if (food.contains(value)) return 'food';
    if (nightlife.contains(value)) return 'nightlife';
    if (value == 'hotel' || value == 'motel' || value == 'guest_house') {
      return 'travel/hotel';
    }
    if (value == 'hostel') return 'travel/hostel';
    if (medical.contains(value) || key == 'healthcare') {
      return 'building/medical';
    }
    if (value == 'fitness_centre' || value == 'sports_centre') {
      return 'building/gym';
    }
    if (education.contains(value)) return 'education';
    if (arts.contains(value) || key == 'historic') return 'arts_entertainment';
    if (key == 'leisure' || value == 'park') return 'parks_outdoors';
    if (key == 'shop') return 'shops';
    if (travel.contains(value) || key == 'tourism') return 'travel';
    if (key == 'office' || key == 'craft') return 'work';
    return 'building';
  }

  static Json? photonPlace(Json feature, int index) {
    final p = object(feature['properties']),
        geometry = object(feature['geometry']);
    final point = coordinatesOf(geometry);
    final name = string(p['name'] ?? p['street'] ?? p['city'] ?? p['country']);
    if (point == null || name.isEmpty) return null;
    final extent = p['extent'];
    return {
      'id': '${p['osm_type'] ?? ''}${p['osm_id'] ?? index}',
      'name': name,
      ...point,
      'address': [
        p['street'],
        p['city'],
        p['state'],
        p['country'],
      ].where((v) => string(v).isNotEmpty && v != name).toSet().join(', '),
      'delta': extent is List && extent.length == 4
          ? deltaForBounds(
              (extent[2] as num).toDouble() - (extent[0] as num).toDouble(),
              (extent[1] as num).toDouble() - (extent[3] as num).toDouble(),
            )
          : .02,
      'kind': p['type'] == 'country'
          ? 'country'
          : [
              'state',
              'county',
              'city',
              'district',
              'locality',
            ].contains(p['type'])
          ? 'region'
          : 'place',
      'venue': venueType(string(p['osm_key']), string(p['osm_value'])),
    };
  }

  static Json? googlePlace(Json item) {
    final geometry = object(item['geometry']),
        point = coordinatesOf(object(object(item['geometry'])['location']));
    if (point == null || string(item['name']).isEmpty) return null;
    final viewport = object(geometry['viewport']),
        ne = coordinatesOf(object(viewport['northeast'])),
        sw = coordinatesOf(object(viewport['southwest']));
    final types = item['types'] as List? ?? [];
    return {
      'id': item['place_id'],
      'name': item['name'],
      'address': item['vicinity'] ?? item['formatted_address'] ?? '',
      ...point,
      'delta': ne != null && sw != null
          ? deltaForBounds(
              ne['longitude'] - sw['longitude'],
              ne['latitude'] - sw['latitude'],
            )
          : .02,
      'kind': types.contains('country')
          ? 'country'
          : types.any(
              (v) =>
                  string(v).startsWith('administrative_area') ||
                  v == 'locality',
            )
          ? 'region'
          : 'place',
      'venue': googleVenueType(types.map(string)),
    };
  }

  static String googleVenueType(Iterable<String> types) {
    for (final type in types) {
      final value = switch (type) {
        'lodging' => 'hotel',
        'night_club' => 'nightclub',
        'gym' => 'fitness_centre',
        'store' || 'shopping_mall' || 'clothing_store' => 'store',
        'tourist_attraction' => 'attraction',
        'art_gallery' => 'gallery',
        'park' => 'park',
        'meal_takeaway' => 'fast_food',
        _ => type,
      };
      final venue = venueType(value == 'store' ? 'shop' : '', value);
      if (venue != 'building') return venue;
    }
    return 'building';
  }
}
