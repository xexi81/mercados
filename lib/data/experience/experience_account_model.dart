class ExperienceAccountModel {
  final Map<String, double> purchaseXpPerM3;
  final Map<String, double> saleXpPerM3;
  final Map<String, double> produceXpPerM3;
  final Map<String, double> retailSaleXpPerM3;
  final Map<String, double> contractFulfilledXpPerM3;
  final int onTimeBonusPercent;
  final int perfectConditionBonusPercent;
  final int xpPenaltyPercent;
  final int flatXpLoss;

  ExperienceAccountModel({
    required this.purchaseXpPerM3,
    required this.saleXpPerM3,
    required this.produceXpPerM3,
    required this.retailSaleXpPerM3,
    required this.contractFulfilledXpPerM3,
    required this.onTimeBonusPercent,
    required this.perfectConditionBonusPercent,
    required this.xpPenaltyPercent,
    required this.flatXpLoss,
  });

  factory ExperienceAccountModel.fromJson(Map<String, dynamic> json) {
    final rules = json['experienceRules'];

    return ExperienceAccountModel(
      purchaseXpPerM3: _parseXpMap(rules['purchase']['baseXpPerM3']),
      saleXpPerM3: _parseXpMap(rules['sale']['baseXpPerM3']),
      produceXpPerM3: _parseXpMap(rules['produce']['baseXpPerM3']),
      retailSaleXpPerM3: _parseXpMap(rules['retailSale']['baseXpPerM3']),
      contractFulfilledXpPerM3: _parseXpMap(
        rules['contractFulfilled']['baseXpPerM3'],
      ),
      onTimeBonusPercent: rules['contractFulfilled']['onTimeBonusPercent'],
      perfectConditionBonusPercent:
          rules['contractFulfilled']['perfectConditionBonusPercent'],
      xpPenaltyPercent: rules['contractFailed']['xpPenaltyPercent'],
      flatXpLoss: rules['contractFailed']['flatXpLoss'],
    );
  }

  static Map<String, double> _parseXpMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }
}
