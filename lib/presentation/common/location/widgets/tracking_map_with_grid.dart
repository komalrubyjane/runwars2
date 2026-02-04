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

    // Territory/route polyline — visible in real time as the user moves
    final routePolyline = points.length >= 2
        ? Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: StravaTheme.orange,
            width: 7,
            geodesic: true,
          )
        : null;

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
