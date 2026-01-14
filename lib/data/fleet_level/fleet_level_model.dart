class FleetLevelModel {
  final int nivel;
  final int coste;
  final int capacidadBonus;

  FleetLevelModel({
    required this.nivel,
    required this.coste,
    required this.capacidadBonus,
  });

  factory FleetLevelModel.fromJson(Map<String, dynamic> json) {
    return FleetLevelModel(
      nivel: json['nivel'],
      coste: json['coste'],
      capacidadBonus: json['capacidad_bonus'],
    );
  }

  Map<String, dynamic> toJson() => {
    'nivel': nivel,
    'coste': coste,
    'capacidad_bonus': capacidadBonus,
  };
}
