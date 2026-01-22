class WarehouseLevelModel {
  final int level;
  final double capacityIncreaseM3;
  final String currency; // "money" or "gems"
  final int cost;

  WarehouseLevelModel({
    required this.level,
    required this.capacityIncreaseM3,
    required this.currency,
    required this.cost,
  });

  factory WarehouseLevelModel.fromJson(Map<String, dynamic> json) {
    return WarehouseLevelModel(
      level: json['level'] as int,
      capacityIncreaseM3: (json['capacity_increase_m3'] as num).toDouble(),
      currency: json['currency'] as String,
      cost: json['cost'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'capacity_increase_m3': capacityIncreaseM3,
      'currency': currency,
      'cost': cost,
    };
  }
}
