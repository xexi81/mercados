import '../materials/container_type.dart';
import 'purchase_cost_model.dart';
import 'container_bonuses_model.dart';

class ContainerModel {
  final int containerId;
  final String name;
  final ContainerType type;
  final double capacityM3;
  final PurchaseCostModel purchaseCost;
  final int sellValue;
  final ContainerBonusesModel bonuses;

  ContainerModel({
    required this.containerId,
    required this.name,
    required this.type,
    required this.capacityM3,
    required this.purchaseCost,
    required this.sellValue,
    required this.bonuses,
  });

  factory ContainerModel.fromJson(Map<String, dynamic> json) {
    return ContainerModel(
      containerId: json['containerId'],
      name: json['name'],
      type: ContainerType.fromCode(json['type']),
      capacityM3: (json['capacityM3'] as num).toDouble(),
      purchaseCost: PurchaseCostModel.fromJson(json['purchaseCost']),
      sellValue: json['sellValue'],
      bonuses: ContainerBonusesModel.fromJson(json['bonuses']),
    );
  }

  Map<String, dynamic> toJson() => {
    'containerId': containerId,
    'name': name,
    'type': type.code,
    'capacityM3': capacityM3,
    'purchaseCost': purchaseCost.toJson(),
    'sellValue': sellValue,
    'bonuses': bonuses.toJson(),
  };
}
