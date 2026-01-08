import 'hire_cost_model.dart';
import 'driver_bonuses_model.dart';

class DriverModel {
  final int driverId;
  final String name;
  final HireCostModel hireCost;
  final DriverBonusesModel bonuses;

  DriverModel({
    required this.driverId,
    required this.name,
    required this.hireCost,
    required this.bonuses,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      driverId: json['driverId'],
      name: json['name'],
      hireCost: HireCostModel.fromJson(json['hireCost']),
      bonuses: DriverBonusesModel.fromJson(json['bonuses']),
    );
  }

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'name': name,
    'hireCost': hireCost.toJson(),
    'bonuses': bonuses.toJson(),
  };
}
