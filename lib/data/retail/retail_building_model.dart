class RetailBuilding {
  final String id;
  final String name;
  final int purchaseCost;
  final int salesPerHour;
  final List<int> items;

  RetailBuilding({
    required this.id,
    required this.name,
    required this.purchaseCost,
    required this.salesPerHour,
    required this.items,
  });

  factory RetailBuilding.fromJson(Map<String, dynamic> json) {
    return RetailBuilding(
      id: json['id'],
      name: json['name'],
      purchaseCost: json['purchaseCost'],
      salesPerHour: json['salesPerHour'],
      items: List<int>.from(json['items']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'purchaseCost': purchaseCost,
    'salesPerHour': salesPerHour,
    'items': items,
  };
}
