class AssociationModel {
  final String id;
  final String name;
  final String creatorId;
  final int level;
  final String? description;
  final String language; // Código de idioma: es, en, fr, etc.
  final double moneyPool;
  final double gemsPool;
  final int experiencePool;
  final bool isActive;
  final DateTime createdAt;

  AssociationModel({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.level,
    this.description,
    required this.language,
    this.moneyPool = 0,
    this.gemsPool = 0,
    this.experiencePool = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory AssociationModel.fromJson(Map<String, dynamic> json) {
    return AssociationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      creatorId: json['creator_id'] as String,
      level: json['level'] as int? ?? 1,
      description: json['description'] as String?,
      language: json['language'] as String? ?? 'es',
      moneyPool: (json['money_pool'] as num?)?.toDouble() ?? 0,
      gemsPool: (json['gems_pool'] as num?)?.toDouble() ?? 0,
      experiencePool: (json['experience_pool'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'creator_id': creatorId,
    'level': level,
    'description': description,
    'language': language,
    'money_pool': moneyPool,
    'gems_pool': gemsPool,
    'experience_pool': experiencePool,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  AssociationModel copyWith({
    String? id,
    String? name,
    String? creatorId,
    int? level,
    String? description,
    String? language,
    double? moneyPool,
    double? gemsPool,
    int? experiencePool,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AssociationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      level: level ?? this.level,
      description: description ?? this.description,
      language: language ?? this.language,
      moneyPool: moneyPool ?? this.moneyPool,
      gemsPool: gemsPool ?? this.gemsPool,
      experiencePool: experiencePool ?? this.experiencePool,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
