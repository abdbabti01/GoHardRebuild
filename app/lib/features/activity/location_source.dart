import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/language.dart' show currentL10n;

/// What the phone's location is able to do right now. Always read from the device, never assumed.
enum GpsAccess {
  /// Location services are switched off on the phone.
  servicesOff,

  /// Not asked yet, or asked and refused this time: asking again is possible.
  notAllowed,

  /// Refused permanently: only the system settings can change it.
  deniedForever,

  /// Allowed, but only approximate (reduced) accuracy: not enough to measure a route.
  approximate,

  /// Allowed with precise location.
  allowed,

  /// This device has no usable location (or the plugin failed).
  unavailable,
}

/// One location reading as the device reported it.
class Reading {
  const Reading({required this.lat, required this.lon, required this.acc, required this.at, this.alt, this.altAcc, this.speed, this.speedAcc, this.heading});
  final double lat, lon, acc;
  final DateTime at;
  final double? alt, altAcc, speed, speedAcc, heading;
}

/// The device's location (docs/RUN_WALK.md › Location). [watch] with `recording: true` is the one stream a recording
/// uses: on Android it runs geolocator's location foreground service with a visible notification, on iOS it allows
/// background updates (with the blue indicator). Ready's preview uses `recording: false` (foreground only).
abstract class LocationSource {
  Future<GpsAccess> access();

  /// Asks for permission in context (when-in-use only; never "all the time").
  Future<GpsAccess> request();
  Stream<Reading> watch({required bool recording, String type = 'run'});
  Future<void> openSettings({required bool app});

  /// True when readings are simulated (tests and labelled demo journeys).
  bool get simulated => false;
}

class DeviceLocationSource implements LocationSource {
  const DeviceLocationSource();

  @override
  bool get simulated => false;

  @override
  Future<GpsAccess> access() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return GpsAccess.servicesOff;
      return await _map(await Geolocator.checkPermission());
    } on Object {
      return GpsAccess.unavailable;
    }
  }

  Future<GpsAccess> _map(LocationPermission p) async => switch (p) {
        LocationPermission.denied => GpsAccess.notAllowed,
        LocationPermission.deniedForever => GpsAccess.deniedForever,
        LocationPermission.unableToDetermine => GpsAccess.unavailable,
        _ => await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced ? GpsAccess.approximate : GpsAccess.allowed,
      };

  @override
  Future<GpsAccess> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return GpsAccess.servicesOff;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      final mapped = await _map(p);
      // iOS 14+: precise location can be asked for once, for this use, when only approximate was given.
      if (mapped == GpsAccess.approximate && defaultTargetPlatform == TargetPlatform.iOS) {
        await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'RouteRecording');
        return await access();
      }
      return mapped;
    } on Object {
      return GpsAccess.unavailable;
    }
  }

  @override
  Stream<Reading> watch({required bool recording, String type = 'run'}) {
    // The notification is in the language resolved when the recording starts.
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 0, intervalDuration: const Duration(seconds: 1),
          // The GPS provider itself: readings every second with the receiver's own speed and altitude.
          forceLocationManager: true,
          foregroundNotificationConfig: recording
              ? ForegroundNotificationConfig(
                  notificationTitle: currentL10n.runNotificationTitle(type),
                  notificationText: currentL10n.runNotificationText(type),
                  notificationChannelName: currentL10n.runNotificationChannel,
                  setOngoing: true, enableWakeLock: true, color: Colors.green.shade800)
              : null),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 0, activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false, allowBackgroundLocationUpdates: recording, showBackgroundLocationIndicator: recording),
      _ => const LocationSettings(accuracy: LocationAccuracy.best),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map((p) => Reading(
          lat: p.latitude, lon: p.longitude, acc: p.accuracy, at: p.timestamp.toUtc(),
          // A device without a measured value reports 0 (Android) or a negative number (iOS): that is "unknown".
          alt: p.altitudeAccuracy > 0 ? p.altitude : null, altAcc: p.altitudeAccuracy > 0 ? p.altitudeAccuracy : null,
          speed: p.speedAccuracy > 0 && p.speed >= 0 ? p.speed : null, speedAcc: p.speedAccuracy > 0 ? p.speedAccuracy : null,
          heading: p.headingAccuracy > 0 ? p.heading : null,
        ));
  }

  @override
  Future<void> openSettings({required bool app}) async {
    try {
      app ? await Geolocator.openAppSettings() : await Geolocator.openLocationSettings();
    } on Object {
      // Nothing to open on this device; the screen keeps saying what is needed.
    }
  }
}

/// Simulated location for tests and the labelled demo journey: a scripted route played at real time. Never used
/// by the app on its own.
class SimulatedLocationSource implements LocationSource {
  SimulatedLocationSource(this.route, {this.interval = const Duration(seconds: 1), this.accessState = GpsAccess.allowed});

  /// (lat, lon, accuracy, altitude?) per reading, in order; the last one repeats once the route has ended.
  final List<(double, double, double, double?)> route;
  final Duration interval;
  GpsAccess accessState;
  int _next = 0;

  @override
  bool get simulated => true;
  @override
  Future<GpsAccess> access() async => accessState;
  @override
  Future<GpsAccess> request() async => accessState == GpsAccess.notAllowed ? accessState = GpsAccess.allowed : accessState;
  @override
  Future<void> openSettings({required bool app}) async {}

  @override
  Stream<Reading> watch({required bool recording, String type = 'run'}) {
    late StreamController<Reading> c;
    Timer? timer;
    void emit() {
      final p = route[_next.clamp(0, route.length - 1)];
      if (recording) _next++;
      c.add(Reading(lat: p.$1, lon: p.$2, acc: p.$3, alt: p.$4, altAcc: p.$4 == null ? null : 4, speed: null, at: DateTime.now().toUtc()));
    }

    c = StreamController<Reading>(onListen: () {
      emit();
      timer = Timer.periodic(interval, (_) => emit());
    }, onCancel: () => timer?.cancel());
    return c.stream;
  }
}

final locationSourceProvider = Provider<LocationSource>((_) => const DeviceLocationSource());
