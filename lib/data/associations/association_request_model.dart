enum AssociationRequestStatus { pending, accepted, rejected }

extension AssociationRequestStatusExt on AssociationRequestStatus {
  String toJson() => name;
  static AssociationRequestStatus fromJson(String? json) {
    return AssociationRequestStatus.values.firstWhere(
      (e) => e.name == json,
      orElse: () => AssociationRequestStatus.pending,
    );
  }
}

class AssociationRequestModel {
  final String id;
  final String associationId;
  final String userId;
  final AssociationRequestStatus status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  AssociationRequestModel({
    required this.id,
    required this.associationId,
    required this.userId,
    this.status = AssociationRequestStatus.pending,
    required this.requestedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory AssociationRequestModel.fromJson(Map<String, dynamic> json) {
    return AssociationRequestModel(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      userId: json['user_id'] as String,
      status: AssociationRequestStatusExt.fromJson(json['status'] as String?),
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'association_id': associationId,
    'user_id': userId,
    'status': status.toJson(),
    'requested_at': requestedAt.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'resolved_by': resolvedBy,
  };
}
