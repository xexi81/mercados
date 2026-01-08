class DriverBonusesModel {
  final double speedBonusPercent;
  final double fuelConsumptionReductionPercent;
  final double accidentRiskReductionPercent;
  final double breakdownRiskReductionPercent;

  DriverBonusesModel({
    required this.speedBonusPercent,
    required this.fuelConsumptionReductionPercent,
    required this.accidentRiskReductionPercent,
    required this.breakdownRiskReductionPercent,
  });

  factory DriverBonusesModel.fromJson(Map<String, dynamic> json) {
    return DriverBonusesModel(
      speedBonusPercent: (json['speedBonusPercent'] as num).toDouble(),
      fuelConsumptionReductionPercent:
          (json['fuelConsumptionReductionPercent'] as num).toDouble(),
      accidentRiskReductionPercent:
          (json['accidentRiskReductionPercent'] as num).toDouble(),
      breakdownRiskReductionPercent:
          (json['breakdownRiskReductionPercent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'speedBonusPercent': speedBonusPercent,
    'fuelConsumptionReductionPercent': fuelConsumptionReductionPercent,
    'accidentRiskReductionPercent': accidentRiskReductionPercent,
    'breakdownRiskReductionPercent': breakdownRiskReductionPercent,
  };
}
