enum ContractStatus {
  pending,
  accepted,
  cancelled,
  fulfilled;

  String toJson() => name.toUpperCase();

  static ContractStatus fromJson(String json) {
    return ContractStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == json.toUpperCase(),
      orElse: () => ContractStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case ContractStatus.pending:
        return 'Pendiente';
      case ContractStatus.accepted:
        return 'Aceptado';
      case ContractStatus.cancelled:
        return 'Cancelado';
      case ContractStatus.fulfilled:
        return 'Finalizado';
    }
  }
}
