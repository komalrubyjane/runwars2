import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../core/services/supabase_service.dart';
import '../../../../../data/model/request/location_request.dart';
import '../../metrics/view_model/metrics_view_model.dart';
import '../../timer/viewmodel/timer_view_model.dart';
import '../models/gps_tracking_model.dart';
import '../services/loop_detection_service.dart';
import '../services/territory_capture_service.dart';
import 'state/location_state.dart';

final locationViewModelProvider =
    StateNotifierProvider<LocationViewModel, LocationState>(
  (ref) => LocationViewModel(ref),
);

/// View model for managing location-related functionality.
class LocationViewModel extends StateNotifier<LocationState> {
  final Ref ref;
  StreamSubscription<Position>? _positionStream;
  bool _isRunActive = false;
  final List<GPSPoint> _gpsTrack = [];
  List<DetectedLoop> _detectedLoops = [];
  CapturedTerritory? _territory;

  /// Creates a [LocationViewModel] instance.
  ///
  /// The [ref] is a reference to the current provider reference.
  LocationViewModel(this.ref) : super(LocationState.initial());

  @override
  Future<void> dispose() async {
    await cancelLocationStream();
    super.dispose();
  }

  /// Starts getting the user's location updates.
  Future<void> startGettingLocation() async {
    final metricsProvider = ref.read(metricsViewModelProvider.notifier);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission denied');
        return;
      }
    }

    // Enable high-accuracy location services
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    print('Location service enabled: $isLocationServiceEnabled');
    
    if (!isLocationServiceEnabled) {
      print('Location services are disabled. Please enable them.');
      return;
    }

    // Get initial position
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        forceAndroidLocationManager: false,
      );
      print('Initial position: ${initialPosition.latitude}, ${initialPosition.longitude}');
      state = state.copyWith(currentPosition: initialPosition);
    } catch (e) {
      print('Error getting initial position: $e');
    }

    _positionStream ??=
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best, // Highest accuracy
            distanceFilter: 1, // Update every 1 meter for precise tracking
            timeLimit: Duration(seconds: 3), // Max 3 seconds between updates
          ),
        ).listen((Position position) {
      if (mounted && _positionStream != null) {
        // Log position updates for debugging
        print('GPS Update: Lat=${position.latitude}, Lon=${position.longitude}, Accuracy=${position.accuracy}m');
        
        final timerProvider = ref.read(timerViewModelProvider.notifier);
        if (timerProvider.isTimerRunning() && timerProvider.hasTimerStarted()) {
          metricsProvider.updateMetrics();

          final positions = List<LocationRequest>.from(state.savedPositions);
          positions.add(
            LocationRequest(
              datetime: DateTime.now(),
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
          
          // Calculate steps from GPS distance
          final newStepCount = _calculateStepsFromDistance(positions);
          
          state = state.copyWith(
            savedPositions: positions,
            stepCount: newStepCount,
          );
          
          // Track GPS point for advanced analytics
          if (_isRunActive) {
            _addGPSPoint(position);
            _updateRunAnalytics();
          }
        }

        state = state.copyWith(
          currentPosition: position,
          lastPosition: state.currentPosition ?? position,
        );
      }
    });
  }

  /// Starts a new run (enables GPS tracking, loop detection, territory capture)
  void startRun() {
    _isRunActive = true;
    _gpsTrack.clear();
    _detectedLoops = [];
    _territory = null;
  }

  /// Stops the current run and finalizes analytics
  RunStatistics stopRun() {
    _isRunActive = false;
    
    // Calculate final statistics
    return _calculateRunStatistics();
  }

  /// Checks if a run is currently active
  bool isRunActive() => _isRunActive;

  /// Adds a GPS point to the tracking data
  void _addGPSPoint(Position position) {
    _gpsTrack.add(GPSPoint(
      position: LatLng(position.latitude, position.longitude),
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
      speed: position.speed,
      altitude: position.altitude,
    ));
  }

  /// Updates run analytics (loop detection, territory capture)
  void _updateRunAnalytics() {
    if (_gpsTrack.length > 10) {
      // Update loop detection
      _detectedLoops = LoopDetectionService.detectLoops(_gpsTrack);
      
      // Update territory capture
      _territory = TerritoryCaptureService.captureTerritory(_gpsTrack);
    }
  }

  /// Calculates comprehensive run statistics
  RunStatistics _calculateRunStatistics() {
    double totalDistance = 0;
    double maxSpeed = 0;
    double totalAltitudeGain = 0;

    // Calculate distance between consecutive points
    for (int i = 1; i < _gpsTrack.length; i++) {
      final distance = GPSPoint.distanceBetween(_gpsTrack[i - 1], _gpsTrack[i]);
      totalDistance += distance;

      // Track max speed
      if (_gpsTrack[i].speed != null && _gpsTrack[i].speed! > maxSpeed) {
        maxSpeed = _gpsTrack[i].speed!;
      }

      // Calculate altitude gain
      if (_gpsTrack[i - 1].altitude != null && _gpsTrack[i].altitude != null) {
        final altitudeDiff = _gpsTrack[i].altitude! - _gpsTrack[i - 1].altitude!;
        if (altitudeDiff > 0) {
          totalAltitudeGain += altitudeDiff;
        }
      }
    }

    // Calculate total time
    final totalTime = _gpsTrack.isEmpty
        ? Duration.zero
        : _gpsTrack.last.timestamp.difference(_gpsTrack.first.timestamp);

    // Calculate average speed
    final averageSpeed = totalTime.inSeconds > 0
        ? totalDistance / totalTime.inSeconds
        : 0.0;

    return RunStatistics(
      totalDistance: totalDistance,
      totalTime: totalTime,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      totalAltitudeGain: totalAltitudeGain,
      pointCount: _gpsTrack.length,
      detectedLoops: _detectedLoops,
      territory: _territory,
    );
  }

  /// Gets the current list of detected loops
  List<DetectedLoop> getDetectedLoops() => _detectedLoops;

  /// Gets the captured territory
  CapturedTerritory? getTerritory() => _territory;

  /// Gets all GPS points collected during the run
  List<GPSPoint> getGPSTrack() => List.unmodifiable(_gpsTrack);

  /// Retrieves the saved positions as a list of [LatLng] objects.
  List<LatLng> savedPositionsLatLng() {
    return state.savedPositions
        .map((position) => LatLng(position.latitude, position.longitude))
        .toList();
  }

  /// Resets the saved positions to an empty list.
  void resetSavedPositions() {
    state = state.copyWith(savedPositions: []);
    _gpsTrack.clear();
    _detectedLoops = [];
    _territory = null;
    _isRunActive = false;
  }

  /// Pauses the location stream.
  void stopLocationStream() {
    _positionStream?.pause();
  }

  /// Resumes the location stream.
  void resumeLocationStream() {
    _positionStream?.resume();
  }

  /// Cancels the location stream and cleans up resources.
  Future<void> cancelLocationStream() async {
    await _positionStream?.cancel();
    _positionStream = null;
    state = state.copyWith(currentPosition: null);
  }

  /// Checks if the location stream is currently paused.
  bool isLocationStreamPaused() {
    return _positionStream?.isPaused ?? false;
  }

  /// Calculates step count from accumulated distance
  /// Assumes average stride length of 0.75 meters per step
  int _calculateStepsFromDistance(List<LocationRequest> positions) {
    if (positions.length < 2) return 0;
    
    double totalDistance = 0;
    for (int i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final curr = positions[i];
      
      // Calculate distance using simple distance formula
      final dLat = curr.latitude - prev.latitude;
      final dLon = curr.longitude - prev.longitude;
      
      // Rough conversion: 1 degree ≈ 111 km
      final distanceKm = 111 * math.sqrt(dLat * dLat + dLon * dLon);
      totalDistance += distanceKm * 1000; // Convert to meters
    }
    
    // Average stride length is 0.75 meters (can be adjusted)
    const strideLength = 0.75;
    return (totalDistance / strideLength).round();
  }

  /// Save the completed activity to Supabase
  Future<bool> saveActivityToSupabase({
    required String userId,
    required double distance,
    required int durationSeconds,
  }) async {
    try {
      final pathPoints = state.savedPositions
          .map((loc) => {
                'latitude': loc.latitude,
                'longitude': loc.longitude,
                'timestamp': loc.datetime.toIso8601String(),
              })
          .toList();

      await SupabaseService().saveActivity(
        userId: userId,
        distance: distance,
        steps: state.stepCount,
        durationSeconds: durationSeconds,
        pathPoints: pathPoints,
      );

      debugPrint('[Supabase] Activity saved (distance: ${distance}km, polyline points: ${pathPoints.length})');
      return true;
    } catch (e) {
      debugPrint('[Supabase] Error saving activity: $e');
      return false;
    }
  }
}
