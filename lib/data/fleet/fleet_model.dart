import 'unlock_cost_model.dart';

class FleetModel {
  final int fleetId;
  final String name;
  final int requiredLevel;
  final UnlockCostModel unlockCost;
  final bool unlockedByDefault;

  FleetModel({
    required this.fleetId,
    required this.name,
    required this.requiredLevel,
    required this.unlockCost,
    required this.unlockedByDefault,
  });

  factory FleetModel.fromJson(Map<String, dynamic> json) {
    return FleetModel(
      fleetId: json['fleetId'],
      name: json['name'],
      requiredLevel: json['requiredLevel'],
      unlockCost: UnlockCostModel.fromJson(json['unlockCost']),
      unlockedByDefault: json['unlockedByDefault'],
    );
  }

  Map<String, dynamic> toJson() => {
    'fleetId': fleetId,
    'name': name,
    'requiredLevel': requiredLevel,
    'unlockCost': unlockCost.toJson(),
    'unlockedByDefault': unlockedByDefault,
  };
}
