import 'unlock_cost_type.dart';

class UnlockCostModel {
  final UnlockCostType type;
  final int amount;

  UnlockCostModel({required this.type, required this.amount});

  factory UnlockCostModel.fromJson(Map<String, dynamic> json) {
    return UnlockCostModel(
      type: UnlockCostType.fromCode(json['type']),
      amount: json['amount'],
    );
  }

  Map<String, dynamic> toJson() => {'type': type.code, 'amount': amount};
}
