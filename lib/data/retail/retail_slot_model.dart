class RetailSlotCost {
  final int money;
  final int gems;

  RetailSlotCost({required this.money, required this.gems});

  factory RetailSlotCost.fromJson(Map<String, dynamic> json) {
    return RetailSlotCost(money: json['money'], gems: json['gems']);
  }

  Map<String, dynamic> toJson() => {'money': money, 'gems': gems};
}

class RetailSlot {
  final int slotId;
  final int requiredLevel;
  final RetailSlotCost cost;

  RetailSlot({
    required this.slotId,
    required this.requiredLevel,
    required this.cost,
  });

  factory RetailSlot.fromJson(Map<String, dynamic> json) {
    return RetailSlot(
      slotId: json['slotId'],
      requiredLevel: json['requiredLevel'],
      cost: RetailSlotCost.fromJson(json['cost']),
    );
  }

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'requiredLevel': requiredLevel,
    'cost': cost.toJson(),
  };
}
