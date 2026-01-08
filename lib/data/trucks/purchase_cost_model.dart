import '../fleet/unlock_cost_type.dart';

class PurchaseCostModel {
  final UnlockCostType type;
  final int amount;

  PurchaseCostModel({required this.type, required this.amount});

  factory PurchaseCostModel.fromJson(Map<String, dynamic> json) {
    return PurchaseCostModel(
      type: UnlockCostType.fromCode(json['type']),
      amount: json['amount'],
    );
  }

  Map<String, dynamic> toJson() => {'type': type.code, 'amount': amount};
}
