import 'material_component.dart';

class MaterialModel {
  final int id;
  final String name;
  final String category;
  final String description;
  final int grade;
  final List<MaterialComponent> components;
  final int basePrice;

  MaterialModel({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.grade,
    required this.components,
    required this.basePrice,
  });

  String get imagePath => 'assets/images/materials/$id.png';

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      description: json['description'] ?? '',
      grade: json['grade'],
      basePrice: json['basePrice'],
      components: (json['components'] as List)
          .map((c) => MaterialComponent.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'grade': grade,
    'basePrice': basePrice,
    'components': components.map((c) => c.toJson()).toList(),
  };
}
