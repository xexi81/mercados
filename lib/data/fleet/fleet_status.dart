enum FleetStatus {
  enDestino('en destino'),
  parado('parado'),
  enMarcha('en marcha'),
  accidentado('accidentado');

  final String value;
  const FleetStatus(this.value);

  @override
  String toString() => value;

  static FleetStatus fromString(String status) {
    return FleetStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => FleetStatus.enDestino,
    );
  }
}
