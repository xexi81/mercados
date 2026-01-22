import 'production_tier_model.dart';

class FactoryModel {
  final int id;
  final String name;
  final int basePurchasePrice;
  final List<ProductionTierModel> productionTiers;

  FactoryModel({
    required this.id,
    required this.name,
    required this.basePurchasePrice,
    required this.productionTiers,
  });

  factory FactoryModel.fromJson(Map<String, dynamic> json) {
    return FactoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      basePurchasePrice: json['basePurchasePrice'] as int,
      productionTiers: (json['productionTiers'] as List<dynamic>)
          .map((t) => ProductionTierModel.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'basePurchasePrice': basePurchasePrice,
      'productionTiers': productionTiers.map((t) => t.toJson()).toList(),
    };
  }
}
