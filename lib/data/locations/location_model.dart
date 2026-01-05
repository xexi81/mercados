class LocationModel {
  final int id;
  final String city;
  final double latitude;
  final double longitude;
  final String countryIso;
  final bool hasMarket;
  final int? marketIndex;

  LocationModel({
    required this.id,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.countryIso,
    required this.hasMarket,
    this.marketIndex,
  });

  String get imagePath =>
      'assets/images/cities/${city.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}.png';

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'],
      city: json['city'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      countryIso: json['countryIso'],
      hasMarket: json['hasMarket'],
      marketIndex: json['marketIndex'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'countryIso': countryIso,
    'hasMarket': hasMarket,
    'marketIndex': marketIndex,
  };
}
