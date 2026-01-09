enum ContainerType {
  bulkSolid,
  bulkLiquid,
  refrigerated,
  standard,
  heavy,
  hazardous;

  /// Returns the Spanish display name for this container type
  String get displayName {
    switch (this) {
      case ContainerType.bulkSolid:
        return 'Granel sólido';
      case ContainerType.bulkLiquid:
        return 'Granel líquido';
      case ContainerType.refrigerated:
        return 'Refrigerado';
      case ContainerType.standard:
        return 'Contenedor estándar';
      case ContainerType.heavy:
        return 'Carga pesada';
      case ContainerType.hazardous:
        return 'Peligroso';
    }
  }

  /// Returns the code string used in JSON
  String get code {
    switch (this) {
      case ContainerType.bulkSolid:
        return 'BULK_SOLID';
      case ContainerType.bulkLiquid:
        return 'BULK_LIQUID';
      case ContainerType.refrigerated:
        return 'REFRIGERATED';
      case ContainerType.standard:
        return 'STANDARD';
      case ContainerType.heavy:
        return 'HEAVY';
      case ContainerType.hazardous:
        return 'HAZARDOUS';
    }
  }

  /// Creates a ContainerType from a JSON code string
  static ContainerType fromCode(String code) {
    switch (code) {
      case 'BULK_SOLID':
        return ContainerType.bulkSolid;
      case 'BULK_LIQUID':
        return ContainerType.bulkLiquid;
      case 'REFRIGERATED':
        return ContainerType.refrigerated;
      case 'STANDARD':
        return ContainerType.standard;
      case 'HEAVY':
        return ContainerType.heavy;
      case 'HAZARDOUS':
        return ContainerType.hazardous;
      default:
        throw ArgumentError('Unknown container type code: $code');
    }
  }
}
