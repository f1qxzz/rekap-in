import 'package:geolocator/geolocator.dart';

class LocationGuard {
  Future<Position> currentPrecisePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationGuardException(
          'Layanan lokasi belum aktif. Aktifkan GPS dari Settings.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationGuardException('Izin lokasi presisi wajib untuk absensi.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (position.isMocked) {
      throw LocationGuardException('Fake GPS terdeteksi. Absensi diblokir.');
    }

    if (position.accuracy > 50) {
      throw LocationGuardException(
          'Akurasi GPS ${position.accuracy.toStringAsFixed(0)}m. Maksimal 50m.');
    }

    return position;
  }
}

class LocationGuardException implements Exception {
  const LocationGuardException(this.message);

  final String message;

  @override
  String toString() => message;
}
