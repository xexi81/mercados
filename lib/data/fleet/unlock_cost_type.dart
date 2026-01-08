enum UnlockCostType {
  free,
  money,
  gems;

  String get code {
    switch (this) {
      case UnlockCostType.free:
        return 'FREE';
      case UnlockCostType.money:
        return 'MONEY';
      case UnlockCostType.gems:
        return 'GEMS';
    }
  }

  static UnlockCostType fromCode(String code) {
    switch (code) {
      case 'FREE':
        return UnlockCostType.free;
      case 'MONEY':
        return UnlockCostType.money;
      case 'GEMS':
        return UnlockCostType.gems;
      default:
        throw ArgumentError('Unknown UnlockCostType code: $code');
    }
  }

  String get displayName {
    switch (this) {
      case UnlockCostType.free:
        return 'Gratis';
      case UnlockCostType.money:
        return 'Dinero';
      case UnlockCostType.gems:
        return 'Gemas';
    }
  }
}
