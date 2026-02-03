import 'dart:math' as math;

import 'package:dart_geohash/dart_geohash.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Unique ID for a grid tile (geohash string).
typedef TileId = String;

/// Represents a claimed/validated territory tile with boundaries and owner.
class TerritoryTile {
  final TileId tileId;
  final String? ownerUserId;
  final DateTime? claimedAt;
  final LatLngBounds bounds;

  const TerritoryTile({
    required this.tileId,
    this.ownerUserId,
    this.claimedAt,
    required this.bounds,
  });

  bool get isClaimed => ownerUserId != null && ownerUserId!.isNotEmpty;
}

/// Geohash-based grid: deterministic tiles from lat/lon, fast point-in-tile, constant-time lookup.
/// Precision (length of geohash) controls tile size: 5 ≈ 4.9×4.9 km, 6 ≈ 1.2×0.6 km, 7 ≈ 153×153 m (~200 m).
class TerritoryTileService {
  TerritoryTileService({this.precision = 7});

  /// Geohash precision (default 7 ≈ ~200 m tiles).
  final int precision;

  final Map<TileId, TerritoryTile> _tiles = {};
  static final _hasher = GeoHasher();

  /// Get unique tile ID for a latitude-longitude position (deterministic).
  /// GeoHasher.encode expects (longitude, latitude).
  TileId getTileId(double latitude, double longitude) {
    return _hasher.encode(longitude, latitude, precision: precision);
  }

  /// Get tile ID for a [LatLng].
  TileId getTileIdFromLatLng(LatLng position) {
    return getTileId(position.latitude, position.longitude);
  }

  /// Fast point-in-tile check: returns true if (lat, lon) falls inside the tile identified by [tileId].
  bool isPointInTile(double latitude, double longitude, TileId tileId) {
    return getTileId(latitude, longitude) == tileId;
  }

  bool isLatLngInTile(LatLng position, TileId tileId) {
    return isPointInTile(position.latitude, position.longitude, tileId);
  }

  /// Constant-time lookup for a tile by ID.
  TerritoryTile? getTile(TileId tileId) => _tiles[tileId];

  /// Approximate cell size in degrees for a given geohash precision. Returns [latDeg, lonDeg].
  static List<double> _cellSize(int prec) {
    final bits = (prec * 5) ~/ 2;
    final latDeg = 180.0 / math.pow(2, bits);
    final lonDeg = 360.0 / math.pow(2, bits);
    return [latDeg.toDouble(), lonDeg.toDouble()];
  }

  /// Get or create tile with clear boundaries (bounding box from geohash decode).
  TerritoryTile getOrCreateTile(TileId tileId) {
    if (_tiles.containsKey(tileId)) return _tiles[tileId]!;
    final decoded = _hasher.decode(tileId);
    // decode returns [longitude, latitude]
    final lon = decoded[0];
    final lat = decoded[1];
    final sizes = _cellSize(tileId.length);
    final halfLat = sizes[0] / 2;
    final halfLon = sizes[1] / 2;
    final bounds = LatLngBounds(
      southwest: LatLng(lat - halfLat, lon - halfLon),
      northeast: LatLng(lat + halfLat, lon + halfLon),
    );
    final tile = TerritoryTile(tileId: tileId, bounds: bounds);
    _tiles[tileId] = tile;
    return tile;
  }

  /// Claim a tile for a user (update in-memory; persist to Supabase separately if needed).
  void claimTile(TileId tileId, String userId) {
    final tile = getOrCreateTile(tileId);
    _tiles[tileId] = TerritoryTile(
      tileId: tileId,
      ownerUserId: userId,
      claimedAt: DateTime.now(),
      bounds: tile.bounds,
    );
  }

  /// Validate that a point is inside the tile (for claiming/validation).
  bool validatePointInTile(double lat, double lon, TileId tileId) {
    return isPointInTile(lat, lon, tileId);
  }

  /// Update tile (e.g. change owner or clear claim).
  void updateTile(TileId tileId, {String? ownerUserId, DateTime? claimedAt}) {
    final existing = _tiles[tileId];
    if (existing == null) return;
    _tiles[tileId] = TerritoryTile(
      tileId: tileId,
      ownerUserId: ownerUserId ?? existing.ownerUserId,
      claimedAt: claimedAt ?? existing.claimedAt,
      bounds: existing.bounds,
    );
  }

  /// Get polygon corners for a tile (for drawing on map). Returns 4 corners + close.
  List<LatLng> getTilePolygon(TileId tileId) {
    final tile = getOrCreateTile(tileId);
    final sw = tile.bounds.southwest;
    final ne = tile.bounds.northeast;
    return [
      sw,
      LatLng(ne.latitude, sw.longitude),
      ne,
      LatLng(sw.latitude, ne.longitude),
      sw,
    ];
  }

  /// Get all tiles in a visible region (bounds). Returns tile IDs that overlap the region.
  /// Uses finer sampling for high precision (small tiles) to ensure full coverage.
  Set<TileId> getTilesInBounds(LatLngBounds bounds) {
    final set = <TileId>{};
    // More samples for precision 7+ (~200m tiles) so we don't miss tiles
    final steps = precision >= 7 ? 50 : 20;
    final stepLat = (bounds.northeast.latitude - bounds.southwest.latitude) / steps;
    final stepLon = (bounds.northeast.longitude - bounds.southwest.longitude) / steps;
    for (var i = 0; i <= steps; i++) {
      for (var j = 0; j <= steps; j++) {
        final lat = bounds.southwest.latitude + i * stepLat;
        final lon = bounds.southwest.longitude + j * stepLon;
        set.add(getTileId(lat, lon));
      }
    }
    return set;
  }

  Map<TileId, TerritoryTile> get allTiles => Map.unmodifiable(_tiles);
}
