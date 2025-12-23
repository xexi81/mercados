class MaterialComponent {
  final int materialId;
  final int quantity;

  MaterialComponent({required this.materialId, required this.quantity});

  factory MaterialComponent.fromJson(Map<String, dynamic> json) {
    return MaterialComponent(
      materialId: json['materialId'],
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'quantity': quantity,
  };
}
