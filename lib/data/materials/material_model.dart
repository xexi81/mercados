import 'material_component.dart';
import 'container_type.dart';

class MaterialModel {
  final int id;
  final String name;
  final String category;
  final String description;
  final int grade;
  final List<MaterialComponent> components;
  final int basePrice;
  final double unitVolumeM3;
  final List<ContainerType> allowedContainers;

  MaterialModel({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.grade,
    required this.components,
    required this.basePrice,
    required this.unitVolumeM3,
    required this.allowedContainers,
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
      unitVolumeM3: (json['unitVolumeM3'] as num).toDouble(),
      allowedContainers: (json['allowedContainers'] as List)
          .map((code) => ContainerType.fromCode(code as String))
          .toList(),
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
    'unitVolumeM3': unitVolumeM3,
    'allowedContainers': allowedContainers.map((c) => c.code).toList(),
    'components': components.map((c) => c.toJson()).toList(),
  };
}
