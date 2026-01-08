class ContainerBonusesModel {
  final double loadingSpeedPercent;
  final double damageRiskReductionPercent;

  ContainerBonusesModel({
    required this.loadingSpeedPercent,
    required this.damageRiskReductionPercent,
  });

  factory ContainerBonusesModel.fromJson(Map<String, dynamic> json) {
    return ContainerBonusesModel(
      loadingSpeedPercent: (json['loadingSpeedPercent'] as num).toDouble(),
      damageRiskReductionPercent: (json['damageRiskReductionPercent'] as num)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'loadingSpeedPercent': loadingSpeedPercent,
    'damageRiskReductionPercent': damageRiskReductionPercent,
  };
}
