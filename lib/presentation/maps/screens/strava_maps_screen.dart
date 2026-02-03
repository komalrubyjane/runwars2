import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/services/territory_tile_service.dart';
import '../../../core/theme/strava_theme.dart';

final _tileServiceProvider = Provider((ref) => TerritoryTileService(precision: 7));

/// Strava-style Maps tab: Google Map with fixed geohash grid overlay and territory tiles.
class StravaMapsScreen extends HookConsumerWidget {
  const StravaMapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileService = ref.watch(_tileServiceProvider);
    final polygons = useState<Set<Polygon>>({});
    final tileCount = useState(0);
    final controllerRef = useRef<GoogleMapController?>(null);

    void updateGrid(GoogleMapController controller) {
      controller.getVisibleRegion().then((bounds) {
        final tiles = tileService.getTilesInBounds(bounds);
        tileCount.value = tiles.length;
        final poly = <Polygon>{};
        for (final id in tiles) {
          final tile = tileService.getOrCreateTile(id);
          final pts = tileService.getTilePolygon(id);
          poly.add(
            Polygon(
              polygonId: PolygonId(id),
              points: pts,
              strokeColor: tile.isClaimed ? StravaTheme.orange : StravaTheme.grey600,
              strokeWidth: 2,
              fillColor: (tile.isClaimed ? StravaTheme.orange : StravaTheme.grey400).withValues(alpha: 0.15),
            ),
          );
        }
        polygons.value = poly;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maps'),
        backgroundColor: StravaTheme.orange,
        foregroundColor: StravaTheme.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(37.7749, -122.4194),
              zoom: 14,
            ),
            onMapCreated: (c) {
              controllerRef.value = c;
              updateGrid(c);
            },
            onCameraIdle: () {
              final conn = controllerRef.value;
              if (conn != null) updateGrid(conn);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            polygons: polygons.value,
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Grid overlay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: StravaTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tiles in view: ${tileCount.value}',
                      style: TextStyle(
                        fontSize: 12,
                        color: StravaTheme.grey600,
                      ),
                    ),
                    Text(
                      'Precision: ${tileService.precision} (~200 m)',
                      style: TextStyle(
                        fontSize: 12,
                        color: StravaTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
