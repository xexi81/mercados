class ExperienceLevelModel {
  final int level;
  final int requiredExperience;

  ExperienceLevelModel({required this.level, required this.requiredExperience});

  factory ExperienceLevelModel.fromJson(Map<String, dynamic> json) {
    return ExperienceLevelModel(
      level: json['level'],
      requiredExperience: json['requiredExperience'],
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'requiredExperience': requiredExperience,
  };
}
