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
  Timer? _fallbackPositionTimer;
  bool _isRunActive = false;
  final List<GPSPoint> _gpsTrack = [];
  List<DetectedLoop> _detectedLoops = [];
  CapturedTerritory? _territory;
  DateTime? _lastLocationReportAt;
  static const _locationReportInterval = Duration(seconds: 30);
  /// Fallback: sample position every 1.5s when run is active so we always get points
  static const _fallbackSampleInterval = Duration(milliseconds: 1500);
  static const _minDistanceMeters = 0.5; // avoid duplicate points

  /// Creates a [LocationViewModel] instance.
  ///
  /// The [ref] is a reference to the current provider reference.
  LocationViewModel(this.ref) : super(LocationState.initial());

  @override
  Future<void> dispose() async {
    _stopFallbackPositionTimer();
    await cancelLocationStream();
    super.dispose();
  }

  /// Starts getting the user's location updates.
  /// Creates the position stream first so tracking works even if initial position is slow.
  Future<void> startGettingLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
        return;
      }
    }

    final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    // Create stream first so we always receive updates once permission is granted
    if (_positionStream != null) return;
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(_onPositionUpdate, onError: (Object e, StackTrace st) {
      debugPrint('Position stream error: $e');
    });

    // Get initial position (don't block stream)
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        forceAndroidLocationManager: false,
      );
      state = state.copyWith(currentPosition: initialPosition);
    } catch (e) {
      debugPrint('Initial position error: $e');
    }
  }

  void _onPositionUpdate(Position position) {
    try {
      if (_positionStream == null) return;

      // Always update current position so UI and polyline can extend to live position
      state = state.copyWith(
        currentPosition: position,
        lastPosition: state.currentPosition ?? position,
      );

      // Record to track only when run is active (Strava Record screen)
      if (_isRunActive) {
        try {
          ref.read(metricsViewModelProvider.notifier).updateMetrics();
        } catch (_) {}
        final positions = List<LocationRequest>.from(state.savedPositions);
        positions.add(LocationRequest(
          datetime: DateTime.now(),
          latitude: position.latitude,
          longitude: position.longitude,
        ));
        final newStepCount = _calculateStepsFromDistance(positions);
        state = state.copyWith(
          savedPositions: positions,
          stepCount: newStepCount,
        );
        _addGPSPoint(position);
        _updateRunAnalytics();
      }

      // Throttled Supabase report
      final now = DateTime.now();
      if (_lastLocationReportAt == null ||
          now.difference(_lastLocationReportAt!) >= _locationReportInterval) {
        _lastLocationReportAt = now;
        final user = SupabaseService().currentUser;
        if (user != null) {
          SupabaseService().upsertUserLocation(
            userId: user.id,
            lat: position.latitude,
            lng: position.longitude,
          );
        }
      }
    } catch (e, st) {
      debugPrint('_onPositionUpdate error: $e $st');
    }
  }

  /// Starts a new run (enables GPS tracking, loop detection, territory capture).
  /// Adds current position as first point so trajectory and metrics work; ensures stream is running.
  void startRun() {
    _isRunActive = true;
    _gpsTrack.clear();
    _detectedLoops = [];
    _territory = null;
    _startFallbackPositionTimer();

    // Ensure we have a position stream (e.g. user tapped Start before screen finished init)
    if (_positionStream == null) {
      startGettingLocation();
    }

    if (state.currentPosition != null) {
      _addFirstPosition(state.currentPosition!);
    } else {
      // Fetch position so we have a start point (stream will add more)
      Geolocator.getCurrentPosition(forceAndroidLocationManager: false)
          .then((Position p) {
        if (_isRunActive && state.savedPositions.isEmpty) {
          _addFirstPosition(p);
        }
      }).catchError((Object e) {
        debugPrint('startRun getCurrentPosition: $e');
      });
      state = state.copyWith(savedPositions: [], stepCount: 0);
    }
  }

  void _startFallbackPositionTimer() {
    _fallbackPositionTimer?.cancel();
    _fallbackPositionTimer = Timer.periodic(_fallbackSampleInterval, (_) {
      if (!_isRunActive) return;
      Geolocator.getCurrentPosition(forceAndroidLocationManager: false)
          .then(_onFallbackPosition)
          .catchError((Object e) {
        debugPrint('Fallback position error: $e');
      });
    });
  }

  void _onFallbackPosition(Position position) {
    if (!_isRunActive || _positionStream == null) return;
    final positions = state.savedPositions;
    if (positions.isNotEmpty) {
      final last = positions.last;
      final dist = _haversineDistanceMeters([
        LocationRequest(datetime: last.datetime, latitude: last.latitude, longitude: last.longitude),
        LocationRequest(datetime: DateTime.now(), latitude: position.latitude, longitude: position.longitude),
      ]);
      if (dist < _minDistanceMeters) return; // skip if barely moved
    }
    // Add this position to track (same logic as stream)
    try {
      ref.read(metricsViewModelProvider.notifier).updateMetrics();
    } catch (_) {}
    final newPositions = List<LocationRequest>.from(positions);
    newPositions.add(LocationRequest(
      datetime: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
    ));
    final newStepCount = _calculateStepsFromDistance(newPositions);
    state = state.copyWith(
      currentPosition: position,
      savedPositions: newPositions,
      stepCount: newStepCount,
    );
    _addGPSPoint(position);
    _updateRunAnalytics();
  }

  void _stopFallbackPositionTimer() {
    _fallbackPositionTimer?.cancel();
    _fallbackPositionTimer = null;
  }

  void _addFirstPosition(Position p) {
    final positions = [
      LocationRequest(
        datetime: DateTime.now(),
        latitude: p.latitude,
        longitude: p.longitude,
      ),
    ];
    state = state.copyWith(currentPosition: p, savedPositions: positions, stepCount: 0);
    _addGPSPoint(p);
  }

  /// Stops the current run and finalizes analytics
  RunStatistics stopRun() {
    _isRunActive = false;
    _stopFallbackPositionTimer();
    // Prefer _gpsTrack; if empty (e.g. stream never emitted) use savedPositions so we don't show all zeros
    if (_gpsTrack.isEmpty && state.savedPositions.length >= 2) {
      return _runStatisticsFromSavedPositions();
    }
    if (_gpsTrack.isEmpty && state.savedPositions.length >= 1) {
      return _runStatisticsFromSavedPositions();
    }
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

  /// Run statistics from savedPositions when _gpsTrack was not filled (fallback)
  RunStatistics _runStatisticsFromSavedPositions() {
    final positions = state.savedPositions;
    if (positions.isEmpty) {
      return RunStatistics(
        totalDistance: 0,
        totalTime: Duration.zero,
        averageSpeed: 0,
        maxSpeed: 0,
        totalAltitudeGain: 0,
        pointCount: 0,
        detectedLoops: [],
        territory: null,
      );
    }
    if (positions.length < 2) {
      return RunStatistics(
        totalDistance: 0,
        totalTime: Duration.zero,
        averageSpeed: 0,
        maxSpeed: 0,
        totalAltitudeGain: 0,
        pointCount: positions.length,
        detectedLoops: [],
        territory: null,
      );
    }
    final totalDistance = _haversineDistanceMeters(positions);
    final totalTime = positions.last.datetime.difference(positions.first.datetime);
    final averageSpeed = totalTime.inSeconds > 0 ? totalDistance / totalTime.inSeconds : 0.0;
    return RunStatistics(
      totalDistance: totalDistance,
      totalTime: totalTime,
      averageSpeed: averageSpeed,
      maxSpeed: averageSpeed,
      totalAltitudeGain: 0,
      pointCount: positions.length,
      detectedLoops: [],
      territory: null,
    );
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
    _stopFallbackPositionTimer();
  }

  /// Resumes the location stream.
  void resumeLocationStream() {
    _positionStream?.resume();
    if (_isRunActive) _startFallbackPositionTimer();
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

  /// Calculates step count from accumulated distance (haversine).
  /// Assumes average stride length of 0.75 meters per step.
  int _calculateStepsFromDistance(List<LocationRequest> positions) {
    if (positions.length < 2) return 0;
    final totalDistanceMeters = _haversineDistanceMeters(positions);
    const strideLength = 0.75;
    return (totalDistanceMeters / strideLength).round();
  }

  /// Haversine distance in meters for a list of positions (sum of segments).
  double _haversineDistanceMeters(List<LocationRequest> positions) {
    if (positions.length < 2) return 0;
    const R = 6371000.0; // Earth radius in meters
    double total = 0;
    for (int i = 1; i < positions.length; i++) {
      final lat1 = positions[i - 1].latitude * math.pi / 180;
      final lat2 = positions[i].latitude * math.pi / 180;
      final dLat = (positions[i].latitude - positions[i - 1].latitude) * math.pi / 180;
      final dLon = (positions[i].longitude - positions[i - 1].longitude) * math.pi / 180;
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      total += R * c;
    }
    return total;
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
