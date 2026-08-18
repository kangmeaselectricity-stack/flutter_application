import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<String> getUTMCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return "48P (GPS មិនបានបើក)";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return "48P (មិនមានសិទ្ធិ GPS)";
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return "48P (សិទ្ធិ GPS ត្រូវបានបិទ)";
      }

      final LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return "48P GPS-Timeout";
      }

      double lat = position.latitude;
      double lng = position.longitude;

      int zone = 48;
      String band = "P";

      double laRad = lat * 0.01745329251;
      double k0 = 0.9996;
      double a = 6378137.0;
      double eccSquared = 0.00669437999;
      double longitudeOrigin = (zone * 6 - 183) * 0.01745329251;

      double eccPrimeSquared = (eccSquared) / (1 - eccSquared);
      double n = a / sqrt(1 - eccSquared * sin(laRad) * sin(laRad));
      double t = tan(laRad) * tan(laRad);
      double c = eccPrimeSquared * cos(laRad) * cos(laRad);
      double a1 = cos(laRad) * ((lng * 0.01745329251) - longitudeOrigin);

      double m =
          a *
          ((1 - eccSquared / 4 - 3 * eccSquared * eccSquared / 64) * laRad -
              (3 * eccSquared / 8 + 3 * eccSquared * eccSquared / 32) *
                  sin(2 * laRad) +
              (15 * eccSquared * eccSquared / 256) * sin(4 * laRad));

      double utmEasting =
          (k0 *
              n *
              (a1 +
                  (1 - t + c) * a1 * a1 * a1 / 6 +
                  (5 - 18 * t + t * t + 72 * c - 58 * eccPrimeSquared) *
                      a1 *
                      a1 *
                      a1 *
                      a1 *
                      a1 /
                      120)) +
          500000.0;

      double utmNorthing =
          (k0 *
          (m +
              n *
                  tan(laRad) *
                  (a1 * a1 / 2 +
                      (5 - t + 9 * c + 4 * c * c) * a1 * a1 * a1 * a1 / 24 +
                      (61 - 58 * t + t * t + 600 * c - 330 * eccPrimeSquared) *
                          a1 *
                          a1 *
                          a1 *
                          a1 *
                          a1 *
                          a1 /
                          720)));

      return "$zone$band ${utmEasting.toStringAsFixed(0)} ${utmNorthing.toStringAsFixed(0)}";
    } catch (e) {
      debugPrint("❌ GPS Error: $e");
      return "48P (Error GPS)";
    }
  }
}
