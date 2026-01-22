class WarehouseModel {
  final int id;
  final String name;
  final int grade;
  final int requiredLevel;
  final UnlockCost unlockCost;
  final double capacityM3;

  WarehouseModel({
    required this.id,
    required this.name,
    required this.grade,
    required this.requiredLevel,
    required this.unlockCost,
    required this.capacityM3,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      grade: json['grade'] as int,
      requiredLevel: json['required_level'] as int,
      unlockCost: UnlockCost.fromJson(
        json['unlock_cost'] as Map<String, dynamic>,
      ),
      capacityM3: (json['capacity_m3'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'required_level': requiredLevel,
      'unlock_cost': unlockCost.toJson(),
      'capacity_m3': capacityM3,
    };
  }
}

class UnlockCost {
  final String type; // "money" or "gems"
  final int amount;

  UnlockCost({required this.type, required this.amount});

  factory UnlockCost.fromJson(Map<String, dynamic> json) {
    return UnlockCost(
      type: json['type'] as String,
      amount: json['amount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'amount': amount};
  }
}
