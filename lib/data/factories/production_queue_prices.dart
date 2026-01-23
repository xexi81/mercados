class ProductionQueuePrices {
  final int slot1Price;
  final int slot2Price;
  final int slot3Price;
  final int slot4Price;

  ProductionQueuePrices({
    required this.slot1Price,
    required this.slot2Price,
    required this.slot3Price,
    required this.slot4Price,
  });

  factory ProductionQueuePrices.fromJson(Map<String, dynamic> json) {
    return ProductionQueuePrices(
      slot1Price: json['slot1Price'] as int,
      slot2Price: json['slot2Price'] as int,
      slot3Price: json['slot3Price'] as int,
      slot4Price: json['slot4Price'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot1Price': slot1Price,
      'slot2Price': slot2Price,
      'slot3Price': slot3Price,
      'slot4Price': slot4Price,
    };
  }

  int getPriceForSlot(int slotNumber) {
    switch (slotNumber) {
      case 1:
        return slot1Price;
      case 2:
        return slot2Price;
      case 3:
        return slot3Price;
      case 4:
        return slot4Price;
      default:
        return 0;
    }
  }
}
