import 'contract_enums.dart';

class ContractModel {
  final String id;
  final String creatorId;
  final String? assigneeId;
  final int materialId;
  final int quantity;
  final int fulfilledQuantity;
  final int deadlineDays;
  final ContractStatus status;
  final String locationId;
  final int pendingStock;
  final int? acceptedPrice;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  ContractModel({
    required this.id,
    required this.creatorId,
    this.assigneeId,
    required this.materialId,
    required this.quantity,
    this.fulfilledQuantity = 0,
    required this.deadlineDays,
    this.status = ContractStatus.pending,
    required this.locationId,
    this.pendingStock = 0,
    this.acceptedPrice,
    required this.createdAt,
    this.acceptedAt,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    return ContractModel(
      id: json['id'],
      creatorId: json['creator_id'],
      assigneeId: json['assignee_id'],
      materialId: json['material_id'],
      quantity: json['quantity'],
      fulfilledQuantity: json['fulfilled_quantity'] ?? 0,
      deadlineDays: json['deadline_days'],
      status: ContractStatus.fromJson(json['status']),
      locationId: json['location_id'],
      pendingStock: json['pending_stock'] ?? 0,
      acceptedPrice: json['accepted_price'] != null
          ? (json['accepted_price'] as num).toInt()
          : null,
      createdAt: DateTime.parse(json['created_at']),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'creator_id': creatorId,
    'assignee_id': assigneeId,
    'material_id': materialId,
    'quantity': quantity,
    'fulfilled_quantity': fulfilledQuantity,
    'deadline_days': deadlineDays,
    'status': status.toJson(),
    'location_id': locationId,
    'pending_stock': pendingStock,
    'accepted_price': acceptedPrice,
    'accepted_at': acceptedAt?.toIso8601String(),
  };

  double get progress => quantity > 0 ? fulfilledQuantity / quantity : 0;
  int get remainingQuantity => quantity - fulfilledQuantity;

  bool get isFulfilled => fulfilledQuantity >= quantity;

  String get remainingTime {
    final start = acceptedAt ?? createdAt;
    final deadline = start.add(Duration(days: deadlineDays));
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) return 'EXPIRADO';

    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days > 0) {
      return '${days}D ${hours}H';
    } else {
      return '${hours}H RESTANTES';
    }
  }
}
