import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/services/territory_tile_service.dart';
import '../../../../core/theme/strava_theme.dart';

final _tileServiceProvider = Provider((ref) => TerritoryTileService(precision: 7));

/// Map for Record screen: polyline, loops, grid overlay, markers
class TrackingMapWithGrid extends HookConsumerWidget {
  final List<LatLng> points;
  final Set<Marker> markers;
  final List<List<LatLng>> closedLoopPolygons;

  const TrackingMapWithGrid({
    super.key,
    required this.points,
    required this.markers,
    this.closedLoopPolygons = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileService = ref.watch(_tileServiceProvider);
    final gridPolygons = useState<Set<Polygon>>({});
    final controllerRef = useRef<GoogleMapController?>(null);

    final center = points.isNotEmpty
        ? LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
          )
        : const LatLng(37.7749, -122.4194);

    void updateGrid(GoogleMapController c) {
      c.getVisibleRegion().then((bounds) {
        final tiles = tileService.getTilesInBounds(bounds);
        final poly = <Polygon>{};
        for (final id in tiles) {
          final tile = tileService.getOrCreateTile(id);
          final pts = tileService.getTilePolygon(id);
          poly.add(
            Polygon(
              polygonId: PolygonId('grid_$id'),
              points: pts,
              strokeColor: tile.isClaimed ? StravaTheme.orange : StravaTheme.grey600,
              strokeWidth: 1,
              fillColor: (tile.isClaimed ? StravaTheme.orange : StravaTheme.grey400)
                  .withValues(alpha: 0.08),
            ),
          );
        }
        gridPolygons.value = poly;
      });
    }

    // Territory/route polyline — real-time trajectory from start to current/end (Strava-style)
    final List<LatLng> routePoints = points.length >= 2
        ? points
        : points.length == 1
            ? [points[0], LatLng(points[0].latitude + 0.00001, points[0].longitude)]
            : <LatLng>[];
    final routePolyline = routePoints.isNotEmpty
        ? Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: StravaTheme.orange,
            width: 10,
            geodesic: true,
          )
        : null;

    // Fit map to route when points change so trajectory is always visible
    useEffect(() {
      if (points.length < 2) return;
      final c = controllerRef.value;
      if (c == null) return;
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      // Avoid invalid bounds when all points are the same
      const pad = 0.0001;
      if (maxLat <= minLat) { maxLat = minLat + pad; minLat = minLat - pad; }
      if (maxLng <= minLng) { maxLng = minLng + pad; minLng = minLng - pad; }
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
      return null;
    }, [points.length]);

    final loopPolygons = <Polygon>{};
    for (var i = 0; i < closedLoopPolygons.length; i++) {
      final pts = closedLoopPolygons[i];
      if (pts.length >= 3) {
        loopPolygons.add(
          Polygon(
            polygonId: PolygonId('loop_$i'),
            points: pts,
            fillColor: StravaTheme.orange.withValues(alpha: 0.25),
            strokeColor: StravaTheme.orange,
            strokeWidth: 3,
          ),
        );
      }
    }

    final allPolygons = {...gridPolygons.value, ...loopPolygons};

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 15),
      onMapCreated: (c) {
        controllerRef.value = c;
        updateGrid(c);
      },
      onCameraIdle: () {
        final c = controllerRef.value;
        if (c != null) updateGrid(c);
      },
      markers: markers,
      polylines: {if (routePolyline != null) routePolyline},
      polygons: allPolygons,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      mapType: MapType.normal,
    );
  }
}
