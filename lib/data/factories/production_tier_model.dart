import 'factory_product_model.dart';

class ProductionTierModel {
  final int tier;
  final int maxGrade;
  final int unlockPrice;
  final List<FactoryProductModel> products;

  ProductionTierModel({
    required this.tier,
    required this.maxGrade,
    required this.unlockPrice,
    required this.products,
  });

  factory ProductionTierModel.fromJson(Map<String, dynamic> json) {
    return ProductionTierModel(
      tier: json['tier'] as int,
      maxGrade: json['maxGrade'] as int,
      unlockPrice: json['unlockPrice'] as int,
      products: (json['products'] as List<dynamic>)
          .map((p) => FactoryProductModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'maxGrade': maxGrade,
      'unlockPrice': unlockPrice,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }
}
