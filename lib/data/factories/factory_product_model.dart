class FactoryProductModel {
  final int materialId;
  final int productionTimeSeconds;

  FactoryProductModel({
    required this.materialId,
    required this.productionTimeSeconds,
  });

  factory FactoryProductModel.fromJson(Map<String, dynamic> json) {
    return FactoryProductModel(
      materialId: json['materialId'] as int,
      productionTimeSeconds: json['productionTimeSeconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'materialId': materialId,
      'productionTimeSeconds': productionTimeSeconds,
    };
  }
}
