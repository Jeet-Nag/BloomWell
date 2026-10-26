import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/calculators/gps_tracker_calculator.dart';

enum TrackingState { stopped, tracking, paused }

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  TrackingState _state = TrackingState.stopped;
  TrackingState get state => _state;

  StreamSubscription<Position>? _positionSubscription;
  final List<GpsPoint> _recordedPoints = [];
  List<GpsPoint> get recordedPoints => List.unmodifiable(_recordedPoints);

  DateTime? _sessionStartTime;
  DateTime? get sessionStartTime => _sessionStartTime;

  /// Total elapsed duration of the session in seconds (excludes paused time).
  int _totalElapsedSeconds = 0;
  int get totalElapsedSeconds => _totalElapsedSeconds;

  /// Active walking duration in seconds (strictly increments only during confirmed movement).
  int _activeDurationSeconds = 0;
  int get activeDurationSeconds => _activeDurationSeconds;

  bool _isMoving = false;
  bool get isMoving => _isMoving;

  double _lastAccuracy = 0.0;
  double get lastAccuracy => _lastAccuracy;

  bool get isWaitingForGps => _recordedPoints.isEmpty || _lastAccuracy <= 0.0;

  bool get isGpsSignalWeak =>
      _lastAccuracy > GpsTrackerCalculator.maxAcceptableAccuracyMeters ||
      _lastAccuracy <= 0.0;

  Timer? _ticker;

  final StreamController<double> _distanceStreamController =
      StreamController<double>.broadcast();
  Stream<double> get distanceStream => _distanceStreamController.stream;

  final StreamController<double> _speedStreamController =
      StreamController<double>.broadcast();
  Stream<double> get speedStream => _speedStreamController.stream;

  final StreamController<bool> _movingStateStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get movingStateStream => _movingStateStreamController.stream;

  final StreamController<double> _accuracyStreamController =
      StreamController<double>.broadcast();
  Stream<double> get accuracyStream => _accuracyStreamController.stream;

  final StreamController<int> _activeDurationStreamController =
      StreamController<int>.broadcast();
  Stream<int> get activeDurationStream => _activeDurationStreamController.stream;

  final StreamController<int> _elapsedDurationStreamController =
      StreamController<int>.broadcast();
  Stream<int> get elapsedDurationStream => _elapsedDurationStreamController.stream;

  double _totalDistanceMeters = 0.0;
  double get totalDistanceMeters => _totalDistanceMeters;

  double _currentSpeedKmh = 0.0;
  double get currentSpeedKmh => _currentSpeedKmh;

  GpsPoint? _lastConfirmedPoint;
  GpsPoint? _anchorPoint;
  GpsPoint? _lastMovingCandidatePoint;
  int _consecutiveMovingCandidates = 0;
  int _consecutiveStationaryCandidates = 0;

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> startTracking() async {
    final hasPerm = await checkAndRequestPermission();
    if (!hasPerm) return false;

    _resetSessionState();
    _sessionStartTime = DateTime.now();
    _state = TrackingState.tracking;

    _startTicker();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Request all fixes so stationary jitter is caught and rejected
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_state != TrackingState.tracking) return;

      final point = GpsPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
        speed: position.speed >= 0 ? position.speed : null,
      );

      processIncomingPoint(point);
    });

    return true;
  }

  void _resetSessionState() {
    _recordedPoints.clear();
    _totalDistanceMeters = 0.0;
    _currentSpeedKmh = 0.0;
    _totalElapsedSeconds = 0;
    _activeDurationSeconds = 0;
    _isMoving = false;
    _lastAccuracy = 0.0;
    _lastConfirmedPoint = null;
    _anchorPoint = null;
    _lastMovingCandidatePoint = null;
    _consecutiveMovingCandidates = 0;
    _consecutiveStationaryCandidates = 0;
  }

  /// Processes an incoming GPS point through the quality filter and hysteresis state machine.
  /// Exposed for both live geolocation and rigorous deterministic unit testing.
  void processIncomingPoint(GpsPoint point) {
    _lastAccuracy = point.accuracy;
    _accuracyStreamController.add(_lastAccuracy);

    // 1. Accuracy & coordinate validation
    if (!GpsTrackerCalculator.isValidPoint(point)) {
      // Discard poor-accuracy fix; if currently stationary keep speed at 0
      if (!_isMoving) {
        _currentSpeedKmh = 0.0;
        _speedStreamController.add(0.0);
      }
      return;
    }

    if (_lastConfirmedPoint == null) {
      // First valid fix establishes the starting anchor only.
      // It must NOT itself add distance or mark movement.
      _lastConfirmedPoint = point;
      _anchorPoint = point;
      _recordedPoints.add(point);
      _currentSpeedKmh = 0.0;
      _isMoving = false;
      _speedStreamController.add(0.0);
      _movingStateStreamController.add(false);
      return;
    }

    final distFromLast = GpsTrackerCalculator.haversineDistanceMeters(
      _lastConfirmedPoint!.latitude,
      _lastConfirmedPoint!.longitude,
      point.latitude,
      point.longitude,
    );

    final dtSeconds = point.timestamp.difference(_lastConfirmedPoint!.timestamp).inSeconds;
    if (dtSeconds <= 0) return;

    final derivedSpeedKmh = (distFromLast / dtSeconds) * 3.6;

    // 2. Teleport / implausible jump rejection
    if (derivedSpeedKmh > GpsTrackerCalculator.maxRealisticSpeedKmh) {
      if (kDebugMode) {
        print('Rejected GPS jump: $distFromLast m in $dtSeconds s (${derivedSpeedKmh.toStringAsFixed(1)} km/h)');
      }
      return;
    }

    // 3. Stationary Drift Filter & Hysteresis State Machine
    final deviceSpeedKmh = (point.speed != null && point.speed! >= 0) ? (point.speed! * 3.6) : null;

    if (!_isMoving) {
      final anchor = _anchorPoint ?? _lastConfirmedPoint!;
      final distFromAnchor = GpsTrackerCalculator.haversineDistanceMeters(
        anchor.latitude,
        anchor.longitude,
        point.latitude,
        point.longitude,
      );
      final dtAnchor = point.timestamp.difference(anchor.timestamp).inSeconds;
      final anchorSpeedKmh = dtAnchor > 0 ? (distFromAnchor / dtAnchor) * 3.6 : 0.0;

      final bool meetsDisplacement = distFromAnchor >=
          math.max(GpsTrackerCalculator.minMovementDistanceMeters, point.accuracy * 0.8);
      final bool meetsWalkingSpeed = anchorSpeedKmh >= GpsTrackerCalculator.minMovingSpeedKmh &&
          anchorSpeedKmh <= GpsTrackerCalculator.maxWalkingSpeedKmh;
      final bool notDopplerStationary = deviceSpeedKmh == null || deviceSpeedKmh >= 0.8;

      if (meetsDisplacement && meetsWalkingSpeed && notDopplerStationary) {
        _consecutiveMovingCandidates++;
        if (_consecutiveMovingCandidates == 1) {
          _lastMovingCandidatePoint = point;
        } else if (_consecutiveMovingCandidates >= 2) {
          // Confirmed start of movement!
          _isMoving = true;
          final stepDist = _lastMovingCandidatePoint != null
              ? GpsTrackerCalculator.haversineDistanceMeters(
                  _lastMovingCandidatePoint!.latitude,
                  _lastMovingCandidatePoint!.longitude,
                  point.latitude,
                  point.longitude,
                )
              : distFromLast;
          _totalDistanceMeters += math.min(stepDist + 4.0, distFromAnchor);
          _lastConfirmedPoint = point;
          _anchorPoint = point;
          _consecutiveMovingCandidates = 0;
          _consecutiveStationaryCandidates = 0;
          _lastMovingCandidatePoint = null;

          _currentSpeedKmh = (deviceSpeedKmh != null && deviceSpeedKmh >= 1.0 && deviceSpeedKmh <= 25.0)
              ? deviceSpeedKmh
              : (anchorSpeedKmh <= 8.5 ? anchorSpeedKmh : 4.0);

          _recordedPoints.add(point);
          _distanceStreamController.add(_totalDistanceMeters);
          _speedStreamController.add(_currentSpeedKmh);
          _movingStateStreamController.add(true);
        }
      } else {
        // Stationary jitter around anchor — do NOT accumulate distance!
        _consecutiveMovingCandidates = 0;
        _lastMovingCandidatePoint = null;
        _currentSpeedKmh = 0.0;
        _speedStreamController.add(0.0);
        if (distFromAnchor < 2.5) {
          _anchorPoint = point;
        }
      }
    } else {
      // Currently moving: check if user stopped or slowed below threshold
      final bool slowDerived = derivedSpeedKmh < GpsTrackerCalculator.stopMovingSpeedKmh && distFromLast < 2.0;
      final bool slowDevice = deviceSpeedKmh != null &&
          deviceSpeedKmh < GpsTrackerCalculator.stopMovingSpeedKmh &&
          distFromLast < 2.0;

      if (slowDerived || slowDevice) {
        _consecutiveStationaryCandidates++;
        if (_consecutiveStationaryCandidates >= 2) {
          // Confirmed stationary state!
          _isMoving = false;
          _anchorPoint = point;
          _lastConfirmedPoint = point;
          _consecutiveStationaryCandidates = 0;
          _currentSpeedKmh = 0.0;
          _speedStreamController.add(0.0);
          _movingStateStreamController.add(false);
        }
      } else {
        // Confirmed continuing movement
        _consecutiveStationaryCandidates = 0;
        _totalDistanceMeters += distFromLast;
        _lastConfirmedPoint = point;
        _currentSpeedKmh = (deviceSpeedKmh != null && deviceSpeedKmh >= 1.0 && deviceSpeedKmh <= 25.0)
            ? deviceSpeedKmh
            : derivedSpeedKmh;

        _recordedPoints.add(point);
        _distanceStreamController.add(_totalDistanceMeters);
        _speedStreamController.add(_currentSpeedKmh);
      }
    }
  }

  void pauseTracking() {
    if (_state == TrackingState.tracking) {
      _state = TrackingState.paused;
      _isMoving = false;
      _currentSpeedKmh = 0.0;
      _speedStreamController.add(0.0);
      _movingStateStreamController.add(false);
    }
  }

  void resumeTracking() {
    if (_state == TrackingState.paused) {
      _state = TrackingState.tracking;
      // Reset anchor on resume so pause duration and teleportation do not create fake distance
      _anchorPoint = null;
      _lastConfirmedPoint = null;
      _lastMovingCandidatePoint = null;
      _consecutiveMovingCandidates = 0;
      _consecutiveStationaryCandidates = 0;
    }
  }

  void stopTracking() {
    _state = TrackingState.stopped;
    _ticker?.cancel();
    _ticker = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMoving = false;
    _currentSpeedKmh = 0.0;
    _speedStreamController.add(0.0);
    _movingStateStreamController.add(false);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == TrackingState.tracking) {
        _totalElapsedSeconds++;
        _elapsedDurationStreamController.add(_totalElapsedSeconds);

        if (_isMoving) {
          _activeDurationSeconds++;
          _activeDurationStreamController.add(_activeDurationSeconds);

          // Watchdog: If no valid movement GPS fix received for 5+ seconds, auto-detect stationary
          if (_lastConfirmedPoint != null &&
              DateTime.now().difference(_lastConfirmedPoint!.timestamp).inSeconds >= 5) {
            _isMoving = false;
            _currentSpeedKmh = 0.0;
            _speedStreamController.add(0.0);
            _movingStateStreamController.add(false);
          }
        }
      }
    });
  }

  /// Helper for unit tests to artificially advance the session state
  @visibleForTesting
  void setTrackingForTesting({
    required double totalDistanceMeters,
    required int totalElapsedSeconds,
    required int activeDurationSeconds,
    required bool isMoving,
    required double currentSpeedKmh,
  }) {
    _totalDistanceMeters = totalDistanceMeters;
    _totalElapsedSeconds = totalElapsedSeconds;
    _activeDurationSeconds = activeDurationSeconds;
    _isMoving = isMoving;
    _currentSpeedKmh = currentSpeedKmh;
    _state = TrackingState.tracking;
  }

  void dispose() {
    stopTracking();
    _distanceStreamController.close();
    _speedStreamController.close();
    _movingStateStreamController.close();
    _accuracyStreamController.close();
    _activeDurationStreamController.close();
    _elapsedDurationStreamController.close();
  }
}
