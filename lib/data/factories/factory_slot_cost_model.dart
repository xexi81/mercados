class FactorySlotCostModel {
  final int money;
  final int gems;

  FactorySlotCostModel({required this.money, required this.gems});

  factory FactorySlotCostModel.fromJson(Map<String, dynamic> json) {
    return FactorySlotCostModel(
      money: json['money'] as int,
      gems: json['gems'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'money': money, 'gems': gems};
  }
}
