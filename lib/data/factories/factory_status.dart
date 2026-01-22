enum FactoryStatus {
  waiting('en espera'),
  manufacturing('fabricando'),
  broken('averiada');

  final String displayName;

  const FactoryStatus(this.displayName);

  static FactoryStatus fromString(String status) {
    switch (status) {
      case 'en espera':
        return FactoryStatus.waiting;
      case 'fabricando':
        return FactoryStatus.manufacturing;
      case 'averiada':
        return FactoryStatus.broken;
      default:
        return FactoryStatus.waiting;
    }
  }
}
