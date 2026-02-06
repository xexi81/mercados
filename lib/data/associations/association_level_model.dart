class AssociationLevelModel {
  final int level;
  final String name;
  final String description;
  final int maxMembers;
  final int requiredExperience;
  final UpgradeCost upgradeCost;

  AssociationLevelModel({
    required this.level,
    required this.name,
    required this.description,
    required this.maxMembers,
    required this.requiredExperience,
    required this.upgradeCost,
  });

  factory AssociationLevelModel.fromJson(Map<String, dynamic> json) {
    return AssociationLevelModel(
      level: json['level'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      maxMembers: json['maxMembers'] as int,
      requiredExperience: json['requiredExperience'] as int,
      upgradeCost: UpgradeCost.fromJson(
        json['upgradeCost'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'name': name,
    'description': description,
    'maxMembers': maxMembers,
    'requiredExperience': requiredExperience,
    'upgradeCost': upgradeCost.toJson(),
  };
}

class UpgradeCost {
  final int money;
  final int gems;

  UpgradeCost({required this.money, required this.gems});

  factory UpgradeCost.fromJson(Map<String, dynamic> json) {
    return UpgradeCost(
      money: (json['money'] as num).toInt(),
      gems: (json['gems'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {'money': money, 'gems': gems};
}
