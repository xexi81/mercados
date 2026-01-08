import '../fleet/unlock_cost_type.dart';

class HireCostModel {
  final UnlockCostType type;
  final int amount;

  HireCostModel({required this.type, required this.amount});

  factory HireCostModel.fromJson(Map<String, dynamic> json) {
    return HireCostModel(
      type: UnlockCostType.fromCode(json['type']),
      amount: json['amount'],
    );
  }

  Map<String, dynamic> toJson() => {'type': type.code, 'amount': amount};
}
