import 'factory_slot_cost_model.dart';

class FactorySlotModel {
  final int slotId;
  final int requiredLevel;
  final FactorySlotCostModel cost;

  FactorySlotModel({
    required this.slotId,
    required this.requiredLevel,
    required this.cost,
  });

  factory FactorySlotModel.fromJson(Map<String, dynamic> json) {
    return FactorySlotModel(
      slotId: json['slotId'] as int,
      requiredLevel: json['requiredLevel'] as int,
      cost: FactorySlotCostModel.fromJson(json['cost'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slotId': slotId,
      'requiredLevel': requiredLevel,
      'cost': cost.toJson(),
    };
  }
}
