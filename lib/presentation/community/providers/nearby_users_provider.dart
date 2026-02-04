import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/supabase_service.dart';

/// Result for one nearby user (within 5 km).
class NearbyUser {
  final String userId;
  final String? fullName;
  final double distanceKm;
  final double lat;
  final double lng;

  const NearbyUser({
    required this.userId,
    this.fullName,
    required this.distanceKm,
    required this.lat,
    required this.lng,
  });

  static NearbyUser fromMap(Map<String, dynamic> map) {
    String? name;
    final users = map['users'];
    if (users is Map) {
      name = users['full_name'] as String?;
    }
    name ??= map['full_name'] as String?;
    if (name == null || name.isEmpty) {
      final email = map['email'] as String?;
      if (email != null && email.isNotEmpty) {
        name = email.toString().split('@').first;
      }
    }
    return NearbyUser(
      userId: map['user_id'] as String,
      fullName: name,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Fetches current location, upserts to Supabase, then returns users within 5 km.
final nearbyUsersProvider = FutureProvider<List<NearbyUser>>((ref) async {
  final user = SupabaseService().currentUser;
  if (user == null) return [];

  Position? position;
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return [];
      }
    }
    position = await Geolocator.getCurrentPosition();
  } catch (_) {
    return [];
  }

  await SupabaseService().upsertUserLocation(
    userId: user.id,
    lat: position.latitude,
    lng: position.longitude,
  );

  const radiusKm = 5.0;
  final list = await SupabaseService().getUsersWithinRadius(
    lat: position.latitude,
    lng: position.longitude,
    radiusKm: radiusKm,
    excludeUserId: user.id,
  );

  return list.map(NearbyUser.fromMap).toList();
});
