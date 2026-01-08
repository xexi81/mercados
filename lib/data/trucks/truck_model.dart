import '../materials/container_type.dart';
import 'purchase_cost_model.dart';

class TruckModel {
  final int truckId;
  final String name;
  final int unlockFleet;
  final PurchaseCostModel purchaseCost;
  final int sellValue;
  final List<ContainerType> allowedContainers;
  final int maxSpeedKmh;
  final double fuelCapacityM3;
  final double fuelConsumptionPer100KmM3;
  final double accidentRiskPercent;
  final double breakdownRiskPercent;

  TruckModel({
    required this.truckId,
    required this.name,
    required this.unlockFleet,
    required this.purchaseCost,
    required this.sellValue,
    required this.allowedContainers,
    required this.maxSpeedKmh,
    required this.fuelCapacityM3,
    required this.fuelConsumptionPer100KmM3,
    required this.accidentRiskPercent,
    required this.breakdownRiskPercent,
  });

  factory TruckModel.fromJson(Map<String, dynamic> json) {
    return TruckModel(
      truckId: json['truckId'],
      name: json['name'],
      unlockFleet: json['unlockFleet'],
      purchaseCost: PurchaseCostModel.fromJson(json['purchaseCost']),
      sellValue: json['sellValue'],
      allowedContainers: (json['allowedContainers'] as List)
          .map((code) => ContainerType.fromCode(code as String))
          .toList(),
      maxSpeedKmh: json['maxSpeedKmh'],
      fuelCapacityM3: (json['fuelCapacityM3'] as num).toDouble(),
      fuelConsumptionPer100KmM3: (json['fuelConsumptionPer100KmM3'] as num)
          .toDouble(),
      accidentRiskPercent: (json['accidentRiskPercent'] as num).toDouble(),
      breakdownRiskPercent: (json['breakdownRiskPercent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'truckId': truckId,
    'name': name,
    'unlockFleet': unlockFleet,
    'purchaseCost': purchaseCost.toJson(),
    'sellValue': sellValue,
    'allowedContainers': allowedContainers.map((c) => c.code).toList(),
    'maxSpeedKmh': maxSpeedKmh,
    'fuelCapacityM3': fuelCapacityM3,
    'fuelConsumptionPer100KmM3': fuelConsumptionPer100KmM3,
    'accidentRiskPercent': accidentRiskPercent,
    'breakdownRiskPercent': breakdownRiskPercent,
  };
}
