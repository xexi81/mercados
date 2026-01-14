import 'dart:math';

class DistanceCalculator {
  /// Radio de la Tierra en kilómetros
  static const double _earthRadiusKm = 6371.0;

  /// Calcula la distancia entre dos coordenadas usando la fórmula de Haversine
  ///
  /// [lat1] Latitud del primer punto
  /// [lng1] Longitud del primer punto
  /// [lat2] Latitud del segundo punto
  /// [lng2] Longitud del segundo punto
  ///
  /// Retorna la distancia en kilómetros
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    // Convertir grados a radianes
    double lat1Rad = _degreesToRadians(lat1);
    double lng1Rad = _degreesToRadians(lng1);
    double lat2Rad = _degreesToRadians(lat2);
    double lng2Rad = _degreesToRadians(lng2);

    // Diferencias
    double deltaLat = lat2Rad - lat1Rad;
    double deltaLng = lng2Rad - lng1Rad;

    // Fórmula de Haversine
    double a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Distancia en kilómetros
    return _earthRadiusKm * c;
  }

  /// Convierte grados a radianes
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Calcula la distancia y la redondea a un número específico de decimales
  ///
  /// [lat1] Latitud del primer punto
  /// [lng1] Longitud del primer punto
  /// [lat2] Latitud del segundo punto
  /// [lng2] Longitud del segundo punto
  /// [decimals] Número de decimales para redondear (por defecto 2)
  ///
  /// Retorna la distancia en kilómetros redondeada
  static double calculateDistanceRounded(
    double lat1,
    double lng1,
    double lat2,
    double lng2, {
    int decimals = 2,
  }) {
    double distance = calculateDistance(lat1, lng1, lat2, lng2);
    return double.parse(distance.toStringAsFixed(decimals));
  }
}
